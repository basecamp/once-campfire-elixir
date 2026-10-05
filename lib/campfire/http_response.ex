defmodule Campfire.HttpResponse do
  @moduledoc "Rails default headers, Rack ETags and conditional GET behavior."
  import Plug.Conn

  @security [
    {"x-frame-options", "SAMEORIGIN"},
    {"x-xss-protection", "0"},
    {"x-content-type-options", "nosniff"},
    {"x-permitted-cross-domain-policies", "none"},
    {"referrer-policy", "strict-origin-when-cross-origin"}
  ]
  def init(opts), do: opts

  def call(conn, _) do
    # The per-request session cache kept by Campfire.Auth.
    Process.delete(:campfire_session)
    conn = delete_resp_header(conn, "cache-control")

    conn =
      case conn.adapter do
        {Bandit.Adapter, adapter} -> %{conn | adapter: {Campfire.HttpAdapter, adapter}}
        _ -> conn
      end

    register_before_send(conn, fn conn ->
      conn = Campfire.ResponseFormats.prepare(conn)
      conn = Campfire.Flash.sweep(conn)

      if conn.assigns[:rails_exception] do
        if conn.resp_body == "", do: conn, else: Campfire.HttpCompression.apply(conn)
      else
        conn =
          Enum.reduce(if(conn.state == :set_file, do: [], else: @security), conn, fn {key, value},
                                                                                     c ->
            if get_resp_header(c, key) == [], do: put_resp_header(c, key, value), else: c
          end)

        conn =
          if conn.request_path in ["/up", "/cable"] ||
               String.starts_with?(conn.request_path, "/rails/active_storage/"),
             do: conn,
             else:
               conn
               |> put_resp_header("x-version", Campfire.Release.version())
               |> put_resp_header("x-rev", Campfire.Release.revision())

        conn =
          if stylesheet?(conn.assigns[:page_parts] || conn.resp_body),
            do: put_resp_header(conn, "link", Campfire.Assets.preload_header()),
            else: conn

        conn = etag(conn)

        conn =
          if get_resp_header(conn, "cache-control") == [],
            do: put_resp_header(conn, "cache-control", "no-cache"),
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

            put_resp_header(
              conn,
              "vary",
              if(vary == "", do: "Accept-Encoding", else: vary <> ",Accept-Encoding")
            )
          else
            conn
          end

        conn =
          if conn.status in [204, 304],
            do:
              conn |> delete_resp_header("content-type") |> delete_resp_header("content-length"),
            else: conn

        Campfire.HttpCompression.apply(conn)
      end
    end)
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
      }[status] || Plug.Conn.Status.reason_phrase(status)

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
      |> put_resp_header("content-type", type <> "; charset=UTF-8")

    conn = if head?, do: put_resp_header(conn, "content-length", "0"), else: conn
    if body != "", do: put_resp_header(conn, "vary", "Accept-Encoding"), else: conn
  end

  # A spliced page's message fragments are sanitized and never link a stylesheet, so only its
  # per-request text is searched rather than the whole (up to 450 KB) body.
  defp stylesheet?([{:raw, _} | _] = parts),
    do: Enum.any?(for {:raw, data} <- parts, do: stylesheet?(data))

  defp stylesheet?(body) when is_binary(body),
    do: String.contains?(body, ~s(<link rel="stylesheet"))

  defp stylesheet?(body) when is_list(body), do: Enum.any?(body, &stylesheet?/1)
  defp stylesheet?(_), do: false

  defp etag(conn) do
    if conn.status in [200, 201] && get_resp_header(conn, "etag") == [] &&
         get_resp_header(conn, "last-modified") == [] &&
         (is_binary(conn.resp_body) || is_list(conn.resp_body)) &&
         IO.iodata_length(conn.resp_body) > 0 do
      {conn, digested} = digested(conn)

      digest =
        :crypto.hash(:sha256, digested)
        |> Base.encode16(case: :lower)
        |> binary_part(0, 32)

      conn = put_resp_header(conn, "etag", ~s(W/"#{digest}"))

      if get_resp_header(conn, "cache-control") == [],
        do: put_resp_header(conn, "cache-control", "max-age=0, private, must-revalidate"),
        else: conn
    else
      conn
    end
  end

  # Rack::ETag digests the whole body. A page spliced from cached message fragments (about
  # 450 KB for a room) is digested from its parts' digests: each fragment's is computed once and
  # kept with the fragment, and the per-request text's is kept on the parts for gzip to reuse.
  defp digested(%{assigns: %{page_parts: parts}} = conn) do
    parts = Campfire.HttpCompression.with_digests(parts)
    {assign(conn, :page_parts, parts), Enum.map(parts, &Campfire.HttpCompression.digest/1)}
  end

  defp digested(conn), do: {conn, conn.resp_body}

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
