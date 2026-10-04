#!/usr/bin/env python3
"""Pinned Net::HTTP wire behavior against disposable local TCP responses."""
import base64,gzip,json,socketserver,subprocess,threading,time,zlib
from sessions import ROOT
class Sink(socketserver.BaseRequestHandler):
 wire=b'';delay=0
 def handle(self):
  data=b''
  while b'\r\n\r\n' not in data:data+=self.request.recv(65536)
  time.sleep(self.server.delay)
  try:self.request.sendall(self.server.wire)
  except OSError:pass
class Server(socketserver.ThreadingTCPServer):allow_reuse_address=True;daemon_threads=True
TEXT=b'<p>Protocol &amp; reply \xce\xa9</p>'
def response(headers,body=TEXT,status=200):return f'HTTP/1.1 {status} fixture\r\n'.encode()+headers+b'\r\n'+body
CASES={
 'plain':response(b'Content-Type: text/html\r\nContent-Length: '+str(len(TEXT)).encode()+b'\r\n'),
 'gzip':response(b'Content-Type: text/html\r\nContent-Encoding: gzip\r\nContent-Length: '+str(len(gzip.compress(TEXT,mtime=0))).encode()+b'\r\n',gzip.compress(TEXT,mtime=0)),
 'deflate':response(b'Content-Type: text/html\r\nContent-Encoding: deflate\r\nContent-Length: '+str(len(zlib.compress(TEXT))).encode()+b'\r\n',zlib.compress(TEXT)),
 'chunked':response(b'Content-Type: text/html\r\nTransfer-Encoding: chunked\r\n',f'{len(TEXT):x};extension=yes\r\n'.encode()+TEXT+b'\r\n0\r\nX-Trailer: ok\r\n\r\n'),
 'informational':b'HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 103 Early Hints\r\nLink: </a>\r\n\r\n'+response(b'Content-Type: text/html\r\n'),
 'repeated_headers':response(b'X-Fixture: one\r\nX-Fixture: two\r\nContent-Type: text/html\r\n'),
 'folded_headers':response(b'X-Fixture: one\r\n two\r\nContent-Type: text/html\r\n'),
 'bodyless_204':response(b'Content-Type: text/plain\r\nContent-Length: 12345\r\n',b'',204),
 'bodyless_304':response(b'Content-Type: text/plain\r\nContent-Length: 12345\r\n',b'',304),
 'truncated_length':response(b'Content-Type: text/html\r\nContent-Length: 12345\r\n'),
 'invalid_chunk':response(b'Transfer-Encoding: chunked\r\n',b'zz\r\nhello'),
 'timeout':response(b'Content-Type: text/html\r\n')}
RUBY='''require "net/http"; require "json"; require "base64"; h=Net::HTTP.new("127.0.0.1",47113);h.open_timeout=0.2;h.read_timeout=0.2; begin;r=h.request(Net::HTTP::Post.new("/", "Content-Type"=>"application/json").tap{|q|q.body="{}"});puts JSON.generate(status:r.code.to_i,headers:r.to_hash.transform_values{|v|v.join(", ")},body:r.body && Base64.strict_encode64(r.body));rescue=>e;puts JSON.generate(error:e.class.name);end'''
ELIXIR='''result = case Campfire.Network.request("http://127.0.0.1:47113/", :post, [{"Content-Type", "application/json"}], "{}", guard: :none, timeout: 200) do {:ok, status, headers, body} -> %{status: status, headers: headers, body: body && Base.encode64(body)}; error -> %{error: inspect(error)} end; IO.puts(Jason.encode!(result))'''
def client(side):
 name='campfire-elixir-'+('rails' if side=='reference' else 'candidate')
 command=['docker','exec',name]
 command+=['ruby','-e',RUBY] if side=='reference' else ['env','CAMPFIRE_NO_SERVER=1','CAMPFIRE_JOBS_ADAPTER=disabled','mix','run','-e',ELIXIR]
 r=subprocess.run(command,capture_output=True,text=True,check=True,timeout=30)
 return json.loads(r.stdout.strip().splitlines()[-1])
if __name__=='__main__':
 for side in ['reference','candidate']:subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 server=Server(('127.0.0.1',47113),Sink);threading.Thread(target=server.serve_forever,daemon=True).start();results={s:{} for s in ['reference','candidate']}
 try:
  for label,wire in CASES.items():
   server.wire=wire;server.delay=.35 if label=='timeout' else 0
   for side in results:results[side][label]=client(side)
 finally:server.shutdown();server.server_close()
 for side,r in results.items():(ROOT/f'parity/results/network-protocol.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 issues=[]
 for label,a in results['reference'].items():
  b=results['candidate'][label]
  if 'error' in a:
   if 'error' not in b:issues.append((label,a,b))
  elif a!=b:issues.append((label,a,b))
 passed=not issues
 (ROOT/'parity/results/network-protocol.json').write_text(json.dumps({'passed':passed,'scope':list(CASES),'failure_comparison':'runtime-specific exception classes retained; failures compared by disposition','differences':issues},indent=2)+'\n')
 if issues:print(json.dumps(issues,indent=2));raise SystemExit('Network protocol parity failed')
 print('Network protocol parity passed')
