#!/usr/bin/env python3
from drain_jobs import WAIT
"""Compare avatar/logo attachment updates, processed files, removal and queued purge."""
import base64,hashlib,http.client,json,re,sqlite3,subprocess
from sessions import ROOT,request,csrf_token
from media import sign

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=csrf_token(page)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 def mutate(path,method,attrs):
  status,body,h=request(port,path,method,dict(attrs,authenticity_token=token),cookies);assert status==302,(side,path,status,body[:100]);return h['location']
 def image(path):
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request('GET',path,headers={'Host':'campfire.test','Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items())});r=c.getresponse();data=r.read();h={k.lower():v for k,v in r.getheaders()};c.close();assert r.status==200,(side,path,r.status,data[:100]);return {'checksum':base64.b64encode(hashlib.md5(data).digest()).decode(),'byte_size':len(data),'type':h['content-type']}
 mutate('/users/me/profile','PATCH',{'user[avatar]':sign(7,'blob_id')})
 with sqlite3.connect(dbpath) as db:user=db.execute('SELECT name,updated_at FROM users WHERE id=127326141').fetchone()
 # The avatar ID verifier uses SHA256 and URL-safe Base64, as the User model does.
 secret=next(line.split('=',1)[1] for line in (ROOT/'parity/reference.env').read_text().splitlines() if line.startswith('SECRET_KEY_BASE='))
 import hmac
 key=hashlib.pbkdf2_hmac('sha256',secret.encode(),b'active_record/signed_id',1000,64)
 encoded=base64.urlsafe_b64encode(json.dumps({'_rails':{'data':127326141,'pur':'user/avatar'}},separators=(',',':')).encode()).decode().rstrip('=')
 avatar=encoded+'--'+hmac.new(key,encoded.encode(),'sha256').hexdigest()
 avatar_image=image('/users/'+avatar+'/avatar')
 mutate('/account','PATCH',{'account[logo]':sign(1,'blob_id')})
 logo=image('/account/logo');small=image('/account/logo?size=small')
 mutate('/users/me/avatar','DELETE',{});mutate('/account/logo','DELETE',{})
 if side=='reference':
  subprocess.run(['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"while job=Resque.reserve('default'); job.perform; end"],check=True,capture_output=True)
 else:
  subprocess.run(['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e',WAIT],check=True,capture_output=True)
 def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
 assert redis('LLEN','resque:queue:default')=='0';assert redis('GET','resque:stat:failed') in ['','0']
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());state={}
 with sqlite3.connect(dbpath) as db:
  db.row_factory=sqlite3.Row
  for table,old in fixture['tables'].items():
   rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   for row in rows:
    if table=='sessions' and row['id'] not in {r['id'] for r in old}:
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    if table=='active_storage_blobs' and row['id'] not in {r['id'] for r in old}:
     key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key);data=(ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')/key[:2]/key[2:4]/key).read_bytes();assert base64.b64encode(hashlib.md5(data).digest()).decode()==row['checksum'];row['key']='<VALIDATED_BASE36_KEY>'
   state[table]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
 return {'avatar':avatar_image,'logo':logo,'small_logo':small,'after_removal_and_purge':state}
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/branding.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/branding.json').write_text(json.dumps({'passed':passed,'scope':['signed-blob avatar/logo changes','fresh variant file bytes','avatar/logo removal','queued analysis and purge','all persisted tables']},indent=2)+'\n')
 if not passed:
  import difflib
  print(''.join(difflib.unified_diff(json.dumps(a,sort_keys=True,indent=2).splitlines(True),json.dumps(b,sort_keys=True,indent=2).splitlines(True)))[:10000]);raise SystemExit('Branding parity failed')
 print('Branding variant/removal parity passed')
