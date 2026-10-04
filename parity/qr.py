#!/usr/bin/env python3
"""Public invitation and sign-in QR SVG bytes, cache lifetime and invalid inputs."""
import json,base64,subprocess
from sessions import ROOT,request

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results={}
 inputs=['','http://campfire.test/join/CampfireJoinToken','http://campfire.test/session/transfers/'+'a'*240,'HELLO WORLD','012345678901234567890','Ω🙂<&>']
 for i,text in enumerate(inputs):
  token=base64.urlsafe_b64encode(text.encode()).decode()
  # An empty ID has no route; the encoder's empty case is covered by the oracle.
  if not token:continue
  for padding in [True,False]:
   path='/qr_code/'+(token if padding else token.rstrip('='))
   status,body,h=request(port,path,cookies={});assert status==200,(side,status)
   results[str(i)+str(padding)]={'status':status,'body':body,'content_type':h['content-type'],'cache_control':h['cache-control']}
 for token in ['A','!!!!','YQ===','YR']:
  status,body,_=request(port,'/qr_code/'+token,cookies={});assert status==500,(side,token,status)
  results['invalid_'+token]={'status':status,'body':body}
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/qr.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/qr.json').write_text(json.dumps({'passed':passed,'scope':['public URL-safe tokens with/without padding','exact invitation/transfer/unicode/numeric/alphanumeric SVG','cache lifetime and MIME','malformed and noncanonical Base64 errors']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,{f:(a[key][f][:100] if isinstance(a[key][f],str) else a[key][f],b[key][f][:100] if isinstance(b[key][f],str) else b[key][f]) for f in a[key] if a[key][f]!=b[key][f]})
  raise SystemExit('QR parity failed')
 print('QR parity passed')
