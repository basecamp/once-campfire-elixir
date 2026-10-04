require 'json'
require 'uri'
urls = ['http://example.com','https://example.com/a?x=1#part','HTTP://EXAMPLE.COM/a','http://example.com/a b','http://example.com/Ω','http://example.com/%GG','http://example.com/a\\b','http://example.com/a|b','http://example.com/a{b}','http://example.com/a[b]','http://example.com/a\"b',"http://example.com/a\r\nX-Test: injected",'http://example.com:99999','http://example.com:abc','http://[::1]/','http://user:password@example.com/a','http:example.com','https:///example.com','http://example.com/%20','http://example.com?query=é']
puts JSON.pretty_generate(urls.map { |url| begin; uri=URI.parse(url); { url: url, valid: uri.is_a?(URI::HTTP), host: uri.host, path: uri.request_uri }; rescue; { url: url, valid: false }; end })
