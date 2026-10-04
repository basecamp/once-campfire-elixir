require 'json'
rows=JSON.parse(File.read('/rails/tmp/elixir-route-actions.json'))
samples=rows.filter_map do |row|
 next unless ['GET','POST','PUT','PATCH','DELETE'].include?(row['verb'])
 next if row['path'].include?('*')
 path=row['path'].sub('(.:format)','').gsub(/:room_id/, '486777696').gsub(/:user_id/,'127326141').gsub(/:message_id/,'933434638').gsub(/:id/,'933434638').gsub(/:bot_key/,'394959859-BenderBot123').gsub(/:join_code/,'CampfireJoinToken')
 begin
  params=Rails.application.routes.recognize_path(path,method:row['verb'].downcase.to_sym)
  {path:path,method:row['verb'],params:params}
 rescue ActionController::RoutingError
  {path:path,method:row['verb'],params:nil}
 end
end
puts JSON.pretty_generate(samples)
