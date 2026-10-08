#!/usr/bin/env python3
"""No-room landing page, redirects and full/frame layouts."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 for email in ['lou@37signals.com','david@37signals.com']:
  cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
  for frame in [False,True]:
   status,p,h=request(port,'/',cookies=cookies,headers={'Turbo-Frame':'user_sidebar'} if frame else {})
   results[email+str(frame)]={'status':status,'html':normalize(p),'location':h.get('location')}
  if email.startswith('lou'):
   dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
   with sqlite3.connect(dbpath) as db:db.execute('UPDATE users SET name=? WHERE id=?',['Lou "<&> Ω',773523958])
   status,p,h=request(port,'/',cookies=cookies);results['escaped']=normalize(p)
 assert request(port,'/',cookies={})[0]==302
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/welcome.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/welcome.json').write_text(json.dumps({'passed':passed,'scope':['no-room landing page','escaped user name','full and Turbo frame layouts','existing-room redirect','authentication']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,a[key] if isinstance(a[key],dict) and a[key]['status']!=b[key]['status'] else ''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:3000])
  raise SystemExit('Welcome parity failed')
 print('Welcome parity passed')
