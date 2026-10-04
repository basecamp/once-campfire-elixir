#!/usr/bin/env python3
"""Actual Resque workers: failed jobs, no automatic retry, claims and active-job shutdown."""
import datetime,http.server,json,os,pathlib,sqlite3,subprocess,threading,time
from sessions import ROOT
started=threading.Event();release=threading.Event()
class Sink(http.server.BaseHTTPRequestHandler):
 def do_POST(self):
  self.rfile.read(int(self.headers['Content-Length']));started.set();release.wait(15)
  body=b'<p>Graceful shutdown reply</p>';self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
 def log_message(self,*args):pass

def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
def await_condition(check):
 for _ in range(200):
  value=check()
  if value:return value
  time.sleep(.05)
 raise AssertionError('Worker condition timed out')
def enqueue(cls,args):
 job={'job_class':cls,'job_id':'971c64cc-9957-4e8c-8536-4f613a48d39f','provider_job_id':None,'queue_name':'default','priority':None,'arguments':args,'executions':0,'exception_executions':{},'locale':'en','timezone':'UTC','enqueued_at':'2026-03-02T16:00:00.000000000Z','scheduled_at':None}
 payload={'class':'ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper','args':[job]}
 redis('SADD','resque:queues','default');redis('RPUSH','resque:queue:default',json.dumps(payload,separators=(',',':')))
 return payload

def run(side):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 name='campfire-elixir-'+('rails' if side=='reference' else 'candidate')
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:
  db.execute('DELETE FROM push_subscriptions');db.execute('UPDATE webhooks SET url=? WHERE user_id=394959859',['http://127.0.0.1:47111/shutdown'])
  message=db.execute('SELECT id FROM messages WHERE creator_id=127326141 LIMIT 1').fetchone()[0]
 failed=enqueue('Room::PushMessageJob',[{'_aj_globalid':'gid://campfire/Rooms::Open/9999999999'},{'_aj_globalid':f'gid://campfire/Message/{message}'}])
 log=(ROOT/f'parity/worker-{side}.log').open('w')
 if side=='reference':cmd=['docker','exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1',name,'bin/rails','runner',"Resque::Worker.new('default').work(0.1)"]
 else:cmd=['docker','exec','-e','CAMPFIRE_NO_SERVER=1','-e','CAMPFIRE_WORKER=1',name,'mix','run','--no-halt']
 proc=subprocess.Popen(cmd,stdout=log,stderr=log)
 try:
  await_condition(lambda:redis('GET','resque:stat:failed')=='1')
  failure=json.loads(redis('LINDEX','resque:failed','0'));assert failure['payload']==failed
  assert failure['queue']=='default' and failure['exception'] and failure['error'] and failure['backtrace']
  await_condition(lambda:redis('GET','resque:stat:processed')=='1')
  worker=redis('SMEMBERS','resque:workers');assert len(worker.splitlines())==1,worker
  assert redis('EXISTS','resque:worker:'+worker)=='0'
  time.sleep(.2);assert redis('LLEN','resque:queue:default')=='0';assert redis('GET','resque:stat:failed')=='1'
  payload=enqueue('Bot::WebhookJob',[{'_aj_globalid':'gid://campfire/User/394959859'},{'_aj_globalid':f'gid://campfire/Message/{message}'}])
  assert started.wait(10)
  claim=json.loads(redis('GET','resque:worker:'+worker));assert claim['payload']==payload and claim['queue']=='default'
  pid=worker.split(':')[1];assert pid.isdigit()
  timer=threading.Timer(6,release.set);timer.start();begin=time.monotonic()
  subprocess.run(['docker','exec',name,'kill','-QUIT' if side=='reference' else '-TERM',pid],check=True)
  proc.wait(timeout=25);elapsed=time.monotonic()-begin;timer.join()
  assert elapsed>=5,(side,elapsed)
  assert redis('SMEMBERS','resque:workers')==''
  assert redis('EXISTS','resque:worker:'+worker,'resque:worker:'+worker+':started')=='0'
  assert redis('GET','resque:stat:failed')=='1'
  with sqlite3.connect(dbpath) as db:
   reply=db.execute("SELECT body FROM action_text_rich_texts WHERE body LIKE '%Graceful shutdown reply%'").fetchone()
   assert reply and reply[0]=='<p>Graceful shutdown reply</p>',(side,reply)
  # Push of the completed webhook reply remains queued for the next worker.
  assert redis('LLEN','resque:queue:default')=='1'
  return {'failed_payload_preserved':True,'failure_record':True,'failed_job_processed_count':True,'automatic_retry':False,'active_claim':True,'graceful_reply_committed':True,'worker_unregistered':True,'reply_push_queued':True}
 finally:
  release.set()
  if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
  log.close()

if __name__=='__main__':
 server=http.server.HTTPServer(('127.0.0.1',47111),Sink);threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  a=run('reference');started.clear();release.clear();b=run('candidate')
 finally:server.shutdown();server.server_close()
 assert a==b
 (ROOT/'parity/results/worker-lifecycle.json').write_text(json.dumps({'passed':True,'scope':a,'exception_comparison':'Runtime-specific exception names and stacks are retained in raw worker logs; failure payload and effects are checked.'},indent=2)+'\n')
 print('Worker failure/claim/graceful shutdown parity passed')
