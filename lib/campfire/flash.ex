defmodule Campfire.Flash do
  alias Campfire.{Assets, Auth}

  def put(conn, key, message) do
    {conn, data} = Auth.csrf_session(conn)
    flash = %{"discard" => [], "flashes" => %{to_string(key) => message}}

    conn
    |> Plug.Conn.assign(:new_flash, true)
    |> Auth.set_csrf_session(Map.put(data, "flash", flash))
  end

  def sweep(conn) do
    if conn.assigns[:new_flash] || conn.assigns[:rails_exception] do
      conn
    else
      {conn, incoming} = Auth.csrf_session(conn)

      if incoming["flash"] do
        data =
          case conn.resp_cookies["_campfire_session"] do
            %{value: value} ->
              Campfire.Rails.decrypt_cookie("_campfire_session", URI.decode(value))

            _ ->
              incoming
          end

        if is_map(data) && data["flash"],
          do: Auth.set_csrf_session(conn, Map.delete(data, "flash")),
          else: conn
      else
        conn
      end
    end
  end

  def render(data) do
    flashes = get_in(data, ["flash", "flashes"]) || %{}
    notice = flashes["notice"] || flashes["alert"]

    if notice do
      alert = flashes["alert"]
      style = if alert, do: "--flash-background: var(--color-negative)", else: ""
      icon = if alert, do: "alert.svg", else: "check.svg"

      "      <div class=\"flash\" data-controller=\"element-removal\" data-action=\"animationend->element-removal#remove\">\n        <div class=\"flash__inner shadow\" style=\"#{style}\">\n            <img aria-hidden=\"true\" class=\"colorize--white\" src=\"#{Assets.path(icon)}\" width=\"24\" height=\"24\" /></span>\n        </div>\n        <span class=\"for-screen-reader\" role=\"alert\" aria-atomic=\"true\">#{Assets.html_escape(to_string(notice))}</span>\n      </div>\n\n"
    else
      "\n"
    end
  end
end
