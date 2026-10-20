defmodule Campfire.HttpResponse do
  @moduledoc "Rails default headers, Rack ETags and conditional GET behavior."
  import Plug.Conn
  alias Plug.Conn.Status

  @security [
    {"x-frame-options", "SAMEORIGIN"},
    {"x-xss-protection", "0"},
    {"x-content-type-options", "nosniff"},
    {"x-permitted-cross-domain-policies", "none"},
    {"referrer-policy", "strict-origin-when-cross-origin"}
  ]
  def init(opts), do: opts

  def call(conn, opts) do
    do_call(conn, opts)
  end

  defp do_call(conn, _) do
    conn = delete_resp_header(conn, "cache-control")

    conn =
      case conn.adapter do
        {Bandit.Adapter, adapter} -> %{conn | adapter: {Campfire.HttpAdapter, adapter}}
        _ -> conn
      end

    register_before_send(conn, &finalize/1)
  end

  @doc """
  Produces the final representation: security and version headers, validators, compression and the
  response-cache capture.

  The cached-hit path skips this, because the entry it replays already holds the result.
  """
  def finalize(conn) do
    conn = Campfire.ResponseFormats.prepare(conn)
    conn = Campfire.Flash.sweep(conn)

    if conn.assigns[:rails_exception] do
      if conn.resp_body == "", do: conn, else: Campfire.HttpCompression.apply(conn)
    else
      # @security is a compile-time constant list; Plug's per-write CRLF scan is not needed here.
      conn =
        if conn.state == :set_file do
          conn
        else
          missing = Enum.reject(@security, fn {key, _} -> get_resp_header(conn, key) != [] end)
          %{conn | resp_headers: missing ++ conn.resp_headers}
        end

      conn =
        if conn.request_path in ["/up", "/cable"] ||
             String.starts_with?(conn.request_path, "/rails/active_storage/"),
           do: conn,
           else:
             conn
             |> put_header("x-version", version_header(:version, "APP_VERSION"))
             |> put_header("x-rev", version_header(:rev, "GIT_REVISION"))

      conn =
        if is_binary(conn.resp_body) &&
             String.contains?(conn.resp_body, ~s(<link rel="stylesheet")),
           do: put_header(conn, "link", Campfire.Assets.preload_header()),
           else: conn

      conn = etag(conn)

      conn =
        if get_resp_header(conn, "cache-control") == [],
          do: put_header(conn, "cache-control", "no-cache"),
          else: conn

      conn =
        if conn.status == 200 && conn.method in ["GET", "HEAD"] && fresh?(conn),
          do:
            %{conn | status: 304, resp_body: ""}
            |> delete_resp_header("content-type")
            |> delete_resp_header("content-length"),
          else: conn

      conn =
        if conn.status not in [204, 304] && conn.status not in 100..199 do
          vary = Enum.join(get_resp_header(conn, "vary"), ",")

          put_header(
            conn,
            "vary",
            if(
              "accept-encoding" in (vary
                                    |> String.downcase()
                                    |> String.split(",")
                                    |> Enum.map(&String.trim/1)),
              do: vary,
              else: if(vary == "", do: "Accept-Encoding", else: vary <> ",Accept-Encoding")
            )
          )
        else
          conn
        end

      conn =
        if conn.status in [204, 304],
          do: conn |> delete_resp_header("content-type") |> delete_resp_header("content-length"),
          else: conn

      conn |> Campfire.HttpCompression.apply() |> Campfire.ResponseCache.complete()
    end
  end

  def error(conn, status) do
    {body, type} = error_parts(conn, status)
    exception(conn, status, body, type)
  end

  def error_parts(conn, status) do
    formats = Campfire.ResponseFormats.requested(conn)

    reason =
      %{
        400 => "Bad Request",
        404 => "Not Found",
        406 => "Not Acceptable",
        413 => "Content Too Large",
        422 => "Unprocessable Content",
        500 => "Internal Server Error"
      }[status] || Status.reason_phrase(status)

    cond do
      List.first(formats) == "json" ->
        {~s({"status":#{status},"error":"#{reason}"}), "application/json"}

      List.first(formats) == "xml" ->
        {~s(<?xml version="1.0" encoding="UTF-8"?>\n<hash>\n  <status type="integer">#{status}</status>\n  <error>#{reason}</error>\n</hash>\n),
         "application/xml"}

      true ->
        file = Campfire.Assets.file("public/#{status}.html")
        {if(File.exists?(file), do: File.read!(file), else: ""), "text/html"}
    end
  end

  def exception(conn, status, body, type \\ "text/html") do
    conn = exception_response(conn, status, body, type)
    send_resp(conn, conn.status, conn.resp_body)
  end

  def exception_response(conn, status, body, type) do
    head? =
      case conn.adapter do
        {_, %{method: "HEAD"}} -> true
        _ -> false
      end

    body = if head?, do: "", else: body

    conn =
      %{conn | status: status, resp_body: body, resp_headers: [], resp_cookies: %{}}
      |> assign(:rails_exception, true)
      |> put_header("content-type", type <> "; charset=UTF-8")

    conn = if head?, do: put_header(conn, "content-length", "0"), else: conn
    if body != "", do: put_header(conn, "vary", "Accept-Encoding"), else: conn
  end

  defp version_header(key, name) do
    cache = {__MODULE__, key}

    case :persistent_term.get(cache, nil) do
      nil ->
        value = Campfire.Env.get(name, "dev")
        :persistent_term.put(cache, value)
        value

      value ->
        value
    end
  end

  # Keys and values here are ours (constants or computed digests), so writing them directly skips
  # Plug's CRLF scan without weakening anything: nothing user-controlled reaches this function.
  defp put_header(conn, key, value) do
    headers = :lists.keydelete(key, 1, conn.resp_headers)
    %{conn | resp_headers: [{key, value} | headers]}
  end

  defp etag(conn) do
    if conn.status in [200, 201] && get_resp_header(conn, "etag") == [] &&
         get_resp_header(conn, "last-modified") == [] &&
         (is_binary(conn.resp_body) || is_list(conn.resp_body)) &&
         IO.iodata_length(conn.resp_body) > 0 do
      digest =
        :crypto.hash(:sha256, conn.resp_body) |> Base.encode16(case: :lower) |> binary_part(0, 32)

      conn = put_header(conn, "etag", ~s(W/"#{digest}"))

      if get_resp_header(conn, "cache-control") == [],
        do: put_header(conn, "cache-control", "max-age=0, private, must-revalidate"),
        else: conn
    else
      conn
    end
  end

  defp fresh?(conn) do
    case get_req_header(conn, "if-none-match") do
      [match | _] ->
        validators = String.split(match, ",") |> Enum.map(&String.trim/1)

        Enum.any?(get_resp_header(conn, "etag"), &(&1 in validators)) ||
          (conn.assigns[:controller_validator] == true && "*" in validators)

      [] ->
        with [since | _] <- get_req_header(conn, "if-modified-since"),
             [modified | _] <- get_resp_header(conn, "last-modified"),
             {:ok, since} <- date(since),
             {:ok, modified} <- date(modified),
             do: since >= modified,
             else: (_ -> false)
    end
  end

  defp date(raw) do
    case :httpd_util.convert_request_date(String.to_charlist(raw)) do
      {{_, _, _}, {_, _, _}} = value -> {:ok, :calendar.datetime_to_gregorian_seconds(value)}
      _ -> :error
    end
  rescue
    _ -> :error
  end
end
