require 'json'
result=Rails.application.routes.routes.filter_map do |route|
 defaults=route.defaults
 next unless defaults[:controller]
 begin
  klass="#{defaults[:controller].camelize}Controller".constantize
  status=klass.action_methods.include?(defaults[:action]) ? 'implemented' : 'missing_action'
 rescue NameError
  status='missing_controller'
 end
 {path:route.path.spec.to_s,verb:route.verb,controller:defaults[:controller],action:defaults[:action],status:status}
end
puts JSON.pretty_generate(result)
