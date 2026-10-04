defmodule Campfire.Application do
  use Application

  def start(_, _) do
    Campfire.HttpCompression.configure_level()

    children = [
      {Registry, keys: :duplicate, name: Campfire.Streams},
      {Registry, keys: :duplicate, name: Campfire.Connections},
      Campfire.RateLimiter,
      Campfire.FragmentCache,
      Campfire.CableFrames,
      Campfire.ResponseCache,
      Campfire.LocalQueue,
      {Campfire.DB, path: System.get_env("DATABASE_PATH", "var/production.sqlite3")}
    ]

    children = children ++ Campfire.HtmlParser.children()

    children =
      case System.get_env("REDIS_URL") do
        nil ->
          children

        url ->
          children ++
            [
              {Redix, {url, [name: Campfire.Redis]}},
              %{
                id: Campfire.CableRedis,
                start: {Redix.PubSub, :start_link, [url, [name: Campfire.CableRedis]]}
              }
            ]
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
