#!/usr/bin/env python3
"""Capture pinned view branch rendering for native EEx translation."""
import sys,re,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parity'))
from sessions import ROOT,request
cases={
 'chrome_mac':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36',
 'chrome_windows':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36',
 'chrome_android':'Mozilla/5.0 (Linux; Android 14; Pixel) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Mobile Safari/537.36',
 'chrome_ios':'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/131.0 Mobile/15E148 Safari/604.1',
 'firefox_mac':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:131.0) Gecko/20100101 Firefox/131.0',
 'firefox_windows':'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0',
 'firefox_android':'Mozilla/5.0 (Android 14; Mobile; rv:131.0) Gecko/131.0 Firefox/131.0',
 'edge_mac':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36 Edge/131.0',
 'edge_windows':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36 Edge/131.0',
 'safari_mac':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
 'safari_ios':'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
 'generic':'Something/1.0'
}
if __name__=='__main__':
 cookies={};_,p,_=request(47071,'/session/new',cookies=cookies);token=re.search(r'name="csrf-token" content="([^"]+)"',p)[1]
 assert request(47071,'/session','POST',{'email_address':'david@37signals.com','password':'secret123456','authenticity_token':token},cookies)[0]==302
 outputs={}
 for name,ua in cases.items():
  status,room,_=request(47071,'/rooms/486777696',cookies=cookies,headers={'User-Agent':ua});assert status in [200,500],(name,status,room[:80])
  if status==500:
   outputs[name]={'user_agent':ua,'error':500};continue
  status,profile,_=request(47071,'/users/me/profile',cookies=cookies,headers={'User-Agent':ua});assert status==200
  block=room.split('<div class="txt-align-start margin-block-start">\n',1)[1].split('          </div>',1)[0]
  install=profile.split('style="view-transition-name: avatar-127326141">\n',1)[1].split('  <div class="align-center center avatar__form',1)[0]
  outputs[name]={'user_agent':ua,'room':block,'profile':install}
 (ROOT/'vectors/pwa-views.json').write_text(json.dumps(outputs,indent=2,ensure_ascii=False)+'\n')
 print('Captured PWA branches:',len(outputs))
