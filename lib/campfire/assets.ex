defmodule Campfire.Assets do
  @external_resource "priv/static/assets/.manifest.json"
  @manifest Jason.decode!(File.read!(@external_resource))
  @preloads Regex.scan(
              ~r/Assets.path\("([^"]+\.css)"\)/,
              File.read!("priv/templates/application.html.eex")
            )
            |> Enum.map(fn [_, logical] ->
              "</assets/" <>
                Map.fetch!(@manifest, logical)["digested_path"] <>
                ">; rel=preload; as=style; nopush"
            end)
            |> Enum.reduce_while("", fn link, header ->
              if byte_size(header) + byte_size(link) > 1000,
                do: {:halt, header},
                else: {:cont, header <> if(header == "", do: "", else: ",") <> link}
            end)
  def preload_header, do: @preloads
  def file(relative), do: Application.app_dir(:campfire, "priv/" <> relative)
  def read(relative), do: relative |> file() |> File.read!()

  def path(logical) do
    "/assets/" <> Map.fetch!(@manifest, logical)["digested_path"]
  end

  def html_escape(text),
    do:
      text
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\"", "&quot;")
      |> String.replace("'", "&#39;")

  def manifest(base) do
    account = Campfire.DB.one("SELECT * FROM accounts LIMIT 1")
    name = if account, do: account["name"], else: "Campfire"

    version =
      if account,
        do: account["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14),
        else: nil

    logo = "/account/logo" <> if(version, do: "?v=#{version}", else: "")
    small = "/account/logo?size=small" <> if(version, do: "&v=#{version}", else: "")

    Campfire.Assets.read("pwa/manifest.json.erb")
    |> String.replace(~s(<%= Current.account&.name || "Campfire" %>), html_escape(name))
    |> String.replace("<%= fresh_account_logo_path(size: :small) %>", html_escape(small))
    |> String.replace("<%= fresh_account_logo_path %>", html_escape(logo))
    |> then(fn template ->
      Regex.replace(~r/<%= image_url\("([^"]+)"\) %>/, template, fn _, logical ->
        html_escape(base <> path(logical))
      end)
    end)
  end
end
