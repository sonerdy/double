defmodule Double do
  @moduledoc """
  Double is a simple library to help build injectable dependencies for your tests.
  It does NOT override behavior of existing modules or functions.
  """

  use GenServer

  @type option :: {:with, [...]} | {:returns, any} | {:raises, String.t | {atom, String.t}}

  # API

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
    Double.Registry.start
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    double_id = :crypto.hash(:sha, pid |> inspect) |> Base.encode16 |> String.downcase
    Double.Registry.register_double(double_id, pid)
    Map.put(struct_or_map, :_double_id, double_id)
  end

  @doc """
  Adds a stubbed function to the given map or struct.
  Structs will only work if they contain the key given for function_name.
  """
  @spec allow(map | struct, atom, [option]) :: map | struct
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
    args = opts[:with] || []
    raises = opts[:raises]
    pid = Double.Registry.whereis_double(dbl._double_id)
    GenServer.call(pid, {:allow, dbl, function_name, args, return_values, raises})
  end

  # SERVER

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
    stubs = stubs |> Enum.reject(fn(stub) -> match?({^function_name, ^args, _return_value}, stub) end)
    stubs = stubs ++ Enum.map(return_values, fn(return_value) ->
      {function_name, args, return_value}
    end)
    dbl = put_in(dbl, [Access.key(function_name)], stub_function(dbl._double_id, function_name, args, raises))
    {:reply, dbl, stubs}
  end

  defp matching_stubs(stubs, function_name, args) do
    Enum.filter(stubs, fn(stub) -> matching_stub?(stub, function_name, args) end)
    |> Enum.sort_by(fn(stub) ->
      case stub do
        {_function_name, {:any, _arity}, _return_value} -> 1
        _ -> 0
      end
    end)
  end

  defp matching_stub?(stub, function_name, args) do
    match?({^function_name, ^args, _return_value}, stub) ||
    match?({^function_name, {:any, _arity}, _return_value}, stub)
  end

  defp stub_function(double_id, function_name, allowed_arguments, raises) do
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
      pid = Double.Registry.whereis_double(\"#{double_id}\")
      GenServer.call(pid, {:pop_function, :#{function_name}, [#{function_signature}]})
      #{error_code}
    end
    """
    {result, _} = Code.eval_string(function_string)
    result
  end

  defp struct_key_error(dbl, key) do
    msg = "The struct #{dbl.__struct__} does not contain key: #{key}. Use a Map if you want to add dynamic function names."
    raise ArgumentError, message: msg
  end
end
