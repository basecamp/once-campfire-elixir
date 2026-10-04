#!/usr/bin/env python3
"""Reject incomplete application measurements and preserve preflight response evidence."""
import gzip,hashlib,http.client,importlib.machinery,json,pathlib,re,sqlite3,sys,urllib.parse
ROOT=pathlib.Path(__file__).resolve().parents[1]
module=importlib.machinery.SourceFileLoader('verification',str(ROOT/'bin/verify-parity')).load_module()
if sys.argv[1]=='digest':print(module.identity());raise SystemExit
if sys.argv[1]=='ledger':
 ledger=json.loads((ROOT/'plans/contracts.json').read_text());v=json.loads((ROOT/'parity/results/verification.json').read_text())
 assert ledger['complete'] and all(x['status']=='verified' for x in ledger['contracts']), 'Application parity ledger incomplete'
 assert v['passed'] and v['complete_run'] and v['source_unchanged'] and v['source_digest']==module.identity(),'Final complete verification required for current application'
 raise SystemExit
_,_,base,cookie,room,before,avatar,css,dbpath,out=sys.argv
uri=urllib.parse.urlsplit(base);result={}
paths={'room_show':f'/rooms/{room}','messages_page':f'/rooms/{room}/messages?before={before}','sidebar':'/users/me/sidebar','search':'/searches?q=coffee','avatar':f'/users/{avatar}/avatar','static_css':css,'up':'/up'}
for name,path in paths.items():
 c=http.client.HTTPConnection(uri.hostname,uri.port,timeout=30);c.request('GET',path,headers={'Cookie':cookie,'Accept-Encoding':'gzip'});r=c.getresponse();data=r.read();h=dict((k.lower(),v) for k,v in r.getheaders());c.close();assert r.status==200,(name,r.status)
 body=gzip.decompress(data) if h.get('content-encoding')=='gzip' else data
 assert body,(name,'empty response')
 if name in ['room_show','messages_page','search']:assert re.search(rb'data-message-id="\d+"',body),(name,'populated message response required')
 if name=='sidebar':assert b'shared_rooms' in body and room.encode() in body
 if name=='avatar':assert h['content-type'].startswith('image/') and len(body)>100
 if name=='static_css':assert h['content-type'].startswith('text/css') and b'{' in body
 if name=='up':assert b'background-color: green' in body
 result[name]={'status':r.status,'type':h.get('content-type'),'encoding':h.get('content-encoding'),'wire_bytes':len(data),'body_bytes':len(body),'body_sha256':hashlib.sha256(body).hexdigest()}
with sqlite3.connect(dbpath) as db:
 assert db.execute('SELECT COUNT(*) FROM messages WHERE room_id=?',[room]).fetchone()[0]>50
 assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
pathlib.Path(out).write_text(json.dumps({'passed':True,'responses':result,'populated_fixture_and_integrity':True},indent=2)+'\n')
