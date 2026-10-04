#!/usr/bin/env python3
"""Message collection validators, conditional GET/HEAD and update invalidation."""
import json,re,sqlite3,subprocess,difflib
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 path='/rooms/486777696/messages';result={}
 def check(label,headers=None,method='GET'):
  status,body,h=request(port,path,method,cookies=cookies,headers=headers)
  result[label]={'status':status,'body':normalize(body),'headers':{k:h.get(k) for k in ['etag','last-modified','cache-control','content-type','vary']}}
  return h
 h=check('initial');etag=h['etag'];modified=h['last-modified']
 for name,headers,method in [
  ('etag',{'If-None-Match':etag},'GET'),('head',{'If-None-Match':etag},'HEAD'),
  ('list',{'If-None-Match':'"other", '+etag},'GET'),('any',{'If-None-Match':'*'},'GET'),
  ('strong',{'If-None-Match':etag.removeprefix('W/')},'GET'),('old',{'If-Modified-Since':'Sun, 01 Mar 2026 00:00:00 GMT'},'GET'),
  ('modified',{'If-Modified-Since':modified},'GET'),('newer',{'If-Modified-Since':'Tue, 03 Mar 2026 00:00:00 GMT'},'GET'),
  ('both_stale_etag',{'If-Modified-Since':modified,'If-None-Match':'"other"'},'GET'),
  ('both_stale_date',{'If-Modified-Since':'Sun, 01 Mar 2026 00:00:00 GMT','If-None-Match':etag},'GET'),
  ('json',{'Accept':'application/json'},'GET')]:check(name,headers,method)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:db.execute("UPDATE messages SET updated_at='2026-03-02 16:00:00' WHERE id=136976342")
 check('updated',{'If-None-Match':etag})
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/message-cache.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/message-cache.json').write_text(json.dumps({'passed':passed,'scope':['collection model/template validators','conditional GET and HEAD','ETag lists/wildcards/strong validators','date validators','combined validators','record touch invalidation','JSON format failure']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]:print(k,''.join(difflib.unified_diff(str(a[k]).splitlines(True),str(b[k]).splitlines(True)))[:1200])
  raise SystemExit('Message cache parity failed')
 print('Message collection cache parity passed')
