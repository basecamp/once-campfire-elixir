#!/usr/bin/env python3
"""Rails security/version headers, Rack body ETags, HEAD and conditional GET."""
import json,re,subprocess,base64,hashlib
from sessions import ROOT,request,normalize
KEYS=['content-type','cache-control','etag','x-frame-options','x-xss-protection','x-content-type-options','x-permitted-cross-domain-policies','referrer-policy','x-version','x-rev','vary']
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 paths=['/up','/webmanifest.json','/service-worker.js','/qr_code/'+base64.urlsafe_b64encode(b'http://campfire.test/join/CampfireJoinToken').decode()]
 for path in paths:
  status,p,h=request(port,path,cookies={});assert status==200,(side,path,status)
  digest=hashlib.sha256(p.encode()).hexdigest()[:32]
  assert h.get('etag')=='W/"'+digest+'"',(side,path,h.get('etag'),digest)
  results[path]={'status':status,'body':p,'headers':{k:h.get(k) for k in KEYS}}
  for name,headers in [('match',{'If-None-Match':h['etag']}),('different',{'If-None-Match':'W/"different"'}),('strong',{'If-None-Match':h['etag'][2:]}),('wildcard',{'If-None-Match':'*'})]:
   status,p,h2=request(port,path,cookies={},headers=headers);results[path+name]={'status':status,'body':p,'headers':{k:h2.get(k) for k in KEYS}}
  status,p,h2=request(port,path,'HEAD',cookies={});assert status==200 and p==''
  results[path+'head']={'status':status,'body':p,'headers':{k:h2.get(k) for k in KEYS}}
 for path in ['/webmanifest','/service-worker']:
  for accept in ['text/html','application/json','text/javascript']:
   status,p,h=request(port,path,cookies={},headers={'Accept':accept});results[path+accept]={'status':status,'body':p,'headers':{k:h.get(k) for k in KEYS}}
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/http-headers.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/http-headers.json').write_text(json.dumps({'passed':passed,'scope':['security/version/cache headers','SHA256 body ETags','exact weak ETag conditional matching','HEAD body suppression','PWA format negotiation']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,{f:(a[key][f][:100] if isinstance(a[key][f],str) else a[key][f],b[key][f][:100] if isinstance(b[key][f],str) else b[key][f]) for f in a[key] if a[key][f]!=b[key][f]})
  raise SystemExit('HTTP header parity failed')
 print('HTTP header parity passed')
