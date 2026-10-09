#!/usr/bin/env python3
"""Invite signup HTML, security/duplicate paths, and complete persisted rows."""
import json,pathlib,re,sqlite3,subprocess,difflib,http.client,base64,hashlib,hmac
from sessions import request,normalize,form_token,BROWSER
from media import sign,SECRET
ROOT=pathlib.Path(__file__).resolve().parents[1]
fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
code=fixture['tables']['accounts'][0]['join_code']

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 cookies={};results={}
 assert request(port,'/join/invalid',cookies=cookies)[0]==404
 status,page,_=request(port,'/join/'+code,cookies=cookies);assert status==200,(side,status)
 token=form_token(page)
 assert request(port,'/join/'+code,'POST',{'user[name]':'Forged signup'},cookies,browser=False)[0]==422
 duplicate={'user[name]':'Duplicate','user[email_address]':'david@37signals.com','user[password]':'duplicate-password','authenticity_token':token}
 status,body,h=request(port,'/join/'+code,'POST',duplicate,cookies);assert status==302,(side,status,body[:200])
 results['duplicate_location']=h['location']
 create={'user[name]':'Invite parity user','user[email_address]':'invite-parity@example.com','user[password]':'signup-password','user[avatar]':sign(7,'blob_id'),'authenticity_token':token}
 status,body,h=request(port,'/join/'+code,'POST',create,cookies);assert status==302,(side,status,body[:200])
 results['create_location']=h['location'];results['page']=normalize(page)
 status,body,h=request(port,'/join/invalid',cookies=cookies);assert status==302
 results['authenticated_location']=h['location']
 # A second signup uploads original file bytes through the actual multipart form.
 other={};status,form,_=request(port,'/join/'+code,cookies=other);assert status==200
 formtoken=form_token(form)
 boundary='campfire-signup-parity';parts=[]
 for key,value in [('authenticity_token',formtoken),('user[name]','Uploaded avatar user'),('user[email_address]','avatar-signup@example.com'),('user[password]','avatar-password')]:
  parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
 image=(ROOT/'reference/test/fixtures/files/moon.jpg').read_bytes()
 parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="user[avatar]"; filename="moon.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode()+image+b'\r\n')
 body=b''.join(parts)+f'--{boundary}--\r\n'.encode()
 c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request('POST','/join/'+code,body,{'Host':'campfire.test',**BROWSER,'User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36','Cookie':'; '.join(f'{k}={v}' for k,v in other.items()),'Content-Type':f'multipart/form-data; boundary={boundary}'})
 r=c.getresponse();body=r.read();headers={k.lower():v for k,v in r.getheaders()};c.close();assert r.status==302,(side,r.status,body[:500])
 results['multipart_location']=headers['location']
 # Both avatars are served as source-compatible WebP variants.
 pictures=[]
 with sqlite3.connect(path) as db:ids=[r[0] for r in db.execute("SELECT id FROM users WHERE email_address IN ('invite-parity@example.com','avatar-signup@example.com') ORDER BY id")]
 for user_id in ids:
  key=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'active_record/signed_id',1000,64)
  encoded=base64.urlsafe_b64encode(json.dumps({'_rails':{'data':user_id,'pur':'user/avatar'}},separators=(',',':')).encode()).decode().rstrip('=')
  avatar=encoded+'--'+hmac.new(key,encoded.encode(),'sha256').hexdigest()
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request('GET','/users/'+avatar+'/avatar',headers={'Host':'campfire.test','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36','Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items())});r=c.getresponse();body=r.read();headers={k.lower():v for k,v in r.getheaders()};c.close();assert r.status==200
  pictures.append({'byte_size':len(body),'checksum':base64.b64encode(hashlib.md5(body).digest()).decode(),'type':headers['content-type']})
 results['avatars']=pictures
 if side=='reference':
  subprocess.run(['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"while job=Resque.reserve('default'); job.perform; end"],check=True,capture_output=True)
 else:
  subprocess.run(['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e','Process.sleep(2500)'],check=True,capture_output=True)
 rows={}
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table in fixture['tables']:
   entries=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   for row in entries:
    if table=='users' and row['email_address'] in ['invite-parity@example.com','avatar-signup@example.com']:
     assert re.fullmatch(r'\$2[aby]\$12\$[./A-Za-z0-9]{53}',row['password_digest']);row['password_digest']='<VALIDATED_BCRYPT12>'
    if table=='sessions' and row['id'] not in {r['id'] for r in fixture['tables']['sessions']}:
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    if table=='active_storage_blobs' and row['id'] not in {r['id'] for r in fixture['tables']['active_storage_blobs']}:
     key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key)
     data=(ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')/key[:2]/key[2:4]/key).read_bytes()
     assert len(data)==row['byte_size'] and base64.b64encode(hashlib.md5(data).digest()).decode()==row['checksum']
     row['key']='<VALIDATED_BASE36_KEY>'
   rows[table]=sorted(entries,key=lambda r:json.dumps(r,sort_keys=True))
 results['rows']=rows
 # Independently validate the new salted password by signing in again.
 other={};status,login,_=request(port,'/session/new',cookies=other);assert status==200
 token=form_token(login)
 assert request(port,'/session','POST',{'email_address':'invite-parity@example.com','password':'signup-password','authenticity_token':token},other)[0]==302
 return results

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/signup.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/signup.json').write_text(json.dumps({'passed':passed,'scope':'signup HTML, invalid invitation, CSRF, duplicate email, authenticated redirect, new password login, signed-blob and multipart avatars, generated WebP bytes, queued analysis, full tables'},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:
    if isinstance(a[key],str):print(key+': '+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:6000])
    else:
     for table in a[key]:
      if a[key][table]!=b[key][table]:print(table,a[key][table],b[key][table])
  raise SystemExit('Signup parity failed')
 print('Signup parity passed')
