#!/usr/bin/env python3
"""Pinned public documents: full bytes, HEAD, caching and Rack byte ranges."""
import difflib,http.client,json,subprocess
MANIFEST=json.loads((__import__('pathlib').Path(__file__).resolve().parents[1]/'priv/static/assets/.manifest.json').read_text())
NAMES=['assets/'+MANIFEST[k]['digested_path'] for k in ['_reset.css','application.js','lexxy.js','lexxy.js.gz','lexxy.js.br']]
NAMES += ['assets/lib/../'+MANIFEST['_reset.css']['digested_path'], 'assets/../robots.txt', 'assets/%2e%2e/robots.txt', 'assets//'+MANIFEST['_reset.css']['digested_path']]
for suffix in ['.svg','.png','.woff2','.map']:
 match=next((v['digested_path'] for k,v in MANIFEST.items() if k.endswith(suffix)),None)
 if match:NAMES.append('assets/'+match)
from sessions import ROOT
FIELDS=['content-type','content-length','content-range','cache-control','last-modified','etag','content-encoding','vary','accept-ranges','x-frame-options','x-version']
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 result={}
 for name in NAMES:
  for label,method,headers in [('get','GET',{}),('head','HEAD',{}),('gzip','GET',{'Accept-Encoding':'gzip'}),('fresh','GET',{'If-Modified-Since':'Mon, 02 Mar 2026 16:00:00 GMT'}),('range','GET',{'Range':'bytes=3-12'}),('multipart','GET',{'Range':'bytes=0-2,10-12'}),('unsatisfiable','GET',{'Range':'bytes=999999-'}),('gzip_range','GET',{'Range':'bytes=3-12','Accept-Encoding':'gzip'}),('gzip_multipart','GET',{'Range':'bytes=0-2,10-12','Accept-Encoding':'gzip'}),('gzip_head','HEAD',{'Accept-Encoding':'gzip'})]:
   c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request(method,'/'+name,headers={'Host':'campfire.test','Accept-Encoding':'identity',**headers});r=c.getresponse();data=r.read();h={k.lower():v for k,v in r.getheaders()};c.close()
   result[name+' '+label]={'status':r.status,'body':data.hex(),'headers':{key:h.get(key) for key in FIELDS}}
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,data in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/assets.{side}.json').write_text(json.dumps(data,indent=2)+'\n')
 passed=a==b;(ROOT/'parity/results/assets.json').write_text(json.dumps({'passed':passed,'scope':['exported CSS, JavaScript, compressed files, images and fonts','exact bytes and selected headers','GET and HEAD','gzip request','If-Modified-Since','single/multipart/unsatisfiable Rack ranges']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key,''.join(difflib.unified_diff(json.dumps(a[key],indent=2).splitlines(True),json.dumps(b[key],indent=2).splitlines(True)))[:1400])
  raise SystemExit('Asset parity failed')
 print('Asset bytes/headers/range parity passed')
