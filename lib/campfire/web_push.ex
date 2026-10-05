defmodule Campfire.WebPush do
  alias Campfire.{Clock, Storage}

  def encrypt(message, p256dh, auth, private \\ nil, salt \\ nil, layout \\ :gem) do
    if message == "" || p256dh in [nil, ""] || auth in [nil, ""],
      do: raise(ArgumentError, "blank Web Push argument")

    client = decode(p256dh) |> strip_zeros()
    auth = decode(auth)

    {public, private} =
      if private,
        do: :crypto.generate_key(:ecdh, :secp256r1, private),
        else: :crypto.generate_key(:ecdh, :secp256r1)

    salt = salt || :crypto.strong_rand_bytes(16)
    shared = :crypto.compute_key(:ecdh, client, private, :secp256r1)
    prk = hkdf(auth, shared, "WebPush: info\0" <> client <> public, 32)
    key = hkdf(salt, prk, "Content-Encoding: aes128gcm\0", 16)
    nonce = hkdf(salt, prk, "Content-Encoding: nonce\0", 12)
    padding = if layout == :rfc, do: <<2>>, else: <<2, 0>>

    {encrypted, tag} =
      :crypto.crypto_one_time_aead(:aes_128_gcm, key, nonce, message <> padding, "", 16, true)

    ciphertext = encrypted <> tag
    if byte_size(ciphertext) > 4096, do: raise(ArgumentError, "encrypted payload is too big")
    record_size = if layout == :rfc, do: 4096, else: byte_size(ciphertext)
    salt <> <<record_size::32, byte_size(public)::8>> <> public <> ciphertext
  end

  def decrypt(body, private, auth) do
    <<salt::binary-size(16), size::32, length::8, rest::binary>> = body
    <<server::binary-size(^length), ciphertext::binary>> = rest
    {public, _} = :crypto.generate_key(:ecdh, :secp256r1, private)
    shared = :crypto.compute_key(:ecdh, server, private, :secp256r1)
    prk = hkdf(auth, shared, "WebPush: info\0" <> public <> server, 32)
    key = hkdf(salt, prk, "Content-Encoding: aes128gcm\0", 16)
    nonce = hkdf(salt, prk, "Content-Encoding: nonce\0", 12)
    split = byte_size(ciphertext) - 16
    <<encrypted::binary-size(^split), tag::binary-size(16)>> = ciphertext
    {size, :crypto.crypto_one_time_aead(:aes_128_gcm, key, nonce, encrypted, "", tag, false)}
  end

  def authorization(audience, now \\ DateTime.to_unix(Clock.now())) do
    private = decode(System.fetch_env!("VAPID_PRIVATE_KEY"))
    public = decode(System.fetch_env!("VAPID_PUBLIC_KEY"))
    header = Base.url_encode64(~s({"typ":"JWT","alg":"ES256"}), padding: false)

    claims =
      Storage.ordered_json([
        {"aud", audience},
        {"exp", now + 43200},
        {"sub", "mailto:support@37signals.com"}
      ])
      |> Base.url_encode64(padding: false)

    input = header <> "." <> claims
    signature = :crypto.sign(:ecdsa, :sha256, input, [private, :secp256r1])
    {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", signature)
    signature = <<r::256, s::256>> |> Base.url_encode64(padding: false)
    "vapid t=#{input}.#{signature},k=#{Base.url_encode64(public, padding: false)}"
  end

  def encoded_message(payload, badge) do
    data = ~s({"path":#{Jason.encode!(payload["path"])},"badge":#{Jason.encode!(badge)}})
    options = ~s({"body":#{Jason.encode!(payload["body"])},"icon":"/account/logo","data":#{data}})
    ~s({"title":#{Jason.encode!(payload["title"])},"options":#{options}})
  end

  def decode(raw) do
    normalized =
      raw |> String.replace("-", "+") |> String.replace("_", "/") |> String.trim_trailing("=")

    Base.decode64!(normalized, padding: false)
  end

  defp strip_zeros(<<0, rest::binary>>), do: strip_zeros(rest)
  defp strip_zeros(value), do: value

  defp hkdf(salt, ikm, info, length) do
    prk = :crypto.mac(:hmac, :sha256, salt, ikm)
    :crypto.mac(:hmac, :sha256, prk, info <> <<1>>) |> binary_part(0, length)
  end
end
