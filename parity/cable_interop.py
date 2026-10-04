#!/usr/bin/env python3
"""Exercise Rails/Elixir Redis stream fanout and remote disconnect interoperability."""
import json,pathlib,re,subprocess
from sessions import request
from websocket import WebSocket
ROOT=pathlib.Path(__file__).resolve().parents[1]
for side in ['reference','candidate']:subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
connections=[];credentials=[]
for port in [47071,47070]:
 cookies={};status,page,_=request(port,'/session/new',cookies=cookies);assert status==200
 csrf=re.search(r'name="csrf-token" content="([^"]+)"',page)[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':csrf},cookies);assert status==302
 ws=WebSocket(port,cookies);assert ws.receive()=={'type':'welcome'}
 identifier,status=ws.subscribe({'channel':'TypingNotificationsChannel','room_id':486777696});assert status=='confirm_subscription'
 connections.append((ws,identifier));credentials.append((cookies,csrf))
rails,native=connections
native[0].perform(native[1],'start');a=rails[0].receive();b=native[0].receive();assert a['message']==b['message']=={'action':'start','user':{'id':127326141,'name':'David'}}
rails[0].perform(rails[1],'stop');a=rails[0].receive();b=native[0].receive();assert a['message']==b['message']=={'action':'stop','user':{'id':127326141,'name':'David'}}
# Closing membership must disconnect the user's sockets in both runtimes.
cookies,csrf=credentials[1]
status,body,_=request(47070,'/rooms/closeds/486777696','PATCH',{'room[name]':'Watercooler','user_ids[]':149087659,'authenticity_token':csrf},cookies);assert status==302,(status,body)
a=rails[0].receive();b=native[0].receive();assert a==b=={'type':'disconnect','reason':'remote','reconnect':True}
for ws,_ in connections:ws.close()
(ROOT/'parity/results/cable-interop.json').write_text(json.dumps({'passed':True,'flows':['native-to-Rails typing','Rails-to-native typing','native membership revocation disconnects both runtimes']},indent=2)+'\n')
print('Cable Redis interoperability passed')
