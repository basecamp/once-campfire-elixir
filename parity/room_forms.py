#!/usr/bin/env python3
"""Room settings, participant controls and administration form parity."""
import json,re,subprocess,difflib,sqlite3
from sessions import ROOT,request,normalize

def run(side,port):
 subprocess.run([str(ROOT/'bin/parity-services'),'reset',side],check=True)
 pages={}
 for email in ['david@37signals.com','kevin@37signals.com']:
  cookies={};_,p,_=request(port,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
  assert request(port,'/session','POST',{'email_address':email,'password':'secret123456','authenticity_token':token},cookies)[0]==302
  paths=['/rooms/opens/new','/rooms/closeds/new','/rooms/directs/new']
  roomids=[104393281,486777696,201306877,699448326] if email=='david@37signals.com' else [201306877,699448326]
  paths += [f'/rooms/{kind}s/{id}/edit' for id in roomids for kind in ['open','closed']]
  paths += [f'/rooms/directs/{id}/edit' for id in ([186869642,699448325] if email=='david@37signals.com' else [340026324,699448325,699448329])]
  for path in paths:
   for frame in [False,True]:
    status,p,h=request(port,path,cookies=cookies,headers={'Turbo-Frame':'direct_rooms_control'} if frame else {})
    # Dave is not a member of Kevin's Quiet Corner. Redirects remain part of scope.
    pages[email+path+str(frame)]={'status':status,'html':normalize(p),'location':h.get('location')}
  for path in ['/rooms/opens/186869642/edit','/rooms/closeds/186869642/edit','/rooms/directs/201306877/edit','/rooms/opens/9999999999/edit']:
   status,p,h=request(port,path,cookies=cookies);assert status==302
   pages[email+path]={'status':status,'html':p,'location':h.get('location')}
  status,p,_=request(port,'/account/edit',cookies=cookies);assert status==200;pages[email+'inaccessible_notice']=normalize(p)
  # Submit the real form token to update a room the viewer can administer.
  id=201306877 if email=='david@37signals.com' else 699448326
  status,p,_=request(port,f'/rooms/closeds/{id}/edit',cookies=cookies);assert status==200
  token=re.search(r'name="authenticity_token" value="([^"]+)"',p)[1]
  params={'room[name]':'Room "<&> Ω','user_ids[]':127326141 if email=='david@37signals.com' else 712064548,'authenticity_token':token}
  assert request(port,f'/rooms/closeds/{id}','PATCH',params,cookies)[0]==302
  status,p,_=request(port,f'/rooms/closeds/{id}/edit',cookies=cookies);assert status==200;pages[email+'updated']=normalize(p)
 assert request(port,'/rooms/opens/new',cookies={})[0]==302
 return pages
if __name__=='__main__':
 a=run('reference',47071);b=run('candidate',47070)
 for side,result in [('reference',a),('candidate',b)]:
  (ROOT/f'parity/results/room-forms.{side}.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 passed=a==b
 (ROOT/'parity/results/room-forms.json').write_text(json.dumps({'passed':passed,'scope':['open/closed/direct new and edit forms','type conversion views','administrator/creator/readonly permissions','selected and unselected membership controls','one-person/group direct settings','CSRF form submission','escaped room name','inaccessible room flash','full and Turbo frame layouts']},indent=2)+'\n')
 if not passed:
  for key in a:
   if a[key]!=b[key]:print(key+': '+''.join(difflib.unified_diff(a[key]['html'].splitlines(True) if isinstance(a[key],dict) else a[key].splitlines(True),b[key]['html'].splitlines(True) if isinstance(b[key],dict) else b[key].splitlines(True)))[:3000])
  raise SystemExit('Room form parity failed')
 print('Room form parity passed')
