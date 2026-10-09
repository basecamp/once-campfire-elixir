#!/usr/bin/env python3
"""Room namespace navigation, remembered rooms and inaccessible-room notices."""
import json,re,subprocess,difflib
from sessions import ROOT,request,normalize,csrf_token

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 for email in ['david@37signals.com','kevin@37signals.com']:
  c={};_,p,_=request(port,'/session/new',cookies=c);token=csrf_token(p)
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},c)[0]==302
  for path in ['/rooms/opens','/rooms/closeds','/rooms/directs','/rooms/opens/201306877','/rooms/closeds/201306877','/rooms/opens/486777696','/rooms/directs/699448325','/rooms/directs/201306877','/rooms/opens/186869642','/rooms/closeds/9999999999']:
   status,p,h=request(port,path,cookies=c)
   results[email+path]={'status':status,'html':normalize(p),'location':h.get('location'),'last_room':c.get('last_room')}
  status,p,_=request(port,'/account/edit',cookies=c);results[email+'notice']=normalize(p)
  status,p,_=request(port,'/account/edit',cookies=c);results[email+'cleared']=normalize(p)
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/navigation.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/navigation.json').write_text(json.dumps({'passed':passed,'scope':['open/closed/direct namespace index and show','remembered room cookies','namespace access restrictions','inaccessible room notice and consumption']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:2000])
  raise SystemExit('Navigation parity failed')
 print('Navigation parity passed')
