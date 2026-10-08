#!/usr/bin/env python3
"""Administration forms, dynamic values, CSS layout injection and flash consumption."""
import json,re,subprocess,difflib
from sessions import ROOT,request,normalize
from media import sign

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};pages={}
 assert request(port,'/account/bots/new',cookies=cookies)[0]==302
 _,p,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 for path in ['/account/bots','/account/custom_styles/edit','/account/bots/new','/account/bots/394959859/edit','/account/bots/773523956/edit']:
  status,p,_=request(port,path,cookies=cookies);assert status==200,(side,path,status,p[:500]);pages[path]=normalize(p)
 assert request(port,'/account/bots/773523957/edit',cookies=cookies)[0]==404
 assert request(port,'/account/custom_styles','PATCH',{'account[custom_styles]':'body { --custom: "&<>"; }'},cookies)[0]==422
 status,_,h=request(port,'/account/custom_styles','PATCH',{'account[custom_styles]':'body { --custom: "&<>"; }','authenticity_token':token},cookies);assert status==302
 assert h['location']=='http://campfire.test/account/custom_styles/edit'
 for n in range(2):
  status,p,_=request(port,'/account/custom_styles/edit',cookies=cookies);assert status==200
  pages['styles_after_update_'+str(n)]=normalize(p)
  assert ('role="alert"' in p)==(n==0)
  assert '<style data-turbo-track="reload">body { --custom: "&<>"; }</style>' in p
 status,p,_=request(port,'/session/new',cookies={});assert status==200;pages['login_custom_styles']=normalize(p)
 status,p,h=request(port,'/account/bots/394959859','PATCH',{'user[name]':'Bot "<&> Ω','user[webhook_url]':'https://example.com/hooks?x=1&y=2','user[avatar]':sign(7,'blob_id'),'authenticity_token':token},cookies);assert status==302
 status,p,_=request(port,'/account/bots/394959859/edit',cookies=cookies);assert status==200
 pages['bot_after_update']=normalize(p)
 status,p,_=request(port,'/account/bots',cookies=cookies);assert status==200;pages['bots_after_update']=normalize(p)
 # A regular member cannot administer bots or custom styles.
 member={};_,p,_=request(port,'/session/new',cookies=member);membertoken=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
 status,_,_=request(port,'/session','POST',{'email_address':'kevin@37signals.com','password':'secret123456','authenticity_token':membertoken},member);assert status==302,(side,status)
 for path in ['/account/bots/new','/account/custom_styles/edit','/account/bots/394959859/edit']:
  assert request(port,path,cookies=member)[0]==403
 return pages

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/settings-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/settings-pages.json').write_text(json.dumps({'passed':passed,'scope':['bot new/edit forms','bot dynamic name/webhook/avatar','custom CSS edit and layout injection','flash display and consumption','administrator/member/unauthenticated access']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:6000])
  raise SystemExit('Settings page parity failed')
 print('Settings page parity passed')
