#!/usr/bin/env python3
"""Production HTTP drain while a manual push request waits on isolated HTTPS."""
import json,os,shutil,sqlite3,subprocess,time
from sessions import ROOT
from push_delivery import prepare,FOLDER,docker
BASE=ROOT/'var/http-drain';SINK='campfire-elixir-http-sink';APP='campfire-elixir-http-drain'
SINK_CODE='''require "socket";require "openssl"
c=OpenSSL::SSL::SSLContext.new;c.cert=OpenSSL::X509::Certificate.new(File.read('/push/cert.pem'));c.key=OpenSSL::PKey.read(File.read('/push/key.pem'))
s=OpenSSL::SSL::SSLServer.new(TCPServer.new('93.184.216.34',443),c);File.write('/fixture/ready','1')
loop do
 begin
  q=s.accept;q.gets;h={};while(l=q.gets)&&l!="\\r\\n";k,v=l.split(':',2);h[k.downcase]=v.strip;end;q.read(h.fetch('content-length','0').to_i)
  File.write('/fixture/started','1');sleep 0.02 until File.exist?('/fixture/release');q.write("HTTP/1.1 201 Created\\r\\nContent-Length: 0\\r\\nConnection: close\\r\\n\\r\\n");q.close
 rescue OpenSSL::SSL::SSLError,IOError,Errno::ECONNRESET
 end
end
'''
CLIENT_CODE='''require "net/http";require "json";require "uri"
jar={};csrf=nil
send_request=->(path,method,params={}) do
 http=Net::HTTP.new('127.0.0.1',47200);http.read_timeout=30
 q=(method=='GET' ? Net::HTTP::Get : Net::HTTP::Post).new(path)
 q['Host']='campfire.test';q['User-Agent']='Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36';q['Cookie']=jar.map{|k,v|"#{k}=#{v}"}.join('; ')
 if method!='GET';q.set_form_data(params);q['Origin']='http://campfire.test';q['Sec-Fetch-Site']='same-origin';end
 r=http.request(q);(r.get_fields('set-cookie')||[]).each{|v|k,x=v.split(';',2).first.split('=',2);jar[k]=x};r
end
case ARGV[0]
when 'ready'
  200.times do
   begin;r=send_request.call('/up','GET');exit 0 if r.code=='200';rescue SystemCallError,EOFError;end;sleep 0.05
  end;raise 'not ready'
when 'login'
  r=send_request.call('/session/new','GET');csrf=r.body[/name="csrf-token" content="([^"]*)"/,1];raise 'missing csrf' unless csrf
  r=send_request.call('/session','POST',{'email_address'=>'david@37signals.com','password'=>'secret123456','authenticity_token'=>csrf});raise r.code unless r.code=='302'
  File.write('/fixture/credentials.json',JSON.generate(cookies:jar,csrf:csrf))
when 'post'
  c=JSON.parse(File.read('/fixture/credentials.json'));jar.merge!(c['cookies']);r=send_request.call('/users/me/push_subscriptions/123/test_notifications','POST',{'authenticity_token'=>c['csrf']})
  File.write('/fixture/result.json',JSON.generate(status:r.code.to_i,location:r['location'],body:r.body))
end
'''
def await_file(path):
 for _ in range(400):
  if path.exists():return
  time.sleep(.05)
 raise AssertionError('Timed out waiting for '+str(path))
def seed(folder):
 if folder.exists():shutil.rmtree(folder)
 folder.mkdir();(folder/'files').mkdir()
 data=json.loads((ROOT/'test/fixtures/seed.json').read_text())
 with sqlite3.connect(folder/'production.sqlite3') as db:
  db.executescript(';\n'.join(data['schema'])+';')
  for table,rows in data['tables'].items():
   for row in rows:db.execute('INSERT INTO "'+table+'" ('+','.join('"'+k+'"' for k in row)+') VALUES ('+','.join('?' for k in row)+')',list(row.values()))
  v=json.loads((ROOT/'vectors/web_push.json').read_text());db.execute('DELETE FROM push_subscriptions WHERE id=123');db.execute('INSERT INTO push_subscriptions (id,user_id,endpoint,p256dh_key,auth_key,created_at,updated_at) VALUES (123,127326141,?,?,?,?,?)',['https://parity.fcm.googleapis.com/drain',v['p256dh'],v['auth'],'2026-03-02 16:00:00','2026-03-02 16:00:00'])
 for blob in data['tables']['active_storage_blobs']:
  key=blob['key'];p=folder/'files'/key[:2]/key[2:4]/key;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'test/fixtures/storage'/key,p)
