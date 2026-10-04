defmodule @@MODULE@@.Application do
  use Application
  def start(_, _), do: Supervisor.start_link([{Bandit, plug: @@MODULE@@.Router, port: 7070}], strategy: :one_for_one)
end
