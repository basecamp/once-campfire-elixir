defmodule Campfire.Signup do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  import Plug.Conn
  alias Campfire.{Assets, Auth, DB, Page, People, Rails}
  require EEx
  EEx.function_from_file(:defp, :form, "priv/templates/signup.html.eex", [:assigns])
  EEx.function_from_file(:defp, :nav, "priv/templates/signup_nav.html.eex", [:_assigns])

  def call(conn, code) do
    {conn, user, session} = Auth.session_user(conn)
    account = DB.one("SELECT * FROM accounts LIMIT 1")

    cond do
      conn.method == "POST" && !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        head(conn, 429)

      user ->
        conn |> Auth.set_auth_cookie(session) |> Auth.redirect("/")

      !account || account["join_code"] != code ->
        head(conn, 404)

      conn.method == "GET" ->
        show(conn, account)

      conn.method == "POST" ->
        create(conn)
    end
  end

  defp show(conn, account) do
    {conn, data} = Auth.csrf_session(conn)

    content =
      form(
        path: Assets.html_escape(conn.request_path),
        form_token:
          Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], conn.request_path, "POST")),
        account_name: Assets.html_escape(account["name"]),
        account_version:
          account["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14),
        help: Campfire.Sessions.help()
      )

    {conn, html} =
      Page.render(conn, nil, data,
        title: "Sign up",
        body_class: "signup",
        nav: nav([]),
        content: content
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html)
  end

  defp create(conn) do
    attrs =
      conn.params
      |> Campfire.Params.required("user")
      |> Campfire.Params.permit(~w(name avatar email_address password))

    case People.create(attrs) do
      user when is_map(user) ->
        conn |> Auth.start_session(user) |> Auth.redirect("/")

      {:error, error} ->
        if String.contains?(inspect(error), "UNIQUE constraint failed: users.email_address"),
          do:
            Auth.redirect(
              conn,
              "/session/new?email_address=" <>
                URI.encode_www_form(attrs["email_address"] || "")
            ),
          else: raise(error)
    end
  end

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")
end
