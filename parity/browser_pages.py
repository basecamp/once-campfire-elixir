#!/usr/bin/env python3
"""Browser restriction order, bot exemptions and incompatible page HTML."""
import json,re,subprocess,difflib
from sessions import ROOT,request,normalize
VECTORS=json.loads((ROOT/'vectors/campfire_user_agents.json').read_text())['user_agents']
CASES=[r for r in VECTORS if r['ua'] and '\n' not in r['ua'] and '\r' not in r['ua'] and isinstance(r['blocked'],bool)]
CASES=[r for r in CASES if r['blocked']][:20]+[r for r in CASES if not r['blocked']][:12]
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 pages={};cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 for i,row in enumerate(CASES):
  headers={'User-Agent':row['ua']}
  for name,path,jar in [('login','/session/new',{}),('protected','/rooms/486777696',cookies),('anonymous','/rooms/486777696',{})]:
   status,p,h=request(port,path,cookies=jar,headers=headers)
   pages[f'{i}_{name}']={'status':status,'body':normalize(p),'location':h.get('location')}
 old={'User-Agent':CASES[0]['ua']}
 status,p,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456'},cookies,old);assert status==422
 assert request(port,'/up',headers=old)[0]==200
 return pages
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/browser-pages.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/browser-pages.json').write_text(json.dumps({'passed':passed,'user_agents':len(CASES),'scope':['restricted browser HTML','minimum version boundaries','authenticated and anonymous request order','CSRF precedes browser guard','unrestricted and bot browser cases','health endpoint exemption']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(json.dumps(a[key],indent=2).splitlines(True),json.dumps(b[key],indent=2).splitlines(True)))[:1800])
  raise SystemExit('Browser page parity failed')
 print('Browser page parity passed')
