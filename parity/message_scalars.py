#!/usr/bin/env python3
"""Scalar casts and ignored nested fields through real message/boost mutation endpoints."""
import difflib,http.client,json,re,sqlite3,subprocess
from sessions import ROOT,request,normalize,csrf_token,BROWSER

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 path=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 jar={};_,page,_=request(port,'/session/new',cookies=jar);csrf=csrf_token(page)
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},jar)[0]==302
 def send(url,method,key,attrs):
  c=http.client.HTTPConnection('127.0.0.1',port,timeout=30);c.request(method,url,json.dumps({key:attrs}),{'Host':'campfire.test',**BROWSER,'Content-Type':'application/json','Accept':'text/vnd.turbo-stream.html' if key=='message' and method=='POST' else 'text/html','Cookie':'; '.join(k+'='+v for k,v in jar.items()),'X-CSRF-Token':csrf});r=c.getresponse();body=r.read().decode();headers=dict((k.lower(),v) for k,v in r.getheaders());c.close()
  with sqlite3.connect(path) as db:
   db.row_factory=sqlite3.Row
   rows={t:[dict(x) for x in db.execute('SELECT '+('rowid,body' if t=='message_search_index' else '*')+' FROM '+t)] for t in ['messages','action_text_rich_texts','boosts','rooms','memberships','message_search_index']}
  return {'status':r.status,'type':headers.get('content-type'),'body':normalize(body),'location':headers.get('location'),'rows':rows}
 result={}
 for index,value in enumerate([False,True,123,None,{'ignored':'body'},['ignored']]):
  result[f'create_{index}']=send('/rooms/486777696/messages','POST','message',{'body':value,'client_message_id':f'scalar-{index}'})
  assert result[f'create_{index}']['status']==200,(side,index,result[f'create_{index}']['status'])
  message=max(x['id'] for x in result[f'create_{index}']['rows']['messages'])
  result[f'update_{index}']=send(f'/rooms/486777696/messages/{message}','PATCH','message',{'body':value,'client_message_id':value})
  result[f'boost_{index}']=send(f'/messages/{message}/boosts','POST','boost',{'content':value})
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/message-scalars.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/message-scalars.json').write_text(json.dumps({'passed':passed,'scope':['boolean/number/null message body and boost content','arrays/objects filtered by strong parameters','actual create/update responses and persisted mutation tables']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]:print(k,''.join(difflib.unified_diff(json.dumps(a[k],indent=2).splitlines(True),json.dumps(b[k],indent=2).splitlines(True)))[:1500])
  raise SystemExit('Message scalar parity failed')
 print('Message/boost scalar and strong parameter parity passed')
