#!/usr/bin/env python3
"""People and bot pages across status, role and viewer permissions."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 pages={};users=json.loads((ROOT/'test/fixtures/seed.json').read_text())['tables']['users']
 for email in ['david@37signals.com','kevin@37signals.com']:
  cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
  for user in users:
   path=f'/users/{user["id"]}'
   for frame in [False,True]:
    status,p,_=request(port,path,cookies=cookies,headers={'Turbo-Frame':'user'} if frame else {});assert status==200,(side,user['id'],status)
    pages[email+path+str(frame)]=normalize(p)
  if email=='david@37signals.com':
   for name,headers in [('referrer',{'Referer':'http://campfire.test/account/edit'}),('self_referrer',{'Referer':'http://campfire.test/users/149087659'})]:
    status,p,_=request(port,'/users/149087659',cookies=cookies,headers=headers);assert status==200;pages[name]=normalize(p)
   status,p,_=request(port,'/users/149087659',cookies=cookies);assert status==200
   form=re.search(r'<form[^>]+action="/rooms/directs\?[^>]+>.*?</form>',p,re.S)[0]
   token=(re.search(r'name="authenticity_token" value="([^"]+)"',form) or ("", ""))[1]
   assert request(port,'/rooms/directs?user_ids%5B%5D=149087659','POST',{'authenticity_token':token},cookies)[0]==302
  status,p,_=request(port,'/users/9999999999',cookies=cookies);pages[email+'missing']={'status':status,'body':p};assert status==404
 assert request(port,'/users/149087659',cookies={})[0]==302
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:db.execute('UPDATE users SET name=?,bio=?,email_address=? WHERE id=?',['Person "<&> Ω','Bio\n<&> Ω','html+email@example.com',149087659])
 status,p,_=request(port,'/users/149087659',cookies=cookies);assert status==200;pages['escaped_member_view']=normalize(p)
 return pages

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/user-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/user-pages.json').write_text(json.dumps({'passed':passed,'scope':['admin/member viewers','self and other people','active/banned/deactivated people','active/deactivated bots','avatar URLs','transfer and ban controls','direct room form token submission','referrer navigation','HTML escaping','missing user/authentication','full and frame layout']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:3500])
  raise SystemExit('User page parity failed')
 print('User page parity passed')
