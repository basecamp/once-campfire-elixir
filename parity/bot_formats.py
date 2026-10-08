#!/usr/bin/env python3
"""Bot and session API routes, inherited views, optional formats and head responses."""
import difflib,http.client,json,re,sqlite3,subprocess
from sessions import ROOT,request,normalize
FORMATS=['json','html','xml','turbo_stream','pdf']
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 with sqlite3.connect(dbpath) as db:
  db.execute('DELETE FROM push_subscriptions')
  bot,room=db.execute("SELECT u.id || '-' || u.bot_token,m.room_id FROM users u JOIN memberships m ON m.user_id=u.id WHERE u.role=2 AND u.status=0 AND m.room_id=486777696 LIMIT 1").fetchone()
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);csrf=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies)[0]==302
 result={}
 def call(label,path,method='GET',body=None,jar=None):
  headers={'Host':'campfire.test','Content-Type':'text/plain','User-Agent':'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36'}
  if jar:headers.update({'Cookie':'; '.join(f'{k}={v}' for k,v in jar.items()),'X-CSRF-Token':csrf})
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request(method,path,body,headers);r=c.getresponse();text=r.read().decode();h={k.lower():v for k,v in r.getheaders()};c.close()
  parsed=json.loads(text) if text and h.get('content-type','').startswith('application/json') else normalize(text)
  def clean(v):
   if isinstance(v,str):return re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}','<VALIDATED_UUID>',v)
   if isinstance(v,list):return [clean(x) for x in v]
   if isinstance(v,dict):return {k:clean(x) for k,x in v.items()}
   return v
  result[label]={'status':r.status,'type':h.get('content-type'),'body':clean(parsed),'location':h.get('location'),'total':h.get('x-total-count'),'link':h.get('link')}
  return h
 for mode,jar in [('bot',{}),('session',cookies)]:
  base=f'/rooms/{room}/{bot}/messages'
  for fmt in FORMATS:
   call(f'{mode}_{fmt}_index',base+'.'+fmt,jar=jar)
   call(f'{mode}_{fmt}_show',base+'/933434530.'+fmt,jar=jar)
   h=call(f'{mode}_{fmt}_create',base+'.'+fmt,'POST','<p>API body Ω</p>'.encode(),jar)
   assert h.get('location'),(side,mode,fmt,h)
   message=int(h['location'].rsplit('/',1)[1])
   call(f'{mode}_{fmt}_update',base+f'/{message}.'+fmt,'PATCH','<p>API edited Ω</p>'.encode(),jar)
   call(f'{mode}_{fmt}_destroy',base+f'/{message}.'+fmt,'DELETE',None,jar)
   boostbase=base+'/933434530/boosts'
   call(f'{mode}_{fmt}_boost_create',boostbase+'.'+fmt,'POST','+1',jar)
   with sqlite3.connect(dbpath) as db: boost=db.execute('SELECT MAX(id) FROM boosts').fetchone()[0]
   call(f'{mode}_{fmt}_boost_destroy',boostbase+f'/{boost}.'+fmt,'DELETE',None,jar)
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/bot-formats.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/bot-formats.json').write_text(json.dumps({'passed':passed,'scope':['bot and session authentication','index/show/create/update/destroy','JSON/HTML/XML/Turbo/PDF formats','inherited templates','status/body/MIME/pagination/location']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]:print(k,''.join(difflib.unified_diff(str(a[k]).splitlines(True),str(b[k]).splitlines(True)))[:1100])
  raise SystemExit('Bot optional-format parity failed')
 print('Bot API optional-format parity passed')
