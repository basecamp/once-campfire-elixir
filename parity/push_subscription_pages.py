#!/usr/bin/env python3
"""Push subscription controls, browser labels and CSRF deletion."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 for email in ['david@37signals.com','kevin@37signals.com','lou@37signals.com']:
  c={};_,p,_=request(port,'/session/new',cookies=c);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},c)[0]==302
  for frame in [False,True]:
   status,p,h=request(port,'/users/me/push_subscriptions',cookies=c,headers={'Turbo-Frame':'subscriptions'} if frame else {})
   results[email+str(frame)]={'status':status,'html':normalize(p)}
  if email.startswith('david'):
   path='/users/me/push_subscriptions/56887440'
   token=re.search(r'action="'+path+r'".*?name="authenticity_token" value="([^"]+)"',p,re.S)[1]
   assert request(port,path,'DELETE',{'authenticity_token':token},c)[0]==302
   status,p,h=request(port,'/users/me/push_subscriptions',cookies=c);results['deleted']=normalize(p)
 assert request(port,'/users/me/push_subscriptions',cookies={})[0]==302
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/push-subscription-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/push-subscription-pages.json').write_text(json.dumps({'passed':passed,'scope':['subscription listing and empty list','browser/version/platform labels','full and frame layouts','actual form token deletion','authentication']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:4000])
  raise SystemExit('Push subscription page parity failed')
 print('Push subscription page parity passed')
