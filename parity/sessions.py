#!/usr/bin/env python3
"""Live Rails/Elixir browser login, credential rejection and cookie interoperability."""
import http.client,json,pathlib,re,sqlite3,subprocess,urllib.parse
ROOT=pathlib.Path(__file__).resolve().parents[1]
def request(port,path,method='GET',params=None,cookies=None,headers=None):
 h={'Host':'campfire.test','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36'}
 if cookies:h['Cookie']='; '.join(f'{k}={v}' for k,v in cookies.items())
 if headers:h.update(headers)
 body=urllib.parse.urlencode(params) if params is not None else None
 if body is not None:h['Content-Type']='application/x-www-form-urlencoded'
 c=http.client.HTTPConnection('127.0.0.1',port,timeout=15);c.request(method,path,body,h);r=c.getresponse();s=r.read().decode();headers=r.getheaders();c.close()
 for k,v in headers:
  if k.lower()=='set-cookie' and cookies is not None:
   n,val=v.split(';',1)[0].split('=',1);cookies[n]=val
 return r.status,s,dict((k.lower(),v) for k,v in headers)
def normalize(s):return re.sub(r'(name="(?:csrf-token|authenticity_token)" (?:content|value)=")[^"]+',r'\1<VALIDATED_TOKEN>',s)
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};status,page,h=request(port,'/session/new',cookies=cookies);assert status==200
 token=re.search(r'name="authenticity_token" value="([^"]+)"',page)[1]
 forged=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456'},cookies)[0];assert forged==422
 status,rejected,h=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'incorrect','authenticity_token':token},cookies);assert status==401
 token=re.search(r'name="authenticity_token" value="([^"]+)"',rejected)[1]
 status,body,h=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies);assert status==302 and h['location']=='http://campfire.test/'
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:
  db.row_factory=sqlite3.Row;row=dict(db.execute('SELECT * FROM sessions ORDER BY id DESC LIMIT 1').fetchone())
 assert re.fullmatch(r'[1-9A-HJ-NP-Za-km-z]{24}',row['token']);session_token=row['token'];row['token']='<VALIDATED_BASE58_TOKEN>'
 return {'page':normalize(page),'rejected':normalize(rejected),'session':row,'cookies':cookies,'session_token':session_token}
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 # Interchange authentication cookies on protected Rails and native bot API routes.
 for origin,target,port in [(a,'candidate',47070),(b,'reference',47071)]:
  dbpath=ROOT/'var'/('rails/db' if target=='reference' else 'candidate')/'production.sqlite3'
  with sqlite3.connect(dbpath) as db:
   db.execute("INSERT INTO sessions (user_id,token,last_active_at,created_at,updated_at) VALUES (?,?,?,?,?)",[127326141,origin['session_token'],'2026-03-02 16:00:00','2026-03-02 16:00:00','2026-03-02 16:00:00'])
  status,body,_=request(port,'/rooms/486777696/invalid/messages',cookies=origin['cookies'].copy());assert status==200,(target,status,body)
 a.pop('cookies');b.pop('cookies');a.pop('session_token');b.pop('session_token');passed=a==b
 (ROOT/'parity/results/session.reference.json').write_text(json.dumps(a,indent=2,ensure_ascii=False)+'\n')
 (ROOT/'parity/results/session.candidate.json').write_text(json.dumps(b,indent=2,ensure_ascii=False)+'\n')
 (ROOT/'parity/results/sessions.json').write_text(json.dumps({'passed':passed,'flows':['HTML','csrf_rejection','credential_rejection','login','session_rows','bidirectional_cookie_interoperability']},indent=2)+'\n')
 if not passed:
  import difflib
  for key in a:
   if a[key]!=b[key]:
    if isinstance(a[key],str):print(key+': '+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:5000])
    else:print(key,a[key],b[key])
  raise SystemExit('Session parity failed')
 print('Session parity passed')
