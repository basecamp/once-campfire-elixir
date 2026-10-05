#!/usr/bin/env python3
"""Production proxy binary provenance, cached TLS, ALPN HTTP/2 and HTTPS redirects."""
import hashlib,json,os,shutil,subprocess,time
from sessions import ROOT
from http_shutdown import seed
BASE=ROOT/'var/frontend';NAME='campfire-elixir-frontend';BASE.mkdir(parents=True,exist_ok=True)
CPUS=os.environ.get('PARITY_CPUS',','.join(map(str,sorted(os.sched_getaffinity(0)))))
def run(args):return subprocess.check_output(list(map(str,args)),text=True)
ARCH=run(['docker','image','inspect','campfire-reference:app','--format','{{.Architecture}}']).strip()
BINARY,PROXY_SHA256={
 'amd64':('/usr/local/bundle/ruby/3.4.0/gems/thruster-0.1.23-x86_64-linux/exe/x86_64-linux/thrust','0dc6606e316dff1c44212797b02f03ff339098ff20cca240e26802d342d0244e'),
 'arm64':('/usr/local/bundle/ruby/3.4.0/gems/thruster-0.1.23-aarch64-linux/exe/aarch64-linux/thrust','e92e38da9e12bd3fd8ff1e05ea8d5fbcca2b5a28b7c59c45c543d0026f7d3639')
}[ARCH]
def query(folder,path,secure=True,h2=True):
 body=folder/'body';head=folder/'headers'
 args=['curl','--silent','--show-error','--noproxy','*','--max-time','10','-H','Host: campfire.test','--resolve',f'campfire.test:{47077 if secure else 47076}:127.0.0.1','--cacert',BASE/'cert.pem','--http2' if h2 else '--http1.1','-D',head,'-o',body,'-w','%{json}',f'{"https" if secure else "http"}://campfire.test:{47077 if secure else 47076}{path}']
 info=json.loads(run(args));headers={}
 for line in head.read_text().splitlines():
  if ': ' in line:
   key,value=line.split(': ',1);headers.setdefault(key.lower(),[]).append(value)
 return {'status':info['http_code'],'protocol':info['http_version'],'location':headers.get('location'),'body_sha256':hashlib.sha256(body.read_bytes()).hexdigest()},headers

def one(side):
 folder=BASE/side;seed(folder);(folder/'db').mkdir();shutil.copyfile(folder/'production.sqlite3',folder/'db/production.sqlite3');cache=folder/'thruster';cache.mkdir();(cache/'campfire.test').write_bytes((BASE/'key.pem').read_bytes()+(BASE/'cert.pem').read_bytes())
 image='campfire-reference:app' if side=='reference' else 'campfire-elixir:release'
 subprocess.run(['docker','rm','-f',NAME],capture_output=True)
 run(['docker','run','-d','--name',NAME,'--cpuset-cpus',CPUS,'--user',f'{os.getuid()}:{os.getgid()}','--env-file',ROOT/'parity/reference.env','-e','TLS_DOMAIN=campfire.test','-e','H2C_ENABLED=true','-e','LOG_REQUESTS=false','-p','127.0.0.1:47076:80','-p','127.0.0.1:47077:443','-v',f'{folder}:/rails/storage',image])
 try:
  for _ in range(120):
   try:
    result,headers=query(folder,'/up')
    if result['status']==200:break
   except subprocess.CalledProcessError:pass
   time.sleep(.1)
  else:raise AssertionError(run(['docker','logs',NAME]))
  assert result['protocol']=='2' and result['status']==200,result
  result={'tls_http2_up':result}
  public,h=query(folder,'/robots.txt')
  public['type']=h.get('content-type');public['cache']=h.get('cache-control');result['public_document']=public
  result['startup_page_sha256']=run(['docker','exec',NAME,'sha256sum','/rails/public/502.html' if side=='reference' else '/campfire/public/502.html']).split()[0]
  result['tls_http1_up'],_=query(folder,'/up',h2=False)
  result['http_redirect'],_=query(folder,'/up',secure=False,h2=False)
  result['https_auth_redirect'],_=query(folder,'/rooms/486777696')
  assert result['https_auth_redirect']['location']==['https://campfire.test/session/new']
  assert result['http_redirect']['status'] in [301,302,307,308]
  path=BINARY if side=='reference' else '/usr/local/bin/thrust'
  result['proxy_sha256']=run(['docker','exec',NAME,'sha256sum',path]).split()[0]
  assert result['proxy_sha256']==PROXY_SHA256
  return result
 finally:
  log=subprocess.run(['docker','logs',NAME],capture_output=True,text=True);(ROOT/f'parity/frontend-{side}.log').write_text(log.stdout+log.stderr);subprocess.run(['docker','rm','-f',NAME],capture_output=True)
if __name__=='__main__':
 run(['openssl','ecparam','-name','prime256v1','-genkey','-noout','-out',BASE/'key.pem'])
 run(['openssl','req','-new','-x509','-key',BASE/'key.pem','-out',BASE/'cert.pem','-days','365','-subj','/CN=campfire.test','-addext','subjectAltName=DNS:campfire.test'])
 a=one('reference');b=one('candidate')
 for side,data in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/frontend.{side}.json').write_text(json.dumps(data,indent=2)+'\n')
 assert a==b,(a,b)
 (ROOT/'parity/results/frontend.json').write_text(json.dumps({'passed':True,'scope':['same pinned Thruster 0.1.23 binary','real TLS using isolated cached certificates','ALPN HTTP/2 and HTTP/1.1','HTTP to HTTPS redirect','HTTPS Rails authentication authority','no public ACME request needed for cached certificate fixture']},indent=2)+'\n')
 print('Production TLS/HTTP2/proxy parity passed')
