#!/usr/bin/env python3
import hashlib,json,pathlib,re,sqlite3,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/rails-to-elixir/lib'))
from rails_to_elixir.parity import request
SIDE=sys.argv[2]
URL='http://127.0.0.1:'+('47071' if SIDE=='reference' else '47070')
PREFIX='/rooms/486777696/394959859-BenderBot123/messages'
def send(path,method,body,status):
 r=request(URL,{'id':'mutation','path':path,'method':method,'body':body,'headers':{'Host':'campfire.test','Content-Type':'text/plain'},'compare_headers':['location']},15)
 if r['status']!=status:raise SystemExit(f'{SIDE}: {method} returned {r["status"]}, expected {status}')
 return r
def perform():
 r=send(PREFIX,'POST','<p>nativeparityneedle first</p>',201)
 message_id=r['headers']['location'][0].rsplit('/',1)[1]
 send(PREFIX+'/'+message_id,'PATCH','<p>nativeparityneedle edited</p>',200)
 r=send(PREFIX+'/'+message_id+'/boosts','POST','+1',201)
 boost_id=json.loads(r['body'])['id']
 send(PREFIX+'/'+message_id+'/boosts/'+str(boost_id),'DELETE','',204)
def snapshot():
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
 path=ROOT/'var'/('rails/db' if SIDE=='reference' else 'candidate')/'production.sqlite3'
 state={}
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table in fixture['tables']:
   rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   if table=='messages':
    baseline_ids={row['id'] for row in fixture['tables']['messages']}
    for row in rows:
     if row['id'] not in baseline_ids:
      if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',row['client_message_id']):raise SystemExit('new client message id is not a valid UUID v4')
      row['client_message_id']='<GENERATED_UUID_V4>'
   state[table]=sorted(rows,key=lambda x:json.dumps(x,sort_keys=True))
 effects=[]
 if SIDE in ['reference','candidate']:
  def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).splitlines()
  for key in sorted(filter(None,redis('KEYS','resque:queue:*'))):
   for line in redis('LRANGE',key,'0','-1'):
    if not line:continue
    payload=json.loads(line)
    for job in payload['args']:
     if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',job['job_id']):raise SystemExit('job id is not UUID v4')
     job['job_id']='<GENERATED_UUID_V4>'
    effects.append({'queue':key,'payload':payload})
 else:
  effects=[]
 value={'rows':state,'effects':effects}
 folder=ROOT/'parity/results';folder.mkdir(exist_ok=True)
 (folder/('mutation.'+SIDE+'.json')).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps(value,sort_keys=True,ensure_ascii=False))
if sys.argv[1]=='perform':perform()
elif sys.argv[1]=='snapshot':snapshot()
else:raise SystemExit('usage: mutations.py perform|snapshot reference|candidate')
