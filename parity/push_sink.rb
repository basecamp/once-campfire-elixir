require "openssl"
require "socket"
require "json"
require "base64"
context=OpenSSL::SSL::SSLContext.new
context.cert=OpenSSL::X509::Certificate.new(File.read('/fixture/cert.pem'))
context.key=OpenSSL::PKey.read(File.read('/fixture/key.pem'))
listener=OpenSSL::SSL::SSLServer.new(TCPServer.new('93.184.216.34',443),context)
File.write('/fixture/ready','ready')
loop do
 begin
  socket=listener.accept
  line=socket.gets
  headers={}
  while (line_header=socket.gets) && line_header!="\r\n"
   name,value=line_header.split(':',2);headers[name.downcase]=value.strip
  end
  body=socket.read(headers.fetch('content-length','0').to_i)
  path=line.split(' ')[1]
  File.open('/fixture/wire.jsonl','a') { |f| f.puts JSON.generate(path: path,headers: headers,body: Base64.strict_encode64(body)) }
  status=path.split('/').last.to_i
  socket.write("HTTP/1.1 #{status} fixture\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
  socket.close
 rescue OpenSSL::SSL::SSLError, IOError, Errno::ECONNRESET
 end
end
