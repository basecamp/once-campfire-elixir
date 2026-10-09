#!/usr/bin/env python3
"""Public exception bodies, content negotiation, CSRF errors and unfurl rejections."""
import json,re,subprocess,difflib
from sessions import ROOT,request,csrf_token
KEYS=['content-type','cache-control','etag','vary','x-version','x-rev','x-frame-options','x-xss-protection','x-content-type-options','x-permitted-cross-domain-policies','referrer-policy']
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={};c={};_,p,_=request(port,'/session/new',cookies=c);token=csrf_token(p)
 # A case without a token is a forged request on both sides.
 def case(name,path,params,headers=None,method='POST'):
  status,p,h=request(port,path,method,params,c,headers=headers,browser='authenticity_token' in params)
  results[name]={'status':status,'body':p,'headers':{k:h.get(k) for k in KEYS}}
 for accept in ['text/html','application/json']:
  case('login_csrf'+accept,'/session',{}, {'Accept':accept})
  case('signup_csrf'+accept,'/join/CampfireJoinToken',{}, {'Accept':accept})
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},c)[0]==302
 for path in ['/rooms/486777696/messages','/account','/account/custom_styles','/users/me/profile','/unfurl_link','/users/me/push_subscriptions','/rooms/opens','/rooms/closeds','/rooms/directs']:
  for accept in ['text/html','application/json']:case(path+accept,path,{}, {'Accept':accept},method='PATCH' if path in ['/account','/account/custom_styles','/users/me/profile'] else 'POST')
 for accept in ['text/html','application/json']:
  case('unfurl_missing'+accept,'/unfurl_link',{'authenticity_token':token},{'Accept':accept})
 for url in ['http://127.0.0.1:47111/','http://localhost/','http://169.254.169.254/latest/meta-data/','http://[::1]/','javascript:alert(1)','invalid','https://example.com/test.png']:
  case('unfurl_'+url,'/unfurl_link',{'authenticity_token':token,'url':url})
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/errors.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/errors.json').write_text(json.dumps({'passed':passed,'scope':['CSRF public exception HTML/JSON bodies and headers','missing required URL','invalid/private/media unfurl URLs']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,{f:(a[key][f][:120] if isinstance(a[key][f],str) else a[key][f],b[key][f][:120] if isinstance(b[key][f],str) else b[key][f]) for f in a[key] if a[key][f]!=b[key][f]})
  raise SystemExit('Exception parity failed')
 print('Exception parity passed')
