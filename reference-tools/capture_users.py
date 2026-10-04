#!/usr/bin/env python3
import sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parity'))
from sessions import ROOT,request
cases={'admin_self':('david@37signals.com',127326141),'admin_active':('david@37signals.com',149087659),'admin_banned':('david@37signals.com',773523955),'member_self':('kevin@37signals.com',712064548),'member_active':('kevin@37signals.com',149087659),'member_banned':('kevin@37signals.com',773523955),'deactivated':('david@37signals.com',773523954),'bot_active':('david@37signals.com',394959859),'bot_deactivated':('david@37signals.com',773523957)}
if __name__=='__main__':
 users={u['id']:u for u in json.loads((ROOT/'test/fixtures/seed.json').read_text())['tables']['users']};outputs={};sessions={}
 for name,(email,id) in cases.items():
  if email not in sessions:
   cookies={};_,p,_=request(47071,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
   assert request(47071,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
   sessions[email]=cookies
  status,p,_=request(47071,f'/users/{id}',cookies=sessions[email]);assert status==200
  outputs[name]={'user':users[id],'html':p}
 (ROOT/'var/users-source.json').write_text(json.dumps(outputs,indent=2,ensure_ascii=False)+'\n')
 print('Captured user views:',len(outputs))
