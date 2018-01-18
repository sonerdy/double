defmodule Double.Eval do
  @moduledoc """
  This is a simple GenServer that does a Code.eval_string while ignoring module conflict warnings.
  The need for a GenServer is to prevent two evaluations from executing simultaneously which has
  been observed to output the module conflict warnings due to the global nature of the setting.
  """

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def eval(code) do
    GenServer.call(__MODULE__, {:eval, code})
  end

  def init(initial) do
    {:ok, initial}
  end

  def handle_call({:eval, code}, _from, state) do
    Code.compiler_options(ignore_module_conflict: true)
    Code.eval_string(code)
    Code.compiler_options(ignore_module_conflict: false)
    {:reply, :ok, state}
  end
end
