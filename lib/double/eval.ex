defmodule Double.Eval do
  def eval(code) do
    %{ignore_module_conflict: ignore_module_conflict} = Code.compiler_options()
    Code.compiler_options(ignore_module_conflict: true)
    Code.eval_string(code)
    Code.compiler_options(ignore_module_conflict: ignore_module_conflict)
  end

  def init(initial) do
    {:ok, initial}
  end
end
