require 'json'
require 'rqrcode'
inputs = ['', 'hello', 'HELLO WORLD', '012345678901234567890', 'https://campfire.test/join/abcdefgh', 'http://campfire.test/join/CampfireJoinToken', 'http://campfire.test/session/transfers/' + 'a'*240, 'Ω🙂<&>', "binary\xFF".b] + [20,40,80,120,180,240,400,700,1000,1273,1274].map { |n| 'x'*n }
vectors = inputs.map do |text|
  row = {base64: [text].pack('m0')}
  begin
    qr = RQRCode::QRCode.new(text)
    svg = qr.as_svg(viewbox: true, fill: :white, color: :black)
    row.merge!(version: qr.qrcode.version, mask: qr.qrcode.send(:get_best_mask_pattern), svg: svg)
  rescue => e
    row[:error] = e.class.name
  end
  row
end
puts JSON.generate(vectors)
