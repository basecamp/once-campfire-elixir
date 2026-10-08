#!/usr/bin/env python3
"""Live authenticated message HTML, JSON and Turbo response comparison."""
import difflib,json,re,subprocess
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 cookies={}
 status,page,_=request(port,'/session/new',cookies=cookies);assert status==200
 token=(re.search(r'name="authenticity_token" value="([^"]+)"',page) or ("", ""))[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies);assert status==302
 results={}
 for room in [486777696]:
  path=f'/rooms/{room}/messages'
  status,body,headers=request(port,path,cookies=cookies);assert status==200,(side,status,body)
  results['index']={'status':status,'body':normalize(body),'content_type':headers['content-type']}
  _,page,_=request(port,'/session/new',cookies=cookies)
  token=(re.search(r'name="csrf-token" content="([^"]+)"',page) or ("", ""))[1]
  status,body,headers=request(port,path,'POST',{'authenticity_token':token,'message[body]':'<div>Hello native world</div>','message[client_message_id]':'parity-message-client'},cookies,headers={'Accept':'text/vnd.turbo-stream.html'})
  results['create']={'status':status,'body':normalize(body),'content_type':headers['content-type']}
 (ROOT/f'parity/results/messages.{side}.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for key in a:
  if a[key]!=b[key]:
   print(key, a[key]['status'],b[key]['status'])
   print(''.join(difflib.unified_diff(a[key]['body'].splitlines(True),b[key]['body'].splitlines(True)))[:12000])
 passed=a==b
 (ROOT/'parity/results/messages.json').write_text(json.dumps({'passed':passed,'scope':['message index HTML','text create Turbo response']},indent=2)+'\n')
 if not passed:raise SystemExit('Message parity failed')
 print('Message parity passed')
