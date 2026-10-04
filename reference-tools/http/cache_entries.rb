require 'base64'
coder=Rails.cache.instance_variable_get(:@coder)
values=['','plain HTML',"<p>Ω 日本 😅 &amp;</p>",'<p>repeated</p>'*200]
results=[]
values.each do |value|
  [nil,'20260302160000000000'].each do |version|
    [nil,1000000000.0,2100000000.0].each do |expires|
      entry=ActiveSupport::Cache::Entry.new(value,version:version,expires_at:expires)
      results << {value:value,version:version,expires:expires,base64:Base64.strict_encode64(coder.dump_compressed(entry,1024))}
    end
  end
end
puts JSON.pretty_generate(results)
