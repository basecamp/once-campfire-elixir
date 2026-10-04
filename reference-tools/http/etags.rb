require "json"
results={}
[[Users::AvatarsController, User.find(127326141)], [Accounts::LogosController,Account.first]].each do |klass,record|
 c=klass.new
 c.set_request! ActionDispatch::TestRequest.create
 c.set_response! klass.make_response!(c.request)
 c.action_name="show"
 template=c.send(:pick_template_for_etag,{})
 digest=template && c.send(:lookup_and_digest_template,template)
 validators=c.send(:combine_etags,record,{})
 results[klass.name]={template:template,digest:digest,key:record.cache_key_with_version,expanded:ActiveSupport::Cache.expand_cache_key(validators),etag:c.response.tap{|r| r.weak_etag=validators}.etag}
end
puts JSON.pretty_generate(results)
