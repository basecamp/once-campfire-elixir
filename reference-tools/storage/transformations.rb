require "json"
require "digest"
inputs = [
 { resize_to_limit: [96, 80] }, { resize_to_fit: [96, 80] }, { resize_to_fill: [96, 80] }, { resize_and_pad: [96, 80] },
 { resize_to_fit: [2400, 1800] }, { resize_to_limit: [nil, 80] }, { resize_to_fit: [96, nil] },
 { rotate: 90 }, { rotate: 180 }, { rotate: 270 }, { rotate: 17 },
 { flip: "horizontal" }, { flip: "vertical" }, { crop: [12, 24, 96, 80] }, { resize: 0.25 },
 { sharpen: { sigma: 1.2 } }, { gamma: { exponent: 1.6 } }, { flatten: { background: [240, 245, 250] } },
 { resize_to_fill: [96, 80], rotate: 90 }, { resize_to_fit: [96, 80, { sharpen: false }] },
 { resize_to_cover: [96, 80] },
 { loader: { page: 0, autorot: false } }, { loader: { unknown_fixture_option: true } },
 { saver: { compression: 1, strip: true } }, { saver: { quality: 20 } }, { saver: { unknown_fixture_option: true } },
 { convert: "jpg", saver: { quality: 33 } },
 { resize_and_pad: [96, 96, { background: [240, 245, 250], extend: "background", gravity: "north-west", alpha: true }] },
 { blur: 2 }, { combine_options: { resize: "96x80" } }, { nonexistent: true }, { rotate: false }
]
results = inputs.map do |transformations|
 result = { transformations: transformations, fixture: "moon.jpg", format: "png" }
 begin
  File.open(Rails.root.join("test/fixtures/files/moon.jpg")) do |input|
   ActiveStorage::Transformers::Vips.new(transformations).transform(input, format: "png") do |output|
    bytes = output.read
    image = Vips::Image.new_from_file(output.path)
    result.merge!(bytes: bytes.bytesize, checksum: Digest::MD5.base64digest(bytes), width: image.width, height: image.height)
   end
  end
 rescue => error
  result[:error] = error.class.name
 end
 result
end
puts JSON.pretty_generate(results)
