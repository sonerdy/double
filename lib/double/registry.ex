defmodule Double.Registry do

  use GenServer

  # API

  def start do
    GenServer.start(__MODULE__, nil, name: :registry)
  end

  def whereis_double(double_id) do
    GenServer.call(:registry, {:whereis_double, double_id})
  end

  def register_double(double_id, pid) do
    GenServer.call(:registry, {:register_id, double_id, pid})
  end

  # SERVER

  def init(_) do
    {:ok, Map.new}
  end

  def handle_call({:whereis_double, double_id}, _from, state) do
    {:reply, Map.get(state, double_id, :undefined), state}
  end

  def handle_call({:register_id, double_id, pid}, _from, state) do
    case Map.get(state, double_id) do
      nil ->
        {:reply, :yes, Map.put(state, double_id, pid)}

      _ ->
        {:reply, :no, state}
    end
  end
end
