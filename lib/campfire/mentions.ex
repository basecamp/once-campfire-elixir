defmodule Campfire.Mentions do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.{Assets, DB, Rails, RichText}

  def resolve(attrs) do
    sgid = Map.new(attrs)["sgid"]
    gid = if is_binary(sgid), do: unsigned_gid(sgid)

    with true <- is_binary(gid) && !String.contains?(gid, "\uFFFD"),
         %URI{scheme: "gid", host: host, path: path} <- URI.parse(gid),
         true <- is_binary(host) && host != "",
         [_, id] <- Regex.run(~r/\A\/User\/([0-9]+)\z/, path),
         user when is_map(user) <-
           DB.one("SELECT * FROM users WHERE id=?", [String.to_integer(id)]) do
      user
    else
      _ -> nil
    end
  end

  # Campfire deliberately resolves User mentions after secret rotation. No other
  # model is located through this unsigned fallback, and Marshal is never loaded.
  defp unsigned_gid(sgid) do
    parts =
      String.split(sgid, "--") |> Enum.reverse() |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()

    if message = List.first(parts) do
      decoded = decode_base64(message)

      envelope = decoded |> repair_utf8() |> Jason.decode!()
      rails = envelope["_rails"] || %{}

      cond do
        rails["data"] ->
          rails["data"]

        rails["message"] ->
          encoded = rails["message"]

          bytes = decode_base64(encoded)

          case Regex.run(~r(gid://campfire/[^/]+/\d+), bytes) do
            [gid] -> gid
            _ -> nil
          end

        true ->
          nil
      end
    end
  end

  # Ruby's JSON parser preserves invalid UTF-8 in strings; GlobalID then rejects
  # such identifiers. Jason validates strings, so preserve the rejection at the
  # locator boundary while continuing to reject malformed JSON syntax.
  defp repair_utf8(<<>>), do: ""
  defp repair_utf8(<<c::utf8, rest::binary>>), do: <<c::utf8>> <> repair_utf8(rest)
  defp repair_utf8(<<_, rest::binary>>), do: "\uFFFD" <> repair_utf8(rest)

  defp decode_base64(message) do
    # Ruby's m0 decoder rejects nonzero padding bits, including after URL-safe
    # alphabet translation. Elixir's decoder accepts those bits by default.
    normalized = message |> String.replace("-", "+") |> String.replace("_", "/")
    padded = normalized <> String.duplicate("=", rem(4 - rem(byte_size(normalized), 4), 4))

    with {:ok, bytes} <- Base.decode64(padded),
         true <- Base.encode64(bytes) == padded do
      bytes
    else
      _ -> raise ArgumentError, "invalid base64"
    end
  end

  defp resolve_verified(attrs) do
    sgid = Map.new(attrs)["sgid"]

    with true <- is_binary(sgid),
         gid when is_binary(gid) <- Rails.verify_message("signed_global_ids", sgid, "attachable"),
         %URI{scheme: "gid", host: host, path: path} <- URI.parse(gid),
         true <- is_binary(host) && host != "",
         [_, id] <- Regex.run(~r/\A\/User\/([0-9]+)\z/, path) do
      DB.one("SELECT * FROM users WHERE id=?", [String.to_integer(id)])
    else
      _ -> nil
    end
  end

  def missing_known_model?(attrs) do
    sgid = Map.new(attrs)["sgid"]

    with true <- is_binary(sgid),
         gid when is_binary(gid) <- Rails.verify_message("signed_global_ids", sgid, "attachable"),
         %URI{scheme: "gid", path: path} <- URI.parse(gid) do
      Regex.match?(~r/\A\/(?:User|Message|Room|Account|Boost)\//, path)
    else
      _ -> false
    end
  end

  def users(html) do
    html
    |> RichText.parse()
    |> Floki.find("action-text-attachment")
    |> Enum.map(fn {_, attrs, _} -> resolve_verified(attrs) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["id"])
  end

  def avatar(user, render \\ :action_text) do
    title =
      [user["name"], user["bio"]]
      |> Enum.reject(&(is_nil(&1) || String.trim(&1) == ""))
      |> Enum.join(" – ")
      |> Assets.html_escape()

    token = Rails.signed_id("User", user["id"], "avatar")
    version = user["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14)

    if render == :action_text do
      ~s(<a title="#{title}" class="btn avatar" href="/users/#{user["id"]}"><img src="/users/#{token}/avatar?v=#{version}" width="48" height="48"></a>)
    else
      ~s(<a title="#{title}" class="btn avatar" data-turbo-frame="_top" href="/users/#{user["id"]}"><img aria-hidden="true" src="/users/#{token}/avatar?v=#{version}" width="48" height="48" /></a>)
    end
  end

  def html(user),
    do:
      ~s(<span class="mention" sgid="#{Rails.attachable_sgid("User", user["id"])}">#{avatar(user)} #{Assets.html_escape(user["name"])}</span>)
end
