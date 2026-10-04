#!/usr/bin/env python3
import sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parity'))
from sessions import ROOT,request
c={};_,p,_=request(47071,'/session/new',cookies=c);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
assert request(47071,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},c)[0]==302
status,p,h=request(47071,'/users/me/push_subscriptions',cookies=c);assert status==200
(ROOT/'var/push-subscriptions-source.json').write_text(json.dumps({'html':p,'headers':h},indent=2)+'\n')
print(p[p.index('    <nav id="nav">'):p.index('    <aside id="sidebar"')])
