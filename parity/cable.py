#!/usr/bin/env python3
"""Action Cable authentication, stream authorization, typing and presence parity."""
import base64,hashlib,hmac,json,pathlib,re,sqlite3,subprocess,time
from sessions import request
from websocket import WebSocket
ROOT=pathlib.Path(__file__).resolve().parents[1]
SECRET=next(s.split('=',1)[1] for s in (ROOT/'parity/reference.env').read_text().splitlines() if s.startswith('SECRET_KEY_BASE='))
def signed_stream(stream):
 key=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'turbo/signed_stream_verifier_key',1000,64)
 data=base64.b64encode(json.dumps(stream,separators=(',',':')).encode()).decode()
 return data+'--'+hmac.new(key,data.encode(),'sha256').hexdigest()
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};status,page,_=request(port,'/session/new',cookies=cookies)
 csrf=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies);assert status==302
 anon=WebSocket(port);unauthorized=anon.receive();assert unauthorized=={'type':'disconnect','reason':'unauthorized','reconnect':False};anon.close()
 a=WebSocket(port,cookies);b=WebSocket(port,cookies)
 assert a.receive()==b.receive()=={'type':'welcome'}
 subscriptions=[]
 room_id=486777696
 for params,expected in [({'channel':'HeartbeatChannel'},'confirm_subscription'),({'channel':'ReadRoomsChannel'},'confirm_subscription'),({'channel':'UnreadRoomsChannel'},'confirm_subscription'),({'channel':'RoomChannel','room_id':room_id},'confirm_subscription'),({'channel':'RoomChannel','room_id':-1},'reject_subscription')]:
  id,status=a.subscribe(params);assert status==expected;subscriptions.append({'params':params,'type':status})
 for channel,gid,suffix,expected in [('RoomMessagesChannel',f'gid://campfire/Rooms::Closed/{room_id}','messages','confirm_subscription'),('RoomMessagesChannel','gid://campfire/Rooms::Closed/999','messages','reject_subscription'),('Turbo::StreamsChannel',f'gid://campfire/Rooms::Closed/{room_id}','messages','reject_subscription')]:
  stream=base64.urlsafe_b64encode(gid.encode()).decode().rstrip('=')+':'+suffix
  params={'channel':channel,'signed_stream_name':signed_stream(stream)}
  id,status=a.subscribe(params);assert status==expected,(side,params,status);subscriptions.append({'params':params,'type':status})
 typing_a,status=a.subscribe({'channel':'TypingNotificationsChannel','room_id':room_id});assert status=='confirm_subscription'
 typing_b,status=b.subscribe({'channel':'TypingNotificationsChannel','room_id':room_id});assert status=='confirm_subscription'
 b.perform(typing_b,'start');started=a.receive();assert started['message']=={'action':'start','user':{'id':127326141,'name':'David'}}
 assert b.receive()['message']==started['message']
 b.perform(typing_b,'stop');stopped=a.receive();assert stopped['message']['action']=='stop';b.receive()
 # Presence confirmation may interleave with its read broadcast on the same socket.
 presence,status=b.subscribe({'channel':'PresenceChannel','room_id':room_id});assert status=='confirm_subscription'
 read=a.receive();assert read['message']=={'room_id':room_id}
 dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
 def membership():
  with sqlite3.connect(dbpath) as db:
   db.row_factory=sqlite3.Row;return dict(db.execute('SELECT * FROM memberships WHERE user_id=127326141 AND room_id=?',[room_id]).fetchone())
 present=membership();assert present['connections']==1 and present['unread_at'] is None
 b.perform(presence,'refresh');time.sleep(.1)
 refreshed=membership();b.unsubscribe(presence);time.sleep(.1);absent=membership();assert absent['connections']==0 and absent['connected_at'] is None
 a.close();b.close()
 return {'unauthorized':unauthorized,'subscriptions':subscriptions,'typing':[started,stopped],'read':read,'presence':[present,refreshed,absent]}
a=run('reference',47071);b=run('candidate',47070);passed=a==b
for side,result in [('reference',a),('candidate',b)]:(ROOT/f'parity/results/cable.{side}.json').write_text(json.dumps(result,indent=2)+'\n')
(ROOT/'parity/results/cable.json').write_text(json.dumps({'passed':passed,'scope':'protocol, authentication, room/Turbo authorization, typing, read, presence; message/boost broadcasts pending'},indent=2)+'\n')
if not passed:
 import difflib
 print(''.join(difflib.unified_diff(json.dumps(a,indent=2).splitlines(True),json.dumps(b,indent=2).splitlines(True)))[:9000]);raise SystemExit('Cable parity failed')
print('Cable protocol/presence parity passed')
