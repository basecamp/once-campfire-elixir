defmodule Campfire.HtmlParser do
  @moduledoc """
  HTML parsing on the pinned Gumbo binding, at the reference's parser-time limits.

  A fragment parses in a `body` context, as Nokogiri's `HTML5.fragment` does for the
  reference, and one past the reference's tree-depth or per-element attribute limit
  raises `ArgumentError` instead of returning a tree.

  Processing instructions are dropped: the binding keeps them (the spec gained them in
  2026) while the reference records a bogus comment, and the render pipeline discards
  comments either way, so dropping them here keeps the rendered output the same.
  """
  @options [max_tree_depth: 401, max_attributes: 400, max_errors: 0]

  def parse(html) do
    case Gumbo.parse_fragment(html, :body, @options) do
      {:ok, output} ->
        output
        |> Gumbo.Output.fragment_nodes()
        |> Gumbo.materialize(detail: :tree)
        |> Enum.flat_map(&List.wrap(to_term(&1)))

      {:error, :tree_too_deep} ->
        raise ArgumentError, "Document tree depth limit exceeded"

      {:error, :too_many_attributes} ->
        raise ArgumentError, "Attributes per element limit exceeded"

      {:error, reason} ->
        raise ArgumentError, "cannot parse HTML: #{inspect(reason)}"
    end
  end

  defp to_term(%{type: type, tag_name: tag_name, attributes: attributes, children: children})
       when type in [:element, :template] do
    {tag_name, attributes, Enum.flat_map(children, &List.wrap(to_term(&1)))}
  end

  defp to_term(%{type: :comment} = comment), do: {:comment, comment.text}

  # A `<?…>` is a processing instruction here and a bogus comment to the reference, whose
  # generation predates the token type: it keeps `?pi?` where this binding keeps `target`/`data`
  # and loses the delimiters, so the two cannot be made to agree node for node by mapping one
  # onto the other. The render pipeline discards comments and instructions alike, so dropping
  # the node is what keeps this tree the shape the reader works on; the tree comparison against
  # the reference parser labels the two bodies it moves rather than counting them as divergences
  # (var/classify_diffs.exs, `:processing_instruction`).
  defp to_term(%{type: :processing_instruction}), do: nil

  defp to_term(%{text: text}), do: text
end
