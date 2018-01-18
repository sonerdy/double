defmodule Double.FuncList do
  alias Double.FuncList
  @moduledoc false

  use GenServer

  defstruct funcs: [], applied_funcs: [], dbl: nil

  def init([]) do
    {:ok, %FuncList{}}
  end

  def push(pid, function_name, func) when is_function(func) and is_atom(function_name) do
    GenServer.call(pid, {:push, function_name, func})
  end

  def clear(_pid, _function_name \\ nil)
  def clear(_pid, []), do: :ok

  def clear(pid, [function_name, function_names]) do
    clear(pid, function_name)
    clear(pid, function_names)
  end

  def clear(pid, function_name) do
    GenServer.call(pid, {:clear, function_name})
  end

  def apply(pid, function_name, args) when is_atom(function_name) and is_list(args) do
    state = GenServer.call(pid, :state)

    funcs =
      state.funcs
      |> Enum.filter(fn {func_name, _} -> func_name == function_name end)

    applied_funcs =
      state.applied_funcs
      |> Enum.filter(fn {func_name, _} -> func_name == function_name end)

    verify_function_name_and_arity(funcs ++ applied_funcs, function_name, args)

    return_value =
      case try_apply(funcs, args) do
        :notfound ->
          case try_apply(applied_funcs, args) do
            :notfound ->
              FunctionClauseError
              |> raise(function: function_name, arity: Enum.count(args))

            {:ok, return_value, _found} ->
              return_value
          end

        {:ok, return_value, found} ->
          GenServer.call(pid, {:mark_applied, found})
          return_value
      end

    return_value
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  # SERVER

  def handle_call(:list, _from, state) do
    {:reply, state.funcs ++ state.applied_funcs, state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:push, function_name, func}, _from, state) do
    state = %FuncList{state | funcs: state.funcs ++ [{function_name, func}]}
    {:reply, :ok, state}
  end

  def handle_call({:clear, function_name}, _from, state) do
    state =
      case function_name do
        nil ->
          %FuncList{}

        _ ->
          predicate = fn {func_name, _} -> func_name == function_name end

          new_funcs =
            state.funcs
            |> Enum.reject(predicate)

          new_applied_funcs =
            state.applied_funcs
            |> Enum.reject(predicate)

          %FuncList{state | funcs: new_funcs, applied_funcs: new_applied_funcs}
      end

    {:reply, state, state}
  end

  def handle_call({:mark_applied, {func_name, func}}, _from, state) do
    new_funcs = List.delete(state.funcs, {func_name, func})

    state =
      case new_funcs == state.funcs do
        true ->
          state

        false ->
          new_applied_funcs = [{func_name, func}] ++ state.applied_funcs
          %FuncList{state | funcs: new_funcs, applied_funcs: new_applied_funcs}
      end

    {:reply, :ok, state}
  end

  defp try_apply([], _args), do: :notfound

  defp try_apply([{func_name, func} | funcs], args) do
    {:ok, apply(func, args), {func_name, func}}
  rescue
    BadArityError -> try_apply(funcs, args)
    FunctionClauseError -> try_apply(funcs, args)
  end

  defp verify_function_name_and_arity(all_funcs, function_name, args) do
    needed_arity = Enum.count(args)

    matches =
      all_funcs
      |> Enum.filter(fn {func_name, func} ->
        func_arity = :erlang.fun_info(func)[:arity]
        func_name == function_name and func_arity == needed_arity
      end)

    if Enum.count(matches) == 0 do
      raise UndefinedFunctionError, function: function_name, arity: needed_arity
    end
  end
end
