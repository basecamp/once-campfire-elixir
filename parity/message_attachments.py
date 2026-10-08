#!/usr/bin/env python3
"""Signed message attachment edits and rich-text blob association lifecycle."""
import base64,difflib,hashlib,hmac,json,re,sqlite3,subprocess
from sessions import ROOT,request,normalize
from media import sign,SECRET
from drain_jobs import drain

def sgid(blob):
 key=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'signed_global_ids',1000,64)
 data=base64.urlsafe_b64encode(json.dumps({'_rails':{'data':f'gid://campfire/ActiveStorage::Blob/{blob}?expires_in','pur':'attachable'}},separators=(',',':')).encode()).decode()
 return data+'--'+hmac.new(key,data.encode(),'sha1').hexdigest()
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:db.execute('DELETE FROM push_subscriptions')
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 result={};room=486777696
 def mutate(label,path,method,attrs):
  status,body,h=request(port,path,method,{'authenticity_token':token,**attrs},cookies,headers={'Accept':'text/vnd.turbo-stream.html' if method=='POST' else 'text/html'})
  assert status in [200,302],(side,label,status,body[:300]);result[label]={'status':status,'body':normalize(body),'location':h.get('location')}
 def snapshot(label):
  fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());state={}
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row
   for table,old in fixture['tables'].items():
    rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
    oldids={row.get('id') for row in old}
    for row in rows:
     if table=='sessions' and row['id'] not in oldids:assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
     if table=='active_storage_blobs' and row['id'] not in oldids:
      key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key);row['key']='<VALIDATED_BASE36_KEY>'
    state[table]=sorted(rows,key=lambda row:json.dumps(row,sort_keys=True))
  result[label]=state
 mutate('create',f'/rooms/{room}/messages','POST',{'message[body]':'<p>Original edit body</p>','message[attachment]':sign(7,'blob_id'),'message[client_message_id]':'edited-attachment'})
 with sqlite3.connect(dbpath) as db:message=db.execute("SELECT id FROM messages WHERE client_message_id='edited-attachment'").fetchone()[0]
 path=f'/rooms/{room}/messages/{message}'
 drain(side);snapshot('original')
 mutate('replace',path,'PATCH',{'message[attachment]':sign(13,'blob_id')});drain(side);snapshot('replaced')
 mutate('change_body',path,'PATCH',{'message[body]':'<p>Updated body</p>'});drain(side);snapshot('body_changed')
 mutate('clear',path,'PATCH',{'message[attachment]':''});drain(side);snapshot('cleared')
 blobbody=f'<p>Before <action-text-attachment sgid="{sgid(1)}" caption="Moon &amp; Ω"></action-text-attachment> after</p>'
 mutate('embed',f'/rooms/{room}/messages','POST',{'message[body]':blobbody,'message[client_message_id]':'embedded-blob'})
 with sqlite3.connect(dbpath) as db:embedded=db.execute("SELECT id FROM messages WHERE client_message_id='embedded-blob'").fetchone()[0]
 drain(side);snapshot('embedded')
 mutate('embed_blank',f'/rooms/{room}/messages/{embedded}','PATCH',{'message[body]':''});drain(side);snapshot('blank_embedded')
 mutate('embed_remove',f'/rooms/{room}/messages/{embedded}','PATCH',{'message[body]':'<p>File removed</p>'});drain(side);snapshot('removed_embedded')
 for label,body in [
  ('embed_no_caption',f'<div><action-text-attachment sgid="{sgid(1)}"></action-text-attachment></div>'),
  ('embed_file',f'<div><action-text-attachment sgid="{sgid(13)}"></action-text-attachment></div>'),
  ('embed_video',f'<div><action-text-attachment sgid="{sgid(9)}"></action-text-attachment></div>'),
  ('embed_gallery',f'<div><action-text-attachment sgid="{sgid(1)}" presentation="gallery"></action-text-attachment><action-text-attachment sgid="{sgid(7)}" presentation="gallery"></action-text-attachment></div>'),
  ('embed_single_gallery',f'<div><action-text-attachment sgid="{sgid(1)}" presentation="gallery"></action-text-attachment></div>'),
  ('embed_bad_signature',f'<div><action-text-attachment sgid="{sgid(1)[:-1]}0" caption="Untrusted"></action-text-attachment></div>')]:
  mutate(label,f'/rooms/{room}/messages','POST',{'message[body]':body,'message[client_message_id]':label});drain(side);snapshot(label+'_rows')
 return result

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/message-attachments.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/message-attachments.json').write_text(json.dumps({'passed':passed,'scope':['signed attachment replacement/removal','body unchanged by attachment-only edits','body edits retain attachments','rich-text signed blob embeds','blank body preserves embeds per Rails callback','nonblank replacement removes embeds','all persisted tables after real queue drains','native Action Text image blob HTML']},indent=2)+'\n')
 if not passed:
  print(''.join(difflib.unified_diff(json.dumps(a,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True),json.dumps(b,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True)))[:10000]);raise SystemExit('Message attachment edits/embeds differ')
 print('Message attachment edit/blob embed parity passed')
