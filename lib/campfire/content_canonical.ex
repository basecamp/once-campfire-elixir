defmodule Campfire.ContentCanonical do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils

  @trix ~w(sgid contentType url href filename filesize width height previewable content caption presentation)

  def nodes(nodes),
    do:
      Enum.flat_map(nodes, fn
        {tag, attrs, children} ->
          data = Map.new(attrs)

          cond do
            Map.has_key?(data, "data-trix-attachment") ->
              attachment = trix_json(data["data-trix-attachment"])
              extra = trix_json(data["data-trix-attributes"])
              values = Map.merge(attachment, extra)

              attrs =
                for key <- @trix,
                    Map.has_key?(values, key),
                    do:
                      {if(key == "contentType", do: "content-type", else: key),
                       to_string(values[key])}

              if attrs == [] do
                []
              else
                unless Campfire.OpengraphEmbed.resolve(attrs),
                  do: Campfire.Mentions.resolve(attrs)

                [{"action-text-attachment", attrs, []}]
              end

            tag == "action-text-attachment" ->
              [{tag, attrs, []}]

            true ->
              [{tag, attrs, nodes(children)}]
          end

        text ->
          [text]
      end)

  def gallery?(nodes) do
    members = Enum.count(nodes, &gallery_attachment?/1)

    members >= 2 &&
      Enum.all?(nodes, fn
        text when is_binary(text) -> Regex.match?(~r/\A[ \n]*\z/, text)
        node -> gallery_attachment?(node)
      end)
  end

  defp gallery_attachment?({"action-text-attachment", attrs, _}),
    do: Map.new(attrs)["presentation"] == "gallery"

  defp gallery_attachment?(_), do: false

  defp trix_json(nil), do: %{}

  defp trix_json(json) do
    case Campfire.RubyJSON.decode(json) do
      {:ok, value} when value in [nil, false] -> %{}
      {:ok, value} when is_map(value) -> value
      {:ok, _} -> raise ArgumentError, "Trix attachment attributes must be an object"
      {:error, _} -> %{}
    end
  end
end
