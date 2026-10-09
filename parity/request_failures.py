#!/usr/bin/env python3
"""Missing/scalar nested parameters, callback ordering and bot-key authorization."""
import json,re,sqlite3,subprocess,urllib.parse,difflib
from sessions import ROOT,request,normalize,csrf_token
ACTIONS=[('/account','PATCH','account'),('/account/custom_styles','PATCH','account'),('/users/me/profile','PATCH','user'),('/account/users/127326141','PATCH','user'),('/account/bots','POST','user'),('/rooms/opens','POST','room'),('/rooms/closeds','POST','room'),('/rooms/486777696/messages','POST','message'),('/rooms/486777696/messages/933434530','PATCH','message'),('/messages/933434530/boosts','POST','boost')]
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=csrf_token(page)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 result={}
 for path,method,key in ACTIONS:
  for fmt in ['html','json','xml']:
   for value in ['missing','blank','space','array','scalar']:
    params={'authenticity_token':token}
    if value!='missing':params[key+('[]' if value=='array' else '')]={'blank':'','space':'   ','array':'','scalar':'scalar'}[value]
    status,body,h=request(port,path+'.'+fmt,method,params,cookies)
    assert status in [400,500],(side,path,value,status,body[:200])
    result[f'{method} {path}.{fmt} {value}']={'status':status,'type':h.get('content-type'),'body':json.loads(body) if h.get('content-type','').startswith('application/json') else normalize(body)}
 # Invalid JSON updates must keep the callback's authentication/CSRF responses.
 for label,jar,params in [('anonymous',{},{}),('no_csrf',cookies,{}),('valid_csrf',cookies,{'authenticity_token':token})]:
  status,body,h=request(port,'/rooms/486777696/messages/933434530.json','PATCH',params,jar,browser=label=='valid_csrf')
  result['update_'+label]={'status':status,'type':h.get('content-type'),'body':json.loads(body) if h.get('content-type','').startswith('application/json') else normalize(body),'location':h.get('location')}
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:key=db.execute("SELECT id || '-' || bot_token FROM users WHERE role=2 AND status=0 LIMIT 1").fetchone()[0]
 for path in ['/account/edit','/rooms/486777696','/rooms/486777696/messages','/session/new']:
  for valid in [True,False]:
   status,body,h=request(port,path+'?'+urllib.parse.urlencode({'bot_key':' '+key+' ' if valid else 'invalid'}),cookies={})
   result[path+' query_bot='+str(valid)]={'status':status,'type':h.get('content-type'),'body':normalize(body),'location':h.get('location')}
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/request-failures.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/request-failures.json').write_text(json.dumps({'passed':passed,'scope':['10 mutation endpoints','missing/blank/whitespace/array/scalar nested params','HTML/JSON/XML public exceptions','authentication and CSRF before mutation format errors','query-string bot credentials with trimming','anonymous public login behavior']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]:print(k,''.join(difflib.unified_diff(str(a[k]).splitlines(True),str(b[k]).splitlines(True)))[:1500])
  raise SystemExit('Request failure parity failed')
 print('Request parameter/error/auth callback parity passed')
