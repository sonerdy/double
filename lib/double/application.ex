defmodule Double.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Double.Registry, []),
      worker(Double.Eval, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
