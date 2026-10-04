c=MessagesController.new
c.set_request! ActionDispatch::TestRequest.create
c.lookup_context.formats=[:html]
values={}
%w[ messages/_message messages/boosts/_boost ].each do |name|
 values[name]=ActionView::Digestor.digest(name:name,format:nil,finder:c.lookup_context)
end
puts JSON.pretty_generate(values)
