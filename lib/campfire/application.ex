defmodule Campfire.Application do
  use Application

  def start(_, _) do
    children = [
      {Registry, keys: :duplicate, name: Campfire.Streams},
      {Registry, keys: :duplicate, name: Campfire.Connections},
      Campfire.RateLimiter,
      Campfire.FragmentCache,
      Campfire.Front.Cache,
      {Campfire.DB, path: System.get_env("DATABASE_PATH", "var/production.sqlite3")}
    ]

    children =
      if System.get_env("CAMPFIRE_JOBS_ADAPTER") == "disabled",
        do: children,
        else: children ++ [{Task.Supervisor, name: Campfire.JobTasks}, Campfire.Worker]

    children =
      if System.get_env("CAMPFIRE_NO_SERVER") == "1",
        do: children,
        else: children ++ Campfire.Front.Server.children(Campfire.Front.Config.load())

    Supervisor.start_link(children, strategy: :one_for_one, name: Campfire.Supervisor)
  end
end
