#!/usr/bin/env python3
"""Observe native and Rails message/boost broadcasts on real authenticated sockets."""
import base64,difflib,hashlib,hmac,json,re,subprocess
from sessions import ROOT,request
from websocket import WebSocket
SECRET=next(s.split('=',1)[1] for s in (ROOT/'parity/reference.env').read_text().splitlines() if s.startswith('SECRET_KEY_BASE='))
def signed_stream(stream):
 key=hashlib.pbkdf2_hmac('sha256',SECRET.encode(),b'turbo/signed_stream_verifier_key',1000,64)
 data=base64.b64encode(json.dumps(stream,separators=(',',':')).encode()).decode()
 return data+'--'+hmac.new(key,data.encode(),'sha256').hexdigest()
def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies)
 token=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies);assert status==302
 sock=WebSocket(port,cookies);assert sock.receive()=={'type':'welcome'}
 room=486777696
 stream=base64.urlsafe_b64encode(f'gid://campfire/Rooms::Closed/{room}'.encode()).decode().rstrip('=')+':messages'
 channel,status=sock.subscribe({'channel':'RoomMessagesChannel','signed_stream_name':signed_stream(stream)});assert status=='confirm_subscription'
 unread,status=sock.subscribe({'channel':'UnreadRoomsChannel'});assert status=='confirm_subscription'
 results={}
 def receive():
  event=sock.receive();assert event['identifier']==channel,event;return event['message']
 def mutate(path,method,attrs):
  status,body,headers=request(port,path,method,{'authenticity_token':token,**attrs},cookies,headers={'Accept':'text/html' if method=='PATCH' or '/boosts' in path and method=='POST' else 'text/vnd.turbo-stream.html'});assert status in [200,204,302],(side,status,body[:200]);return {'status':status,'body':body,'location':headers.get('location')}
 path=f'/rooms/{room}/messages'
 results['create']=mutate(path,'POST',{'message[body]':'<div>Broadcast me</div>','message[client_message_id]':'broadcast-parity-client'})
 results['append']=receive();event=sock.receive();assert event['identifier']==unread;results['unread']=event['message']
 message=int(re.search(r'data-message-id="(\d+)"',results['append'])[1])
 results['edit']=mutate(f'{path}/{message}','PATCH',{'message[body]':'<div>Edited body</div>'});results['replace']=receive()
 results['boost_create']=mutate(f'/messages/{message}/boosts','POST',{'boost[content]':'👍'});results['boost_append']=receive()
 boost=int(re.search(r'id="boost_(\d+)"',results['boost_append'])[1])
 results['boost_delete']=mutate(f'/messages/{message}/boosts/{boost}','DELETE',{});results['boost_remove']=receive()
 results['delete']=mutate(f'{path}/{message}','DELETE',{});results['remove']=receive()
 sock.close()
 (ROOT/f'parity/results/message-broadcasts.{side}.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for key in a:
  if a[key]!=b[key]:print(key+'\n'+''.join(difflib.unified_diff(str(a[key]).splitlines(True),str(b[key]).splitlines(True)))[:6000])
 passed=a==b
 (ROOT/'parity/results/message-broadcasts.json').write_text(json.dumps({'passed':passed,'scope':['text append','unread','presentation replace','boost append/remove','message remove','HTTP mutations']},indent=2)+'\n')
 if not passed:raise SystemExit('Message broadcasts differ')
 print('Message broadcasts parity passed')
