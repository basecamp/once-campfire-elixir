#!/usr/bin/env python3
"""Compare persisted administration mutations on isolated reference/candidate fixtures."""
import json,pathlib,re,sqlite3,subprocess
from sessions import request
ROOT=pathlib.Path(__file__).resolve().parents[1]
fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 cookies={};status,page,_=request(port,'/session/new',cookies=cookies);assert status==200
 token=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 def send(path,method,params):
  status,body,h=request(port,path,method,dict(params,authenticity_token=token),cookies);assert status==302,(side,path,status,body[:500]);return h['location']
 send('/session','POST',{'email_address':'david@37signals.com','password':'secret123456'})
 def one(sql):
  with sqlite3.connect(path) as db:
   db.row_factory=sqlite3.Row;return dict(db.execute(sql).fetchone())
 closed=send('/rooms/closeds','POST',{'room[name]':'Private parity room','user_ids[]':127326141}).rsplit('/',1)[1]
 send('/rooms/opens/'+closed,'PATCH',{'room[name]':'Public parity room'})
 direct=send('/rooms/directs','POST',{'user_ids[]':149087659}).rsplit('/',1)[1]
 same=send('/rooms/directs','POST',{'user_ids[]':149087659}).rsplit('/',1)[1];assert same==direct
 send('/account/bots','POST',{'user[name]':'Parity bot','user[webhook_url]':'https://example.com/hooks'})
 bot=one('SELECT * FROM users ORDER BY id DESC LIMIT 1')['id']
 send(f'/account/bots/{bot}','PATCH',{'user[name]':'Renamed parity bot','user[webhook_url]':'https://example.com/new-hook'})
 send(f'/account/bots/{bot}/key','PATCH',{})
 send(f'/account/bots/{bot}','DELETE',{})
 send('/account/users/149087659','PATCH',{'user[role]':'administrator'})
 send('/users/me/profile','PATCH',{'user[name]':'David Parity','user[bio]':'Profile parity'})
 send('/account','PATCH',{'account[name]':'Parity account'})
 send('/account/custom_styles','PATCH',{'account[custom_styles]':'body { color: purple; }'})
 send('/account/join_code','POST',{})
 send('/rooms/'+closed+'/involvement','PATCH',{'involvement':'nothing'})
 send('/rooms/directs/'+direct,'DELETE',{})
 state={}
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table in fixture['tables']:
   rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   for row in rows:
    if table=='sessions' and row['id'] not in {r['id'] for r in fixture['tables']['sessions']}:
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    if table=='users' and row['id']==bot:
     assert re.fullmatch(r'[A-Za-z0-9]{12}',row['bot_token']);row['bot_token']='<VALIDATED_BOT_TOKEN>'
    if table=='accounts':
     assert re.fullmatch(r'[A-Za-z0-9]{4}(?:-[A-Za-z0-9]{4}){2}',row['join_code']);row['join_code']='<VALIDATED_JOIN_CODE>'
   state[table]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
 return state
a=run('reference',47071);b=run('candidate',47070)
for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/administration.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
passed=a==b
(ROOT/'parity/results/administration.json').write_text(json.dumps({'passed':passed,'scope':'HTTP redirects and complete persisted rows; realtime effects pending'},indent=2)+'\n')
if not passed:
 for table in a:
  if a[table]!=b[table]:
   import difflib
   print(table+':\n'+''.join(difflib.unified_diff(json.dumps(a[table],indent=2).splitlines(True),json.dumps(b[table],indent=2).splitlines(True)))[:10000])
 raise SystemExit('Administration parity failed')
print('Administration persistence parity passed')
