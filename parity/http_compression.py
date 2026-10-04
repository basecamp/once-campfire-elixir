#!/usr/bin/env python3
"""Rack compression negotiation and wire byte parity."""
import json,http.client,gzip,subprocess,base64,hashlib
from sessions import ROOT

def request(port,path,encoding,method='GET'):
 c=http.client.HTTPConnection('127.0.0.1',port,timeout=15)
 c.request(method,path,headers={'Host':'campfire.test','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36','Accept-Encoding':encoding})
 r=c.getresponse();body=r.read();h=dict(r.getheaders());c.close()
 return {'status':r.status,'body':base64.b64encode(body).decode(),'headers':{k.lower():v for k,v in h.items() if k.lower() in ['content-type','content-length','content-encoding','etag','cache-control','vary','x-version','x-rev','x-frame-options']}}
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 for path in ['/account/logo','/account/logo?size=small','/up','/webmanifest.json','/service-worker.js','/session/new','/qr_code/'+base64.urlsafe_b64encode(b'http://campfire.test/join/CampfireJoinToken').decode(),'/qr_code/!!!!']:
  for encoding in ['','gzip','identity','br','gzip,deflate','gzip;q=0.5,identity;q=1','gzip;q=1,identity;q=0.5','gzip;q=0,identity;q=0','*;q=0','*','GZIP','gzip;q=.3','gzip;q=0,*;q=1','identity;q=0','gzip;q=0.0','gzip;q=1,gzip;q=0','gzip;q=2','gzip;q=invalid','br;q=1,identity;q=.2,gzip;q=.3']:
   result=request(port,path,encoding)
   if path=='/session/new':
    # CSRF masking and randomized session cookies change rendered bytes.
    body=base64.b64decode(result['body'])
    if result['headers'].get('content-encoding')=='gzip':body=gzip.decompress(body)
    import re
    body=re.sub(rb'(name="(?:csrf-token|authenticity_token)" (?:content|value)=")[^"]+',rb'\1<VALIDATED_TOKEN>',body)
    result['body']=base64.b64encode(body).decode();result['headers'].pop('etag',None);result['headers'].pop('content-length',None)
   results[path+encoding]=result
  results[path+'HEADgzip']=request(port,path,'gzip','HEAD')
  if path=='/session/new':
   results[path+'HEADgzip']['headers'].pop('etag',None);results[path+'HEADgzip']['headers'].pop('content-length',None)
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/compression.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/compression.json').write_text(json.dumps({'passed':passed,'scope':['gzip wire bytes','encoding quality negotiation','public exception responses','CSRF pages','HEAD compressed response metadata']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,{f:(a[key][f][:100] if isinstance(a[key][f],str) else a[key][f],b[key][f][:100] if isinstance(b[key][f],str) else b[key][f]) for f in a[key] if a[key][f]!=b[key][f]})
  raise SystemExit('Compression parity failed')
 print('Compression parity passed')
