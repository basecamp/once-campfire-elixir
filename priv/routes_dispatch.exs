# Generated from the router table this replaces; the router injects it with
# Module.eval_quoted, so Plug.Router's macro expansion is unchanged.
  get("/", do: Campfire.Navigation.welcome(conn))
  get("/rooms/:room_id/@:message_id", do: Campfire.RoomPage.show(conn, room_id, message_id))
  get("/rooms/opens/new", do: Campfire.RoomForms.show(conn, "open"))
  get("/rooms/opens/:id/edit", do: Campfire.RoomForms.show(conn, "open", id))
  get("/rooms/closeds/new", do: Campfire.RoomForms.show(conn, "closed"))
  get("/rooms/closeds/:id/edit", do: Campfire.RoomForms.show(conn, "closed", id))
  get("/rooms/directs/new", do: Campfire.RoomForms.show(conn, "direct"))
  get("/rooms/directs/:id/edit", do: Campfire.RoomForms.show(conn, "direct", id))
  get("/rooms/directs/:id", do: Campfire.Navigation.direct_room(conn, id))
  get("/rooms/opens/:id", do: Campfire.Navigation.shared_room(conn, id))
  get("/rooms/closeds/:id", do: Campfire.Navigation.shared_room(conn, id))
  get("/rooms/:id", do: Campfire.RoomPage.show(conn, id))
  get("/rooms", do: Campfire.Navigation.rooms_index(conn))

  get("/rooms/:room_id/refresh", do: Campfire.Refresh.show(conn, room_id))

  get("/searches", do: Campfire.Searches.call(conn))
  post("/searches", do: Campfire.Searches.call(conn))
  delete("/searches/clear", do: Campfire.Searches.call(conn))

  post("/unfurl_link", do: Campfire.UnfurlLinks.create(conn))

  get("/autocompletable/users", do: Campfire.Autocomplete.index(conn))
  get("/rooms/:room_id/involvement", do: Campfire.Involvement.show(conn, room_id))

  get("/users/:id", do: Campfire.UserPage.show(conn, id))
  get("/users/:user_id/sidebar", do: Campfire.Sidebar.show(conn))

  delete("/account/logo", do: Campfire.Admin.call(conn, :destroy_logo))
  delete("/users/:user_id/avatar", do: Campfire.Admin.call(conn, :destroy_avatar))
  get("/account/logo", do: Campfire.Images.logo(conn))
  get("/users/:token/avatar", do: Campfire.Images.avatar(conn, token))

  get("/cable", do: Campfire.Cable.upgrade(conn))

  get("/qr_code/:id", do: Campfire.QR.show(conn, id))

  get("/up",
    do:
      send_resp(
        put_resp_content_type(conn, "text/html"),
        200,
        "<!DOCTYPE html><html><body style=\"background-color: green\"></body></html>"
      )
  )

  get("/webmanifest", do: Campfire.Pwa.endpoint(conn, :manifest))
  get("/service-worker", do: Campfire.Pwa.endpoint(conn, :worker))

  get "/webmanifest.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Campfire.Assets.manifest(base(conn)))
  end

  get "/service-worker.js" do
    conn
    |> put_resp_content_type("text/javascript")
    |> send_resp(200, Campfire.Assets.read("pwa/service_worker.js"))
  end

  match("/rooms/:room_id/:bot_key/messages", do: bot_request(conn, room_id, bot_key, nil))
  match("/rooms/:room_id/:bot_key/messages/:id", do: bot_request(conn, room_id, bot_key, id))

  match "/rooms/:room_id/:bot_key/messages/:message_id/boosts" do
    bot_boost_request(conn, room_id, bot_key, message_id, nil)
  end

  match "/rooms/:room_id/:bot_key/messages/:message_id/boosts/:id" do
    bot_boost_request(conn, room_id, bot_key, message_id, id)
  end

  get "/session/new" do
    if DB.one("SELECT id FROM users LIMIT 1"),
      do: Campfire.Sessions.login_page(conn, conn.params),
      else: Auth.redirect(conn, "/first_run")
  end

  get("/join/:code", do: Campfire.Signup.call(conn, code))
  post("/join/:code", do: Campfire.Signup.call(conn, code))

  get("/first_run", do: Campfire.Sessions.first_run_page(conn))
  post("/first_run", do: Campfire.Sessions.first_run_create(conn, conn.params))

  post("/session", do: Campfire.Sessions.create(conn, conn.params))
  delete("/session", do: Campfire.Sessions.destroy(conn, conn.params))
  get("/session/transfers/:id", do: Campfire.Sessions.transfer_page(conn, id))
  put("/session/transfers/:id", do: Campfire.Sessions.transfer(conn, id, conn.params))
  patch("/session/transfers/:id", do: Campfire.Sessions.transfer(conn, id, conn.params))

  post("/users/:user_id/ban", do: Campfire.Admin.call(conn, :ban, user_id))
  delete("/users/:user_id/ban", do: Campfire.Admin.call(conn, :unban, user_id))

  post("/users/:user_id/push_subscriptions/:id/test_notifications",
    do: Campfire.PushSubscriptions.test_notification(conn, id)
  )

  get("/users/:user_id/push_subscriptions", do: Campfire.PushSubscriptions.call(conn))
  post("/users/:user_id/push_subscriptions", do: Campfire.PushSubscriptions.call(conn))
  delete("/users/:user_id/push_subscriptions/:id", do: Campfire.PushSubscriptions.call(conn, id))

  get("/account/users", do: Campfire.AccountPage.index(conn))
  get("/account/users.turbo_stream", do: Campfire.AccountPage.index(conn))
  get("/account/edit", do: Campfire.AccountPage.show(conn))
  get("/account/custom_styles/edit", do: Campfire.SettingsPages.call(conn, :custom_styles))
  get("/account/bots", do: Campfire.BotsPage.show(conn))
  get("/account/bots/new", do: Campfire.SettingsPages.call(conn, :new_bot))
  get("/account/bots/:id/edit", do: Campfire.SettingsPages.call(conn, :edit_bot, id))

  put("/account", do: Campfire.Admin.call(conn, :account, nil))
  patch("/account", do: Campfire.Admin.call(conn, :account, nil))
  post("/account/join_code", do: Campfire.Admin.call(conn, :join_code, nil))
  put("/account/custom_styles", do: Campfire.Admin.call(conn, :custom_styles, nil))
  patch("/account/custom_styles", do: Campfire.Admin.call(conn, :custom_styles, nil))
  put("/account/users/:id", do: Campfire.Admin.call(conn, :role, id))
  patch("/account/users/:id", do: Campfire.Admin.call(conn, :role, id))
  get("/users/:user_id/profile", do: Campfire.ProfilePage.show(conn))
  put("/users/:user_id/profile", do: Campfire.Admin.call(conn, :profile, nil))
  patch("/users/:user_id/profile", do: Campfire.Admin.call(conn, :profile, nil))
  put("/account/bots/:id", do: Campfire.Admin.call(conn, :update_bot, id))
  patch("/account/bots/:id", do: Campfire.Admin.call(conn, :update_bot, id))
  put("/account/bots/:bot_id/key", do: Campfire.Admin.call(conn, :reset_bot_key, bot_id))
  patch("/account/bots/:bot_id/key", do: Campfire.Admin.call(conn, :reset_bot_key, bot_id))
  delete("/account/users/:id", do: Campfire.Admin.call(conn, :deactivate, id))
  delete("/account/bots/:id", do: Campfire.Admin.call(conn, :delete_bot, id))
  post("/account/bots", do: Campfire.Admin.call(conn, :create_bot))
  post("/rooms/opens", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Open"}))
  put("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Open"}, id))
  patch("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Open"}, id))
  delete("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Open"}, id))
  post("/rooms/closeds", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Closed"}))
  put("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Closed"}, id))
  patch("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Closed"}, id))
  delete("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Closed"}, id))
  post("/rooms/directs", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Direct"}))
  delete("/rooms/directs/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Direct"}, id))
  delete("/rooms/:id", do: Campfire.Admin.call(conn, {:delete_room, nil}, id))
  put("/rooms/:id/involvement", do: Campfire.Admin.call(conn, :involvement, id))
  patch("/rooms/:id/involvement", do: Campfire.Admin.call(conn, :involvement, id))

  get("/rails/active_storage/blobs/redirect/:id/*filename",
    do: Campfire.Storage.redirect_blob(conn, id)
  )

  get("/rails/active_storage/representations/redirect/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key)
  )

  get("/rails/active_storage/representations/proxy/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key, true)
  )

  get("/rails/active_storage/representations/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key)
  )

  get("/rails/active_storage/blobs/proxy/:id/*filename", do: Campfire.Storage.proxy(conn, id))
  get("/rails/active_storage/blobs/:id/*filename", do: Campfire.Storage.redirect_blob(conn, id))
  get("/rails/active_storage/disk/:id/*filename", do: Campfire.Storage.disk(conn, id))
  put("/rails/active_storage/disk/:id", do: Campfire.Storage.upload(conn, id))
  post("/rails/active_storage/direct_uploads", do: Campfire.Storage.direct_upload(conn))

  match("/messages/:message_id/boosts", do: Campfire.Boosts.call(conn, message_id))
  match("/messages/:message_id/boosts/:id", do: Campfire.Boosts.call(conn, message_id, id))

  get("/messages/:id/edit", do: Campfire.Messages.call(conn, conn.params["room_id"], id, true))
  match("/messages", do: Campfire.Messages.call(conn, conn.params["room_id"]))
  match("/messages/:id", do: Campfire.Messages.call(conn, conn.params["room_id"], id))
  get("/rooms/:room_id/messages/:id/edit", do: Campfire.Messages.call(conn, room_id, id, true))

  match("/rooms/:room_id/messages", do: Campfire.Messages.call(conn, room_id))
  match("/rooms/:room_id/messages/:id", do: Campfire.Messages.call(conn, room_id, id))

  match(_, do: Campfire.HttpResponse.error(conn, 404))
