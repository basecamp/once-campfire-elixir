#!/usr/bin/env python3
from drain_jobs import WAIT
"""Drain real Resque queues and compare webhook delivery/reply persistence on fixture copies."""
import http.server,json,re,sqlite3,subprocess,threading
from sessions import ROOT,request
class Sink(http.server.BaseHTTPRequestHandler):
 payloads=[]
 def do_POST(self):
  body=self.rfile.read(int(self.headers['Content-Length']));self.payloads.append({'path':self.path,'content_type':self.headers['Content-Type'],'body':body.decode()})
  reply=b'<p>A real worker reply</p>';self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(reply)));self.end_headers();self.wfile.write(reply)
 def log_message(self,*args):pass

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(path) as db:
  db.execute('DELETE FROM push_subscriptions');db.execute('UPDATE webhooks SET url=? WHERE user_id=394959859',['http://127.0.0.1:47110/hook'])
 c={};_,p,_=request(port,'/session/new',cookies=c);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},c);assert status==302
 status,_,h=request(port,'/rooms/directs','POST',{'authenticity_token':token,'user_ids[]':394959859},c);assert status==302;room=h['location'].rsplit('/',1)[1]
 status,_,_=request(port,f'/rooms/{room}/messages','POST',{'authenticity_token':token,'message[body]':'<p>Job queue delivery</p>','message[client_message_id]':'job-source-message'},c,headers={'Accept':'text/vnd.turbo-stream.html'});assert status==200
 Sink.payloads=[]
 if side=='reference':
  proc=subprocess.run(['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"n=0; while job=Resque.reserve('default'); job.perform; n+=1; end; puts n"],capture_output=True,text=True,check=True);assert proc.stdout.strip().endswith('3'),proc.stdout
 else:
  proc=subprocess.run(['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1','campfire-elixir-candidate','mix','run','-e',WAIT],capture_output=True,text=True,check=True)
 assert len(Sink.payloads)==1,(side,Sink.payloads,proc.stdout,proc.stderr)
 def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
 assert redis('LLEN','resque:queue:default')=='0'
 assert redis('GET','resque:stat:failed') in ['','0']
 if side=='candidate':assert redis('GET','resque:stat:processed')=='3'
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
 result={'delivery':Sink.payloads.copy(),'rows':{}}
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table,old in fixture['tables'].items():
   rows=[dict(r) for r in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   old_ids={r.get('id') for r in old}
   for row in rows:
    if table=='sessions' and row['id'] not in old_ids:
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    if table=='messages' and row['id'] not in old_ids and row['client_message_id']!='job-source-message':
     assert re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',row['client_message_id']);row['client_message_id']='<VALIDATED_UUID_V4>'
   result['rows'][table]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
 (ROOT/f'parity/results/jobs.{side}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 return result
if __name__=='__main__':
 server=http.server.HTTPServer(('127.0.0.1',47110),Sink);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
 try:a=run('reference',47071);b=run('candidate',47070)
 finally:server.shutdown();server.server_close()
 passed=a==b
 (ROOT/'parity/results/jobs.json').write_text(json.dumps({'passed':passed,'scope':['real queued push without subscriptions','webhook HTTP delivery','text reply','all persisted tables','queue drained without failures']},indent=2)+'\n')
 if not passed:
  import difflib
  print(''.join(difflib.unified_diff(json.dumps(a,ensure_ascii=False,indent=2).splitlines(True),json.dumps(b,ensure_ascii=False,indent=2).splitlines(True)))[:9000]);raise SystemExit('Worker parity failed')
 print('Worker delivery/persistence parity passed')
