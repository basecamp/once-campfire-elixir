#!/usr/bin/env python3
import sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parity'))
from sessions import ROOT,request
cases={'open_new':('david@37signals.com','/rooms/opens/new'),'closed_new':('david@37signals.com','/rooms/closeds/new'),'open_edit':('david@37signals.com','/rooms/opens/486777696/edit'),'closed_edit':('david@37signals.com','/rooms/closeds/486777696/edit'),'open_readonly':('kevin@37signals.com','/rooms/opens/201306877/edit'),'closed_readonly':('kevin@37signals.com','/rooms/closeds/201306877/edit'),'direct_new':('david@37signals.com','/rooms/directs/new'),'direct_edit':('david@37signals.com','/rooms/directs/186869642/edit')}
if __name__=='__main__':
 sessions={};outputs={}
 for name,(email,path) in cases.items():
  if email not in sessions:
   cookies={};_,p,_=request(47071,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
   assert request(47071,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
   sessions[email]=cookies
  status,p,_=request(47071,path,cookies=sessions[email]);assert status==200,(name,status)
  outputs[name]={'html':p,'path':path}
 (ROOT/'var/room-forms-source.json').write_text(json.dumps(outputs,indent=2,ensure_ascii=False)+'\n')
 print('Captured room forms:',len(outputs))
