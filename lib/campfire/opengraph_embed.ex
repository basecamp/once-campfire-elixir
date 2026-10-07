defmodule Campfire.OpengraphEmbed do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.{Assets, RichText}
  require EEx
  EEx.function_from_file(:defp, :markup, "priv/templates/opengraph_embed.html.eex", [:assigns])
  @content_type ~r/application\/vnd.actiontext.opengraph-embed/

  def resolve(attrs, host \\ Process.get(:campfire_request_host)) do
    attrs = Map.new(attrs)

    if Regex.match?(@content_type, attrs["content-type"] || "") do
      raw =
        if Campfire.Chat.present?(attrs["filename"]) do
          %{
            "href" => attrs["href"],
            "url" => attrs["url"],
            "filename" => attrs["filename"],
            "description" => attrs["caption"]
          }
        else
          content = RichText.parse(attrs["content"] || "")
          title = Floki.find(content, ".og-embed__title")
          link = Floki.find(title, "a")

          %{
            "href" => List.first(Floki.attribute(link, "href")),
            "url" => List.first(Floki.attribute(content, ".og-embed__image img", "src")),
            "filename" => Floki.text(if(link == [], do: title, else: link)) |> String.trim(),
            "description" =>
              Floki.find(content, ".og-embed__description") |> Floki.text() |> String.trim()
          }
        end

      raw |> Map.update!("href", &web_url(&1, host)) |> Map.update!("url", &web_url(&1, host))
    end
  end

  def web_url(value, host) when is_binary(value) do
    uri = URI.parse(value)

    if (uri.scheme == "mailto" && !String.contains?(uri.path || "", "@")) ||
         (is_binary(uri.host) && Regex.match?(~r/\A\.+\z/, uri.host)),
       do: raise(ArgumentError, "invalid Open Graph URL")

    named = uri.host && !String.contains?(uri.host, "%") && String.contains?(uri.host, ".")
    ending = if named, do: uri.host |> String.split(".") |> List.last()
    canonical = fn value -> value |> String.downcase() |> String.trim_trailing(".") end

    valid =
      named && ending && Regex.match?(~r/[a-z]/i, ending) && !Regex.match?(~r/\A0x/i, ending)

    if uri.scheme in ["http", "https"] && valid && !Regex.match?(~r/[^\x21-\x7e]/, value) &&
         !Regex.match?(~r/[<>\"`{}|\\^]/, uri.path || "") &&
         canonical.(uri.host) != canonical.(host || ""),
       do: value
  end

  def web_url(_, _), do: nil

  def render(embed) do
    title = Assets.html_escape(truncate(embed["filename"] || "", 280))

    title =
      if embed["href"],
        do:
          ~s(<a rel="noreferrer" target="_blank" href="#{Assets.html_escape(embed["href"])}">#{title}</a>),
        else: title

    markup(
      title: title,
      description: Assets.html_escape(truncate(embed["description"] || "", 560)),
      image: embed["url"] && Assets.html_escape(embed["url"]),
      twitter_avatar:
        String.starts_with?(embed["url"] || "", "https://pbs.twimg.com/profile_images")
    )
  end

  defp truncate(text, size),
    do: if(String.length(text) > size, do: String.slice(text, 0, size - 1) <> "…", else: text)
end
