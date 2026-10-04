#!/usr/bin/env python3
"""Deliberate fixture-only SQLite callback faults and parent/child commit boundaries."""
import difflib,http.client,json,re,sqlite3,subprocess
from sessions import ROOT,request,normalize
FIXTURE=json.loads((ROOT/'test/fixtures/seed.json').read_text())
def run(side,port,setup):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 if setup:
  with sqlite3.connect(path) as db:
   db.execute('PRAGMA foreign_keys=OFF')
   for table in FIXTURE['tables']:
    if table not in ['schema_migrations','ar_internal_metadata']:db.execute('DELETE FROM "'+table+'"')
   db.execute("CREATE TRIGGER fixture_fail BEFORE INSERT ON rooms BEGIN SELECT RAISE(ABORT,'fixture room insert failure'); END")
 cookies={};_,page,_=request(port,'/first_run' if setup else '/session/new',cookies=cookies);csrf=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 if not setup:assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies)[0]==302
 def send(url,attrs):
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request('POST',url,json.dumps({'user':attrs}),{'Host':'campfire.test','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36','Content-Type':'application/json','Accept':'text/html','Cookie':'; '.join(k+'='+v for k,v in cookies.items()),'X-CSRF-Token':csrf});r=c.getresponse();body=r.read().decode();headers=dict((k.lower(),v) for k,v in r.getheaders());c.close()
  with sqlite3.connect(path) as db:
   db.row_factory=sqlite3.Row;rows={}
   for table in ['accounts','users','rooms','memberships','webhooks','sessions','sqlite_sequence']:
    items=[dict(x) for x in db.execute('SELECT * FROM '+table+' ORDER BY '+('name' if table=='sqlite_sequence' else 'id'))]
    for row in items:
     if table=='accounts':assert re.fullmatch(r'[A-Za-z0-9]{4}(?:-[A-Za-z0-9]{4}){2}',row['join_code']);row['join_code']='<VALIDATED_JOIN_CODE>'
     if table=='users' and row['id'] not in {u['id'] for u in FIXTURE['tables']['users']} and row['bot_token']:assert re.fullmatch('[A-Za-z0-9]{12}',row['bot_token']);row['bot_token']='<VALIDATED_BOT_TOKEN>'
     if table=='sessions':assert re.fullmatch('[1-9A-HJ-NP-Za-km-z]{24}',row['token']);row['token']='<VALIDATED_SESSION_TOKEN>'
    rows[table]=items
  return {'status':r.status,'type':headers.get('content-type'),'body':normalize(body),'location':headers.get('location'),'rows':rows}
 if setup:return {'room_insert_fault':send('/first_run',{'name':'Failure owner','email_address':'fault@example.com'})}
 result={}
 for label,attrs in [('null_name',{'name':None}),('boolean_name',{'name':False}),('null_webhook',{'name':'No webhook','webhook_url':None})]:result[label]=send('/account/bots',attrs)
 with sqlite3.connect(path) as db:db.execute("CREATE TRIGGER fixture_fail BEFORE INSERT ON webhooks BEGIN SELECT RAISE(ABORT,'fixture webhook insert failure'); END")
 result['webhook_insert_fault']=send('/account/bots',{'name':'Committed parent','webhook_url':'https://example.com/fault'})
 return result
if __name__=='__main__':
 results={side:{str(setup):run(side,port,setup) for setup in [False,True]} for side,port in [('reference',47071),('candidate',47070)]}
 for side,r in results.items():(ROOT/f'parity/results/transaction-failures.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 a=results['reference'];b=results['candidate'];passed=a==b
 (ROOT/'parity/results/transaction-failures.json').write_text(json.dumps({'passed':passed,'scope':['fixture-only SQLite abort triggers','first-run room failure preserves account and rolls back user','bot webhook failure preserves committed user and callbacks','null name/boolean name/null webhook','domain rows and autoincrement sequence']},indent=2)+'\n')
 if not passed:print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True)))[:9000]);raise SystemExit('Transaction failure parity failed')
 print('Transaction failure/commit boundary parity passed')
