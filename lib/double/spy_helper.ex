defmodule Double.SpyHelper do
  @moduledoc """
  Helper functions for spy args
  """

  def create_args(_, 0), do: []

  def create_args(fn_mod, arg_cnt) do
    Enum.map(1..arg_cnt, &Macro.var(:"arg#{&1}", fn_mod))
  end
end
