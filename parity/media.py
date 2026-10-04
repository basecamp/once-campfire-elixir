#!/usr/bin/env python3
"""Generate image representations and compare bytes, tracked records and analysis jobs."""
import base64,hashlib,hmac,http.client,json,re,sqlite3,subprocess,urllib.parse
from sessions import ROOT
from drain_jobs import drain
SECRET=next(s.split('=',1)[1] for s in (ROOT/'parity/reference.env').read_text().splitlines() if s.startswith('SECRET_KEY_BASE='))
KEY=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'ActiveStorage',1000,64)
def sign(value,purpose):
 encoded=base64.b64encode(json.dumps({'_rails':{'data':value,'pur':purpose}},separators=(',',':')).encode()).decode()
 return encoded+'--'+hmac.new(KEY,encoded.encode(),'sha1').hexdigest()
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 def raw(path):
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request('GET',path,headers={'Host':'campfire.test'});r=c.getresponse();body=r.read();headers={k.lower():v for k,v in r.getheaders()};c.close();return r.status,body,headers
 results=[]
 cases=[(blob,{'format':fmt,'resize_to_limit':size}) for blob,fmt,size in [(1,'webp',[512,512]),(7,'png',[192,192]),(7,'png',[512,512]),(9,'webp',[1200,800])]]
 cases.extend((1,{'format':'png',**item['transformations']}) for item in json.loads((ROOT/'vectors/transformations.json').read_text()) if not item.get('error'))
 for blob_id,transformations in cases:
  representation='/rails/active_storage/representations/redirect/'+sign(blob_id,'blob_id')+'/'+sign(transformations,'variation')+'/original.file'
  status,_,headers=raw(representation);assert status==302,(side,status,headers)
  disk=urllib.parse.urlsplit(headers['location']).path
  status,body,headers=raw(disk);assert status==200,(side,status)
  digest=base64.b64encode(hashlib.md5(body).digest()).decode()
  results.append({'source':blob_id,'transformations':transformations,'bytes':len(body),'checksum':digest,'content_type':headers['content-type']})
  status,again,h=raw(representation.replace('/redirect/','/proxy/'));assert status==200 and again==body
 # Invalid signatures must never create records.
 status,_,_=raw(representation.replace('/'+sign(blob_id,'blob_id')+'/', '/invalid/'));assert status==404
 def redis(*args):return subprocess.check_output(['docker','exec','campfire-elixir-redis','redis-cli','-p','47079','--raw',*args],text=True).strip()
 queued=[json.loads(line)['args'][0] for line in redis('LRANGE','resque:queue:default','0','-1').splitlines()]
 for job in queued:
  assert re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',job['job_id']);job['job_id']='<VALIDATED_UUID_V4>'
 def rows():
  fixture=json.loads((ROOT/'test/fixtures/seed.json').read_text());state={}
  with sqlite3.connect(path) as db:
   db.row_factory=sqlite3.Row
   for table in ['active_storage_blobs','active_storage_attachments','active_storage_variant_records']:
    values=[dict(row) for row in db.execute('SELECT * FROM '+table+' ORDER BY id')]
    for value in values:
     if table=='active_storage_blobs' and value['id'] not in {r['id'] for r in fixture['tables'][table]}:
      key=value['key'];assert re.fullmatch(r'[a-z0-9]{28}',key)
      data=(ROOT/'var'/('rails/files' if side=='reference' else 'candidate/files')/key[:2]/key[2:4]/key).read_bytes()
      assert len(data)==value['byte_size'] and base64.b64encode(hashlib.md5(data).digest()).decode()==value['checksum']
      value['key']='<VALIDATED_BASE36_KEY>'
    state[table]=values
  return state
 before=rows()
 drain(side)
 assert redis('LLEN','resque:queue:default')=='0'
 assert redis('GET','resque:stat:failed') in ['','0']
 return {'files':results,'queued':queued,'before_analysis':before,'after_analysis':rows()}
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/media.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/media.json').write_text(json.dumps({'passed':passed,'scope':['fresh image representation redirects','proxy bytes','variant records','blob metadata before and after queued analysis','file integrity','idempotent processing','invalid signatures']},indent=2)+'\n')
 if not passed:
  import difflib
  print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True)))[:9000]);raise SystemExit('Media parity failed')
 print('Media processing/persistence parity passed')
