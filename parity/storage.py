#!/usr/bin/env python3
"""Live direct-upload allocation, byte integrity, redirects and range contracts."""
import base64,hashlib,hmac,http.client,json,pathlib,re,sqlite3,subprocess,urllib.parse
from sessions import request
ROOT=pathlib.Path(__file__).resolve().parents[1]
SECRET=next(s.split('=',1)[1] for s in (ROOT/'parity/reference.env').read_text().splitlines() if s.startswith('SECRET_KEY_BASE='))
KEY=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'ActiveStorage',1000,64)
def decode(token,purpose):
 token=urllib.parse.unquote(token);encoded,digest=token.split('--');assert hmac.compare_digest(hmac.new(KEY,encoded.encode(),'sha1').hexdigest(),digest)
 claims=json.loads(base64.b64decode(encoded))['_rails'];assert claims['pur']==purpose;return claims

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};status,page,_=request(port,'/session/new',cookies=cookies);assert status==200
 csrf=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies);assert status==302
 def raw(path,method='GET',body=None,headers=None):
  h={'Host':'campfire.test','Cookie':'; '.join(f'{k}={v}' for k,v in cookies.items()),'X-CSRF-Token':csrf}
  if headers:h.update(headers)
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=15);c.request(method,path,body,h);r=c.getresponse();data=r.read();headers=dict((k.lower(),v) for k,v in r.getheaders());c.close();return r.status,data,headers
 data=b'0123456789 Campfire storage parity\n'
 payload={'blob':{'filename':'resume & file.txt','byte_size':len(data),'checksum':base64.b64encode(hashlib.md5(data).digest()).decode(),'content_type':'text/plain','metadata':{'parity':True}}}
 status,body,_=raw('/rails/active_storage/direct_uploads','POST',json.dumps(payload),{'Content-Type':'application/json'});assert status==200,(side,status,body)
 response=json.loads(body);key=response['key'];assert re.fullmatch(r'[a-z0-9]{28}',key)
 sid=decode(response['signed_id'],'blob_id');assert sid['data']==response['id']
 upload_path=urllib.parse.urlsplit(response['direct_upload']['url']).path;upload_claims=decode(upload_path.rsplit('/',1)[1],'blob_token')
 assert upload_claims['data']['key']==key
 status,_,_=raw(upload_path,'PUT',data,{'Content-Type':'text/plain'});assert status==204,(side,status)
 path='/rails/active_storage/blobs/redirect/'+response['signed_id']+'/resume.txt'
 status,_,h=raw(path);assert status==302
 disk_path=urllib.parse.urlsplit(h['location']).path;disk_claims=decode(disk_path.split('/')[4],'blob_key');assert disk_claims['data']['key']==key
 requests=[]
 for range_value in [None,'bytes=0-9','bytes=-4','bytes=0-2,5-8','bytes=999-1000','invalid']:
  status,body,h=raw(disk_path,headers={'Range':range_value} if range_value else None)
  requests.append({'range':range_value,'status':status,'body_hex':body.hex(),'headers':{k:v for k,v in h.items() if k in ['content-type','content-range','content-disposition','cache-control']}})
 status,body,_=raw('/rails/active_storage/blobs/proxy/'+response['signed_id']+'/resume.txt',headers={'Range':'bytes=4-7'});assert status==206 and body==data[4:8]
 # Mismatched MD5 must delete the bytes that were written.
 status,_,_=raw(upload_path,'PUT',b'x'*len(data),{'Content-Type':'text/plain'});assert status==422
 status,_,_=raw(disk_path);assert status==404
 for claims in [upload_claims,disk_claims]:claims['data']['key']='<VALIDATED_BASE36_KEY>'
 response['key']='<VALIDATED_BASE36_KEY>';response['signed_id']=sid;response['direct_upload']['url']=upload_claims
 return {'response':response,'disk':disk_claims,'requests':requests}
a=run('reference',47071);b=run('candidate',47070)
passed=a==b
for side,v in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/storage.{side}.json').write_text(json.dumps(v,indent=2)+'\n')
(ROOT/'parity/results/storage.json').write_text(json.dumps({'passed':passed,'scope':'direct upload allocation, signature validation, checksum, disk single/multipart/error ranges, proxy range; variants pending'},indent=2)+'\n')
if not passed:
 import difflib
 print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True)))[:8000]);raise SystemExit('Storage parity failed')
print('Storage upload/range parity passed')
