#!/usr/bin/env python3
"""Smoke-test the separately mounted production release on fixture data."""
import json,re,subprocess
from sessions import ROOT,request,csrf_token
subprocess.run([str(ROOT/'bin/parity-services'),'reset','candidate'],check=True)
config=json.loads(subprocess.check_output(['docker','inspect','campfire-elixir-release'],text=True))[0]
assert all(mount['Destination']=='/data' for mount in config['Mounts'])
assert subprocess.run(['docker','exec','campfire-elixir-release','sh','-c','! command -v ruby && test ! -e /app/reference && test ! -e /rails/app && test ! -e /rails/config && test -e /campfire/lib/campfire-0.1.0/priv/native/campfire_html.so && command -v campfire-vips && command -v ffmpeg && command -v ffprobe'],capture_output=True).returncode==0
c={};status,p,h=request(47072,'/session/new',cookies=c);assert status==200
t=csrf_token(p)
assert request(47072,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':t},c)[0]==302
for path in ['/rooms/104393281','/users/me/profile','/account/edit','/users/me/push_subscriptions','/webmanifest.json','/service-worker.js']:
 status,p,h=request(47072,path,cookies=c);assert status==200,(path,status,p[:100])
 if path.startswith(('/webmanifest','/service-worker')):
  status,q,k=request(47070,path);assert status==200 and p==q
css=json.loads((ROOT/'priv/static/assets/.manifest.json').read_text())['_reset.css']['digested_path']
assert request(47072,'/assets/'+css)[0]==200
(ROOT/'parity/results/release.json').write_text(json.dumps({'passed':True,'scope':['production Mix release','no application source mount','native parser and bundled media executables','login','room/profile/account/push pages','public PWA responses','compiled static assets','no Ruby runtime or Rails reference present']},indent=2)+'\n')
print('Standalone release smoke passed')
