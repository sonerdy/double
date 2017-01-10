defmodule Double do
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

  def handle_call({:set_pid, pid}, _from, dbl) do
    dbl = %{dbl | _pid: pid}
    {:reply, dbl, dbl}
  end

  def stub_function(pid, function_name, allowed_arguments) do
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
