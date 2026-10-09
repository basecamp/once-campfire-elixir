#!/usr/bin/env python3
from drain_jobs import WAIT
"""Exercise real multipart attachments against the source and the native application."""
import base64,hashlib,http.client,json,re,sqlite3,subprocess
from sessions import ROOT,request,csrf_token,BROWSER

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:db.execute("DELETE FROM push_subscriptions")
 cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=csrf_token(p)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 with sqlite3.connect(dbpath) as db:room=db.execute("SELECT room_id FROM memberships WHERE user_id=127326141 AND room_id IN (SELECT id FROM rooms WHERE type='Rooms::Open') LIMIT 1").fetchone()[0]
 results=[]
 for filename,type in [('moon.jpg','image/jpeg'),('launch-notes.txt','text/plain'),('alpha-centuri.mov','video/quicktime'),('yodel.mp3','audio/mpeg'),('notes.pdf','application/pdf')]:
  if filename=='launch-notes.txt':data=b'Attachment persistence parity\n'
  elif filename=='yodel.mp3':data=(ROOT/'reference/app/assets/sounds/yodel.mp3').read_bytes()
  elif filename=='notes.pdf':data=(ROOT/'test/fixtures/files/notes.pdf').read_bytes()
  else:data=(ROOT/'reference/test/fixtures/files'/filename).read_bytes()
  boundary='campfire-attachment-parity';parts=[]
  for key,value in [('authenticity_token',token),('message[client_message_id]','attachment-'+filename)]:
   parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
  parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="message[attachment]"; filename="{filename}"\r\nContent-Type: {type}\r\n\r\n'.encode()+data+b'\r\n')
  body=b''.join(parts)+f'--{boundary}--\r\n'.encode()
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=60);c.request('POST',f'/rooms/{room}/messages',body,{'Host':'campfire.test',**BROWSER,'Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items()),'Content-Type':f'multipart/form-data; boundary={boundary}','Accept':'text/vnd.turbo-stream.html'});r=c.getresponse();response=r.read().decode();c.close();assert r.status==200,(side,filename,r.status,response[:500])
  results.append({'filename':filename,'status':r.status,'body':response})
 def snapshot():
  fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());state={}
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row
   for table,old in fixture['tables'].items():
    rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
    oldids={row.get('id') for row in old}
    for row in rows:
     if table=='sessions' and row['id'] not in oldids:
      assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
     if table=='active_storage_blobs' and row['id'] not in oldids:
      key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key)
      bytes=(ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')/key[:2]/key[2:4]/key).read_bytes();assert len(bytes)==row['byte_size'] and base64.b64encode(hashlib.md5(bytes).digest()).decode()==row['checksum']
      row['key']='<VALIDATED_BASE36_KEY>'
    state[table]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
  return state
 state=snapshot()
 queue=subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw','LRANGE','resque:queue:default','0','-1'],text=True)
 jobs=[json.loads(line)['args'][0] for line in queue.splitlines() if line]
 for job in jobs:
  assert re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',job['job_id']);job['job_id']='<VALIDATED_UUID_V4>'
 def drain():
  if side=='reference':
   subprocess.run(['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"while job=Resque.reserve('default'); job.perform; end"],check=True,capture_output=True)
  else:
   subprocess.run(['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e',WAIT],check=True,capture_output=True)
 drain()
 analyzed=snapshot()
 for result in results:
  with sqlite3.connect(dbpath) as db:message=db.execute('SELECT id FROM messages WHERE client_message_id=?',['attachment-'+result['filename']]).fetchone()[0]
  status,body,_=request(port,f'/rooms/{room}/messages/{message}','DELETE',{'authenticity_token':token},cookies,headers={'Accept':'text/vnd.turbo-stream.html'});assert status==200,(side,status,body)
 drain()
 def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
 assert redis('LLEN','resque:queue:default')=='0'
 assert redis('GET','resque:stat:failed') in ['','0']
 files=ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')
 keys=sorted(path.name for path in files.rglob('*') if path.is_file())
 assert keys==sorted(blob['key'] for blob in json.loads((ROOT/'test/fixtures/seed.json').read_text())['tables']['active_storage_blobs'])
 return {'responses':results,'rows':state,'jobs':jobs,'after_queued_analysis':analyzed,'after_delete_and_purge':snapshot(),'remaining_keys':keys}
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/attachments.{side}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/attachments.json').write_text(json.dumps({'passed':passed,'scope':['multipart image/file/video/audio/PDF message creation','Turbo stream HTML','all persisted tables','original and generated byte checksums','queued analysis and push effects','deletion and recursive blob purge','remaining file corpus']},indent=2)+'\n')
 if not passed:
  import difflib
  print(''.join(difflib.unified_diff(json.dumps(a,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True),json.dumps(b,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True)))[:15000]);raise SystemExit('Attachment parity failed')
 print('Attachment multipart/persistence parity passed')
