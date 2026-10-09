#!/usr/bin/env python3
"""Custom boost composition, regular layout and Turbo frame layout parity."""
import json,re,subprocess,difflib
from sessions import ROOT,request,normalize,csrf_token,form_token

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=csrf_token(p)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());message=next(m for m in fixture['tables']['messages'] if m['room_id']==486777696)
 path=f'/messages/{message["id"]}/boosts';pages={}
 for name,url in [('new',path+'/new'),('index',path),('involvement','/rooms/486777696/involvement')]:
  for frame in [False,True]:
   headers={'Turbo-Frame':'new_boost_message_'+message['client_message_id']} if frame else {}
   status,p,_=request(port,url,cookies=cookies,headers=headers);assert status==200,(side,name,status,p[:500]);pages[name+('_frame' if frame else '')]=normalize(p)
 # Submit the actual per-form token; the created boost must appear in both layouts.
 status,p,_=request(port,path+'/new',cookies=cookies)
 token=form_token(p)
 assert request(port,path,'POST',{'boost[content]':'Nice! Ω','authenticity_token':token},cookies)[0]==302
 for frame in [False,True]:
  status,p,_=request(port,path,cookies=cookies,headers={'Turbo-Frame':'boosting_message_'+message['client_message_id']} if frame else {});assert status==200
  pages['created'+('_frame' if frame else '')]=normalize(p)
 assert request(port,'/messages/99999999999/boosts/new',cookies=cookies)[0]==404
 assert request(port,path+'/new',cookies={})[0]==302
 return pages

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/boost-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/boost-pages.json').write_text(json.dumps({'passed':passed,'scope':['custom boost form','form token submission','boost listing','regular and Turbo frame layouts','involvement frame layout','authentication and unreachable messages']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:6000])
  raise SystemExit('Boost page parity failed')
 print('Boost page parity passed')
