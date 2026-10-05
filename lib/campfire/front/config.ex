defmodule Campfire.Front.Config do
  @moduledoc """
  Settings of the in-process front server, under Thruster 0.1.23's environment names.

  Each setting reads `THRUSTER_<NAME>`, falling back to `<NAME>`; a value that does not parse
  keeps the default. The certificate store reads only `THRUSTER_STORAGE_PATH`, since the app
  uses `STORAGE_PATH` for its files.
  """
  @mb 1024 * 1024
  defstruct [
    :http_port,
    :https_port,
    :tls_domains,
    :acme_directory,
    :tls_email,
    :storage_path,
    :cache_size,
    :max_cache_item_size,
    :gzip_enabled,
    :gzip_disable_on_auth,
    :gzip_jitter,
    :max_request_body,
    :idle_timeout,
    :read_timeout,
    :write_timeout,
    :forward_headers,
    :log_requests
  ]

  def get do
    case :persistent_term.get(__MODULE__, nil) do
      nil -> load()
      config -> config
    end
  end

  def load(env \\ System.get_env()) do
    find = fn key -> env["THRUSTER_" <> key] || env[key] end

    int = fn key, default ->
      case Integer.parse(find.(key) || "") do
        {value, ""} -> value
        _ -> default
      end
    end

    boolean = fn key, default ->
      case find.(key) do
        value when value in ~w(1 t T TRUE true True) -> true
        value when value in ~w(0 f F FALSE false False) -> false
        _ -> default
      end
    end

    tls_domains =
      (find.("TLS_DOMAIN") || "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    config = %__MODULE__{
      http_port: int.("HTTP_PORT", int.("PORT", 80)),
      https_port: int.("HTTPS_PORT", 443),
      tls_domains: tls_domains,
      acme_directory: find.("ACME_DIRECTORY") || "https://acme-v02.api.letsencrypt.org/directory",
      tls_email: find.("TLS_EMAIL"),
      storage_path: env["THRUSTER_STORAGE_PATH"] || "/rails/storage/thruster",
      cache_size: int.("CACHE_SIZE", 64 * @mb),
      max_cache_item_size: int.("MAX_CACHE_ITEM_SIZE", @mb),
      gzip_enabled: boolean.("GZIP_COMPRESSION_ENABLED", true),
      gzip_disable_on_auth: boolean.("GZIP_COMPRESSION_DISABLE_ON_AUTH", false),
      gzip_jitter: int.("GZIP_COMPRESSION_JITTER", 32),
      max_request_body: int.("MAX_REQUEST_BODY", 0),
      idle_timeout: max(int.("HTTP_IDLE_TIMEOUT", 60), 0) * 1000,
      read_timeout: max(int.("HTTP_READ_TIMEOUT", 30), 0) * 1000,
      write_timeout: max(int.("HTTP_WRITE_TIMEOUT", 30), 0) * 1000,
      forward_headers: boolean.("FORWARD_HEADERS", tls_domains == []),
      log_requests: boolean.("LOG_REQUESTS", true)
    }

    :persistent_term.put(__MODULE__, config)
    config
  end

  def tls?(%__MODULE__{tls_domains: domains}), do: domains != []
end
