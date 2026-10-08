#!/usr/bin/env python3
"""Dirty tracking, null values and transaction failures through JSON requests."""
import difflib,http.client,json,os,re,sqlite3,subprocess
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True,env=dict(os.environ,CAMPFIRE_PARITY_TICK='1'))
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);csrf=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies)[0]==302
 def state():
  with sqlite3.connect(path) as db:
   db.row_factory=sqlite3.Row
   return {table:[dict(row) for row in db.execute('SELECT * FROM '+table+' ORDER BY id')] for table in ['accounts','users','rooms','webhooks','active_storage_attachments','active_storage_blobs']}
 initial=state();previous=initial;stamps={};account=initial['accounts'][0];room=next(x for x in initial['rooms'] if x['id']==486777696);bot=next(x for x in initial['users'] if x['role']==2 and x['status']==0)
 actions=[('/account','account',{'name':account['name']}),('/account','account',{'name':None}),('/account','account',{'name':False}),('/account','account',{'name':123}),('/account','account',{'name':'Edges account'}),('/rooms/opens/486777696','room',{'name':room['name']}),('/rooms/opens/486777696','room',{'name':None}),('/rooms/opens/486777696','room',{'name':False}),('/rooms/opens/486777696','room',{'name':123}),('/account/bots/'+str(bot['id']),'user',{'name':bot['name']}),('/account/bots/'+str(bot['id']),'user',{'name':None,'webhook_url':'https://example.com/rollback'}),('/account/bots/'+str(bot['id']),'user',{'name':False}),('/account/bots/'+str(bot['id']),'user',{'name':123}),('/users/me/profile','user',{'name':None}),('/users/me/profile','user',{'name':False}),('/users/me/profile','user',{'name':123})]
 actions += [('/account','account',{'name':{'ignored':'name'},'settings':'ignored'}),('/rooms/opens/486777696','room',{'name':['ignored']}),('/account/bots/'+str(bot['id']),'user',{'name':{'ignored':'name'}}),('/users/me/profile','user',{'name':['ignored']})]
 actions += [('/account','account',{'logo':None}),('/account/bots/'+str(bot['id']),'user',{'avatar':None}),('/users/me/profile','user',{'avatar':None}),('/users/me/profile','user',{'avatar':False,'name':'Atomic failed profile'}),('/account/bots/'+str(bot['id']),'user',{'avatar':'invalid','name':'Atomic failed bot','webhook_url':'https://example.com/invalid-attachment'}),('/account','account',{'logo':'invalid','name':'Atomic failed account'})]
 actions += [('/users/me/profile','user',{'password':False,'name':'Atomic failed password'})]
 actions += [('/account/custom_styles','account',attrs) for attrs in [{'custom_styles':'body {color: red}'}, {'custom_styles':'body {color: red}'}, {'custom_styles':False}, {'custom_styles':123}, {'custom_styles':None}, {'custom_styles':['ignored']}, {'name':'ignored'}]]
 result={}
 for index,(url,key,attrs) in enumerate(actions):
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30)
  c.request('PATCH',url,json.dumps({key:attrs}),{'Host':'campfire.test','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36','Content-Type':'application/json','Accept':'text/html','Cookie':'; '.join(k+'='+v for k,v in cookies.items()),'X-CSRF-Token':csrf})
  r=c.getresponse();body=r.read().decode();headers=dict((k.lower(),v) for k,v in r.getheaders());c.close()
  current=state()
  for table,rows in current.items():
   old={row['id']:row for row in previous[table]}
   for row in rows:
    for field in ['created_at','updated_at']:
     value=row.get(field)
     if value!=old.get(row['id'],{}).get(field):
      assert value and value.startswith('2026-03-02 16:'),(side,table,row['id'],field,value)
      stamps[(table,row['id'],field)]=f'<VALIDATED_TIMESTAMP_FROM_REQUEST_{index}>'
  previous=current
  clean=json.loads(json.dumps(current))
  for table,rows in clean.items():
   for row in rows:
    for field in ['created_at','updated_at']:
     if (table,row['id'],field) in stamps:row[field]=stamps[(table,row['id'],field)]
  result[str(index)+' '+url+' '+json.dumps(attrs)]={'status':r.status,'type':headers.get('content-type'),'body':normalize(body),'location':headers.get('location'),'state':clean}
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/mutation-edges.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/mutation-edges.json').write_text(json.dumps({'passed':passed,'scope':['JSON null/boolean/number string attribute casts','unchanged updates retain timestamps','failed bot update rolls back webhook mutation','account/room/bot/profile response and complete domain tables']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]:
    print(k)
    print(''.join(difflib.unified_diff(json.dumps(a[k],indent=2).splitlines(True),json.dumps(b[k],indent=2).splitlines(True)))[:1800])
  raise SystemExit('Mutation edge parity failed')
 print('Mutation edge parity passed')
