defmodule Campfire.Front.Server do
  @moduledoc """
  The listeners Thruster used to provide: plain HTTP on `HTTP_PORT`, or with `TLS_DOMAIN`,
  HTTPS (HTTP/2 via ALPN) on `HTTPS_PORT` with automatic certificates, and an HTTP listener
  that answers ACME challenges and redirects everything else to HTTPS.
  """
  alias Campfire.Front.Config

  def children(%Config{} = config) do
    Campfire.Front.setup_logging(config)

    if Config.tls?(config),
      do: Campfire.Front.TLS.children(config, listener_options(config)),
      else: [
        {Bandit,
         [plug: Campfire.Endpoint, scheme: :http, port: config.http_port] ++
           listener_options(config)}
      ]
  end

  def listener_options(config) do
    [
      ip: :any,
      http_options: [compress: false],
      thousand_island_options: [read_timeout: max(config.idle_timeout, config.read_timeout)]
    ]
  end
end
