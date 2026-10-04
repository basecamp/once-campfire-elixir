vec = Jason.decode!(File.read!("vectors/web_push.json"))
private = Campfire.WebPush.decode(vec["receiver_private_key"])
auth = Campfire.WebPush.decode(vec["auth"])
wire = File.read!("var/push/wire.jsonl") |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)
expected = ~w(success gone missing server_error manual_gone)
results = Enum.map(wire, fn request ->
  [_, side, label, _] = String.split(request["path"], "/")
  body = Base.decode64!(request["body"])
  {size, plaintext} = Campfire.WebPush.decrypt(body, private, auth)
  true = size == byte_size(body) - 86
  <<message::binary-size(byte_size(plaintext)-2), 2, 0>> = plaintext
  headers = request["headers"]
  true = String.to_integer(headers["content-length"]) == byte_size(body)
  [_, token, public] = Regex.run(~r/^vapid t=([^,]+),k=(.+)$/, headers["authorization"])
  [header, claims, signature] = String.split(token, ".")
  %{"typ" => "JWT", "alg" => "ES256"} = Jason.decode!(Campfire.WebPush.decode(header))
  claims = Jason.decode!(Campfire.WebPush.decode(claims))
  true = claims["aud"] == "https://parity.fcm.googleapis.com"
  true = claims["sub"] == "mailto:support@37signals.com"
  true = abs(claims["exp"] - DateTime.to_unix(DateTime.utc_now()) - 43200) < 300
  <<r::256,s::256>> = Campfire.WebPush.decode(signature)
  der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value",r,s})
  signed = Enum.take(String.split(token, "."),2) |> Enum.join(".")
  true = :crypto.verify(:ecdsa,:sha256,signed,der,[Campfire.WebPush.decode(public),:secp256r1])
  true = Campfire.WebPush.decode(public) == Campfire.WebPush.decode(System.fetch_env!("VAPID_PUBLIC_KEY"))
  {side,label,%{"payload" => Jason.decode!(message), "headers" => Map.take(headers,~w(host content-type ttl urgency content-encoding)), "vapid" => Map.delete(claims,"exp")}}
end)
by_side = Enum.group_by(results,&elem(&1,0),fn {_,label,value} -> {label,value} end) |> Map.new(fn {side,values} -> {side,Map.new(values)} end)
true = Map.keys(by_side["reference"]) |> Enum.sort() == Enum.sort(expected)
true = Map.keys(by_side["candidate"]) |> Enum.sort() == Enum.sort(expected)
true = by_side["reference"] == by_side["candidate"]
File.write!("parity/results/push-wire.json", Jason.encode!(%{"passed" => true,"scope" => ["actual HTTPS wire requests","both runtime ciphertexts decrypted","AES-GCM authentication/framing","VAPID signature/public key/audience/expiry","payload JSON, badge and delivery headers"], "deliveries" => by_side["reference"]},pretty: true) <> "\n")
IO.puts("HTTPS push payload, encryption, VAPID and delivery header parity passed")
