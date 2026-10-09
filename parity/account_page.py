#!/usr/bin/env python3
"""Account settings HTML, role controls, invitation, logo and actual form actions."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize,csrf_token,form_token
from media import sign

def login(port,email):
 c={};_,p,_=request(port,'/session/new',cookies=c);token=csrf_token(p)
 assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},c)[0]==302
 return c

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 pages={};cookies=login(port,'david@37signals.com')
 status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200,(side,status,p[:400]);pages['administrator']=normalize(p)
 # Submit the actual URL and token generated for the account model form.
 match=re.search(r'<form class="flex flex-column gap"[^>]*action="([^"]+)"[^>]*>([\s\S]*?)</form>',p)
 assert match and match[1].startswith('/account.')
 status,_,h=request(port,match[1],'PATCH',{'account[name]':'Account "<&> Ω','authenticity_token':form_token(match[2])},cookies);assert status==302,(side,status)
 status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200;pages['renamed']=normalize(p)
 token=csrf_token(p)
 for value in ['true','false']:
  status,_,_=request(port,match[1],'PUT',{'account[settings][restrict_room_creation_to_administrators]':value,'authenticity_token':token},cookies);assert status==302,(side,status)
  status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200;pages['restriction_'+value]=normalize(p)
 request(port,'/account','PATCH',{'account[logo]':sign(1,'blob_id'),'authenticity_token':token},cookies)
 status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200;pages['with_logo']=normalize(p)
 member=login(port,'kevin@37signals.com')
 status,p,_=request(port,'/account/edit',cookies=member);assert status==200;pages['member']=normalize(p)
 # Role forms actually post updates and exclude deactivated/bot accounts.
 status,_,_=request(port,'/account/users/712064548','PATCH',{'user[role]':'administrator','authenticity_token':token},cookies);assert status==302
 status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200;pages['promoted_member']=normalize(p)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(path) as db:
  db.row_factory=sqlite3.Row
  account=dict(db.execute('SELECT * FROM accounts').fetchone())
  users=[dict(row) for row in db.execute('SELECT * FROM users ORDER BY id')]
 return {'pages':pages,'account':account,'users':users}

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/account-page.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/account-page.json').write_text(json.dumps({'passed':passed,'scope':['administrator/member HTML','role controls and promotion','actual singleton form action and CSRF tokens','account name escaping','typed settings switches','invitation links','logo controls and body classes','flash notice']},indent=2)+'\n')
 if not passed:
  for key in a['pages']:
   if a['pages'][key]!=b['pages'][key]:print(key+': '+''.join(difflib.unified_diff(a['pages'][key].splitlines(True),b['pages'][key].splitlines(True)))[:5500])
  for key in ['account','users']:
   if a[key]!=b[key]:print(key,a[key],b[key])
  raise SystemExit('Account page parity failed')
 print('Account page parity passed')
