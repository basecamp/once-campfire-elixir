#!/usr/bin/env python3
"""Fresh production volumes, first-run setup and real ONCE backup/restore hooks."""
import hashlib,json,os,re,shutil,sqlite3,subprocess,time
from sessions import ROOT,request,csrf_token
from contextlib import closing
BASE=ROOT/'var/fresh-install'
def docker(*args,check=True):return subprocess.run(['docker',*map(str,args)],capture_output=True,text=True,check=check)
def snapshot(path):
 with closing(sqlite3.connect(path)) as db, db:
  db.row_factory=sqlite3.Row
  assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
  tables=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
  return {table:[dict(r) for r in db.execute('SELECT * FROM "'+table+'"')] for table in tables}
def run(side,port):
 name='campfire-elixir-fresh-'+side;folder=BASE/side
 docker('rm','-f',name,check=False)
 if folder.exists():shutil.rmtree(folder)
 folder.mkdir(parents=True);(folder/'db').mkdir();(folder/'files').mkdir();(folder/'backups').mkdir()
 image='campfire-reference:app' if side=='reference' else 'campfire-elixir:release'
 docker('run','-d','--name',name,'--cpuset-cpus','8-11','--user',f'{os.getuid()}:{os.getgid()}','--env-file',ROOT/'parity/reference.env','-p',f'127.0.0.1:{port}:'+'80','-v',f'{folder}:/rails/storage',image)
 path=folder/'db/production.sqlite3'
 try:
  for _ in range(300):
   try:
    if request(port,'/up')[0]==200:break
   except OSError:pass
   time.sleep(.1)
  else:raise AssertionError(docker('logs',name).stdout)
  jar={};status,page,_=request(port,'/first_run',cookies=jar);assert status==200,(side,status,page[:100])
  csrf=csrf_token(page)
  status,body,_=request(port,'/first_run','POST',{'user[name]':'Fresh owner','user[email_address]':'fresh@example.com','user[password]':'fresh-password','authenticity_token':csrf},jar);assert status==302,(side,status,body[:100])
  assert request(port,'/',cookies=jar)[0]==302
  # A fresh all-in-one image must process queued application callbacks.
  status,page,_=request(port,'/rooms/'+str(snapshot(path)['rooms'][0]['id']),cookies=jar);assert status==200
  token=csrf_token(page)
  room=snapshot(path)['rooms'][0]['id']
  assert request(port,f'/rooms/{room}/messages','POST',{'message[body]':'<p>Fresh queued message</p>','message[client_message_id]':'fresh-production-message','authenticity_token':token},jar,headers={'Accept':'text/vnd.turbo-stream.html'})[0]==200
  for _ in range(200):
   queued=docker('exec',name,'redis-cli','--raw','LLEN','resque:queue:default').stdout.strip()
   processed=int(docker('exec',name,'redis-cli','--raw','GET','resque:stat:processed').stdout.strip() or 0)
   if queued=='0' and processed>=1:break
   time.sleep(.05)
  else:raise AssertionError('Fresh production queue not drained')
  assert int(docker('exec',name,'redis-cli','--raw','GET','resque:stat:processed').stdout.strip() or 0)>=1
  original=snapshot(path)
  assert len(original['accounts'])==len(original['users'])==len(original['rooms'])==1
  assert original['users'][0]['role']==1 and len(original['memberships'])==1
  with closing(sqlite3.connect(path)) as db, db:
   assert db.execute("SELECT seq FROM sqlite_sequence WHERE name='memberships'").fetchone()[0]==3
  docker('exec',name,'/hooks/pre-backup')
  backup=folder/'backups/production.sqlite3';assert backup.exists() and snapshot(backup)==original
  with closing(sqlite3.connect(path)) as db, db:db.execute("UPDATE accounts SET name='After snapshot'")
  docker('stop','--time','30',name)
  docker('run','--rm','--user',f'{os.getuid()}:{os.getgid()}','-v',f'{folder}:/rails/storage','--entrypoint','/hooks/post-restore',image)
  assert snapshot(path)==original
  assert not (folder/'db/production.sqlite3-wal').exists()
  return {'fresh_volume_initialized':True,'first_run':True,'message_write_and_real_worker':True,'creator_membership_sequence':3,'backup_matches_all_tables':True,'restore_matches_all_tables':True,'wal_removed':True,'sqlite_integrity':True}
 finally:
  log=docker('logs',name,check=False);(ROOT/f'parity/fresh-install-{side}.log').write_text(log.stdout+log.stderr);docker('rm','-f',name,check=False)
if __name__=='__main__':
 a=run('reference',47073);b=run('candidate',47074);assert a==b
 (ROOT/'parity/results/fresh-install.json').write_text(json.dumps({'passed':True,'scope':a,'runtime':'production images on fresh isolated volumes; real pre-backup and post-restore executables'},indent=2)+'\n')
 print('Fresh production setup and ONCE backup/restore parity passed')
