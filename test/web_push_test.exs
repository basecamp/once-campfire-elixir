defmodule Campfire.WebPushTest do
  use ExUnit.Case, async: true
  alias Campfire.WebPush
  @expected Jason.decode!(File.read!("vectors/web_push.json"))
  test "decrypts the actual Ruby web-push ciphertext" do
    {size, plain} =
      WebPush.decrypt(
        WebPush.decode(@expected["ciphertext"]),
        WebPush.decode(@expected["receiver_private_key"]),
        WebPush.decode(@expected["auth"])
      )

    assert plain == @expected["message"] <> <<2, 0>>
    assert size == byte_size(WebPush.decode(@expected["ciphertext"])) - 86
  end

  test "matches RFC8291 deterministic encryption vector" do
    body =
      WebPush.encrypt(
        WebPush.decode("V2hlbiBJIGdyb3cgdXAsIEkgd2FudCB0byBiZSBhIHdhdGVybWVsb24"),
        "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
        "BTBZMqHH6r4Tts7J_aSIgg",
        WebPush.decode("yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"),
        WebPush.decode("DGv6ra1nlYgDCS1FRnbzlw"),
        :rfc
      )

    assert Base.url_encode64(body, padding: false) ==
             "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN"
  end

  test "random encryption round trips with the gem's record framing" do
    {public, private} = :crypto.generate_key(:ecdh, :secp256r1)
    auth = :crypto.strong_rand_bytes(16)
    message = ~s({"title":"Campfire"})

    body =
      WebPush.encrypt(
        message,
        Base.url_encode64(public, padding: false),
        Base.url_encode64(auth, padding: false)
      )

    assert WebPush.decrypt(body, private, auth) == {byte_size(message) + 18, message <> <<2, 0>>}
  end
end
