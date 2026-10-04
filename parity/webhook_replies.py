#!/usr/bin/env python3
from drain_jobs import WAIT
"""Queued webhook response handling, attachment replies and all persisted tables."""
import http.server,json,re,sqlite3,subprocess,threading,base64,hashlib,difflib,gzip,zlib,time
from sessions import ROOT,request
from jobs import Sink
class ReplySink(Sink):
 status=200;type='text/html';reply=b'<p>A worker reply</p>';encoding=None;delay=0
 def do_POST(self):
  body=self.rfile.read(int(self.headers['Content-Length']));self.payloads.append({'path':self.path,'content_type':self.headers['Content-Type'],'body':body.decode()})
  time.sleep(self.delay)
  self.send_response(self.status)
  if self.encoding:self.send_header('Content-Encoding',self.encoding)
  if self.type:self.send_header('Content-Type',self.type)
  self.send_header('Content-Length',str(len(self.reply)));self.end_headers()
  try:self.wfile.write(self.reply)
  except (BrokenPipeError,ConnectionResetError):pass
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(path) as db:
  db.execute('DELETE FROM push_subscriptions');db.execute('UPDATE webhooks SET url=? WHERE user_id=394959859',['http://127.0.0.1:47111/hook'])
 c={};_,p,_=request(port,'/session/new',cookies=c);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},c)[0]==302
 _,_,h=request(port,'/rooms/directs','POST',{'authenticity_token':token,'user_ids[]':394959859},c);room=h['location'].rsplit('/',1)[1]
 assert request(port,f'/rooms/{room}/messages','POST',{'authenticity_token':token,'message[body]':'<p>Webhook delivery</p>','message[client_message_id]':'webhook-source-message'},c,headers={'Accept':'text/vnd.turbo-stream.html'})[0]==200
 ReplySink.payloads=[]
 if side=='reference':
  proc=subprocess.run(['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"Resque::Worker.new('default').work(0)"],capture_output=True,text=True,check=True)
 else:
  proc=subprocess.run(['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e',WAIT],capture_output=True,text=True,check=True)
 assert len(ReplySink.payloads)==1,(side,proc.stdout,proc.stderr)
 def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
 assert redis('LLEN','resque:queue:default')=='0'
 failed=int(redis('GET','resque:stat:failed') or 0)
 assert failed == (1 if ReplySink.status in [204,304] else 0),(side,redis('LRANGE','resque:failed','0','-1'),proc.stderr)
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());rows={};files=[]
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table,old in fixture['tables'].items():
   result=[dict(r) for r in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   old_ids={r.get('id') for r in old}
   for row in result:
    if table=='sessions' and row['id'] not in old_ids:
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    if table=='messages' and row['id'] not in old_ids and row['client_message_id']!='webhook-source-message':
     assert re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',row['client_message_id']);row['client_message_id']='<VALIDATED_UUID_V4>'
    if table=='active_storage_blobs' and row['id'] not in old_ids:
     key=row['key'];assert re.fullmatch(r'[a-z0-9]{28}',key)
     data=(ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')/key[:2]/key[2:4]/key).read_bytes()
     assert len(data)==row['byte_size'] and base64.b64encode(hashlib.md5(data).digest()).decode()==row['checksum']
     files.append({'id':row['id'],'bytes':base64.b64encode(data).decode()});row['key']='<VALIDATED_BASE36_KEY>'
   rows[table]=sorted(result,key=lambda r:json.dumps(r,sort_keys=True))
 return {'delivery':ReplySink.payloads.copy(),'rows':rows,'files':files,'failed_jobs':failed}
if __name__=='__main__':
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());blob=next(b for b in fixture['tables']['active_storage_blobs'] if b['id']==1)
 image=(ROOT/'test/fixtures/storage'/blob['key']).read_bytes()
 cases=[('html',200,'text/html; charset=UTF-8',b'<p>Text &amp; reply</p>'),('plain',200,'text/plain',b'Plain reply'),('png',200,'image/png',image),('failed_text_attachment',500,'text/plain',b'Not a text reply'),('unknown',200,'application/x-campfire',b'unknown attachment bytes'),('no_type',200,None,b'ignored')]
 cases += [('gzip_text',200,'text/html',gzip.compress(b'<p>Compressed reply</p>',mtime=0)),('deflate_text',200,'text/plain',zlib.compress(b'Compressed reply')),('bodyless_204',204,'text/plain',b''),('bodyless_304',304,'text/plain',b''),('read_timeout',200,'text/html',b'<p>Late reply</p>')]
 server=http.server.ThreadingHTTPServer(('127.0.0.1',47111),ReplySink);threading.Thread(target=server.serve_forever,daemon=True).start();a={};b={}
 try:
  for name,status,type,reply in cases:
   ReplySink.status=status;ReplySink.type=type;ReplySink.reply=reply;ReplySink.encoding='gzip' if name=='gzip_text' else 'deflate' if name=='deflate_text' else None;ReplySink.delay=8 if name=='read_timeout' else 0
   a[name]=run('reference',47071);b[name]=run('candidate',47070)
 finally:server.shutdown();server.server_close()
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/webhook-replies.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/webhook-replies.json').write_text(json.dumps({'passed':passed,'scope':[c[0] for c in cases]+['all persisted tables','attachment and variant bytes','real queue drained']},indent=2)+'\n')
 if not passed:
  print(''.join(difflib.unified_diff(json.dumps(a,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True),json.dumps(b,sort_keys=True,indent=2,ensure_ascii=False).splitlines(True)))[:9000]);raise SystemExit('Webhook reply parity failed')
 print('Webhook reply parity passed')
