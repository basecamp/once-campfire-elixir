defmodule Campfire.Application do
  use Application

  def start(_, _) do
    database_path = Campfire.Env.get("DATABASE_PATH", "var/production.sqlite3")

    children = [
      Campfire.Tables,
      {Registry, keys: :duplicate, name: Campfire.Streams},
      {Registry, keys: :duplicate, name: Campfire.Connections},
      Campfire.CookieMemo,
      Campfire.RateLimiter,
      Campfire.CableFrames,
      {Campfire.DB, path: database_path},
      {Campfire.ResponseCache, path: database_path}
    ]

    children =
      if System.schedulers_online() > 1 do
        # Two readers, not one per scheduler: measured on this workload, eight read-only
        # connections to the same file moved 154-157k single-row reads a second while eight callers
        # queueing on one connection moved 206-297k, because SQLite's WAL read accounting is
        # per-process bookkeeping. Two keeps a second connection for latency isolation without the
        # contention.
        children ++
          [
            {PartitionSupervisor,
             name: Campfire.DB.ReadPool,
             child_spec: {Campfire.DB, path: database_path, read_only: true, name: nil},
             partitions: min(System.schedulers_online(), 2)}
          ]
      else
        children
      end

    children =
      case {Campfire.Env.get("REDIS_URL"), Campfire.Env.get("CAMPFIRE_CABLE_REDIS_BRIDGE")} do
        {url, "1"} when is_binary(url) ->
          children ++
            [
              {Redix, {url, [name: Campfire.Redis]}},
              {Campfire.CableRedisBridge, url}
            ]

        {url, _} when is_binary(url) ->
          children ++
            [
              {Redix, {url, [name: Campfire.Redis]}}
            ]

        {nil, _} ->
          children
      end

    children =
      if Campfire.Env.get("CAMPFIRE_WORKER") == "1",
        do: children ++ [Campfire.Worker],
        else: children

    children =
      if Campfire.Env.get("CAMPFIRE_NO_SERVER") == "1",
        do: children,
        else:
          children ++
            [
              {Bandit,
               plug: Campfire.Endpoint,
               http_options: [compress: false],
               port: String.to_integer(Campfire.Env.get("PORT", "7070")),
               ip:
                 if(Campfire.Env.get("CAMPFIRE_BIND") == "loopback",
                   do: {127, 0, 0, 1},
                   else: {0, 0, 0, 0}
                 )}
            ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Campfire.Supervisor)
  end
end
