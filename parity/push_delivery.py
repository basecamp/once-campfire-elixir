#!/usr/bin/env python3
"""Actual HTTPS push delivery in a network namespace with no external access."""
import json,os,sqlite3,subprocess,time
from sessions import ROOT
SINK='campfire-elixir-push-sink';HOST='parity.fcm.googleapis.com';FOLDER=ROOT/'var/push'
def docker(*args,**opts):
 r=subprocess.run(['docker',*map(str,args)],capture_output=True,text=True,**opts)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r
def run(side):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 folder=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')
 path=folder/'production.sqlite3'
 vec=json.loads((ROOT/'vectors/web_push.json').read_text())
 result={}
 for label,status,invalidate,trust,host in [('success',201,True,True,HOST),('gone',410,True,True,HOST),('missing',404,True,True,HOST),('server_error',500,True,True,HOST),('manual_gone',410,False,True,HOST),('bad_certificate',201,True,False,HOST),('manual_bad_certificate',201,False,False,HOST),('private',201,True,True,'private.fcm.googleapis.com')]:
  endpoint=f'https://{host}/{side}/{label}/{status}'
  with sqlite3.connect(path) as db:
   db.execute('DELETE FROM push_subscriptions WHERE id=123')
   db.execute('INSERT INTO push_subscriptions (id,user_id,endpoint,p256dh_key,auth_key,created_at,updated_at) VALUES (123,127326141,?,?,?,?,?)',[endpoint,vec['p256dh'],vec['auth'],'2026-03-02 16:00:00','2026-03-02 16:00:00'])
  common=['run','--rm','--network','container:'+SINK,'--user',f'{os.getuid()}:{os.getgid()}','--env-file',ROOT/'parity/reference.env','-e','LD_PRELOAD=','-e','SSL_CERT_FILE='+('/push/ca.pem' if trust else '/etc/ssl/certs/ca-certificates.crt'),'-v',f'{folder}:/fixture','-v',f'{FOLDER}:/push','-v',f'{FOLDER}/hosts:/etc/hosts:ro']
  if side=='reference':
   common += ['-v',f'{ROOT}/var/rails:/rails/storage','campfire-reference:latest','bin/rails','runner']
   code='s=Push::Subscription.find(123); n=s.notification(title: "Push <& Ω", body: "Body\\nline", path: "/rooms/486777696"); '
   if invalidate:code+='p=WebPush::Pool.new(invalid_subscription_handler: ->(id) { Push::Subscription.find(id).destroy! }); begin; p.send(:deliver,n,s.id); rescue => e; puts e.class; ensure; p.shutdown; end'
   else:code+='begin; n.deliver; rescue => e; puts e.class; end'
  else:
   common += ['-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_JOBS_ADAPTER=disabled','-e','DATABASE_PATH=/fixture/production.sqlite3','-e','EXQLITE_USE_SYSTEM=1','-e','HOME=/app','-e','HEX_HOME=/app/.hex','-e','MIX_HOME=/app/.mix','-e','TMPDIR=/app/var/tmp','-v',f'{ROOT}:/app','-w','/app','campfire-elixir:toolchain','mix','run','-e']
   code='s=Campfire.DB.one("SELECT * FROM push_subscriptions WHERE id=123"); IO.inspect Campfire.Push.deliver(s,%{"title" => "Push <& Ω", "body" => "Body\\nline", "path" => "/rooms/486777696"},Campfire.DB.one("SELECT count(*) AS n FROM memberships WHERE user_id=127326141 AND unread_at IS NOT NULL")["n"],invalidate: '+str(invalidate).lower()+')'
  output=docker(*common,code,timeout=60)
  (ROOT/f'parity/push-{side}-{label}.log').write_text(output.stdout+output.stderr)
  with sqlite3.connect(path) as db:result[label]={'exists':db.execute('SELECT count(*) FROM push_subscriptions WHERE id=123').fetchone()[0]==1}
 return result
