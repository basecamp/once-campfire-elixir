#!/usr/bin/env python3
"""Profile forms, membership controls, avatar preview and transfer tokens."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize
from media import sign

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 pages={}
 for email in ['david@37signals.com','kevin@37signals.com']:
  cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
  if email=='david@37signals.com':
   for name,row in json.loads((ROOT/'vectors/pwa-views.json').read_text()).items():
    status,p,_=request(port,'/users/me/profile',cookies=cookies,headers={'User-Agent':row['user_agent']});assert status==row.get('error',200),(side,name,status)
    pages['pwa_'+name]=normalize(p)
  for name,headers in [('initial',{}),('referrer',{'Referer':'http://campfire.test/rooms/486777696'}),('self_referrer',{'Referer':'http://campfire.test/users/me/profile'}),('frame',{'Turbo-Frame':'profile'})]:
   status,p,_=request(port,'/users/me/profile',cookies=cookies,headers=headers);assert status==200,(side,status,p[:500]);pages[email+name]=normalize(p)
  token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
  attrs={'user[name]':'Profile "<&> Ω','user[email_address]':email,'user[bio]':'Line 1\n<&> Ω','authenticity_token':token}
  status,_,_=request(port,'/users/me/profile','PATCH',attrs,cookies);assert status==302
  for n in range(2):
   status,p,_=request(port,'/users/me/profile',cookies=cookies);assert status==200;pages[email+'updated'+str(n)]=normalize(p)
  status,_,_=request(port,'/users/me/profile','PATCH',{'user[avatar]':sign(7,'blob_id'),'authenticity_token':token},cookies);assert status==302
  status,p,_=request(port,'/users/me/profile',cookies=cookies);assert status==200;pages[email+'avatar']=normalize(p)
 assert request(port,'/users/me/profile',cookies={})[0]==302
 return pages

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/profile-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/profile-pages.json').write_text(json.dumps({'passed':passed,'scope':['profile form HTML','escaped profile updates','admin and member','referrer navigation','avatar replacement/delete control','room involvement','four-hour transfer link','flash consumption','full and frame layout']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:5000])
  raise SystemExit('Profile page parity failed')
 print('Profile page parity passed')
