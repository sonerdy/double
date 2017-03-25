defmodule Double do
  @moduledoc """
  Double builds on-the-fly injectable dependencies for your tests.
  It does NOT override behavior of existing modules or functions.
  """

  use GenServer

  @type option :: {:with, [...]} | {:returns, any} | {:raises, String.t | {atom, String.t}}
  @type double_option :: {:verify, true | false}

  # API

  @spec double :: map :: atom
  @spec double(map | struct | atom) :: map | struct | atom
  @spec double(map | struct | atom, opts :: double_option) :: map | struct | atom
  @doc """
  Returns a map that can be used to setup stubbed functions.
  """
  def double() do
    double(%{})
  end
  @doc """
  Same as double/0 but can return structs and modules too
  """
  def double(source, opts \\ [verify: true]) do
    Double.Registry.start
    test_pid = self()
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    double_id = case is_atom(source) do
      true ->
        source_name = source |> Atom.to_string |> String.split(".") |> List.last
        "#{source_name}Double#{:erlang.unique_integer([:positive])}"
      false -> :crypto.hash(:sha, pid |> inspect) |> Base.encode16 |> String.downcase
    end
    Double.Registry.register_double(double_id, pid, test_pid, source, opts)
    case is_atom(source) do
      true -> double_id |> String.to_atom
      false -> Map.put(source, :_double_id, double_id)
    end
  end

  @doc """
  Adds a stubbed function to the given map, struct, or module.
  Structs will fail if they are missing the key given for function_name.
  Modules will fail if the function is not defined.
  """
  @spec allow(map | struct | atom, atom, [option]) :: map | struct
  def allow(dbl, function_name, opts) when is_list(opts) do
    verify_mod_double(dbl, function_name, opts)
    |> verify_struct_double(function_name)
    |> do_allow(function_name, opts)
  end

  defp do_allow(dbl, function_name, opts) when is_list(opts) do
    return_values = Enum.reduce(opts, [], fn({k, v}, acc) ->
      if k == :returns, do: acc ++ [v], else: acc
    end)
    return_values = if return_values == [], do: [nil], else: return_values
    args = opts[:with] || []
    raises = opts[:raises]
    double_id = if is_atom(dbl), do: Atom.to_string(dbl), else: dbl._double_id
    pid = Double.Registry.whereis_double(double_id)
    GenServer.call(pid, {:allow, dbl, function_name, args, return_values, raises})
  end

  defp verify_mod_double(dbl, function_name, opts) when is_atom(dbl) do
    double_opts = Double.Registry.opts_for("#{dbl}")
    if double_opts[:verify] do
      source = Double.Registry.source_for("#{dbl}")
      source_functions = source.__info__(:functions)
      stub_arity = arity(opts[:with])
      matching_function = Enum.find(source_functions, fn({k, v}) ->
        k == function_name && v == stub_arity
      end)
      if matching_function == nil do
        raise VerifyingDoubleError, message: "The function '#{function_name}/#{stub_arity}' is not defined in TestModuleDouble"
      end
    end
    dbl
  end
  defp verify_mod_double(dbl, _, _), do: dbl

  defp verify_struct_double(%{__struct__: _} = dbl, function_name) do
    if Enum.member?(Map.keys(dbl), function_name), do: dbl, else: struct_key_error(dbl, function_name)
  end
  defp verify_struct_double(dbl, _), do: dbl

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
    dbl = case is_atom(dbl) do
      true ->
        stub_module(dbl, stubs, raises)
        dbl
      false -> Map.put(dbl, function_name, stub_function(dbl._double_id, function_name, args, raises))
    end
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

  defp stub_module(mod, stubs, raises) do
    stubs = stubs |> Enum.uniq_by(fn({function_name, allowed_arguments, _}) ->
     {function_name, arity(allowed_arguments)}
    end)
    code = """
    defmodule :#{mod} do
    """
    code = Enum.reduce(stubs, code, fn({function_name, allowed_arguments, _}, acc) ->
      {signature, message, error} = function_pieces(function_name, allowed_arguments, raises)
      acc <> """
        def #{function_name}(#{signature}) do
          #{function_body(mod, message, function_name, signature, error)}
        end
      """
    end)

    code = code <> "\nend"
    Code.compiler_options(ignore_module_conflict: true)
    Code.eval_string(code)
    Code.compiler_options(ignore_module_conflict: false)
  end

  defp stub_function(double_id, function_name, allowed_arguments, raises) do
    {signature, message, error_code} = function_pieces(function_name, allowed_arguments, raises)
    function_string = """
    fn(#{signature}) ->
      #{function_body(double_id, message, function_name, signature, error_code)}
    end
    """
    {result, _} = Code.eval_string(function_string)
    result
  end

  defp function_body(double_id, message, function_name, signature, error_code) do
    """
    test_pid = Double.Registry.whereis_test(\"#{double_id}\")
    send(test_pid, #{message})
    pid = Double.Registry.whereis_double(\"#{double_id}\")
    GenServer.call(pid, {:pop_function, :#{function_name}, [#{signature}]})
    #{error_code}
    """
  end

  defp arity(allowed_arguments) do
    case allowed_arguments do
      nil -> 0
      {:any, arity} -> arity
      _ -> Enum.count(allowed_arguments)
    end
  end

  defp function_pieces(function_name, allowed_arguments, raises) do
    error_code = case raises do
      {error_type, msg} -> "raise #{error_type}, message: \"#{msg}\""
      msg when is_bitstring(msg) -> "raise \"#{msg}\""
      _ -> ""
    end
    arity = arity(allowed_arguments)
    function_signature = case arity do
      0 -> ""
      _ -> Enum.map(0..arity - 1, fn(i) -> << 97 + i :: utf8 >> end) |> Enum.join(", ")
    end
    message = case function_signature do
      "" -> ":#{function_name}"
      _ -> "{:#{function_name}, #{function_signature}}"
    end
    {function_signature, message, error_code}
  end

  defp struct_key_error(dbl, key) do
    msg = "The struct #{dbl.__struct__} does not contain key: #{key}. Use a Map if you want to add dynamic function names."
    raise ArgumentError, message: msg
  end
end
