require "json"
inputs = ["", "hello & goodbye", "<p>Hello &amp; goodbye</p>", "<div>Hello</div><div>World</div>",
  "<p>A<br>B</p><p>C</p>", "<script>alert(1)</script><p>safe</p>",
  '<p onclick="alert(1)" style="color: red">safe</p>', '<a href="javascript:alert(1)">bad</a>',
  '<a href="https://example.com?a=1&amp;b=2">link</a>', '<img src="x" onerror="alert(1)"><p>image</p>',
  '<table><tr><td>one</td><td>two</td></tr></table>', '<p><strong>Bold</strong> <em>em</em> <u>underline</u> <s>strike</s></p>',
  '<pre data-language="ruby">puts &quot;hi&quot;</pre>', '<p>Unicode: ☃ é</p>', '<figure><figcaption>A caption</figcaption></figure>']
data = inputs.map do |input|
  content = ActionText::Content.new(input)
  { input: input, expected: { html: content.to_s, plain_text: content.to_plain_text } }
end
puts "--- RAILS_TO_RUST_JSON_BEGIN ---"
puts JSON.generate(version: 1, kind: "richtext", reference_sha: ENV.fetch("RAILS_TO_RUST_REFERENCE_SHA"),
  policies: { tags: ActionText::ContentHelper.sanitizer.class.allowed_tags.to_a, attributes: ActionText::ContentHelper.sanitizer.class.allowed_attributes.to_a },
  runtime: { ruby_version: RUBY_VERSION, rails_version: Rails.version }, data: data)
puts "--- RAILS_TO_RUST_JSON_END ---"
