require IEx
defmodule Double do
  @moduledoc """
  Double is a simple library to help build injectable dependencies for your tests.
  It does NOT override behavior of existing modules or functions.

  ## Installation

  The package can be installed as:

    1. Add `double` to your list of dependencies in `mix.exs`:

      ```elixir
      def deps do
        [{:double, "~> 0.1.2", only: :test}]
      end
      ```

  ## Usage

  The first step is to make sure the function you want to test will have it's dependencies injected.
  This library requires usage of maps, but maybe in future versions we can do something different.

  ```elixir
  defmodule Example do
    @inject %{
      puts: &IO.puts/1,
      some_service: &SomeService.process/3,
    }

    def process(inject \\ @inject)
      inject.puts.("It works without mocking libraries")
      inject.some_service.(1, 2, 3)
    end
  end
  ```

  Now for an example on how to test this interaction.

  ```elixir
  defmodule ExampleTest do
    use ExUnit.Case
    import Double

    test "example interacts with things" do
      inject = double
      |> allow(:puts, with: {:any, 1}, returns: :ok) # {:any, x} will accept any values of arity x
      |> allow(:some_service, with: [1, 2, 3], returns: :ok) # strictly accepts 3 arguments

      Example.process(inject)

      # now just use the built-in ExUnit methods assert_receive/refute_receive to verify things
      assert_receive({:puts, "It works without mocking librarires"})
      assert_receive({:some_service, 1, 2, 3})
    end
  end
  ```

  ## More Features

  You can stub the same function with different args and return values.
  ```elixir
  double = double
  |> allow(:example, with: [1], returns: 1)
  |> allow(:example, with: [2], returns: 2)
  |> allow(:example, with: [3], returns: 3)

  double.example.(1) # 1
  double.example.(2) # 2
  double.example.(3) # 3
  ```

  You can stub the same function/args to return different results on subsequent calls
  ```elixir
  double = double
  |> allow(:example, with: [1], returns: 1, returns: 2)

  double.example.(1) # 1
  double.example.(1) # 2
  double.example.(1) # 2
  ```

  Use a struct if you want to verify the keys being stubbed.

  ```elixir
  double = double(%MyStruct{})
  |> allow(:example, with: ["hello"], returns: "world")
  ```

  """
  use GenServer

  @type stub_options :: [{:with, [...]}, {:returns, [...]}]

  @spec double :: map
  @spec double(map | struct) :: map | struct
  def double do
    double(%{})
  end
  def double(struct_or_map) do
    case GenServer.start_link(__MODULE__, [], name: __MODULE__) do
      {:ok, _pid} -> struct_or_map
      {:error, {:already_started, _pid}} -> struct_or_map
    end
    struct_or_map
  end

  @spec allow(map | struct, String.t, stub_options) :: map | struct
  def allow(dbl, function_name, opts) when is_list(opts) do
    case dbl do
      %{__struct__: _} ->
        case Enum.member?(Map.keys(dbl), function_name) do
          true -> do_allow(dbl, function_name, opts)
          false -> struct_key_error(dbl, function_name)
        end
      _ -> do_allow(dbl, function_name, opts)
    end
  end
  defp do_allow(dbl, function_name, opts) when is_list(opts) do
    return_values = Enum.reduce(opts, [], fn({k, v}, acc) ->
      case k do
        :returns -> acc ++ [v]
        _ -> acc
      end
    end)
    return_values = if return_values == [], do: [nil], else: return_values
    args = opts[:with]
    raises = opts[:raises]
    GenServer.call(__MODULE__, {:allow, dbl, function_name, args, return_values, raises})
  end

  defp struct_key_error(dbl, key) do
    msg = "The struct #{dbl.__struct__} does not contain key: #{key}. Use a Map if you want to add dynamic function names."
    raise ArgumentError, message: msg
  end

  @doc false
  def handle_call({:pop_function, function_name, args}, _from, stubs) do
    matching_stubs = matching_stubs(stubs, function_name, args)
    case matching_stubs do
      [stub | other_matching_stubs] ->
        # remove this stub from stack only if it's not the only matching one
        stubs = if Enum.empty?(other_matching_stubs) do
          stubs
        else
          List.delete(stubs, stub)
        end
        {_, _, return_value} = stub
        {:reply, return_value, stubs}
      [] -> {:reply, nil, stubs}
    end
  end

  @doc false
  def handle_call({:allow, dbl, function_name, args, return_values, raises}, _from, stubs) do
    matching_stubs = matching_stubs(stubs, function_name, args)
    stubs = stubs |> Enum.reject(fn(stub) -> Enum.member?(matching_stubs, stub) end)
    stubs = stubs ++ Enum.map(return_values, fn(return_value) ->
      {function_name, args, return_value}
    end)
    dbl = put_in(dbl, [Access.key(function_name)], stub_function(function_name, args, raises))
    {:reply, dbl, stubs}
  end

  defp matching_stubs(stubs, function_name, args) do
    Enum.filter(stubs, fn(stub) -> matching_stub?(stub, function_name, args) end)
  end

  defp matching_stub?(stub, function_name, args) do
    match?({^function_name, ^args, _return_value}, stub) ||
    match?({^function_name, {:any, _arity}, _return_value}, stub)
  end

  defp stub_function(function_name, allowed_arguments, raises) do
    error_code = case raises do
      {error_type, msg} -> "raise #{error_type}, message: \"#{msg}\""
      msg when is_bitstring(msg) -> "raise \"#{msg}\""
      _ -> ""
    end
    arity = case allowed_arguments do
      {:any, arity} -> arity
      _ -> Enum.count(allowed_arguments)
    end
    function_signature = case arity do
      0 -> ""
      _ -> Enum.map(0..arity - 1, fn(i) -> << 97 + i :: utf8 >> end) |> Enum.join(", ")
    end
    message = case function_signature do
      "" -> ":#{function_name}"
      _ -> "{:#{function_name}, #{function_signature}}"
    end
    function_string = """
    fn(#{function_signature}) ->
      send(self(), #{message})
      GenServer.call(Double, {:pop_function, :#{function_name}, [#{function_signature}]})
      #{error_code}
    end
    """
    {result, _} = Code.eval_string(function_string)
    result
  end
end
