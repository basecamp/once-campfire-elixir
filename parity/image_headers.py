#!/usr/bin/env python3
"""Model ETags, conditional image responses and cache invalidation."""
import json,re,subprocess,http.client,base64,hashlib,sqlite3
from sessions import ROOT,request
from branding import sign

def image(port,path,cookies,method='GET',headers=None):
 h={'Host':'campfire.test','Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items())}
 h.update(headers or {});c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request(method,path,headers=h);r=c.getresponse();body=r.read();raw=r.getheaders();hs={k.lower():v for k,v in raw};c.close()
 for k,v in raw:
  if k.lower()=='set-cookie':
   name,value=v.split(';',1)[0].split('=',1);cookies[name]=value
 if hs.get('content-disposition') and re.search(r'filename="[a-z0-9]{28}"',hs['content-disposition']):
  hs['content-disposition']=re.sub(r'[a-z0-9]{28}','<VALIDATED_VARIANT_KEY>',hs['content-disposition'])
 return {'status':r.status,'body':base64.b64encode(body).decode(),'headers':{k:hs.get(k) for k in ['etag','cache-control','content-type','content-disposition','vary','content-encoding']}}
def avatar(id):
 secret=next(l.split('=',1)[1] for l in (ROOT/'parity/reference.env').read_text().splitlines() if l.startswith('SECRET_KEY_BASE='))
 import hmac
 key=hashlib.pbkdf2_hmac('sha256',secret.encode(),b'active_record/signed_id',1000,64)
 data=base64.urlsafe_b64encode(json.dumps({'_rails':{'data':id,'pur':'user/avatar'}},separators=(',',':')).encode()).decode().rstrip('=')
 return '/users/'+data+'--'+hmac.new(key,data.encode(),'sha256').hexdigest()+'/avatar'
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',p) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 results={}
 def cases(stage):
  for path in ['/account/logo','/account/logo?size=small',avatar(127326141),avatar(394959859)]:
   result=image(port,path,cookies);assert result['status']==200
   results[stage+path]=result;stable=image(port,path,cookies);results[stage+path+'stable']=stable;etag=stable['headers']['etag']
   for name,headers in [('match',{'If-None-Match':etag}),('other',{'If-None-Match':'W/"other"'}),('wildcard',{'If-None-Match':'*'}),('list',{'If-None-Match':'W/"other", '+etag}),('strong',{'If-None-Match':etag[2:]}),('both',{'If-None-Match':etag,'If-Modified-Since':'Mon, 02 Mar 2026 16:00:00 GMT'})]:
    results[stage+path+name]=image(port,path,cookies,headers=headers)
   results[stage+path+'HEAD']=image(port,path,cookies,'HEAD')
 cases('stock')
 for path,attrs in [('/users/me/profile',{'user[avatar]':sign(7,'blob_id')}),('/account',{'account[logo]':sign(1,'blob_id')})]:
  assert request(port,path,'PATCH',dict(attrs,authenticity_token=token),cookies)[0]==302
 cases('attached')
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/image-headers.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/image-headers.json').write_text(json.dumps({'passed':passed,'scope':['model ETags and cache invalidation','stock/attached logo and avatar bytes','conditional GET validators','HEAD']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key[:80],{f:(a[key][f][:80] if isinstance(a[key][f],str) else a[key][f],b[key][f][:80] if isinstance(b[key][f],str) else b[key][f]) for f in a[key] if a[key][f]!=b[key][f]})
  raise SystemExit('Image header parity failed')
 print('Image header parity passed')
