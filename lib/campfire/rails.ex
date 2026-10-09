defmodule Campfire.Rails do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Rails signing and encryption, validated against reference-produced vectors."
  @doc "JSON as Rails generates it; see `Campfire.JSON`."
  def json(value), do: IO.iodata_to_binary(Campfire.JSON.encode(value))

  # SECRET_KEY_BASE, read once.
  defp secret do
    case :persistent_term.get({__MODULE__, :secret}, nil) do
      nil ->
        secret = System.fetch_env!("SECRET_KEY_BASE")
        :persistent_term.put({__MODULE__, :secret}, secret)
        secret

      secret ->
        secret
    end
  end

  def key(salt, length) do
    secret = secret()
    cache = {__MODULE__, secret, salt, length}

    case :persistent_term.get(cache, nil) do
      nil ->
        key = :crypto.pbkdf2_hmac(:sha256, secret, salt, 1000, length)
        :persistent_term.put(cache, key)
        key

      key ->
        key
    end
  end

  def sign_cookie(name, value, expires \\ nil) do
    legacy(value, "cookie." <> name, expires)
    |> Base.encode64()
    |> sign(key("signed cookie", 64), :sha)
  end

  def verify_cookie(name, raw, now \\ Campfire.Clock.now()) do
    case verified(raw, key("signed cookie", 64), :sha) do
      nil -> nil
      decoded -> cookie_metadata(decoded, "cookie." <> name, now)
    end
  rescue
    _ -> nil
  end

  def encrypt_cookie(name, value, expires \\ nil) do
    iv = :crypto.strong_rand_bytes(12)

    {data, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        key("authenticated encrypted cookie", 32),
        iv,
        legacy(value, "cookie." <> name, expires),
        "",
        16,
        true
      )

    Enum.map_join([data, iv, tag], "--", &Base.encode64/1)
  end

  def decrypt_cookie(name, raw, now \\ Campfire.Clock.now()) do
    case decrypted(raw) do
      nil -> nil
      decoded -> cookie_metadata(decoded, "cookie." <> name, now)
    end
  rescue
    _ -> nil
  end

  defp decrypted(raw) do
    with [data, iv, tag] <- String.split(raw, "--"),
         {:ok, data} <- base64(data),
         {:ok, iv} <- base64(iv),
         {:ok, tag} <- base64(tag),
         true <- byte_size(iv) == 12 and byte_size(tag) == 16,
         plain when is_binary(plain) <-
           :crypto.crypto_one_time_aead(
             :aes_256_gcm,
             key("authenticated encrypted cookie", 32),
             iv,
             data,
             "",
             tag,
             false
           ),
         {:ok, decoded} <- json_decode(plain) do
      decoded
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def sign_message(name, data_json, purpose, expires \\ nil) do
    fields =
      ["\"data\":" <> data_json] ++
        if(expires, do: ["\"exp\":" <> json(expires)], else: []) ++
        if purpose, do: ["\"pur\":" <> json(purpose)], else: []

    payload =
      if purpose || expires,
        do: "{\"_rails\":{" <> Enum.join(fields, ",") <> "}}",
        else: data_json

    payload |> Base.encode64() |> sign(key(name, 64), :sha)
  end

  def attachable_sgid(model, id) do
    envelope =
      ~s({"_rails":{"data":#{json("gid://campfire/#{model}/#{id}?expires_in")},"pur":"attachable"}})

    envelope |> Base.url_encode64() |> sign(key("signed_global_ids", 64), :sha)
  end

  def verify_message(name, raw, purpose, now \\ Campfire.Clock.now()),
    do: verify(raw, key(name, 64), :sha, purpose, now)

  def sign_stream(stream),
    do:
      Jason.encode!(stream)
      |> Base.encode64()
      |> sign(key("turbo/signed_stream_verifier_key", 64), :sha256)

  def verify_stream(raw),
    do:
      verify(raw, key("turbo/signed_stream_verifier_key", 64), :sha256, nil, Campfire.Clock.now())

  def signed_id(model, id, purpose \\ nil, expires \\ nil) do
    fields =
      ["\"data\":" <> json(id)] ++
        if(expires, do: ["\"exp\":" <> json(expires)], else: []) ++
        ["\"pur\":" <> json(purpose(model, purpose))]

    ("{\"_rails\":{" <> Enum.join(fields, ",") <> "}}")
    |> Base.url_encode64(padding: false)
    |> sign(key("active_record/signed_id", 64), :sha256)
  end

  def verify_id(model, raw, purpose \\ nil, now \\ Campfire.Clock.now()) do
    pur = purpose(model, purpose)

    value =
      verify(raw, key("active_record/signed_id", 64), :sha256, pur, now) ||
        verify(raw, key("active_record/signed_id", 64), :sha, pur, now)

    value
  end

  defp purpose(model, purpose) do
    model =
      model
      |> String.replace("::", "/")
      |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
      |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
      |> String.replace("-", "_")
      |> String.downcase()

    [model, purpose] |> Enum.reject(&(is_nil(&1) or String.trim(&1) == "")) |> Enum.join("/")
  end

  defp sign(encoded, key, algorithm),
    do:
      encoded <>
        "--" <> :binary.encode_hex(:crypto.mac(:hmac, algorithm, key, encoded), :lowercase)

  defp verify(raw, key, algorithm, purpose, now) do
    case verified(raw, key, algorithm) do
      nil -> nil
      decoded -> metadata(decoded, purpose, now)
    end
  rescue
    _ -> nil
  end

  defp verified(raw, key, algorithm) do
    with [encoded, digest] <- String.split(raw, "--"),
         expected = :binary.encode_hex(:crypto.mac(:hmac, algorithm, key, encoded), :lowercase),
         true <- Plug.Crypto.secure_compare(digest, expected),
         {:ok, plain} <- decode64(encoded),
         {:ok, decoded} <- json_decode(plain) do
      decoded
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp decode64(value) do
    case base64(value) do
      {:ok, data} -> {:ok, data}
      _ -> base64(value, %{mode: :urlsafe, padding: false})
    end
  end

  # Erlang's native base64 and JSON, as cookies are decoded on every request.
  defp base64(value, options \\ %{}) do
    {:ok, :base64.decode(value, options)}
  rescue
    _ -> :error
  end

  defp json_decode(text) do
    case :json.decode(text, :ok, %{null: nil}) do
      {value, :ok, ""} -> {:ok, value}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp cookie_metadata(%{"_rails" => %{"message" => _} = meta}, purpose, now) do
    metadata(%{"_rails" => meta}, if(is_nil(meta["pur"]), do: nil, else: purpose), now)
  end

  defp cookie_metadata(value, _purpose, _now), do: value

  defp metadata(%{"_rails" => meta}, purpose, now) do
    if meta["pur"] == purpose and unexpired?(meta["exp"], now) do
      case meta do
        %{"data" => data} ->
          data

        %{"message" => message} ->
          with {:ok, text} <- base64(message),
               {:ok, value} <- json_decode(text),
               do: value,
               else: (_ -> nil)

        _ ->
          nil
      end
    end
  end

  defp metadata(value, nil, _), do: value
  defp metadata(_, _, _), do: nil
  defp unexpired?(nil, _), do: true

  defp unexpired?(expires, now) do
    case DateTime.from_iso8601(expires) do
      {:ok, time, _} -> DateTime.compare(time, now) == :gt
      _ -> false
    end
  end

  defp legacy(value, purpose, expires),
    do:
      ~s({"_rails":{"message":) <>
        json(Base.encode64(json(value))) <>
        ~s(,"exp":) <> json(expires) <> ~s(,"pur":) <> json(purpose) <> "}}"

  def csrf_token, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

  def csrf_mask(raw) do
    pad = :crypto.strong_rand_bytes(32)
    Base.url_encode64(pad <> :crypto.exor(pad, raw), padding: false)
  end

  def csrf_global(session_token) do
    {:ok, raw} = Base.url_decode64(session_token, padding: false)
    :crypto.mac(:hmac, :sha256, raw, "!real_csrf_token")
  end

  def csrf_form(session_token, path, method) do
    {:ok, raw} = Base.url_decode64(session_token, padding: false)

    :crypto.mac(
      :hmac,
      :sha256,
      raw,
      String.trim_trailing(path, "/") <> "#" <> String.downcase(method)
    )
  end

  def csrf_valid?(token, session_token, path, method) do
    with true <- is_binary(token) and is_binary(session_token),
         {:ok, data} <-
           Base.url_decode64(
             String.replace(token, ["+", "/"], fn
               "+" -> "-"
               "/" -> "_"
             end),
             padding: false
           ),
         {:ok, real} <- Base.url_decode64(session_token, padding: false) do
      unmasked =
        case data do
          <<pad::binary-size(32), masked::binary-size(32)>> ->
            :crypto.exor(pad, masked)

          <<raw::binary-size(32)>> ->
            if Plug.Crypto.secure_compare(raw, real), do: real, else: nil

          _ ->
            nil
        end

      is_binary(unmasked) and
        Enum.any?(
          [real, csrf_global(session_token), csrf_form(session_token, path, method)],
          &Plug.Crypto.secure_compare(unmasked, &1)
        )
    else
      _ -> false
    end
  rescue
    _ -> false
  end
end
