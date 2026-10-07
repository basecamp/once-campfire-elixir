defmodule Campfire.Application do
  use Application

  def start(_, _) do
    database_path = System.get_env("DATABASE_PATH", "var/production.sqlite3")

    children = [
      {Registry, keys: :duplicate, name: Campfire.Streams},
      {Registry, keys: :duplicate, name: Campfire.Connections},
      Campfire.RateLimiter,
      Campfire.FragmentCache,
      Campfire.CableFrames,
      {Campfire.DB, path: database_path},
      {Campfire.ResponseCache, path: database_path}
    ]

    children =
      if System.schedulers_online() > 1 do
        children ++
          [
            {PartitionSupervisor,
             name: Campfire.DB.ReadPool,
             child_spec: {Campfire.DB, path: database_path, read_only: true, name: nil},
             partitions: min(System.schedulers_online(), 8)}
          ]
      else
        children
      end

    children = children ++ Campfire.HtmlParser.children()

    children =
      case {System.get_env("REDIS_URL"), System.get_env("CAMPFIRE_CABLE_REDIS_BRIDGE")} do
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
      if System.get_env("CAMPFIRE_WORKER") == "1",
        do: children ++ [Campfire.Worker],
        else: children

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
