#!/usr/bin/env python3
"""Compare real paginated account Turbo Stream rows and lazy next-page frames."""
import difflib,json,re,sqlite3,subprocess
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,body,_=request(port,'/session/new',cookies=cookies)
 token=re.search(r'name="csrf-token" content="([^"]+)"',body)[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 results={}
 def capture(path,headers=None):
  status,body,h=request(port,path,cookies=cookies,headers=headers)
  results[path+str(headers)]={'status':status,'body':normalize(body),'type':h.get('content-type'),'vary':h.get('vary'),'count':h.get('x-total-count'),'link':h.get('link')}
 for path in ['/account/users','/account/users.turbo_stream','/account/users.turbo_stream?page=2','/account/users.turbo_stream?page=-1','/account/users.turbo_stream?page=garbage']:
  capture(path)
 capture('/account/users',{'Accept':'text/vnd.turbo-stream.html'})
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:
  db.executemany('INSERT INTO users (id,name,email_address,role,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?)',[(2000000000+i,f'Pagination {i:04d} <& Ω',f'pagination{i}@example.test',0,0,'2026-03-02 16:00:00','2026-03-02 16:00:00') for i in range(510)])
 for path in ['/account/users.turbo_stream','/account/users.turbo_stream?page=2','/account/users.turbo_stream?page=3','/account/edit']:
  capture(path+'?large=1' if '?' not in path else path+'&large=1')
 return results

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/account-users.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/account-users.json').write_text(json.dumps({'passed':passed,'scope':['500-user Turbo Stream pagination','lazy next-page frames','out-of-range and invalid page params','format negotiation','escaped row content and administrator form controls']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key, ''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:4000])
  raise SystemExit('Account user pagination parity failed')
 print('Account user pagination parity passed')
