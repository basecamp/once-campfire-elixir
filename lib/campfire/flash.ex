defmodule Campfire.Flash do
  alias Campfire.{Assets, Auth}

  def put(conn, key, message) do
    {conn, data} = Auth.browser_session(conn)
    flash = %{"discard" => [], "flashes" => %{to_string(key) => message}}

    conn
    |> Plug.Conn.assign(:new_flash, true)
    |> Auth.set_browser_session(Map.put(data, "flash", flash))
  end

  # As in Rails, only a request that loaded the session sweeps the flash it
  # arrived with; others leave the cookie alone.
  def sweep(conn) do
    incoming = conn.private[:campfire_session_incoming]

    if conn.assigns[:new_flash] || conn.assigns[:rails_exception] || !is_map(incoming) ||
         !incoming["flash"] do
      conn
    else
      {conn, data} = Auth.browser_session(conn)

      if data["flash"],
        do: Auth.set_browser_session(conn, Map.delete(data, "flash")),
        else: conn
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
