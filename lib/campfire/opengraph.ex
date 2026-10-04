defmodule Campfire.Opengraph do
  alias Campfire.{HtmlParser, Network, RichText}
  @fields ~w(title url image description)
  @media ~r/\bhttps?:\/\/\S+\.(?:zip|tar|tar\.gz|tar\.bz2|tar\.xz|gz|bz2|rar|7z|dmg|exe|msi|pkg|deb|iso|jpg|jpeg|png|gif|bmp|mp4|mov|avi|mkv|wmv|flv|heic|heif|mp3|wav|ogg|aac|wma|webm|ogv|mpg|mpeg)\b/
  @images ~w(image/jpeg image/png image/gif image/webp)
  @twitter ~w(twitter.com www.twitter.com x.com www.x.com)

  def attributes(html) do
    nodes = HtmlParser.parse(html || "")
    metas = Floki.find(nodes, "meta")

    encoding =
      Enum.any?(metas, fn {_, attrs, _} ->
        a = Map.new(attrs)

        a["charset"] != nil ||
          (String.downcase(a["http-equiv"] || "") == "content-type" &&
             String.contains?(String.downcase(a["content"] || ""), "charset="))
      end)

    Enum.reduce(metas, %{}, fn {_, attrs, _}, acc ->
      a = Map.new(attrs)
      property = a["property"] || a["name"] || ""
      name = String.replace(property, "og:", "")
      content = a["content"]

      if String.starts_with?(property, "og:") && name in @fields && present?(content) do
        content =
          if encoding,
            do: content,
            else: for(<<byte <- content>>, byte < 128, into: "", do: <<byte>>)

        Map.put(acc, name, content)
      else
        acc
      end
    end)
  end

  def from_url(url) do
    uri = URI.parse(url)

    fetch_url =
      if uri.host in @twitter && uri.path not in [nil, "", "/"],
        do: URI.to_string(%{uri | host: "fxtwitter.com"}),
        else: url

    html = if !Regex.match?(@media, fetch_url), do: fetch(fetch_url, :get)
    metadata(html, url)
  rescue
    _ -> :invalid
  end

  def metadata(html, url, options \\ []) do
    valid_url = Keyword.get(options, :valid_url, &valid_url?/1)
    image_type = Keyword.get(options, :image_type, &fetch(&1, :head))
    attrs = attributes(html)
    canonical = if valid_url.(attrs["url"]), do: attrs["url"], else: url

    image =
      if present?(attrs["image"]) && valid_url.(attrs["image"]) &&
           String.downcase(image_type.(attrs["image"]) || "") in @images,
         do: attrs["image"]

    fields = for name <- @fields, Map.has_key?(attrs, name), do: {name, attrs[name]}
    fields = List.keystore(fields, "url", 0, {"url", canonical})
    fields = List.keystore(fields, "image", 0, {"image", image})

    fields =
      Enum.map(fields, fn
        {name, value} when name in ["title", "description"] -> {name, strip_tags(value)}
        pair -> pair
      end)

    sanitized = Map.new(fields)

    if present?(sanitized["title"]) && present?(sanitized["description"]) && present?(canonical) do
      {:ok,
       %Jason.OrderedObject{
         values: fields ++ [{"context_for_validation", %{"context" => nil}}, {"errors", %{}}]
       }}
    else
      :invalid
    end
  end

  def strip_tags(nil), do: ""

  def strip_tags(value),
    do:
      value
      |> HtmlParser.parse()
      |> Floki.text(sep: "", include_inputs: false, js: true)
      |> then(&RichText.serialize_nodes([&1]))

  defp valid_url?(url) when is_binary(url) do
    with {:ok, uri} <- Campfire.HttpURL.parse(url),
         true <- is_binary(uri.host),
         {:ok, _} <- Network.resolve(uri.host),
         do: true,
         else: (_ -> false)
  rescue
    _ -> false
  end

  defp valid_url?(_), do: false

  defp fetch(url, method, redirects \\ 10)
  defp fetch(_, _, 0), do: nil

  defp fetch(url, method, redirects) do
    case Network.request(url, method, [], "", max_body_size: 5 * 1024 * 1024) do
      {:ok, status, headers, _} when status in 300..399 ->
        location = headers["location"]
        if valid_url?(location), do: fetch(location, method, redirects - 1)

      {:ok, _, headers, _} when method == :head ->
        headers["content-type"]

      {:ok, 200, headers, body} ->
        type = headers["content-type"] && hd(String.split(headers["content-type"], ";", parts: 2))
        if String.downcase(type || "") == "text/html", do: body

      _ ->
        nil
    end
  end

  defp present?(nil), do: false
  defp present?(s), do: String.trim(s) != ""
end
