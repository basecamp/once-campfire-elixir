inputs=JSON.parse(STDIN.read)
Opengraph::Location.prepend(Module.new do
  def read_html; $oracle_html; end
  def fetch_content_type; $oracle_image_type; end
  def resolved_ip; '8.8.8.8'; end
end)
puts JSON.pretty_generate(inputs.map do |input|
  $oracle_html=input['html'];$oracle_image_type=input['image_type']
  m=Opengraph::Metadata.from_url(input['url'])
  valid=m.valid?
  input.merge(valid:valid,json:m.to_json)
end)
