require "json"
inputs = [
 {}, { "REMOTE_ADDR" => "203.0.113.1" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.9" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.9, 10.0.0.1, 172.16.1.1" },
 { "HTTP_X_FORWARDED_FOR" => "10.0.0.1, 192.168.1.1" },
 { "HTTP_X_FORWARDED_FOR" => "bad, 198.51.100.9, invalid" },
 { "HTTP_X_FORWARDED_FOR" => "2001:db8::1, fe80::1" },
 { "HTTP_X_FORWARDED_FOR" => "fc00::1, ::1" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.9", "HTTP_CLIENT_IP" => "198.51.100.8" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.9", "HTTP_CLIENT_IP" => "198.51.100.9" },
 { "HTTP_CLIENT_IP" => "198.51.100.8" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.9/32, 10.0.0.1" },
 { "HTTP_X_FORWARDED_FOR" => "198.51.100.0/24, 10.0.0.1" },
 { "HTTP_X_FORWARDED_FOR" => "::ffff:127.0.0.1" },
 { "HTTP_X_FORWARDED_FOR" => "0x7f000001, 2130706433, 127.1, 0177.0.0.1" }
]
puts JSON.pretty_generate(inputs.map do |headers|
 value = { headers: headers }
 app = ->(env) { value[:address] = ActionDispatch::Request.new(env).remote_ip; [200, {}, []] }
 begin
  ActionDispatch::RemoteIp.new(app).call({"REMOTE_ADDR"=>"127.0.0.1"}.merge(headers))
 rescue => error
  value[:error] = error.class.name
 end
 value
end)
