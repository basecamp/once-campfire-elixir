cases=JSON.parse(STDIN.read)
puts JSON.pretty_generate(cases.map{|html|{html:html,attributes:Opengraph::Document.new(html).opengraph_attributes}})