def prepare():
 FOLDER.mkdir(parents=True,exist_ok=True)
 commands=[
 ['docker','run','--rm','--user',f'{os.getuid()}:{os.getgid()}','-v',f'{ROOT}:/app','-w','/app','campfire-elixir:toolchain','cc','-O2','-Wall','-Wextra','-Werror','parity/push_netalias.c','-o','var/push/netalias'],
 ['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(FOLDER/'ca-key.pem'),'-out',str(FOLDER/'ca.pem'),'-days','365','-subj','/CN=CampfirePushFixtureCA'],
 ['openssl','req','-newkey','rsa:2048','-nodes','-keyout',str(FOLDER/'key.pem'),'-out',str(FOLDER/'leaf.csr'),'-subj','/CN=parity.fcm.googleapis.com']]
 (FOLDER/'extensions.cnf').write_text('basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:parity.fcm.googleapis.com\n')
 commands.append(['openssl','x509','-req','-in',str(FOLDER/'leaf.csr'),'-CA',str(FOLDER/'ca.pem'),'-CAkey',str(FOLDER/'ca-key.pem'),'-CAcreateserial','-out',str(FOLDER/'cert.pem'),'-days','365','-extfile',str(FOLDER/'extensions.cnf')])
 for index,command in enumerate(commands):
  with (FOLDER/f'prepare-{index}.log').open('w') as log:subprocess.run(command,check=True,stdout=log,stderr=log)
 (FOLDER/'sink.rb').write_bytes((ROOT/'parity/push_sink.rb').read_bytes())
if __name__=='__main__':
 prepare()
 (FOLDER/'hosts').write_text('127.0.0.1 localhost\n93.184.216.34 parity.fcm.googleapis.com\n127.0.0.1 private.fcm.googleapis.com\n')
 for name in ['ready','wire.jsonl']:(FOLDER/name).unlink(missing_ok=True)
 subprocess.run(['docker','rm','-f',SINK],capture_output=True)
 docker('run','-d','--name',SINK,'--user','0:0','--network','none','--cap-add','NET_ADMIN','-e','LD_PRELOAD=','-v',f'{FOLDER}:/fixture','--entrypoint','/bin/sh','campfire-reference:latest','-c','/fixture/netalias && exec ruby /fixture/sink.rb')
 try:
  for _ in range(100):
   if (FOLDER/'ready').exists():break
   time.sleep(.05)
  assert (FOLDER/'ready').exists(),docker('logs',SINK).stderr
  a=run('reference');b=run('candidate')
  for side,r in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/push-delivery.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
  assert a==b,(a,b)
  expected={'success':True,'gone':False,'missing':True,'server_error':True,'manual_gone':True,'bad_certificate':False,'manual_bad_certificate':True,'private':True}
  assert {k:v['exists'] for k,v in a.items()}==expected,a
  subprocess.run(['docker','run','--rm','--network','host','--user',f'{os.getuid()}:{os.getgid()}','--env-file',ROOT/'parity/reference.env','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_JOBS_ADAPTER=disabled','-e','DATABASE_PATH=/app/var/test.sqlite3','-e','EXQLITE_USE_SYSTEM=1','-e','HOME=/app','-e','HEX_HOME=/app/.hex','-e','MIX_HOME=/app/.mix','-e','TMPDIR=/app/var/tmp','-v',f'{ROOT}:/app','-w','/app','campfire-elixir:toolchain','mix','run','parity/verify_push_wire.exs'],check=True)
  (ROOT/'parity/results/push-delivery.json').write_text(json.dumps({'passed':True,'scope':['actual HTTPS delivery to controlled allowed-host public-IP fixture','201/404/410/500 delivery responses','expired-subscription cleanup','TLS failure cleanup','manual notification preserves invalid subscriptions','private-IP rejection','isolated namespace with no external network']},indent=2)+'\n')
  print('HTTPS push delivery, payloads and subscription invalidation parity passed')
 finally:subprocess.run(['docker','rm','-f',SINK],check=True,capture_output=True)
