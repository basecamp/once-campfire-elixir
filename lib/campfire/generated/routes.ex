# Generated from vectors/routes.json; Rails 90b330024dec3e757c79b6a7e6568f93da8e3148.
defmodule Campfire.Generated.Routes do
  @moduledoc "Ordered reference route contracts. Recognition must implement constraints explicitly."
  def contracts,
    do: [
      %{
        "ordinal" => 0,
        "name" => nil,
        "path" => "/cable",
        "verb" => "",
        "defaults" => %{},
        "requirements" => %{},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::Mapper::Constraints",
        "internal" => true
      },
      %{
        "ordinal" => 1,
        "name" => "root",
        "path" => "/",
        "verb" => "GET",
        "defaults" => %{"controller" => "welcome", "action" => "show"},
        "requirements" => %{"controller" => "welcome", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 2,
        "name" => "new_first_run",
        "path" => "/first_run/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "first_runs", "action" => "new"},
        "requirements" => %{"controller" => "first_runs", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 3,
        "name" => "edit_first_run",
        "path" => "/first_run/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "first_runs", "action" => "edit"},
        "requirements" => %{"controller" => "first_runs", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 4,
        "name" => "first_run",
        "path" => "/first_run(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "first_runs", "action" => "show"},
        "requirements" => %{"controller" => "first_runs", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 5,
        "name" => nil,
        "path" => "/first_run(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "first_runs", "action" => "update"},
        "requirements" => %{"controller" => "first_runs", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 6,
        "name" => nil,
        "path" => "/first_run(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "first_runs", "action" => "update"},
        "requirements" => %{"controller" => "first_runs", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 7,
        "name" => nil,
        "path" => "/first_run(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "first_runs", "action" => "destroy"},
        "requirements" => %{"controller" => "first_runs", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 8,
        "name" => nil,
        "path" => "/first_run(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "first_runs", "action" => "create"},
        "requirements" => %{"controller" => "first_runs", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 9,
        "name" => "session_transfer",
        "path" => "/session/transfers/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "sessions/transfers", "action" => "show"},
        "requirements" => %{"controller" => "sessions/transfers", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 10,
        "name" => nil,
        "path" => "/session/transfers/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "sessions/transfers", "action" => "update"},
        "requirements" => %{"controller" => "sessions/transfers", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 11,
        "name" => nil,
        "path" => "/session/transfers/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "sessions/transfers", "action" => "update"},
        "requirements" => %{"controller" => "sessions/transfers", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 12,
        "name" => "new_session",
        "path" => "/session/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "sessions", "action" => "new"},
        "requirements" => %{"controller" => "sessions", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 13,
        "name" => "edit_session",
        "path" => "/session/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "sessions", "action" => "edit"},
        "requirements" => %{"controller" => "sessions", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 14,
        "name" => "session",
        "path" => "/session(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "sessions", "action" => "show"},
        "requirements" => %{"controller" => "sessions", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 15,
        "name" => nil,
        "path" => "/session(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "sessions", "action" => "update"},
        "requirements" => %{"controller" => "sessions", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 16,
        "name" => nil,
        "path" => "/session(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "sessions", "action" => "update"},
        "requirements" => %{"controller" => "sessions", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 17,
        "name" => nil,
        "path" => "/session(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "sessions", "action" => "destroy"},
        "requirements" => %{"controller" => "sessions", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 18,
        "name" => nil,
        "path" => "/session(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "sessions", "action" => "create"},
        "requirements" => %{"controller" => "sessions", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 19,
        "name" => "account_users",
        "path" => "/account/users(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/users", "action" => "index"},
        "requirements" => %{"controller" => "accounts/users", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 20,
        "name" => nil,
        "path" => "/account/users(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "accounts/users", "action" => "create"},
        "requirements" => %{"controller" => "accounts/users", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 21,
        "name" => "new_account_user",
        "path" => "/account/users/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/users", "action" => "new"},
        "requirements" => %{"controller" => "accounts/users", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 22,
        "name" => "edit_account_user",
        "path" => "/account/users/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/users", "action" => "edit"},
        "requirements" => %{"controller" => "accounts/users", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 23,
        "name" => "account_user",
        "path" => "/account/users/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/users", "action" => "show"},
        "requirements" => %{"controller" => "accounts/users", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 24,
        "name" => nil,
        "path" => "/account/users/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "accounts/users", "action" => "update"},
        "requirements" => %{"controller" => "accounts/users", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 25,
        "name" => nil,
        "path" => "/account/users/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "accounts/users", "action" => "update"},
        "requirements" => %{"controller" => "accounts/users", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 26,
        "name" => nil,
        "path" => "/account/users/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "accounts/users", "action" => "destroy"},
        "requirements" => %{"controller" => "accounts/users", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 27,
        "name" => "account_bot_key",
        "path" => "/account/bots/:bot_id/key(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "accounts/bots/keys", "action" => "update"},
        "requirements" => %{"controller" => "accounts/bots/keys", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 28,
        "name" => nil,
        "path" => "/account/bots/:bot_id/key(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "accounts/bots/keys", "action" => "update"},
        "requirements" => %{"controller" => "accounts/bots/keys", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 29,
        "name" => "account_bots",
        "path" => "/account/bots(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/bots", "action" => "index"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 30,
        "name" => nil,
        "path" => "/account/bots(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "accounts/bots", "action" => "create"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 31,
        "name" => "new_account_bot",
        "path" => "/account/bots/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/bots", "action" => "new"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 32,
        "name" => "edit_account_bot",
        "path" => "/account/bots/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/bots", "action" => "edit"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 33,
        "name" => "account_bot",
        "path" => "/account/bots/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/bots", "action" => "show"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 34,
        "name" => nil,
        "path" => "/account/bots/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "accounts/bots", "action" => "update"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 35,
        "name" => nil,
        "path" => "/account/bots/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "accounts/bots", "action" => "update"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 36,
        "name" => nil,
        "path" => "/account/bots/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "accounts/bots", "action" => "destroy"},
        "requirements" => %{"controller" => "accounts/bots", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 37,
        "name" => "account_join_code",
        "path" => "/account/join_code(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "accounts/join_codes", "action" => "create"},
        "requirements" => %{"controller" => "accounts/join_codes", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 38,
        "name" => "account_logo",
        "path" => "/account/logo(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/logos", "action" => "show"},
        "requirements" => %{"controller" => "accounts/logos", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 39,
        "name" => nil,
        "path" => "/account/logo(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "accounts/logos", "action" => "destroy"},
        "requirements" => %{"controller" => "accounts/logos", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 40,
        "name" => "edit_account_custom_styles",
        "path" => "/account/custom_styles/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts/custom_styles", "action" => "edit"},
        "requirements" => %{"controller" => "accounts/custom_styles", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 41,
        "name" => "account_custom_styles",
        "path" => "/account/custom_styles(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "accounts/custom_styles", "action" => "update"},
        "requirements" => %{"controller" => "accounts/custom_styles", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 42,
        "name" => nil,
        "path" => "/account/custom_styles(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "accounts/custom_styles", "action" => "update"},
        "requirements" => %{"controller" => "accounts/custom_styles", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 43,
        "name" => "new_account",
        "path" => "/account/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts", "action" => "new"},
        "requirements" => %{"controller" => "accounts", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 44,
        "name" => "edit_account",
        "path" => "/account/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts", "action" => "edit"},
        "requirements" => %{"controller" => "accounts", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 45,
        "name" => "account",
        "path" => "/account(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "accounts", "action" => "show"},
        "requirements" => %{"controller" => "accounts", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 46,
        "name" => nil,
        "path" => "/account(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "accounts", "action" => "update"},
        "requirements" => %{"controller" => "accounts", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 47,
        "name" => nil,
        "path" => "/account(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "accounts", "action" => "update"},
        "requirements" => %{"controller" => "accounts", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 48,
        "name" => nil,
        "path" => "/account(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "accounts", "action" => "destroy"},
        "requirements" => %{"controller" => "accounts", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 49,
        "name" => nil,
        "path" => "/account(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "accounts", "action" => "create"},
        "requirements" => %{"controller" => "accounts", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 50,
        "name" => "join",
        "path" => "/join/:join_code(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "users", "action" => "new"},
        "requirements" => %{"controller" => "users", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 51,
        "name" => nil,
        "path" => "/join/:join_code(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "users", "action" => "create"},
        "requirements" => %{"controller" => "users", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 52,
        "name" => "qr_code",
        "path" => "/qr_code/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "qr_code", "action" => "show"},
        "requirements" => %{"controller" => "qr_code", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 53,
        "name" => "user_avatar",
        "path" => "/users/:user_id/avatar(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "users/avatars", "action" => "show"},
        "requirements" => %{"controller" => "users/avatars", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 54,
        "name" => nil,
        "path" => "/users/:user_id/avatar(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "users/avatars", "action" => "destroy"},
        "requirements" => %{"controller" => "users/avatars", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 55,
        "name" => "user_ban",
        "path" => "/users/:user_id/ban(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "users/bans", "action" => "destroy"},
        "requirements" => %{"controller" => "users/bans", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 56,
        "name" => nil,
        "path" => "/users/:user_id/ban(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "users/bans", "action" => "create"},
        "requirements" => %{"controller" => "users/bans", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 57,
        "name" => "user_sidebar",
        "path" => "/users/:user_id/sidebar(.:format)",
        "verb" => "GET",
        "defaults" => %{"user_id" => "me", "controller" => "users/sidebars", "action" => "show"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/sidebars",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 58,
        "name" => "new_user_profile",
        "path" => "/users/:user_id/profile/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "new"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "new"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 59,
        "name" => "edit_user_profile",
        "path" => "/users/:user_id/profile/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "edit"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "edit"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 60,
        "name" => "user_profile",
        "path" => "/users/:user_id/profile(.:format)",
        "verb" => "GET",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "show"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 61,
        "name" => nil,
        "path" => "/users/:user_id/profile(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "update"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 62,
        "name" => nil,
        "path" => "/users/:user_id/profile(.:format)",
        "verb" => "PUT",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "update"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 63,
        "name" => nil,
        "path" => "/users/:user_id/profile(.:format)",
        "verb" => "DELETE",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "destroy"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "destroy"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 64,
        "name" => nil,
        "path" => "/users/:user_id/profile(.:format)",
        "verb" => "POST",
        "defaults" => %{"user_id" => "me", "controller" => "users/profiles", "action" => "create"},
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/profiles",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 65,
        "name" => "user_push_subscription_test_notifications",
        "path" =>
          "/users/:user_id/push_subscriptions/:push_subscription_id/test_notifications(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions/test_notifications",
          "action" => "create"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions/test_notifications",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 66,
        "name" => "user_push_subscriptions",
        "path" => "/users/:user_id/push_subscriptions(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "index"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "index"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 67,
        "name" => nil,
        "path" => "/users/:user_id/push_subscriptions(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "create"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 68,
        "name" => "new_user_push_subscription",
        "path" => "/users/:user_id/push_subscriptions/new(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "new"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "new"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 69,
        "name" => "edit_user_push_subscription",
        "path" => "/users/:user_id/push_subscriptions/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "edit"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "edit"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 70,
        "name" => "user_push_subscription",
        "path" => "/users/:user_id/push_subscriptions/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "show"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 71,
        "name" => nil,
        "path" => "/users/:user_id/push_subscriptions/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "update"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 72,
        "name" => nil,
        "path" => "/users/:user_id/push_subscriptions/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "update"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 73,
        "name" => nil,
        "path" => "/users/:user_id/push_subscriptions/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "destroy"
        },
        "requirements" => %{
          "user_id" => "me",
          "controller" => "users/push_subscriptions",
          "action" => "destroy"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 74,
        "name" => "user",
        "path" => "/users/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "users", "action" => "show"},
        "requirements" => %{"controller" => "users", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 75,
        "name" => "autocompletable_users",
        "path" => "/autocompletable/users(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "autocompletable/users", "action" => "index"},
        "requirements" => %{"controller" => "autocompletable/users", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 76,
        "name" => "room_messages",
        "path" => "/rooms/:room_id/messages(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "index"},
        "requirements" => %{"controller" => "messages", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 77,
        "name" => nil,
        "path" => "/rooms/:room_id/messages(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "messages", "action" => "create"},
        "requirements" => %{"controller" => "messages", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 78,
        "name" => "new_room_message",
        "path" => "/rooms/:room_id/messages/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "new"},
        "requirements" => %{"controller" => "messages", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 79,
        "name" => "edit_room_message",
        "path" => "/rooms/:room_id/messages/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "edit"},
        "requirements" => %{"controller" => "messages", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 80,
        "name" => "room_message",
        "path" => "/rooms/:room_id/messages/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "show"},
        "requirements" => %{"controller" => "messages", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 81,
        "name" => nil,
        "path" => "/rooms/:room_id/messages/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "messages", "action" => "update"},
        "requirements" => %{"controller" => "messages", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 82,
        "name" => nil,
        "path" => "/rooms/:room_id/messages/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "messages", "action" => "update"},
        "requirements" => %{"controller" => "messages", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 83,
        "name" => nil,
        "path" => "/rooms/:room_id/messages/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "messages", "action" => "destroy"},
        "requirements" => %{"controller" => "messages", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 84,
        "name" => "room_bot_message_boosts",
        "path" => "/rooms/:room_id/:bot_key/messages/:message_id/boosts(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/boosts/by_bots",
          "action" => "create"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/boosts/by_bots",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 85,
        "name" => "room_bot_message_boost",
        "path" => "/rooms/:room_id/:bot_key/messages/:message_id/boosts/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/boosts/by_bots",
          "action" => "destroy"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/boosts/by_bots",
          "action" => "destroy"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 86,
        "name" => "room_bot_messages",
        "path" => "/rooms/:room_id/:bot_key/messages(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "index"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "index"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 87,
        "name" => nil,
        "path" => "/rooms/:room_id/:bot_key/messages(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "create"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 88,
        "name" => "room_bot_message",
        "path" => "/rooms/:room_id/:bot_key/messages/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "update"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 89,
        "name" => nil,
        "path" => "/rooms/:room_id/:bot_key/messages/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "update"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "update"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 90,
        "name" => nil,
        "path" => "/rooms/:room_id/:bot_key/messages/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "destroy"
        },
        "requirements" => %{
          "format" => "json",
          "controller" => "messages/by_bots",
          "action" => "destroy"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 91,
        "name" => "room_refresh",
        "path" => "/rooms/:room_id/refresh(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/refreshes", "action" => "show"},
        "requirements" => %{"controller" => "rooms/refreshes", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 92,
        "name" => "room_settings",
        "path" => "/rooms/:room_id/settings(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/settings", "action" => "show"},
        "requirements" => %{"controller" => "rooms/settings", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 93,
        "name" => "room_involvement",
        "path" => "/rooms/:room_id/involvement(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/involvements", "action" => "show"},
        "requirements" => %{"controller" => "rooms/involvements", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 94,
        "name" => nil,
        "path" => "/rooms/:room_id/involvement(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "rooms/involvements", "action" => "update"},
        "requirements" => %{"controller" => "rooms/involvements", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 95,
        "name" => nil,
        "path" => "/rooms/:room_id/involvement(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "rooms/involvements", "action" => "update"},
        "requirements" => %{"controller" => "rooms/involvements", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 96,
        "name" => "room_at_message",
        "path" => "/rooms/:room_id/@:message_id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms", "action" => "show"},
        "requirements" => %{"controller" => "rooms", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 97,
        "name" => "rooms",
        "path" => "/rooms(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms", "action" => "index"},
        "requirements" => %{"controller" => "rooms", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 98,
        "name" => nil,
        "path" => "/rooms(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "rooms", "action" => "create"},
        "requirements" => %{"controller" => "rooms", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 99,
        "name" => "new_room",
        "path" => "/rooms/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms", "action" => "new"},
        "requirements" => %{"controller" => "rooms", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 100,
        "name" => "edit_room",
        "path" => "/rooms/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms", "action" => "edit"},
        "requirements" => %{"controller" => "rooms", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 101,
        "name" => "room",
        "path" => "/rooms/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms", "action" => "show"},
        "requirements" => %{"controller" => "rooms", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 102,
        "name" => nil,
        "path" => "/rooms/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "rooms", "action" => "update"},
        "requirements" => %{"controller" => "rooms", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 103,
        "name" => nil,
        "path" => "/rooms/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "rooms", "action" => "update"},
        "requirements" => %{"controller" => "rooms", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 104,
        "name" => nil,
        "path" => "/rooms/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "rooms", "action" => "destroy"},
        "requirements" => %{"controller" => "rooms", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 105,
        "name" => "rooms_opens",
        "path" => "/rooms/opens(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/opens", "action" => "index"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 106,
        "name" => nil,
        "path" => "/rooms/opens(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "rooms/opens", "action" => "create"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 107,
        "name" => "new_rooms_open",
        "path" => "/rooms/opens/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/opens", "action" => "new"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 108,
        "name" => "edit_rooms_open",
        "path" => "/rooms/opens/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/opens", "action" => "edit"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 109,
        "name" => "rooms_open",
        "path" => "/rooms/opens/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/opens", "action" => "show"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 110,
        "name" => nil,
        "path" => "/rooms/opens/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "rooms/opens", "action" => "update"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 111,
        "name" => nil,
        "path" => "/rooms/opens/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "rooms/opens", "action" => "update"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 112,
        "name" => nil,
        "path" => "/rooms/opens/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "rooms/opens", "action" => "destroy"},
        "requirements" => %{"controller" => "rooms/opens", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 113,
        "name" => "rooms_closeds",
        "path" => "/rooms/closeds(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "index"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 114,
        "name" => nil,
        "path" => "/rooms/closeds(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "create"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 115,
        "name" => "new_rooms_closed",
        "path" => "/rooms/closeds/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "new"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 116,
        "name" => "edit_rooms_closed",
        "path" => "/rooms/closeds/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "edit"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 117,
        "name" => "rooms_closed",
        "path" => "/rooms/closeds/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "show"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 118,
        "name" => nil,
        "path" => "/rooms/closeds/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "update"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 119,
        "name" => nil,
        "path" => "/rooms/closeds/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "update"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 120,
        "name" => nil,
        "path" => "/rooms/closeds/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "rooms/closeds", "action" => "destroy"},
        "requirements" => %{"controller" => "rooms/closeds", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 121,
        "name" => "rooms_directs",
        "path" => "/rooms/directs(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/directs", "action" => "index"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 122,
        "name" => nil,
        "path" => "/rooms/directs(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "rooms/directs", "action" => "create"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 123,
        "name" => "new_rooms_direct",
        "path" => "/rooms/directs/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/directs", "action" => "new"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 124,
        "name" => "edit_rooms_direct",
        "path" => "/rooms/directs/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/directs", "action" => "edit"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 125,
        "name" => "rooms_direct",
        "path" => "/rooms/directs/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rooms/directs", "action" => "show"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 126,
        "name" => nil,
        "path" => "/rooms/directs/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "rooms/directs", "action" => "update"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 127,
        "name" => nil,
        "path" => "/rooms/directs/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "rooms/directs", "action" => "update"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 128,
        "name" => nil,
        "path" => "/rooms/directs/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "rooms/directs", "action" => "destroy"},
        "requirements" => %{"controller" => "rooms/directs", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 129,
        "name" => "message_boosts",
        "path" => "/messages/:message_id/boosts(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages/boosts", "action" => "index"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 130,
        "name" => nil,
        "path" => "/messages/:message_id/boosts(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "messages/boosts", "action" => "create"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 131,
        "name" => "new_message_boost",
        "path" => "/messages/:message_id/boosts/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages/boosts", "action" => "new"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 132,
        "name" => "edit_message_boost",
        "path" => "/messages/:message_id/boosts/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages/boosts", "action" => "edit"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 133,
        "name" => "message_boost",
        "path" => "/messages/:message_id/boosts/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages/boosts", "action" => "show"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 134,
        "name" => nil,
        "path" => "/messages/:message_id/boosts/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "messages/boosts", "action" => "update"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 135,
        "name" => nil,
        "path" => "/messages/:message_id/boosts/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "messages/boosts", "action" => "update"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 136,
        "name" => nil,
        "path" => "/messages/:message_id/boosts/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "messages/boosts", "action" => "destroy"},
        "requirements" => %{"controller" => "messages/boosts", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 137,
        "name" => "messages",
        "path" => "/messages(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "index"},
        "requirements" => %{"controller" => "messages", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 138,
        "name" => nil,
        "path" => "/messages(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "messages", "action" => "create"},
        "requirements" => %{"controller" => "messages", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 139,
        "name" => "new_message",
        "path" => "/messages/new(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "new"},
        "requirements" => %{"controller" => "messages", "action" => "new"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 140,
        "name" => "edit_message",
        "path" => "/messages/:id/edit(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "edit"},
        "requirements" => %{"controller" => "messages", "action" => "edit"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 141,
        "name" => "message",
        "path" => "/messages/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "messages", "action" => "show"},
        "requirements" => %{"controller" => "messages", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 142,
        "name" => nil,
        "path" => "/messages/:id(.:format)",
        "verb" => "PATCH",
        "defaults" => %{"controller" => "messages", "action" => "update"},
        "requirements" => %{"controller" => "messages", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 143,
        "name" => nil,
        "path" => "/messages/:id(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "messages", "action" => "update"},
        "requirements" => %{"controller" => "messages", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 144,
        "name" => nil,
        "path" => "/messages/:id(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "messages", "action" => "destroy"},
        "requirements" => %{"controller" => "messages", "action" => "destroy"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 145,
        "name" => "clear_searches",
        "path" => "/searches/clear(.:format)",
        "verb" => "DELETE",
        "defaults" => %{"controller" => "searches", "action" => "clear"},
        "requirements" => %{"controller" => "searches", "action" => "clear"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 146,
        "name" => "searches",
        "path" => "/searches(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "searches", "action" => "index"},
        "requirements" => %{"controller" => "searches", "action" => "index"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 147,
        "name" => nil,
        "path" => "/searches(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "searches", "action" => "create"},
        "requirements" => %{"controller" => "searches", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 148,
        "name" => "unfurl_link",
        "path" => "/unfurl_link(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "unfurl_links", "action" => "create"},
        "requirements" => %{"controller" => "unfurl_links", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 149,
        "name" => "webmanifest",
        "path" => "/webmanifest(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "pwa", "action" => "manifest"},
        "requirements" => %{"controller" => "pwa", "action" => "manifest"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 150,
        "name" => "service_worker",
        "path" => "/service-worker(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "pwa", "action" => "service_worker"},
        "requirements" => %{"controller" => "pwa", "action" => "service_worker"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 151,
        "name" => "rails_health_check",
        "path" => "/up(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "rails/health", "action" => "show"},
        "requirements" => %{"controller" => "rails/health", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 152,
        "name" => "turbo_recede_historical_location",
        "path" => "/recede_historical_location(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "turbo/native/navigation", "action" => "recede"},
        "requirements" => %{"controller" => "turbo/native/navigation", "action" => "recede"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 153,
        "name" => "turbo_resume_historical_location",
        "path" => "/resume_historical_location(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "turbo/native/navigation", "action" => "resume"},
        "requirements" => %{"controller" => "turbo/native/navigation", "action" => "resume"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 154,
        "name" => "turbo_refresh_historical_location",
        "path" => "/refresh_historical_location(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "turbo/native/navigation", "action" => "refresh"},
        "requirements" => %{"controller" => "turbo/native/navigation", "action" => "refresh"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 155,
        "name" => "rails_postmark_inbound_emails",
        "path" => "/rails/action_mailbox/postmark/inbound_emails(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/postmark/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/postmark/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 156,
        "name" => "rails_relay_inbound_emails",
        "path" => "/rails/action_mailbox/relay/inbound_emails(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/relay/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/relay/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 157,
        "name" => "rails_sendgrid_inbound_emails",
        "path" => "/rails/action_mailbox/sendgrid/inbound_emails(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/sendgrid/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/sendgrid/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 158,
        "name" => "rails_mandrill_inbound_health_check",
        "path" => "/rails/action_mailbox/mandrill/inbound_emails(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/mandrill/inbound_emails",
          "action" => "health_check"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/mandrill/inbound_emails",
          "action" => "health_check"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 159,
        "name" => "rails_mandrill_inbound_emails",
        "path" => "/rails/action_mailbox/mandrill/inbound_emails(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/mandrill/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/mandrill/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 160,
        "name" => "rails_mailgun_inbound_emails",
        "path" => "/rails/action_mailbox/mailgun/inbound_emails/mime(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "action_mailbox/ingresses/mailgun/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "action_mailbox/ingresses/mailgun/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 161,
        "name" => "rails_conductor_inbound_emails",
        "path" => "/rails/conductor/action_mailbox/inbound_emails(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "index"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "index"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 162,
        "name" => nil,
        "path" => "/rails/conductor/action_mailbox/inbound_emails(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 163,
        "name" => "new_rails_conductor_inbound_email",
        "path" => "/rails/conductor/action_mailbox/inbound_emails/new(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "new"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "new"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 164,
        "name" => "rails_conductor_inbound_email",
        "path" => "/rails/conductor/action_mailbox/inbound_emails/:id(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "show"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 165,
        "name" => "new_rails_conductor_inbound_email_source",
        "path" => "/rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails/sources",
          "action" => "new"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails/sources",
          "action" => "new"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 166,
        "name" => "rails_conductor_inbound_email_sources",
        "path" => "/rails/conductor/action_mailbox/inbound_emails/sources(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails/sources",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/inbound_emails/sources",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 167,
        "name" => "rails_conductor_inbound_email_reroute",
        "path" => "/rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/reroutes",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/reroutes",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 168,
        "name" => "rails_conductor_inbound_email_incinerate",
        "path" => "/rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)",
        "verb" => "POST",
        "defaults" => %{
          "controller" => "rails/conductor/action_mailbox/incinerates",
          "action" => "create"
        },
        "requirements" => %{
          "controller" => "rails/conductor/action_mailbox/incinerates",
          "action" => "create"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 169,
        "name" => "rails_service_blob",
        "path" => "/rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "active_storage/blobs/redirect", "action" => "show"},
        "requirements" => %{"controller" => "active_storage/blobs/redirect", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 170,
        "name" => "rails_service_blob_proxy",
        "path" => "/rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "active_storage/blobs/proxy", "action" => "show"},
        "requirements" => %{"controller" => "active_storage/blobs/proxy", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 171,
        "name" => nil,
        "path" => "/rails/active_storage/blobs/:signed_id/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "active_storage/blobs/redirect", "action" => "show"},
        "requirements" => %{"controller" => "active_storage/blobs/redirect", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 172,
        "name" => "rails_blob_representation",
        "path" =>
          "/rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "active_storage/representations/redirect",
          "action" => "show"
        },
        "requirements" => %{
          "controller" => "active_storage/representations/redirect",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 173,
        "name" => "rails_blob_representation_proxy",
        "path" =>
          "/rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "active_storage/representations/proxy",
          "action" => "show"
        },
        "requirements" => %{
          "controller" => "active_storage/representations/proxy",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 174,
        "name" => nil,
        "path" =>
          "/rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{
          "controller" => "active_storage/representations/redirect",
          "action" => "show"
        },
        "requirements" => %{
          "controller" => "active_storage/representations/redirect",
          "action" => "show"
        },
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 175,
        "name" => "rails_disk_service",
        "path" => "/rails/active_storage/disk/:encoded_key/*filename(.:format)",
        "verb" => "GET",
        "defaults" => %{"controller" => "active_storage/disk", "action" => "show"},
        "requirements" => %{"controller" => "active_storage/disk", "action" => "show"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 176,
        "name" => "update_rails_disk_service",
        "path" => "/rails/active_storage/disk/:encoded_token(.:format)",
        "verb" => "PUT",
        "defaults" => %{"controller" => "active_storage/disk", "action" => "update"},
        "requirements" => %{"controller" => "active_storage/disk", "action" => "update"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      },
      %{
        "ordinal" => 177,
        "name" => "rails_direct_uploads",
        "path" => "/rails/active_storage/direct_uploads(.:format)",
        "verb" => "POST",
        "defaults" => %{"controller" => "active_storage/direct_uploads", "action" => "create"},
        "requirements" => %{"controller" => "active_storage/direct_uploads", "action" => "create"},
        "constraints" => %{},
        "endpoint_class" => "ActionDispatch::Routing::RouteSet::Dispatcher",
        "internal" => nil
      }
    ]
end