def client(folder,action,wait=True):
 command=['docker','run','--rm','--network','container:'+SINK,'--user',f'{os.getuid()}:{os.getgid()}','-e','LD_PRELOAD=','-v',f'{folder}:/fixture','-v',f'{BASE}/client.rb:/client.rb:ro','--entrypoint','ruby','campfire-reference:latest','/client.rb',action]
 if wait:return subprocess.run(command,capture_output=True,text=True,check=True,timeout=40)
 log=(folder/'client.log').open('w');return subprocess.Popen(command,stdout=log,stderr=log),log

def run(side):
 folder=BASE/side;seed(folder)
 for f in ['started','release','ready']:(BASE/f).unlink(missing_ok=True)
 subprocess.run(['docker','rm','-f',APP,SINK],capture_output=True)
 docker('run','-d','--name',SINK,'--network','none','--cap-add','NET_ADMIN','--user','0:0','-e','LD_PRELOAD=','-v',f'{BASE}:/fixture','-v',f'{FOLDER}:/push','--entrypoint','/bin/sh','campfire-reference:latest','-c','/push/netalias && exec ruby /fixture/sink.rb')
 await_file(BASE/'ready')
 args=['run','-d','--name',APP,'--network','container:'+SINK,'--user',f'{os.getuid()}:{os.getgid()}','--env-file',ROOT/'parity/reference.env','-e','LD_PRELOAD=','-e','SSL_CERT_FILE=/push/ca.pem','-v',f'{FOLDER}:/push','-v',f'{BASE}/hosts:/etc/hosts:ro','-v',f'{folder}:/data','-e','PORT=47200','-e','CAMPFIRE_JOBS_ADAPTER=disabled']
 if side=='reference':args+=['-v',f'{folder}:/rails/storage','-e','STORAGE_PATH=/data/files','-e','DATABASE_PATH=/data/production.sqlite3','campfire-reference:latest','bin/rails','server','-b','127.0.0.1','-p','47200']
 else:args+=['-e','DATABASE_PATH=/data/production.sqlite3','-e','STORAGE_PATH=/data/files','campfire-elixir:release']
 # Rails uses storage/db by configuration; both copies are fixture owned.
 if side=='reference':
  (folder/'db').mkdir();shutil.copyfile(folder/'production.sqlite3',folder/'db/production.sqlite3')
 docker(*args);client(folder,'ready');client(folder,'login')
 proc,log=client(folder,'post',False)
 try:
  await_file(BASE/'started');begin=time.monotonic();docker('kill','--signal','TERM',APP)
  time.sleep(6);(BASE/'release').write_text('1')
  proc.wait(timeout=20);assert proc.returncode==0,(side,(folder/'client.log').read_text())
  result=json.loads((folder/'result.json').read_text());assert result['status']==302 and result['location']=='http://campfire.test/users/me/push_subscriptions',(side,result)
  exitcode=docker('wait',APP,timeout=25).stdout.strip();elapsed=time.monotonic()-begin;assert elapsed>=6
  dbpath=folder/('db/production.sqlite3' if side=='reference' else 'production.sqlite3')
  with sqlite3.connect(dbpath) as db:assert db.execute('SELECT COUNT(*) FROM push_subscriptions WHERE id=123').fetchone()[0]==1
  (ROOT/f'parity/http-shutdown-{side}.log').write_text(docker('logs',APP).stdout)
  return {'response':result,'request_completed_after_term':True,'valid_subscription_preserved':True,'process_exited':True,'exit_code':exitcode,'drain_seconds':elapsed}
 finally:
  (BASE/'release').write_text('1');log.close()
  subprocess.run(['docker','rm','-f',APP,SINK],capture_output=True)
if __name__=='__main__':
 prepare();BASE.mkdir(parents=True,exist_ok=True);(BASE/'sink.rb').write_text(SINK_CODE);(BASE/'client.rb').write_text(CLIENT_CODE);(BASE/'hosts').write_text('127.0.0.1 localhost\n93.184.216.34 parity.fcm.googleapis.com\n')
 result={side:run(side) for side in ['reference','candidate']}
 (ROOT/'parity/results/http-shutdown.json').write_text(json.dumps({'passed':True,'scope':['production server termination during in-flight HTTP request','real HTTPS external call in namespace without external access','completed response and preserved valid subscription','process shutdown after response'],'results':result},indent=2)+'\n')
 print('Production in-flight HTTP/HTTPS graceful shutdown parity passed')
