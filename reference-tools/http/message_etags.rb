require "json"
c = MessagesController.new
c.set_request! ActionDispatch::TestRequest.create
c.set_response! MessagesController.make_response!(c.request)
c.action_name = "index"
c.lookup_context.formats = [:html]
messages = Room.find(486777696).messages.last_page
template = c.send(:pick_template_for_etag, {})
digest = template && c.send(:lookup_and_digest_template, template)
validators = c.send(:combine_etags, messages, {})
puts JSON.pretty_generate({template: template, digest: digest, keys: messages.map(&:cache_key_with_version), expanded: ActiveSupport::Cache.expand_cache_key(validators), etag: c.response.tap { |r| r.weak_etag = validators }.etag, last_modified: messages.map(&:updated_at).max.httpdate})
