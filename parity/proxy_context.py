#!/usr/bin/env python3
"""Rails redirect authority/protocol behind the production TLS proxy."""
import difflib,json,subprocess
from sessions import ROOT,request
CASES=[{}, {'X-Forwarded-Proto':'https'}, {'X-Forwarded-Ssl':'on'}, {'X-Forwarded-Scheme':'https'}, {'X-Forwarded-Proto':'http, https'}, {'X-Forwarded-Proto':'https, http'}, {'X-Forwarded-Proto':'bad, https, invalid'}, {'X-Forwarded-Proto':'wss'}, {'Forwarded':'for=1.2.3.4;proto=https;host=ignored.test'}, {'Forwarded':'proto=http, proto=https'}, {'Forwarded':'proto="https"'}, {'Forwarded':'proto=bad','X-Forwarded-Proto':'https'}, {'X-Forwarded-Host':'first.test, forwarded.test:8443','X-Forwarded-Proto':'https'}, {'X-Forwarded-Host':'forwarded.test','X-Forwarded-Port':'8443','X-Forwarded-Proto':'https'}, {'Host':'campfire.test:80','X-Forwarded-Proto':'https'}, {'Host':'campfire.test:443'}, {'X-Forwarded-Host':'[::1]:8443','X-Forwarded-Proto':'https'}]
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 results=[]
 for headers in CASES:
  status,body,h=request(port,'/rooms/486777696',headers=headers)
  results.append({'status':status,'location':h.get('location')})
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,data in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/proxy-context.{side}.json').write_text(json.dumps(data,indent=2)+'\n')
 passed=a==b;(ROOT/'parity/results/proxy-context.json').write_text(json.dumps({'passed':passed,'cases':CASES,'scope':'real HTTP redirects with proxy protocol/authority, scheme chains, RFC Forwarded, default and custom ports'},indent=2)+'\n')
 if not passed:print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True))));raise SystemExit('Proxy context parity failed')
 print('Proxy protocol/authority parity passed')
