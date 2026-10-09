#!/usr/bin/env python3
"""Return-to, resume boundaries, transfer expiry, rate limiting, logout and old sockets."""
import difflib,json,re,sqlite3,subprocess,time
from sessions import ROOT,request,normalize,csrf_token,form_token
from websocket import WebSocket

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 results={};cookies={}
 status,_,h=request(port,'/rooms/486777696?old=tab',cookies=cookies);assert status==302
 _,page,_=request(port,'/session/new',cookies=cookies);token=csrf_token(page)
 status,_,h=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies);assert status==302
 results['return_to']=h['location'];assert h['location']=='http://campfire.test/rooms/486777696?old=tab'
 def session():
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row;row=dict(db.execute('SELECT * FROM sessions ORDER BY id DESC LIMIT 1').fetchone());row.pop('token');return row
 first=session()
 for stamp in ['2026-03-02 15:00:00.000000','2026-03-02 14:59:59.999999']:
  with sqlite3.connect(dbpath) as db:db.execute('UPDATE sessions SET last_active_at=? WHERE id=?',[stamp,first['id']])
  status,_,_=request(port,'/account/edit',cookies=cookies,headers={'User-Agent':'Mozilla/5.0 Chrome/132.0.0.0 Safari/537.36'});assert status==200
  results['resume_'+stamp]=session()
 status,page,_=request(port,'/users/me/profile',cookies=cookies);assert status==200
 transfer=re.search(r'/session/transfers/([^"<]+)',page)[1]
 new={};status,page,_=request(port,'/session/transfers/'+transfer,cookies=new);assert status==200
 transfer_token=form_token(page)
 results['bad_transfer']=request(port,'/session/transfers/invalid','PATCH',{'authenticity_token':transfer_token},new)[0]
 results['transfer']=request(port,'/session/transfers/'+transfer,'PATCH',{'authenticity_token':transfer_token},new)[0]
 sock=WebSocket(port,cookies);assert sock.receive()=={'type':'welcome'}
 sock.subscribe({'channel':'HeartbeatChannel'});time.sleep(.2)
 old=cookies.copy()
 status,_,h=request(port,'/session','DELETE',{'authenticity_token':token},cookies);assert status==302
 results['logout_redirect']=h['location'];results['disconnect']=sock.receive();sock.close()
 results['old_tab']=request(port,'/account/edit',cookies=old)[0]
 results['transferred_session']=request(port,'/account/edit',cookies=new)[0]
 anonymous={};_,page,_=request(port,'/session/new',cookies=anonymous);csrf=csrf_token(page)
 results['rate_limit']=[]
 for i in range(11):
  status,page,h=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'wrong','authenticity_token':csrf},anonymous)
  results['rate_limit'].append(status)
  assert status in [401,429]
 return results

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/session-lifecycle.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/session-lifecycle.json').write_text(json.dumps({'passed':passed,'scope':['return-to query preserved','session resume one-hour boundary','transfer links and invalid ids','logout socket revocation','old tab rejection','separate session survives logout','login rate limit']},indent=2)+'\n')
 if not passed:
  print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True))));raise SystemExit('Session lifecycle parity failed')
 print('Session lifecycle parity passed')
