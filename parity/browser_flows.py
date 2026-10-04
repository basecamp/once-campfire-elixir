#!/usr/bin/env python3
"""Actual Chromium/Turbo/Stimulus flows in a disposable browser context per runtime."""
import base64,hashlib,json,os,re,socket,sqlite3,subprocess,time,urllib.request,urllib.parse
from sessions import ROOT
from websocket import WebSocket
PORT=47080
class CDP(WebSocket):
 def __init__(self,url):
  uri=urllib.parse.urlsplit(url);self.socket=socket.create_connection((uri.hostname,uri.port),timeout=10);self.buffer=b'';self.sequence=0;self.events=[]
  key=base64.b64encode(os.urandom(16)).decode();self.socket.sendall(f'GET {uri.path} HTTP/1.1\r\nHost: 127.0.0.1:{PORT}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n'.encode())
  while b'\r\n\r\n' not in self.buffer:self.buffer+=self.socket.recv(65536)
  head,self.buffer=self.buffer.split(b'\r\n\r\n',1);assert head.startswith(b'HTTP/1.1 101'),head
  assert base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()) in head
 def call(self,method,params=None):
  self.sequence+=1;seq=self.sequence;self.send({'id':seq,'method':method,'params':params or {}})
  while True:
   value=self.receive()
   if value.get('id')!=seq:self.events.append(value)
   if value.get('id')==seq:
    assert 'error' not in value,(method,value)
    return value.get('result',{})
 def evaluate(self,expression):
  r=self.call('Runtime.evaluate',{'expression':expression,'returnByValue':True,'awaitPromise':True});assert 'exceptionDetails' not in r,r
  return r.get('result',{}).get('value')
 def wait(self,expression,timeout=20):
  deadline=time.monotonic()+timeout
  while time.monotonic()<deadline:
   value=self.evaluate(expression)
   if value:return value
   time.sleep(.1)
  raise AssertionError('Browser condition timed out: '+expression+' at '+str(self.evaluate('location.href')))
 def navigate(self,url):
  self.call('Page.navigate',{'url':url});self.wait('document.readyState==="complete" && location.href==='+json.dumps(url));self.wait('!document.querySelector("lexxy-editor") || !!document.querySelector("lexxy-editor").querySelector("[contenteditable]")');time.sleep(.3)

