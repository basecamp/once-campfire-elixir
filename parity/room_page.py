#!/usr/bin/env python3
"""Authenticated native room page, composer and permalink live Rails comparison."""
import difflib,json,re,subprocess
from sessions import ROOT,request,normalize
from search_order import canonical_message_order
from transfer_form import canonical_transfer_form

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 c={};_,p,_=request(port,'/session/new',cookies=c);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
 status,_,_=request(port,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},c);assert status==302
 results={}
 for path in ['/rooms/104393281','/rooms/186869642','/rooms/699448329','/rooms/486777696','/rooms/486777696/@933434610','/rooms/486777696/refresh?since=1772467200000','/rooms/486777696/refresh?since=1772304240000','/searches','/searches?q=Coffee','/searches?q=secret-unreachable-needle','/users/me/sidebar','/rooms/486777696/messages/933434610','/rooms/486777696/messages/933434610/edit','/session/transfers/example','/rooms/486777696/involvement','/autocompletable/users?room_id=486777696','/autocompletable/users?filter=da','/autocompletable/users?query=Bot','/autocompletable/users?page=2']:
  status,p,h=request(port,path,cookies=c,headers={'Accept':'text/vnd.turbo-stream.html'} if '/refresh?' in path else None);assert status==200,(side,status,p[:200])
  if re.fullmatch(r'/rooms/[0-9]+',path):assert c['last_room']==path.rsplit('/',1)[1]
  if path.startswith('/session/transfers/'):
   p=canonical_transfer_form(p, side=='candidate')
  results[path]=canonical_message_order(normalize(p)) if path.startswith("/searches?") else normalize(p)
 (ROOT/f'parity/results/room-page.{side}.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
 return results
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for key in a:
  if a[key]!=b[key]:print(key+'\n'+''.join(difflib.unified_diff(a[key].splitlines(True),b[key].splitlines(True)))[:12000])
 passed=a==b
 (ROOT/'parity/results/room-page.json').write_text(json.dumps({'passed':passed,'scope':['closed room scaffold','message list','composer','permalink pagination','last room cookie','sidebar','mention autocomplete','involvement controls']},indent=2)+'\n')
 if not passed:raise SystemExit('Room page differs')
 print('Room page parity passed')
