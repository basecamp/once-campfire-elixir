#!/usr/bin/env python3
"""Real socket room administration broadcasts, per-user delivery and revocation."""
import base64,difflib,json,re,subprocess
from sessions import ROOT,request
from message_broadcasts import signed_stream
from websocket import WebSocket

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={};_,page,_=request(port,'/session/new',cookies=cookies);token=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
 assert request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 sock=WebSocket(port,cookies);assert sock.receive()=={'type':'welcome'}
 for stream in ['rooms',base64.urlsafe_b64encode(b'gid://campfire/User/127326141').decode().rstrip('=')+':rooms']:
  _,status=sock.subscribe({'channel':'Turbo::StreamsChannel','signed_stream_name':signed_stream(stream)});assert status=='confirm_subscription'
 result={}
 def mutate(label,path,method,attrs):
  status,body,h=request(port,path,method,{'authenticity_token':token,**attrs},cookies);assert status==302,(side,label,status,body[:200])
  result[label]=sock.receive()['message']
  return int(h['location'].rsplit('/',1)[-1]) if h['location'].rsplit('/',1)[-1].isdigit() else None
 opened=mutate('create_open','/rooms/opens','POST',{'room[name]':'Room <& Ω'})
 mutate('update_open',f'/rooms/opens/{opened}','PATCH',{'room[name]':'Renamed <& Ω'})
 mutate('remove_open',f'/rooms/{opened}','DELETE',{})
 closed=mutate('create_closed','/rooms/closeds','POST',{'room[name]':'Private <& Ω','user_ids[]':'127326141'})
 mutate('update_closed',f'/rooms/closeds/{closed}','PATCH',{'room[name]':'Private renamed','user_ids[]':'127326141'})
 mutate('hide_closed',f'/rooms/{closed}/involvement','PATCH',{'involvement':'invisible'})
 mutate('show_closed',f'/rooms/{closed}/involvement','PATCH',{'involvement':'mentions'})
 mutate('remove_closed',f'/rooms/{closed}','DELETE',{})
 direct=mutate('create_direct','/rooms/directs','POST',{'user_ids[]':'127326141'})
 mutate('reuse_direct','/rooms/directs','POST',{'user_ids[]':'127326141'})
 mutate('remove_direct',f'/rooms/directs/{direct}','DELETE',{})
 sock.close()
 return result

if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/room-broadcasts.{side}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 passed=a==b
 (ROOT/'parity/results/room-broadcasts.json').write_text(json.dumps({'passed':passed,'scope':['open room global create/update/remove','closed room per-user create/update/remove','direct room per-user create/reuse/remove','HTML escaping']},indent=2)+'\n')
 if not passed:
  for k in a:
   if a[k]!=b[k]: print(k+'\n'+''.join(difflib.unified_diff(a[k].splitlines(True),b[k].splitlines(True)))[:3000])
  raise SystemExit('Room broadcast parity failed')
 print('Room administration broadcasts parity passed')
