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

  You can stub the same function with the same args and different return values on subsequent calls.
  ```elixir
  double = double
  |> allow(:example, with: [1], returns: 1)
  |> allow(:example, with: [1], returns: 2)

  double.example.(1) # 2 the last setup is the first one to return
  double.example.(1) # 1
  double.example.(1) # 1 continues to return 1 until more return values are configured
  ```

  """
  use GenServer

  def double do
    current = self()
    state = %{_parent_pid: current, _pid: nil, _stubs: %{}}
    {:ok, pid} = GenServer.start_link(__MODULE__, state)
    GenServer.call(pid, {:set_pid, pid})
  end

  def allow(dbl, function_name, [with: args, returns: return_value]) do
    GenServer.call(dbl._pid, {:allow, function_name, args, return_value})
  end

  @doc false
  def handle_call({:pop_function, function_name, given_args}, _from, dbl) do
    stubs_data = Map.get(dbl._stubs, function_name)
    reversed_stubs = Enum.reverse(stubs_data)
    stub_data = Enum.find(reversed_stubs, fn({arg_pattern, _return_value}) ->
      case arg_pattern do
        {:any, _arity} -> true
        ^given_args -> true
        _ -> false
      end
    end)

    return_value = case stub_data do
      nil -> raise "Double not setup with #{function_name}(#{inspect given_args}). Available patterns/return values: #{inspect stubs_data}"
      {_arg_pattern, return_value} -> return_value
    end

    case Enum.count(stubs_data) do
      1 -> {:reply, return_value, dbl}
      _ ->
        new_stubs_data = List.delete(stubs_data, stub_data)
        new_dbl = %{dbl | _stubs: Map.merge(dbl._stubs, %{function_name => new_stubs_data})}
        {:reply, return_value, new_dbl}
    end
  end

  @doc false
  def handle_call({:allow, function_name, allowed_args, return_value}, _from, dbl) do
    dbl = case dbl do
      %{_stubs: %{^function_name => stub_data}} when is_list(stub_data) ->
        %{
          dbl | _stubs: Map.merge(
            dbl._stubs, %{function_name => stub_data ++ [{allowed_args, return_value}]}
          )
        }
      _ ->
        function_data = %{function_name => [{allowed_args, return_value}]}
        result = %{dbl | _stubs: Map.merge(dbl._stubs, function_data)}
        result =  Map.merge(result, %{function_name => stub_function(dbl._pid, function_name, allowed_args)})
        result
    end
    {:reply, dbl, dbl}
  end

  @doc false
  def handle_call({:set_pid, pid}, _from, dbl) do
    dbl = %{dbl | _pid: pid}
    {:reply, dbl, dbl}
  end

  defp stub_function(pid, function_name, allowed_arguments) do
    arity = case allowed_arguments do
      {:any, arity} -> arity
      _ -> Enum.count(allowed_arguments)
    end

    # There has to be a better way :(
    case arity do
      0 -> fn ->
        send(self(), function_name)
        GenServer.call(pid, {:pop_function, function_name, []})
      end
      1 -> fn(a) ->
        send(self(), {function_name, a})
        GenServer.call(pid, {:pop_function, function_name, [a]})
      end
      2 -> fn(a,b) ->
        send(self(), {function_name, a, b})
        GenServer.call(pid, {:pop_function, function_name, [a,b]})
      end
      3 -> fn(a,b,c) ->
        send(self(), {function_name, a, b, c})
        GenServer.call(pid, {:pop_function, function_name, [a,b,c]})
      end
      4 -> fn(a,b,c,d) ->
        send(self(), {function_name, a, b, c, d})
        GenServer.call(pid, {:pop_function, function_name, [a,b,c,d]})
      end
      5 -> fn(a,b,c,d,e) ->
        send(self(), {function_name, a, b, c, d, e})
        GenServer.call(pid, {:pop_function, function_name, [a,b,c,d,e]})
      end
      6 -> fn(a,b,c,d,e,f) ->
        send(self(), {function_name, a, b, c, d, e, f})
        GenServer.call(pid, {:pop_function, function_name, [a,b,c,d,e,f]})
      end
    end
  end
end
