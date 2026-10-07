defmodule Campfire.ProfilePage do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  import Plug.Conn
  alias Campfire.{Assets, Attachments, Auth, DB, Involvement, Page, Rails, RoomPage}
  require EEx
  EEx.function_from_file(:defp, :profile, "priv/templates/profile.html.eex", [:assigns])
  EEx.function_from_file(:defp, :nav, "priv/templates/profile_nav.html.eex", [:assigns])

  EEx.function_from_file(:defp, :membership, "priv/templates/profile_membership.html.eex", [
    :assigns
  ])

  EEx.function_from_file(:defp, :transfer, "priv/templates/profile_transfer.html.eex", [:assigns])

  def show(conn) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        {conn, data} = Auth.csrf_session(Auth.set_auth_cookie(conn, session))

        rooms =
          DB.query(
            "SELECT r.*, m.involvement FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY LOWER(r.name)",
            [user["id"]]
          )

        {direct, shared} = Enum.split_with(rooms, &(&1["type"] == "Rooms::Direct"))

        content =
          profile(
            pwa: Campfire.Pwa.render(conn, :profile),
            id: user["id"],
            name: Assets.html_escape(user["name"]),
            email: Assets.html_escape(user["email_address"] || ""),
            bio: Assets.html_escape(user["bio"] || ""),
            avatar_src: avatar_path(user),
            token: token(data, "/users/me/profile", "PATCH"),
            delete_avatar: delete_avatar(user, data),
            shared: Enum.map_join(shared, &render_membership(&1, user, data)),
            direct: Enum.map_join(direct, &render_membership(&1, user, data)),
            separator: shared != [] && direct != [],
            transfer: transfer_link(conn, user)
          )

        referer = List.first(get_req_header(conn, "referer"))

        back =
          if is_nil(referer) || referer == Auth.base(conn) <> conn.request_path,
            do: "/",
            else: referer

        {conn, html} =
          Page.render(conn, user, data,
            title: Assets.html_escape(user["name"]),
            nav: nav(back: Assets.html_escape(back), token: token(data, "/session", "DELETE")),
            content: content
          )

        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    end
  rescue
    Campfire.Pwa.MissingAsset ->
      Campfire.HttpResponse.exception(conn, 500, Campfire.Assets.read("public/500.html"))
  end

  def avatar_path(user) do
    version = user["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14)
    "/users/#{Rails.signed_id("User", user["id"], "avatar")}/avatar?v=#{version}"
  end

  EEx.function_from_file(:defp, :self_label, "priv/templates/transfer_label_self.html.eex", [
    :_assigns
  ])

  EEx.function_from_file(:defp, :other_label, "priv/templates/transfer_label_other.html.eex", [
    :_assigns
  ])

  def transfer_link(conn, user, self \\ true) do
    expires =
      Campfire.Clock.now()
      |> DateTime.add(4 * 3600)
      |> Map.put(:microsecond, {0, 3})
      |> DateTime.to_iso8601()

    url =
      Auth.base(conn) <>
        "/session/transfers/" <> Rails.signed_id("User", user["id"], "transfer", expires)

    transfer(
      url: Assets.html_escape(url),
      qr: Base.url_encode64(url),
      label: if(self, do: self_label([]), else: other_label([]))
    )
  end

  defp render_membership(room, user, data) do
    membership(
      id: room["id"],
      name: Assets.html_escape(RoomPage.display_name(room, user)),
      involvement: Involvement.profile_frame(room, room["involvement"], data)
    )
  end

  defp delete_avatar(user, data) do
    if Attachments.find("User", user["id"], "avatar") do
      path = "/users/#{user["id"]}/avatar"

      ~s(      <form class="button_to" method="post" action="#{path}"><input type="hidden" name="_method" value="delete" /><button class="btn btn--negative txt-small avatar__delete-btn" type="submit">\n        <img aria-hidden="true" src="#{Assets.path("minus.svg")}" width="20" height="20" />\n        <span class="for-screen-reader">Delete avatar</span>\n</button><input type="hidden" name="authenticity_token" value="#{token(data, path, "DELETE")}" /></form>)
    else
      ""
    end
  end

  defp token(data, path, method),
    do: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], path, method))
end
