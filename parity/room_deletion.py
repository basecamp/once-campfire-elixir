#!/usr/bin/env python3
"""Delete a room with image/video messages, boosts, variants and shared embeds."""
import base64,hashlib,http.client,json,re,sqlite3,subprocess,difflib
from sessions import ROOT,request,normalize
from drain_jobs import drain
from message_attachments import sgid

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 folder=ROOT/'var'/('rails/db' if side=='reference' else 'candidate');dbpath=folder/'production.sqlite3';files=ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
 with sqlite3.connect(dbpath) as db:db.execute('DELETE FROM push_subscriptions')
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 status,_,headers=request(port,'/rooms/opens','POST',{'authenticity_token':token,'room[name]':'Delete with files'},cookies);assert status==302
 room=int(headers['location'].rsplit('/',1)[1]);result={}
 for name,mime in [('moon.jpg','image/jpeg'),('alpha-centuri.mov','video/quicktime')]:
  data=(ROOT/'reference/test/fixtures/files'/name).read_bytes();boundary='campfire-room-delete';parts=[]
  for key,value in [('authenticity_token',token),('message[client_message_id]','delete-'+name)]:parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
  parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="message[attachment]"; filename="{name}"\r\nContent-Type: {mime}\r\n\r\n'.encode()+data+b'\r\n');body=b''.join(parts)+f'--{boundary}--\r\n'.encode()
  conn=http.client.HTTPConnection('127.0.0.1',port,timeout=60);conn.request('POST',f'/rooms/{room}/messages',body,{'Host':'campfire.test','Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items()),'Content-Type':f'multipart/form-data; boundary={boundary}','Accept':'text/vnd.turbo-stream.html'});response=conn.getresponse();html=response.read().decode();conn.close();assert response.status==200,(side,name,response.status,html[:200]);result[name]=normalize(html)
 body=f'<p>Shared <action-text-attachment sgid="{sgid(1)}"></action-text-attachment></p>'
 assert request(port,f'/rooms/{room}/messages','POST',{'authenticity_token':token,'message[body]':body,'message[client_message_id]':'delete-shared'},cookies,headers={'Accept':'text/vnd.turbo-stream.html'})[0]==200
 with sqlite3.connect(dbpath) as db:message=db.execute("SELECT id FROM messages WHERE client_message_id='delete-moon.jpg'").fetchone()[0]
 assert request(port,f'/messages/{message}/boosts','POST',{'authenticity_token':token,'boost[content]':'❤️'},cookies)[0]==302
 drain(side)
 def snapshot():
  state={}
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row
   for table,old in fixture['tables'].items():
    rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')];ids={row.get('id') for row in old}
    for row in rows:
     if table=='sessions' and row['id'] not in ids:assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
     if table=='active_storage_blobs' and row['id'] not in ids:
      key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key);data=(files/key[:2]/key[2:4]/key).read_bytes();assert len(data)==row['byte_size'] and base64.b64encode(hashlib.md5(data).digest()).decode()==row['checksum'];row['key']='<VALIDATED_BASE36_KEY>'
    state[table]=sorted(rows,key=lambda row:json.dumps(row,sort_keys=True))
   assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  return state
 result['before']=snapshot();status,html,h=request(port,f'/rooms/{room}','DELETE',{'authenticity_token':token},cookies);assert status==302 and h['location']=='http://campfire.test/'
 result['deleted']={'status':status,'location':h['location']};drain(side);result['after']=snapshot()
 with sqlite3.connect(dbpath) as db:
  assert db.execute('SELECT count(*) FROM messages WHERE room_id=?',[room]).fetchone()[0]==0
  assert db.execute('SELECT count(*) FROM memberships WHERE room_id=?',[room]).fetchone()[0]==0
  assert db.execute('SELECT count(*) FROM active_storage_blobs WHERE id=1').fetchone()[0]==1
  persisted={r[0] for r in db.execute('SELECT key FROM active_storage_blobs')}
 assert {p.name for p in files.rglob('*') if p.is_file()}==persisted
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/room-deletion.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/room-deletion.json').write_text(json.dumps({'passed':passed,'scope':['image/video/boost/shared embedded blob room deletion','all persisted fixture tables','real queued recursive purge','shared blobs survive','all remaining storage files owned by persisted blobs','SQLite integrity']},indent=2)+'\n')
 if not passed:
  print(''.join(difflib.unified_diff(json.dumps(a,sort_keys=True,indent=2).splitlines(True),json.dumps(b,sort_keys=True,indent=2).splitlines(True)))[:7000]);raise SystemExit('Room deletion parity failed')
 print('Room attachment/boost/embed deletion parity passed')
