defmodule Double do
  @moduledoc """
  Double builds on-the-fly injectable dependencies for your tests.
  It does NOT override behavior of existing modules or functions.
  Double uses Elixir's built-in language features such as pattern matching and message passing to
  give you everything you would normally need a complex mocking tool for.
  """

  alias Double.Registry
  alias Double.FuncList
  use GenServer

  @default_options [verify: true]

  @type allow_option :: {:with, [...]}
    | {:returns, any}
    | {:raises, String.t
    | {atom, String.t}}
  @type double_option :: {:verify, true | false}

  # API

  @spec double :: map
  @spec double(struct, [double_option]) :: struct
  @spec double(atom, [double_option]) :: atom
  @doc """
  Returns a map that can be used to setup stubbed functions.
  """
  def double, do: double(%{})
  @doc """
  Same as double/0 but can return structs and modules too
  """
  def double(source, opts \\ @default_options) do
    test_pid = self()
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    double_id = case is_atom(source) do
      true ->
        source_name = source |> Atom.to_string |> String.split(".") |> List.last
        "#{source_name}Double#{:erlang.unique_integer([:positive])}"
      false ->
        :sha
        |> :crypto.hash(inspect(pid))
        |> Base.encode16
        |> String.downcase
    end
    Registry.register_double(double_id, pid, test_pid, source, opts)
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
  @spec allow(any, atom, [function | [allow_option]]) :: struct | map | atom
  def allow(dbl, function_name) when is_atom(function_name), do: allow(dbl, function_name, with: [])
  def allow(dbl, function_name, func_opts) when is_list(func_opts) do
    return_values = Enum.reduce(func_opts, [], fn({k, v}, acc) ->
      if k == :returns, do: acc ++ [v], else: acc
    end)
    return_values = if return_values == [], do: [nil], else: return_values
    option_sets = return_values |> Enum.reduce([], fn(return_value, acc) ->
      append_opts = func_opts
      |> Keyword.take([:with, :raises])
      |> Keyword.put(:returns, return_value)
      acc ++ [append_opts]
    end)
    option_sets |> Enum.reduce(dbl, fn(opts, acc) ->
      {func, _} = create_function_from_opts(opts)
      allow(acc, function_name, func)
    end)
  end
  def allow(dbl, function_name, func) when is_function(func) do
    dbl
    |> verify_mod_double(function_name, func)
    |> verify_struct_double(function_name)
    |> do_allow(function_name, func)
  end

  @doc """
  Clears stubbed functions from a double. By passing no arguments (or nil) all functions will be
  cleared. A single function name (atom) or a list of function names can also be given.
  """
  @spec clear(any, atom | list) :: struct | map | atom
  def clear(dbl, function_name \\ nil) do
    double_id = if is_atom(dbl), do: Atom.to_string(dbl), else: dbl._double_id
    pid = Registry.whereis_double(double_id)
    GenServer.call(pid, {:clear, dbl, function_name})
  end

  @doc false
  def func_list(pid) do
    GenServer.call(pid, :func_list)
  end

  defp do_allow(dbl, function_name, func) do
    double_id = if is_atom(dbl), do: Atom.to_string(dbl), else: dbl._double_id
    pid = Registry.whereis_double(double_id)
    GenServer.call(pid, {:allow, dbl, function_name, func})
  end

  defp verify_mod_double(dbl, function_name, func) when is_atom(dbl) do
    double_opts = Registry.opts_for("#{dbl}")
    if double_opts[:verify] do
      source = Registry.source_for("#{dbl}")
      source_functions = source.module_info(:functions)
      source_functions = case source_functions[:behaviour_info] do
        nil -> source_functions
        _ ->
          behaviours = source.behaviour_info(:callbacks)
          source_functions |> Keyword.merge(behaviours)
      end
      stub_arity = :erlang.fun_info(func)[:arity]
      matching_function = Enum.find(source_functions, fn({k, v}) ->
        k == function_name && v == stub_arity
      end)
      if matching_function == nil do
        raise VerifyingDoubleError, message: "The function '#{function_name}/#{stub_arity}' is not defined in #{inspect dbl}"
      end
    end
    dbl
  end
  defp verify_mod_double(dbl, _, _), do: dbl

  defp verify_struct_double(%{__struct__: _} = dbl, function_name) do
    if Enum.member?(Map.keys(dbl), function_name) do
      dbl
    else
      struct_key_error(dbl, function_name)
    end
  end
  defp verify_struct_double(dbl, _), do: dbl

  # SERVER

  def init([]) do
    {:ok, pid} = GenServer.start_link(FuncList, [])
    {:ok, %{func_list: pid}}
  end

  @doc false
  def handle_call(:func_list, _from, state) do
    {:reply, state.func_list, state}
  end

  @doc false
  def handle_call({:allow, dbl, function_name, func}, _from, state) do
    FuncList.push(state.func_list, function_name, func)

    dbl = case is_atom(dbl) do
      true ->
        stub_module(dbl, state)
        dbl
      false ->
        dbl
        |> Map.put(
          function_name,
          stub_function(dbl._double_id, function_name, func)
        )
    end
    {:reply, dbl, state}
  end

  @doc false
  def handle_call({:clear, dbl, function_name}, _from, state) do
    FuncList.clear(state.func_list, function_name)
    {:reply, dbl, state}
  end

  defp stub_module(mod, state) do
    funcs = state.func_list
    |> FuncList.list
    |> Enum.uniq_by(fn({function_name, func}) ->
     {function_name, arity(func)}
    end)

    code = """
    defmodule :#{mod} do
    """
    code = Enum.reduce(funcs, code, fn({function_name, func}, acc) ->
      {signature, message} = function_parts(function_name, func)
      acc <> """
        def #{function_name}(#{signature}) do
          #{function_body(mod, message, function_name, signature)}
        end
      """
    end)

    code = code <> "\nend"
    Double.Eval.eval(code)
  end

  defp stub_function(double_id, function_name, func) do
    {signature, message} = function_parts(function_name, func)
    func_str = """
    fn(#{signature}) ->
      #{function_body(double_id, message, function_name, signature)}
    end
    """
    {result, _} = Code.eval_string(func_str)
    result
  end

  defp function_body(double_id, message, function_name, signature) do
    """
    test_pid = Double.Registry.whereis_test(\"#{double_id}\")
    send(test_pid, #{message})
    pid = Double.Registry.whereis_double(\"#{double_id}\")
    func_list = Double.func_list(pid)
    Double.FuncList.apply(func_list, :#{function_name}, [#{signature}])
    """
  end

  defp function_parts(function_name, func) do
    signature = case arity(func) do
      0 -> ""
      x ->
        0..(x - 1)
        |> Enum.map(fn(i) -> << 97 + i :: utf8 >> end)
        |> Enum.join(", ")
    end

    message = case signature do
      "" -> ":#{function_name}"
      _ -> "{:#{function_name}, #{signature}}"
    end
    {signature, message}
  end

  defp arity(func) do
    :erlang.fun_info(func)[:arity]
  end

  defp struct_key_error(dbl, key) do
    msg = "The struct #{dbl.__struct__} does not contain key: #{key}. Use a Map if you want to add dynamic function names."
    raise ArgumentError, message: msg
  end

  defp create_function_from_opts(opts) do
    args = case opts[:with] do
      {:any, with_arity} ->
        0..(with_arity - 1)
        |> Enum.map(fn(i) -> << 97 + i :: utf8 >> |> String.to_atom end)
        |> Enum.map(fn(arg_atom) -> {arg_atom, [], Elixir} end)
      nil -> []
      with_args -> with_args
    end
    args
    |> quoted_fn(opts)
    |> Code.eval_quoted
  end

  defp quoted_fn(args, opts) do
    {:fn, [], [{:->, [], [args, quoted_fn_body(opts, opts[:raises])]}]}
  end
  defp quoted_fn_body(_opts, {error_module, message}) do
    {
      :raise,
      [context: Elixir, import: Kernel],
      [{:__aliases__, [alias: false], [error_module]}, message]
    }
  end
  defp quoted_fn_body(_opts, message) when is_binary(message) do
    {
      :raise,
      [context: Elixir, import: Kernel],
      [message]
    }
  end
  defp quoted_fn_body(opts, nil) do
    opts[:returns]
  end
end
