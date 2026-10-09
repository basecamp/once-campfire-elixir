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

  def call(conn, _) do
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
        conn = if conn.state == :set_file, do: conn, else: defaults(conn, @security)

        conn =
          if conn.request_path in ["/up", "/cable"] ||
               String.starts_with?(conn.request_path, "/rails/active_storage/"),
             do: conn,
             else: replace(conn, version_headers())

        conn =
          if stylesheet?(conn),
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
            do:
              conn |> delete_resp_header("content-type") |> delete_resp_header("content-length"),
            else: conn

        conn |> Campfire.HttpCompression.apply() |> Campfire.ResponseCache.complete()
      end
    end)
  end

  # Constant headers, validated once, are added in one step instead of a
  # validated put_resp_header/3 call each, keeping put_resp_header's order.
  defp defaults(conn, headers) do
    missing =
      for {key, _} = header <- headers, not List.keymember?(conn.resp_headers, key, 0), do: header

    %{conn | resp_headers: conn.resp_headers ++ missing}
  end

  defp replace(conn, headers) do
    %{
      conn
      | resp_headers:
          Enum.reduce(headers, conn.resp_headers, &List.keystore(&2, elem(&1, 0), 0, &1))
    }
  end

  defp version_headers do
    case :persistent_term.get({__MODULE__, :version}, nil) do
      nil ->
        headers = [
          {"x-version", System.get_env("APP_VERSION", "dev")},
          {"x-rev", System.get_env("GIT_REVISION", "dev")}
        ]

        # The same check put_resp_header/3 applies to each value.
        for {key, value} <- headers, do: put_resp_header(%Plug.Conn{}, key, value)
        :persistent_term.put({__MODULE__, :version}, headers)
        headers

      headers ->
        headers
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
      |> put_resp_header("content-type", type <> "; charset=UTF-8")

    conn = if head?, do: put_resp_header(conn, "content-length", "0"), else: conn
    if body != "", do: put_resp_header(conn, "vary", "Accept-Encoding"), else: conn
  end

  # Spliced pages only look for the stylesheet in their layout text.
  defp stylesheet?(%{assigns: %{page_parts: parts}}),
    do:
      Enum.any?(parts, fn
        {:raw, data} -> String.contains?(data, ~s(<link rel="stylesheet"))
        _fragment -> false
      end)

  defp stylesheet?(%{resp_body: body}) when is_binary(body),
    do: String.contains?(body, ~s(<link rel="stylesheet"))

  defp stylesheet?(_conn), do: false

  # Like the Rust port, a page built from fragments hashes their cached
  # digests and its own text instead of the whole body.
  defp digest(%{assigns: %{page_parts: parts}}) do
    :crypto.hash(
      :sha256,
      Enum.map(parts, fn
        {:raw, data} ->
          [<<0, IO.iodata_length(data)::64>>, data]

        {:fragment, key, html} ->
          [<<1>>, Campfire.FragmentCache.derived(key, :digest, html, &:crypto.hash(:sha256, &1))]
      end)
    )
  end

  defp digest(conn), do: :crypto.hash(:sha256, conn.resp_body)

  defp etag(conn) do
    if conn.status in [200, 201] && get_resp_header(conn, "etag") == [] &&
         get_resp_header(conn, "last-modified") == [] &&
         (is_binary(conn.resp_body) || is_list(conn.resp_body)) &&
         IO.iodata_length(conn.resp_body) > 0 do
      digest = digest(conn) |> Base.encode16(case: :lower) |> binary_part(0, 32)

      conn = put_resp_header(conn, "etag", ~s(W/"#{digest}"))

      if get_resp_header(conn, "cache-control") == [],
        do: put_resp_header(conn, "cache-control", "max-age=0, private, must-revalidate"),
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
