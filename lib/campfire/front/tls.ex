defmodule Campfire.Front.TLS do
  @moduledoc """
  HTTPS for `TLS_DOMAIN`, as Thruster provided it, with certificates from `site_encrypt`.

  Two listeners run under site_encrypt's supervision: HTTPS on `HTTPS_PORT` (HTTP/2 or
  HTTP/1.1 via ALPN) serving the app, and HTTP on `HTTP_PORT` answering ACME HTTP-01
  challenges and redirecting everything else to HTTPS. Certificates are ordered from
  `ACME_DIRECTORY` (Let's Encrypt by default) and renewed 30 days before they expire; a
  self-signed certificate serves until the first one arrives. They are stored under
  `THRUSTER_STORAGE_PATH/site_encrypt` on the storage volume.

  Unlike Thruster, only the HTTP-01 challenge is used, so `HTTP_PORT` must be reachable,
  and certificates Thruster stored are not reused: a new one is ordered on first start.
  `ACME_DIRECTORY=internal:PORT` runs site_encrypt's local ACME server, for tests.
  """
  use SiteEncrypt.Adapter
  @behaviour SiteEncrypt
  require SiteEncrypt
  alias Campfire.Front.Config

  def children(%Config{} = config, listener_options),
    do: [{__MODULE__, config: config, listener_options: listener_options}]

  def start_link(opts), do: SiteEncrypt.Adapter.start_link(__MODULE__, __MODULE__, opts)

  @impl SiteEncrypt.Adapter
  def config(_id, opts) do
    %{
      certification: certification(),
      site_spec: %{
        id: :listeners,
        type: :supervisor,
        start: {__MODULE__, :start_listeners, [opts]}
      }
    }
  end

  @impl SiteEncrypt.Adapter
  def http_port(_id, opts), do: {:ok, Keyword.fetch!(opts, :config).http_port}

  @impl SiteEncrypt
  def certification do
    config = Config.get()
    [domain | _] = config.tls_domains

    SiteEncrypt.configure(
      client: :native,
      domains: config.tls_domains,
      emails: [config.tls_email || "admin@" <> domain],
      db_folder: Path.join(config.storage_path, "site_encrypt"),
      directory_url: directory(config.acme_directory),
      key_size: 2048
    )
  end

  @impl SiteEncrypt
  def handle_new_cert, do: :ok

  defp directory("internal:" <> port), do: {:internal, port: String.to_integer(port)}
  defp directory(url), do: url

  def start_listeners(opts) do
    config = Keyword.fetch!(opts, :config)
    listener = Keyword.fetch!(opts, :listener_options)
    {tls_island, listener} = Keyword.pop(listener, :thousand_island_options, [])

    Supervisor.start_link(
      [
        Supervisor.child_spec(
          {Bandit,
           [plug: Campfire.Front.Redirect, scheme: :http, port: config.http_port] ++
             listener ++ [thousand_island_options: tls_island]},
          id: :http
        ),
        Supervisor.child_spec(
          {Bandit,
           [plug: Campfire.Endpoint, scheme: :https, port: config.https_port] ++
             listener ++
             [
               thousand_island_options:
                 tls_island ++ [transport_options: SiteEncrypt.https_keys(__MODULE__)]
             ]},
          id: :https
        )
      ],
      strategy: :one_for_one
    )
  end
end

defmodule Campfire.Front.Redirect do
  @moduledoc """
  The HTTP listener alongside HTTPS (`autocert.Manager.HTTPHandler`): ACME HTTP-01
  responses, a 301 to the same URL over HTTPS for `TLS_DOMAIN` hosts, and 421 for others.
  """
  import Plug.Conn
  @behaviour Plug

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/.well-known/acme-challenge/" <> _} = conn, _),
    do: SiteEncrypt.AcmeChallenge.call(conn, Campfire.Front.TLS)

  def call(conn, _) do
    host = conn.host |> String.trim_trailing(".") |> String.downcase()
    conn = put_resp_header(conn, "connection", "close")

    if host in Campfire.Front.Config.get().tls_domains do
      url =
        "https://" <>
          conn.host <>
          conn.request_path <> if(conn.query_string == "", do: "", else: "?" <> conn.query_string)

      body =
        if conn.method == "GET",
          do: ~s(<a href="#{Plug.HTML.html_escape(url)}">Moved Permanently</a>.\n\n),
          else: ""

      conn
      |> put_resp_header("location", url)
      |> then(
        &if(conn.method in ["GET", "HEAD"], do: put_resp_content_type(&1, "text/html"), else: &1)
      )
      |> send_resp(301, body)
    else
      conn |> put_resp_content_type("text/plain") |> send_resp(421, "Misdirected Request\n")
    end
  end
end
