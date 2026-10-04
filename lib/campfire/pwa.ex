defmodule Campfire.Pwa do
  alias Campfire.{Assets, Auth, Platform}
  require EEx

  defmodule MissingAsset do
    defexception message: "The pinned Rails view references an unavailable asset"
  end

  for scope <- [:room, :profile],
      branch <-
        ~w(chrome_mac chrome_windows chrome_android chrome_ios firefox_mac firefox_windows firefox_android safari_mac safari_ios generic) do
    EEx.function_from_file(
      :defp,
      String.to_atom("#{scope}_#{branch}"),
      "priv/templates/pwa_#{scope}_#{branch}.html.eex",
      if(String.contains?(File.read!("priv/templates/pwa_#{scope}_#{branch}.html.eex"), "@"),
        do: [:assigns],
        else: [:_assigns]
      )
    )
  end

  def endpoint(conn, kind) do
    accept = List.first(Plug.Conn.get_req_header(conn, "accept")) || "text/html"
    type = if kind == :manifest, do: "application/json", else: "text/javascript"

    if conn.params["format"] == if(kind == :manifest, do: "json", else: "js") ||
         String.contains?(accept, type) do
      content =
        if kind == :manifest,
          do: Assets.manifest(Auth.base(conn)),
          else: Campfire.Assets.read("pwa/service_worker.js")

      conn =
        if conn.params["format"],
          do: conn,
          else: Plug.Conn.put_resp_header(conn, "vary", "Accept")

      conn
      |> Plug.Conn.put_resp_content_type(type)
      |> Plug.Conn.send_resp(200, content)
    else
      json = String.contains?(accept, "application/json")

      Campfire.HttpResponse.exception(
        conn,
        406,
        if(json, do: ~s({"status":406,"error":"Not Acceptable"}), else: ""),
        if(json, do: "application/json", else: "text/html")
      )
    end
  end

  def render(conn, scope) do
    p = Platform.describe(List.first(Plug.Conn.get_req_header(conn, "user-agent")))

    branch =
      cond do
        p["edge"] ->
          raise MissingAsset

        p["chrome"] ->
          cond do
            p["ios"] -> "chrome_ios"
            p["android"] -> "chrome_android"
            p["windows"] -> "chrome_windows"
            true -> "chrome_mac"
          end

        p["firefox"] ->
          cond do
            p["android"] -> "firefox_android"
            p["windows"] -> "firefox_windows"
            true -> "firefox_mac"
          end

        p["safari"] && p["desktop"] ->
          "safari_mac"

        p["safari"] && p["ios"] ->
          "safari_ios"

        true ->
          "generic"
      end

    assigns = [
      browser: Assets.html_escape(String.capitalize(p["browser"])),
      os: Assets.html_escape(p["operating_system"] || ""),
      base: Assets.html_escape(Auth.base(conn))
    ]

    render_branch(scope, branch, assigns)
  end

  for scope <- [:room, :profile],
      branch <-
        ~w(chrome_mac chrome_windows chrome_android chrome_ios firefox_mac firefox_windows firefox_android safari_mac safari_ios generic) do
    defp render_branch(unquote(scope), unquote(branch), assigns),
      do: unquote(String.to_atom("#{scope}_#{branch}"))(assigns)
  end
end
