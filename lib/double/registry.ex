defmodule Double.Registry do
  @moduledoc false

  use GenServer

  # API

  def start do
    GenServer.start(__MODULE__, nil, name: :registry)
  end

  def whereis_double(double_id) do
    GenServer.call(:registry, {:whereis_double, double_id})
  end

  def whereis_test(double_id) do
    GenServer.call(:registry, {:whereis_test, double_id})
  end

  def source_for(double_id) do
    GenServer.call(:registry, {:source_for, double_id})
  end

  def opts_for(double_id) do
    GenServer.call(:registry, {:opts_for, double_id})
  end

  def register_double(double_id, pid, test_pid, source, opts) do
    arg = {:register_id, double_id, pid, test_pid, source, opts}
    GenServer.call(:registry, arg)
  end

  # SERVER

  def init(_) do
    {:ok, Map.new}
  end

  def handle_call({:whereis_double, double_id}, _from, state) do
    {double_pid, _, _, _} = state
    |> Map.get(double_id, {:undefined, nil, nil, nil})
    {:reply, double_pid, state}
  end

  def handle_call({:whereis_test, double_id}, _from, state) do
    {_, test_pid, _, _} = Map.get(state, double_id, {:undefined, nil, nil, nil})
    {:reply, test_pid, state}
  end

  def handle_call({:source_for, double_id}, _from, state) do
    {_, _, source, _} = Map.get(state, double_id, {:undefined, nil, nil, nil})
    {:reply, source, state}
  end

  def handle_call({:opts_for, double_id}, _from, state) do
    {_, _, _, opts} = Map.get(state, double_id, {:undefined, nil, nil, nil})
    {:reply, opts, state}
  end

  def handle_call({:register_id, double_id, pid, test_pid, source, opts}, _from, state) do
    case Map.get(state, double_id) do
      nil ->
        {:reply, :yes, Map.put(state, double_id, {pid, test_pid, source, opts})}

      _ ->
        {:reply, :no, state}
    end
  end
end
