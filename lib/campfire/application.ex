defmodule Campfire.Application do
  use Application

  def start(_, _) do
    children = [
      {Registry, keys: :duplicate, name: Campfire.Streams},
      {Registry, keys: :duplicate, name: Campfire.Connections},
      Campfire.RateLimiter,
      Campfire.FragmentCache,
      {Campfire.DB, path: System.get_env("DATABASE_PATH", "var/production.sqlite3")}
    ]

    children =
      if System.get_env("CAMPFIRE_JOBS_ADAPTER") == "disabled",
        do: children,
        else: children ++ [{Task.Supervisor, name: Campfire.JobTasks}, Campfire.Worker]

    children =
      if System.get_env("CAMPFIRE_NO_SERVER") == "1",
        do: children,
        else:
          children ++
            [
              {Bandit,
               plug: Campfire.Endpoint,
               http_options: [compress: false],
               port: String.to_integer(System.get_env("PORT", "7070")),
               ip:
                 if(System.get_env("CAMPFIRE_BIND") == "loopback",
                   do: {127, 0, 0, 1},
                   else: {0, 0, 0, 0}
                 )}
            ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Campfire.Supervisor)
  end
end
