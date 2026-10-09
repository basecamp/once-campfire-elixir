#!/usr/bin/env python3
"""Keep raw browser-controller optional-format comparisons during implementation."""
import json,re,subprocess
from sessions import ROOT,request,normalize,csrf_token
PATHS=['/account/edit','/users/127326141','/users/me/profile','/account/bots','/account/bots/new','/account/custom_styles/edit','/rooms/486777696','/rooms/486777696/messages','/rooms/486777696/messages/933434530','/rooms/486777696/messages/933434530/edit','/rooms/486777696/refresh?since=0','/rooms/486777696/involvement','/users/me/sidebar','/autocompletable/users','/searches','/messages/933434530/boosts','/messages/933434530/boosts/new','/users/me/push_subscriptions']
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=csrf_token(p)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 result={}
 for path in PATHS:
  for fmt in ['html','json','xml','turbo_stream']:
   p,mark,query=path.partition('?');url=p+'.'+fmt+(mark+query if mark else '')
   status,body,h=request(port,url,cookies=cookies)
   result[url]={'status':status,'type':h.get('content-type'),'body':json.loads(body) if h.get('content-type','').startswith('application/json') else normalize(body),'location':h.get('location')}
 for accept in ['', '*/*', 'application/pdf', 'application/octet-stream', 'application/json;q=0.1,text/html;q=0.9', 'text/html;q=0,application/json;q=1', 'text/html;q=0', 'application/json,*/*;q=0.8', 'application/xml,application/json;q=0.5', 'image/png', 'text/*', 'application/*', 'text/vnd.turbo-stream.html,text/html', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8']:
  url='/account/edit';status,body,h=request(port,url,cookies=cookies,headers={'Accept':accept})
  result['accept:'+accept]={'status':status,'type':h.get('content-type'),'body':json.loads(body) if h.get('content-type','').startswith('application/json') else normalize(body),'location':h.get('location')}
 (ROOT/f'parity/results/format-probe.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 passed=a==b
 (ROOT/'parity/results/formats.json').write_text(json.dumps({'passed':passed,'scope':['18 authenticated browser endpoints','explicit HTML/JSON/XML/Turbo Stream formats','HTML rows and layouts','JSON autocomplete fields','exception response bodies and MIME types']},indent=2)+'\n')
 if not passed:
  import difflib
  for k in a:
   if a[k]!=b[k]:print(k,''.join(difflib.unified_diff(str(a[k]).splitlines(True),str(b[k]).splitlines(True)))[:1500])
  raise SystemExit('Response format parity failed')
 print('Response format parity passed')
