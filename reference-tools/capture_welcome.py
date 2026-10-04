#!/usr/bin/env python3
import sys,re,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parity'))
from sessions import ROOT,request
cookies={};_,p,_=request(47071,'/session/new',cookies=cookies)
token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
assert request(47071,'/session','POST',{'email_address':'lou@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
s,p,h=request(47071,'/',cookies=cookies)
(ROOT/'var/welcome-source.json').write_text(json.dumps({'status':s,'html':p,'headers':h},indent=2)+'\n')
print(s,p[:100])