def info(path):return json.load(urllib.request.urlopen(f'http://127.0.0.1:{PORT}'+path,timeout=5))
def run(side,port,browser):
 env={**os.environ,'CAMPFIRE_PARITY_TICK':'1'};subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True,env=env)
 context=browser.call('Target.createBrowserContext')['browserContextId'];target=browser.call('Target.createTarget',{'url':'about:blank','browserContextId':context})['targetId'];page=CDP(next(t['webSocketDebuggerUrl'] for t in info('/json/list') if t['id']==target));base=f'http://campfire.test:{port}';steps=[]
 def record(name):steps.append({'step':name,'path':page.evaluate('location.pathname'),'title':page.evaluate('document.title')})
 try:
  page.call('Page.enable');page.call('Runtime.enable');page.navigate(base+'/session/new')
  page.evaluate('document.querySelector("#email_address").value="david@37signals.com";document.querySelector("#password").value="secret123456";document.querySelector("#password").form.requestSubmit()')
  page.wait('!location.pathname.startsWith("/session") && !!document.querySelector("meta[name=current-user-id]")');record('login')
  page.navigate(base+'/rooms/opens/new');page.evaluate('document.querySelector("[name=\\"room[name]\\"]").value="Browser room Ω";document.querySelector("[name=\\"room[name]\\"]").form.requestSubmit()')
  room=page.wait('location.pathname.match(/^\\/rooms\\/(\\d+)$/)?.[1] && document.querySelector("lexxy-editor") && document.querySelector("lexxy-editor").querySelector("[contenteditable]") && location.pathname.match(/^\\/rooms\\/(\\d+)$/)[1]');record('create_room')
  page.evaluate('document.querySelector("lexxy-editor").value="<p>Chromium message Ω</p>";document.querySelector("#composer button[name=send]").click()')
  page.wait('!![...document.querySelectorAll(".message")].find(x=>x.innerText.includes("Chromium message Ω"))');record('composer')
  page.evaluate('window.parityUploads=[];window.XMLHttpRequest=new Proxy(window.XMLHttpRequest,{construct(target,args){const r=Reflect.construct(target,args);r.addEventListener("loadend",()=>window.parityUploads.push({status:r.status,body:r.responseText}));return r}})')
  root=page.call('DOM.getDocument')['root']['nodeId'];node=page.call('DOM.querySelector',{'nodeId':root,'selector':'#composer input[type=file]'})['nodeId'];page.call('DOM.setFileInputFiles',{'nodeId':node,'files':[str(ROOT/'reference/test/fixtures/files/moon.jpg')]});page.wait('document.querySelector("[data-composer-target=fileList]").children.length > 0');page.evaluate('document.querySelector("#composer button[name=send]").click()')
  dbpath=ROOT/'var'/('rails/db' if side=='reference' else 'candidate')/'production.sqlite3'
  for _ in range(200):
   with sqlite3.connect(dbpath) as db:
    count=db.execute("SELECT count(*) FROM messages m JOIN active_storage_attachments a ON a.record_id=m.id AND a.record_type='Message' JOIN active_storage_blobs b ON b.id=a.blob_id WHERE m.room_id=? AND b.filename='moon.jpg'",[int(room)]).fetchone()[0]
   if count:break
   time.sleep(.1)
  assert count==1,(side,'composer upload was not persisted')
  page.wait('[...document.querySelectorAll("img.message__attachment")].some(img=>img.src.includes("/moon.jpg"))');record('composer_file_upload')
  page.navigate(base+f'/rooms/opens/{room}/edit');page.evaluate('document.querySelector("[name=\\"room[name]\\"]").value="Browser renamed Ω";document.querySelector("[name=\\"room[name]\\"]").form.requestSubmit()');page.wait('location.pathname==='+json.dumps('/rooms/'+room)+' && document.body.innerText.includes("Browser renamed Ω")');record('edit_room')
  page.navigate(base+'/users/me/profile');page.evaluate('document.querySelector("#user_name").value="Browser profile Ω";document.querySelector("#user_name").form.requestSubmit()');page.wait('document.title==="Browser profile Ω"');record('profile')
  root=page.call('DOM.getDocument')['root']['nodeId'];node=page.call('DOM.querySelector',{'nodeId':root,'selector':'input[type=file][name="user[avatar]"]'})['nodeId'];page.call('DOM.setFileInputFiles',{'nodeId':node,'files':[str(ROOT/'reference/test/fixtures/files/moon.jpg')]});page.wait('document.body.innerText.includes("It may take up to 30 minutes")');record('avatar_upload')
  page.navigate(base+'/account/edit');page.evaluate('document.querySelector("[name=\\"account[name]\\"]").value="Chromium account Ω";document.querySelector("[name=\\"account[name]\\"]").form.requestSubmit()');page.wait('document.querySelector("[name=\\"account[name]\\"]")?.value==="Chromium account Ω" && !document.documentElement.hasAttribute("data-turbo-preview")');time.sleep(.4);record('account')
  page.navigate(base+'/users/me/profile');page.evaluate('document.querySelector("form[action$=\\"/session\\"]").requestSubmit()');page.wait('location.pathname==="/session/new"');record('logout')
  image=page.call('Page.captureScreenshot',{'format':'png'})['data'];(ROOT/f'parity/results/browser-flows.{side}.png').write_bytes(base64.b64decode(image))
  return steps
 except Exception:
  try:(ROOT/f'var/browser-debug.{side}.html').write_text(page.evaluate('document.documentElement.outerHTML'))
  except Exception:pass
  try:(ROOT/f'var/browser-uploads.{side}.json').write_text(json.dumps(page.evaluate('window.parityUploads'),indent=2))
  except Exception:pass
  (ROOT/f'var/browser-debug.{side}.json').write_text(json.dumps(page.events,indent=2))
  raise
 finally:page.close();browser.call('Target.disposeBrowserContext',{'browserContextId':context})
if __name__=='__main__':
 browser=CDP(info('/json/version')['webSocketDebuggerUrl'])
 try:a=run('reference',47071,browser);b=run('candidate',47070,browser)
 finally:browser.close()
 for side,r in [('reference',a),('candidate',b)]: (ROOT/f'parity/results/browser-flows.{side}.json').write_text(json.dumps(r,indent=2)+'\n')
 # Created IDs are compared by their role; titles and the actual UI outcomes match.
 for r in [a,b]:
  for step in r:step['path']=re.sub(r'/rooms/(?:opens/)?\d+', '/rooms/<created>',step['path'])
 assert a==b,(a,b)
 (ROOT/'parity/results/browser-flows.json').write_text(json.dumps({'passed':True,'browser':info('/json/version')['Browser'],'scope':[s['step'] for s in a],'method':'actual Chromium with isolated contexts, pinned frontend, Turbo/Stimulus form submissions and file input upload'},indent=2)+'\n')
 print('Chromium administration/profile/upload/logout parity passed')
