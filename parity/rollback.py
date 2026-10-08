#!/usr/bin/env python3
"""Fixture-only handoff from pinned Rails to production Elixir and back."""
import json,re,sqlite3,subprocess,shutil,time,base64,hashlib
from contextlib import contextmanager
from sessions import ROOT,request,normalize
from media import sign

@contextmanager
def connect(path):
 db=sqlite3.connect(path)
 try:
  with db:yield db
 finally:db.close()
BASELINE_FOREIGN_KEYS=[]
def docker(*args):return subprocess.run(['docker',*map(str,args)],check=True,capture_output=True,text=True)
def paths(side):
 folder=ROOT/'var'/('rails/db' if side=='reference' else 'release')
 files=ROOT/'var'/('rails/files' if side=='reference' else 'release/files')
 return folder/'production.sqlite3',files

def snapshot(side):
 dbpath,folder=paths(side);tables={};files={}
 with connect(dbpath) as db:
  assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  assert sorted(db.execute('PRAGMA foreign_key_check').fetchall())==BASELINE_FOREIGN_KEYS
  db.row_factory=sqlite3.Row
  names=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
  for name in names:
   rows=[{k:({"sqlite_blob_base64":base64.b64encode(v).decode()} if isinstance(v,bytes) else v) for k,v in dict(r).items()} for r in db.execute('SELECT '+('rowid,body' if name=='message_search_index' else '*')+' FROM "'+name+'"')]
   tables[name]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
 for path in sorted(folder.rglob('*')):
  if path.is_file():files[str(path.relative_to(folder))]=hashlib.sha256(path.read_bytes()).hexdigest()
 return {'tables':tables,'files':files}

def handoff(origin,target):
 src,files=paths(origin);dst,out=paths(target)
 container='campfire-elixir-release' if target=='release' else 'campfire-elixir-rails'
 docker('stop',container)
 for suffix in ['-wal','-shm']:(dst.parent/(dst.name+suffix)).unlink(missing_ok=True)
 with connect(src) as source,connect(dst) as dest:source.backup(dest)
 if out.exists():shutil.rmtree(out)
 shutil.copytree(files,out)
 assert snapshot(origin)==snapshot(target),'handoff changed persisted state'
 docker('start',container)
 port=47072 if target=='release' else 47071
 for _ in range(120):
  try:
   if request(port,'/up')[0]==200:return
  except OSError:pass
  time.sleep(.1)
 raise AssertionError('handoff readiness failed')

def restart(side):
 container='campfire-elixir-release' if side=='release' else 'campfire-elixir-rails'
 port=47072 if side=='release' else 47071
 docker('restart',container)
 for _ in range(120):
  try:
   if request(port,'/up')[0]==200:return
  except OSError:pass
  time.sleep(.1)
 raise AssertionError('restart readiness failed')

def clear_rails_fragments():
 keys=docker('exec','campfire-elixir-redis','redis-cli','-p','47079','--scan','--pattern','views/*').stdout.split()
 if keys:docker('exec','campfire-elixir-redis','redis-cli','-p','47079','DEL',*keys)

def run():
 global BASELINE_FOREIGN_KEYS
 assert docker('inspect','--format','{{.Config.Image}}','campfire-elixir-release').stdout.strip()=='campfire-elixir:release'
 subprocess.run([str(ROOT/'bin/parity-services'),'reset','reference'],check=True)
 # Fixture subscriptions point at real services. This rehearsal has no external deliveries.
 with connect(paths('reference')[0]) as db:
  BASELINE_FOREIGN_KEYS=sorted(db.execute('PRAGMA foreign_key_check').fetchall())
  db.execute('DELETE FROM push_subscriptions')
 cookies={};_,page,_=request(47071,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(47071,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 def mutate(port,path,attrs,method='PATCH'):
  s,p,h=request(port,path,method,dict(attrs,authenticity_token=token),cookies,headers={'Accept':'text/vnd.turbo-stream.html'} if '/messages' in path else {})
  assert s in [200,302],(path,s,p[:200])
 mutate(47071,'/account',{'account[name]':'Rails handoff account'})
 mutate(47071,'/rooms/486777696/messages',{'message[body]':'<p>Created in Rails before handoff</p>','message[client_message_id]':'rollback-rails-message'},'POST')
 restart('reference')
 clear_rails_fragments()
 request(47071,'/rooms/486777696',cookies=cookies)
 _,before,_=request(47071,'/rooms/486777696',cookies=cookies);before=normalize(before)
 handoff('reference','release')
 s,page,_=request(47072,'/rooms/486777696',cookies=cookies);(ROOT/'var/rollback-before-rails.html').write_text(before);(ROOT/'var/rollback-after-elixir.html').write_text(normalize(page));assert s==200 and normalize(page)==before,'existing Rails session/page changed in release'
 mutate(47072,'/account',{'account[name]':'Elixir handoff account'})
 mutate(47072,'/users/me/profile',{'user[avatar]':sign(7,'blob_id')})
 mutate(47072,'/rooms/486777696/messages',{'message[attachment]':sign(7,'blob_id'),'message[client_message_id]':'rollback-elixir-attachment'},'POST')
 restart('release')
 request(47072,'/rooms/486777696',cookies=cookies)
 _,before,_=request(47072,'/rooms/486777696',cookies=cookies);before=normalize(before)
 handoff('release','reference')
 clear_rails_fragments()
 s,page,_=request(47071,'/rooms/486777696',cookies=cookies);(ROOT/'var/rollback-before-elixir.html').write_text(before);(ROOT/'var/rollback-after-rails.html').write_text(normalize(page));assert s==200 and normalize(page)==before,'Elixir page/session changed on Rails rollback'
 mutate(47071,'/rooms/486777696/messages',{'message[body]':'<p>Rails writes after rollback</p>','message[client_message_id]':'rollback-after-message'},'POST')
 # Rails consumes jobs produced by both runtimes, using the native-created storage graph.
 docker('exec','-e','LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1','-e','FAKETIME_DONT_FAKE_MONOTONIC=1','campfire-elixir-rails','bin/rails','runner',"while job=Resque.reserve('default'); job.perform; end")
 assert docker('exec','campfire-elixir-redis','redis-cli','-p','47079','--raw','LLEN','resque:queue:default').stdout.strip()=='0'
 final=snapshot('reference')
 messages=final['tables']['messages'];assert all(any(m['client_message_id']==key for m in messages) for key in ['rollback-rails-message','rollback-elixir-attachment','rollback-after-message'])
 assert final['tables']['accounts'][0]['name']=='Elixir handoff account'
 result={'passed':True,'scope':['production release','all persisted tables and no additional foreign key violations','all storage files copied byte-for-byte','Rails session accepted by release','Elixir cookies accepted by Rails','Rails view-cache invalidation at migration boundaries while preserving jobs','room HTML after each handoff','native avatar and message attachment','Rails consumes mixed-runtime jobs','Rails writes after rollback'],'fixture_foreign_key_violations':BASELINE_FOREIGN_KEYS,'final_tables':{k:len(v) for k,v in final['tables'].items()},'final_files':final['files']}
 (ROOT/'parity/results/rollback.json').write_text(json.dumps(result,indent=2)+'\n')
 print('Rails -> production Elixir -> Rails rollback passed')
if __name__=='__main__':run()
