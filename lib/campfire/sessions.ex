defmodule Campfire.Sessions do
  import Plug.Conn
  alias Campfire.{Assets, Auth, DB, Rails}
  require EEx
  EEx.function_from_file(:defp, :layout_html, "priv/templates/session.html.eex", [:assigns])
  EEx.function_from_file(:defp, :login_html, "priv/templates/login.html.eex", [:assigns])
  EEx.function_from_file(:defp, :setup_html, "priv/templates/first_run.html.eex", [:assigns])

  EEx.function_from_file(:defp, :transfer_html, "priv/templates/transfer.html.eex", [:assigns])

  def transfer_page(conn, _id) do
    {conn, data} = Auth.csrf_session(conn)

    content =
      transfer_html(
        path: Assets.html_escape(conn.request_path),
        token: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], conn.request_path, "PUT"))
      )

    {conn, html} = Campfire.Page.render(conn, nil, data, content: content)
    conn |> put_resp_content_type("text/html") |> send_resp(200, html)
  end

  def login_page(conn, params \\ %{}, status \\ 200) do
    {conn, data} = Auth.csrf_session(conn)
    account = DB.one("SELECT * FROM accounts LIMIT 1") || %{}

    assigns =
      [
        meta_token: Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"])),
        form_token: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], "/session", "POST")),
        base: Auth.base(conn),
        account_version: version(account["updated_at"]),
        account_name: Assets.html_escape(account["name"] || "Campfire"),
        vapid: Assets.html_escape(System.get_env("VAPID_PUBLIC_KEY", "")),
        rejected: status != 200,
        email: if(params["email_address"], do: Assets.html_escape(params["email_address"])),
        account_has_logo: !!Campfire.Attachments.find("Account", account["id"], "logo"),
        custom_styles: Campfire.Page.custom_styles(account),
        help: help(),
        flash: if(status != 200, do: rejection_flash(), else: "\n")
      ] ++
        [
          title: "Sign in",
          body_class: "",
          head: ~s(<meta name="turbo-visit-control" content="reload">)
        ]

    body = layout_html(assigns ++ [content: login_html(assigns)])

    conn
    |> Auth.set_csrf_session(data)
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  def first_run_page(conn) do
    if DB.one("SELECT id FROM accounts LIMIT 1") do
      Auth.redirect(conn, "/")
    else
      {conn, data} = Auth.csrf_session(conn)

      assigns = [
        meta_token: Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"])),
        form_token: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], "/first_run", "POST")),
        base: Auth.base(conn),
        account_version: "",
        vapid: Assets.html_escape(System.get_env("VAPID_PUBLIC_KEY", "")),
        account_has_logo: false,
        custom_styles: "",
        title: "Set up Campfire",
        body_class: "signup",
        head: "",
        flash: "\n"
      ]

      body = layout_html(assigns ++ [content: setup_html(assigns)])

      conn
      |> Auth.set_csrf_session(data)
      |> put_resp_content_type("text/html")
      |> send_resp(200, body)
    end
  end

  def first_run_create(conn, params) do
    cond do
      !Auth.csrf_valid?(conn, params) ->
        Campfire.HttpResponse.error(conn, 422)

      DB.one("SELECT id FROM accounts LIMIT 1") ->
        Auth.redirect(conn, "/")

      Auth.banned?(conn) ->
        head(conn, 429)

      true ->
        case Campfire.People.first_run(
               Campfire.Params.required(params, "user")
               |> Campfire.Params.permit(~w(name avatar email_address password))
             ) do
          user when is_map(user) -> conn |> Auth.start_session(user) |> Auth.redirect("/")
          {:error, :already_configured} -> Auth.redirect(conn, "/")
          {:error, error} -> raise error
        end
    end
  end

  def create(conn, params) do
    cond do
      not Auth.csrf_valid?(conn, params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        head(conn, 429)

      not Campfire.RateLimiter.allowed?(
        "sessions:" <> Campfire.RemoteIP.address(conn),
        10,
        180
      ) ->
        login_page(conn, params, 429)

      true ->
        user =
          DB.one("SELECT * FROM users WHERE status=0 AND email_address=?", [
            params["email_address"]
          ])

        if user && is_binary(params["password"]) && params["password"] != "" &&
             is_binary(user["password_digest"]) &&
             Bcrypt.verify_pass(params["password"], user["password_digest"]) do
          conn |> Auth.start_session(user) |> Auth.post_authenticating()
        else
          if !user, do: Bcrypt.no_user_verify()
          login_page(conn, params, 401)
        end
    end
  end

  def transfer(conn, id, params) do
    if Auth.csrf_valid?(conn, params) do
      with user_id when is_integer(user_id) <- Rails.verify_id("User", id, "transfer"),
           user when is_map(user) <-
             DB.one("SELECT * FROM users WHERE status=0 AND id=?", [user_id]) do
        conn |> Auth.start_session(user) |> Auth.post_authenticating()
      else
        _ -> head(conn, 400)
      end
    else
      Campfire.HttpResponse.error(conn, 422)
    end
  end

  def destroy(conn, params) do
    case Auth.session_user(conn) do
      {conn, nil, _} ->
        Auth.request_authentication(conn)

      {conn, _user, session} ->
        if Auth.csrf_valid?(conn, params) do
          conn
          |> Auth.terminate_session(session, params["push_subscription_endpoint"])
          |> Auth.redirect("/")
        else
          Campfire.HttpResponse.error(conn, 422)
        end
    end
  end

  defp version(nil), do: ""
  defp version(value), do: value |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14)

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")

  def help do
    if owner = DB.one("SELECT * FROM users WHERE role=1 ORDER BY id LIMIT 1") do
      name = Assets.html_escape(owner["name"])
      email = Assets.html_escape(owner["email_address"] || "")

      "  <div class=\"txt-align-center margin-block-double full-width\">\n    <a class=\"btn center\" title=\"Email #{name}\" href=\"mailto:&quot;#{name}&quot; &lt;#{email}&gt;\">\n      <img aria-hidden=\"true\" src=\"#{Assets.path("lifebuoy.svg")}\" />\n      <span>#{email}</span>\n</a>\n    <div class=\"txt-align-center center margin-block txt-subtle\">Campfire&trade; version <span class=\"version-badge\">#{Assets.html_escape(System.get_env("APP_VERSION", "dev"))}</span></div>\n  </div>\n\n"
    else
      ""
    end
  end

  defp rejection_flash do
    "      <div class=\"flash\" data-controller=\"element-removal\" data-action=\"animationend->element-removal#remove\">\n        <div class=\"flash__inner shadow\" style=\"--flash-background: var(--color-negative)\">\n            <img aria-hidden=\"true\" class=\"colorize--white\" src=\"#{Assets.path("alert.svg")}\" width=\"24\" height=\"24\" /></span>\n        </div>\n        <span class=\"for-screen-reader\" role=\"alert\" aria-atomic=\"true\">Too many requests or unauthorized.</span>\n      </div>\n\n"
  end
end
