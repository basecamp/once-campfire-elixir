defmodule Campfire.RichTextComparison do
  @moduledoc "Explicit comparison rules for runtime exceptions and the Rust port's attribute escaping fix."

  def comparable(%{"error" => error, "message" => message}) do
    kind =
      cond do
        error in ["JSON::ParserError", "Jason.DecodeError"] ->
          :invalid_json

        String.contains?(message, "invalid base64") ->
          :invalid_base64

        String.contains?(message, "Trix attachment attributes must be an object") ||
            String.contains?(message, "undefined method 'merge' for an instance of Array") ->
          :invalid_attachment_attributes

        String.contains?(message, "no implicit conversion of String into Integer") ||
            String.contains?(message, "Access module supports only keyword lists") ->
          :invalid_envelope

        String.contains?(message, "invalid Open Graph URL") ||
          error == "URI::InvalidComponentError" || message == "undefined method 'match?' for nil" ->
          :invalid_url

        true ->
          {error, message}
      end

    %{"error" => kind}
  end

  def comparable(value), do: value

  # Rails' rescue logger raises again when JSON::ParserError contains invalid
  # UTF-8. Elixir returns the intended empty presentation; the full message
  # render still returns the same failed-message partial on plain-text errors.
  def presentation(%{
        "error" => "ArgumentError",
        "message" => "invalid byte sequence in UTF-8 (cause: JSON::ParserError)"
      }),
      do: %{"ok" => ""}

  def presentation(%{"ok" => html}), do: %{"ok" => protect_attributes(html, :text, [])}
  def presentation(value), do: value

  # Equivalent to rails-to-rust's with_port_divergences, retaining name attrs.
  # Parsing the unsafe oracle output first would corrupt the attribute boundary.
  defp protect_attributes("", _, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp protect_attributes("<a target=\"_blank\" href=\"" <> rest, :value, acc) do
    [_, text] = String.split(rest, "\">", parts: 2)
    [text, rest] = String.split(text, "</a>", parts: 2)
    protect_attributes(rest, :value, [String.replace(text, ">", "&gt;") | acc])
  end

  defp protect_attributes(<<c::utf8, rest::binary>>, state, acc) do
    next =
      case {state, c} do
        {:text, ?<} -> :tag
        {:tag, ?>} -> :text
        {:tag, ?"} -> :value
        {:value, ?"} -> :tag
        _ -> state
      end

    text =
      case {next, c} do
        {:value, ?<} -> "&lt;"
        {:value, ?>} -> "&gt;"
        _ -> <<c::utf8>>
      end

    protect_attributes(rest, next, [text | acc])
  end
end
