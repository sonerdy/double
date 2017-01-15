defmodule Double do
  @moduledoc """
  Double is a simple library to help build injectable dependencies for your tests.
  It does NOT override behavior of existing modules or functions.
  """

  use GenServer

  @type option :: {:with, [...]} | {:returns, any} | {:raises, String.t | {atom, String.t}}

  @spec double :: map
  @spec double(map | struct) :: map | struct
  @doc """
  Returns a map that can be used to setup stubbed functions.
  """
  def double do
    double(%{})
  end
  @doc """
  Same as double/0 but returns the same map or struct given
  """
  def double(struct_or_map) do
    case GenServer.start_link(__MODULE__, {[], []}, name: __MODULE__) do
      {:ok, _pid} -> struct_or_map
      {:error, {:already_started, _pid}} -> struct_or_map
    end
    struct_or_map
  end

  @doc """
  Adds a stubbed function to the given map or struct.
  Structs will only work if they contain the key given for function_name.
  """
  @spec allow(map | struct, atom, [option]) :: map | struct
  def allow(dbl, function_name, opts \\ []) when is_list(opts) do
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
    args = opts[:with] || []
    raises = opts[:raises]
    expected = opts[:expected] == true
    GenServer.call(__MODULE__, {:allow, dbl, function_name, args, return_values, raises, expected})
  end

  def expect(dbl, function_name, opts \\ []) when is_list(opts) do
    opts = opts ++ [expected: true]
    allow(dbl, function_name, opts)
  end

  def verify_doubles do
    {:messages, messages} = Process.info(self(), :messages)
    GenServer.call(__MODULE__, :get_expects)
    |> Enum.each(fn(expected) ->
      case Enum.find(messages, fn(msg) ->
        case expected do
          {function_name, {:any, arity}} ->
            (is_tuple(msg) && (tuple_size(msg) == (arity + 1)) && elem(msg, 0) == function_name)
          _ -> msg == expected
        end
      end) do
        nil -> raise Double.DoubleVerificationError, expected: expected, messages: messages
        _ -> :ok
      end
    end)
  end

  defp struct_key_error(dbl, key) do
    msg = "The struct #{dbl.__struct__} does not contain key: #{key}. Use a Map if you want to add dynamic function names."
    raise ArgumentError, message: msg
  end

  @doc false
  def handle_call(:get_expects, _from, {stubs, expects}) do
    {:reply, expects, {stubs, expects}}
  end

  @doc false
  def handle_call({:pop_function, function_name, args}, _from, {stubs, expects}) do
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
        {:reply, return_value, {stubs, expects}}
      [] -> {:reply, nil, {stubs, expects}}
    end
  end

  @doc false
  def handle_call({:allow, dbl, function_name, args, return_values, raises, expected}, _from, {stubs, expects}) do
    matching_stubs = matching_stubs(stubs, function_name, args)
    stubs = stubs |> Enum.reject(fn(stub) -> Enum.member?(matching_stubs, stub) end)
    stubs = stubs ++ Enum.map(return_values, fn(return_value) ->
      {function_name, args, return_value}
    end)
    dbl = put_in(dbl, [Access.key(function_name)], stub_function(function_name, args, raises))
    expects = if expected do
      expected_msg = case args do
        [] -> function_name
        {:any, arity} -> {function_name, {:any, arity}}
        _ -> [function_name] ++ args |> List.to_tuple
      end
      expects ++ [expected_msg]
    else
      expects
    end
    {:reply, dbl, {stubs, expects}}
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

  defmodule DoubleVerificationError do
    @moduledoc """
    Raised to signal an error verifying doubles.
    """

    defexception message: nil, expected: nil, messages: nil

    def message(ex) do
      "\n\n" <>
        "Expected to receive #{inspect ex.expected}. " <>
        "Mailbox contained: #{inspect ex.messages}"
    end
  end
end
