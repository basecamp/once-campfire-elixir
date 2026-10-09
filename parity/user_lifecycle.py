#!/usr/bin/env python3
"""Ban/unban/deactivate effects on all active sockets, old cookies and persistent policy."""
import difflib,json,re,sqlite3,subprocess
from sessions import ROOT,request,csrf_token
from websocket import WebSocket
from drain_jobs import drain

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 def login(email,ip):
  cookies={};headers={'X-Forwarded-For':ip};_,page,_=request(port,'/session/new',cookies=cookies,headers=headers);csrf=csrf_token(page)
  status,_,_=request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':csrf},cookies,headers=headers);assert status==302,(side,status)
  return cookies,csrf,headers
 admin,csrf,headers=login('david@37signals.com','198.51.100.10')
 with sqlite3.connect(dbpath) as db:target,email=db.execute('SELECT id,email_address FROM users WHERE id=149087659').fetchone()
 def snapshot():
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row
   result={table:[dict(r) for r in db.execute('SELECT * FROM '+table+' WHERE '+('id' if table=='users' else 'user_id')+'=? ORDER BY id',[target])] for table in ['users','sessions','memberships','bans','push_subscriptions','searches']}
   result['message_count']=db.execute('SELECT COUNT(*) FROM messages WHERE creator_id=?',[target]).fetchone()[0]
   for user in result['users']:
    if user['email_address']:user['email_address']=re.sub(r'-deactivated-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}@','-deactivated-<VALIDATED_UUID>@',user['email_address'])
   for session in result['sessions']:
    assert re.fullmatch('[1-9A-HJ-NP-Za-km-z]{24}',session['token']);session['token']='<VALIDATED_SESSION_TOKEN>'
   return result
 def action(path,method):
  status,body,_=request(port,path,method,{'authenticity_token':csrf},admin,headers=headers);assert status==302,(side,path,status,body[:100])
 result={}
 for stage in ['ban','deactivate']:
  sessions=[login(email,'198.51.100.9') for _ in range(2)];sockets=[]
  for jar,_,_ in sessions:
   sock=WebSocket(port,jar);assert sock.receive()=={'type':'welcome'};_,status=sock.subscribe({'channel':'HeartbeatChannel'});assert status=='confirm_subscription';sockets.append(sock)
  action('/users/'+str(target)+'/ban','POST') if stage=='ban' else action('/account/users/'+str(target),'DELETE')
  result[stage]={'disconnects':[sock.receive() for sock in sockets],'old_sessions':[request(port,'/account/edit',cookies=jar,headers=h)[0] for jar,_,h in sessions],'state':snapshot()}
  assert result[stage]['disconnects']==[{'type':'disconnect','reason':'remote','reconnect':False}]*2
  for sock in sockets:sock.close()
  if stage=='ban':
   action('/users/'+str(target)+'/ban','DELETE');result['unban']=snapshot()
   # The queued cleanup survives unban and removes content using the current User.
   drain(side);result['cleanup_after_unban']=snapshot()
 return result
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,r in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/user-lifecycle.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/user-lifecycle.json').write_text(json.dumps({'passed':passed,'scope':['ban and deactivation revoke multiple active sockets','old authenticated cookies rejected','unban retains callback job','queued banned-content cleanup after unban','complete target user/session/membership/ban/subscription/search rows']},indent=2)+'\n')
 if not passed:print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True)))[:6000]);raise SystemExit('User lifecycle parity failed')
 print('User policy/realtime lifecycle parity passed')
