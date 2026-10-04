#!/usr/bin/env python3
"""Missing controller/actions, unmatched routes, verbs and optional formats over HTTP."""
import json,re,subprocess,difflib
from sessions import ROOT,request

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cases=[]
 for route in json.loads((ROOT/'vectors/route-actions.json').read_text()):
  if route['status']=='implemented':continue
  path=route['path'].replace('(.:format)','')
  path=re.sub(r':(?:room_id|user_id|message_id|id)', '486777696',path)
  cases.append((route['verb'],path));cases.append((route['verb'],path+'.json'))
 cases += [('GET','/definitely-not-a-route'),('POST','/definitely-not-a-route'),('PATCH','/webmanifest.json'),('GET','/rooms/486777696/invalid/messages/1')]
 result={}
 for method,path in cases:
  status,body,h=request(port,path,method,cookies={})
  result[method+' '+path]={'status':status,'body':body,'headers':{k:h.get(k) for k in ['content-type','cache-control','x-version','x-frame-options','vary']}}
 return result

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/route-errors.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/route-errors.json').write_text(json.dumps({'passed':passed,'scope':['40 missing actions','missing controller','unmatched route','unsupported verbs','HTML/JSON error formats','before authentication/CSRF/browser callbacks']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,{k:(a[key][k],b[key][k]) for k in a[key] if a[key][k]!=b[key][k]})
  raise SystemExit('Route errors differ')
 print('Route error parity passed')
