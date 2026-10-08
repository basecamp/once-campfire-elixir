#!/usr/bin/env python3
"""Compare first-run HTML and the complete no-avatar setup database mutation."""
import importlib.util,json,pathlib,re,sqlite3,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
from sessions import request, normalize
fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text())
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(path) as db:
  db.execute('PRAGMA foreign_keys=OFF')
  for table in fixture['tables']:
   if table not in ['schema_migrations','ar_internal_metadata']:db.execute('DELETE FROM "'+table+'"')
 cookies={};status,page,h=request(port,'/first_run',cookies=cookies);assert status==200
 token=(re.search(r'name="authenticity_token" value="([^"]+)"',page) or ("", ""))[1]
 status,body,h=request(port,'/first_run','POST',{'user[name]':'Elixir Owner','user[email_address]':'owner@example.com','user[password]':'setup-password','authenticity_token':token},cookies);assert status==302
 state={}
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  for table in [*fixture['tables'], 'sqlite_sequence']:
   rows=[dict(row) for row in db.execute('SELECT '+('rowid,body' if table=='message_search_index' else '*')+' FROM "'+table+'"')]
   for row in rows:
    if table=='users':
     assert re.fullmatch(r'\$2[aby]\$12\$[./A-Za-z0-9]{53}',row['password_digest']);row['password_digest']='<VALIDATED_BCRYPT12>'
    if table=='accounts':
     assert re.fullmatch(r'[A-Za-z0-9]{4}(?:-[A-Za-z0-9]{4}){2}',row['join_code']);row['join_code']='<VALIDATED_JOIN_CODE>'
    if table=='sessions':
     assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
   state[table]=sorted(rows,key=lambda r:json.dumps(r,sort_keys=True))
 status,body,h=request(port,'/first_run',cookies=cookies);assert status==302
 # Verify the normalized salted password by authenticating against each runtime.
 status,body,h=request(port,'/session/new',cookies=cookies);assert status==200
 token=(re.search(r'name="authenticity_token" value="([^"]+)"',body) or ("", ""))[1]
 status,_,_=request(port,'/session','POST',{'email_address':'owner@example.com','password':'setup-password','authenticity_token':token},cookies);assert status==302
 return {'page':normalize(page),'rows':state}
a=run('reference',47071);b=run('candidate',47070)
for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/first-run.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
passed=a==b
(ROOT/'parity/results/first-run.json').write_text(json.dumps({'passed':passed,'scope':'no-avatar setup, full tables, CSRF form, repeat prevention, password login'},indent=2)+'\n')
if not passed:
 import difflib
 print(''.join(difflib.unified_diff(a['page'].splitlines(True),b['page'].splitlines(True)))[:5000])
 for table in a['rows']:
  if a['rows'][table]!=b['rows'][table]:print(table,a['rows'][table],b['rows'][table])
 raise SystemExit('First-run parity failed')
print('First-run parity passed')
