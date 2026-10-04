// Real frontend smoke against disposable fixture services using Chromium's CDP.
import fs from 'node:fs/promises';
const port = Number(process.argv[2] || 47070);
const target = await (await fetch('http://127.0.0.1:47080/json/new?about:blank', {method:'PUT'})).json();
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve,reject) => { socket.onopen=resolve; socket.onerror=reject; });
let next=1;
const pending=new Map(), exceptions=[], responses=[];
socket.onmessage=event=>{
 const msg=JSON.parse(event.data);
 if(msg.id){ const p=pending.get(msg.id); if(p){pending.delete(msg.id);clearTimeout(p.timer);msg.error?p.reject(new Error(JSON.stringify(msg.error))):p.resolve(msg.result);} }
 else if(msg.method==='Runtime.exceptionThrown')exceptions.push(msg.params.exceptionDetails);
 else if(msg.method==='Network.responseReceived')responses.push({url:msg.params.response.url,status:msg.params.response.status});
};
function call(method,params={}){return new Promise((resolve,reject)=>{const id=next++;const timer=setTimeout(()=>reject(new Error('CDP timeout '+method)),15000);pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function until(expression){for(let i=0;i<100;i++){if(await evaluate("Boolean("+expression+")"))return;await new Promise(r=>setTimeout(r,100));}throw new Error('Browser condition failed: '+expression);}
try {
 await call('Page.enable');await call('Runtime.enable');await call('Network.enable');await call('Network.setCacheDisabled',{cacheDisabled:true});
 await call('Page.navigate',{url:`http://campfire.test:${port}/session/new`});
 await until('document.querySelector("input[name=email_address]") && window.Turbo');
 await evaluate(`document.querySelector('input[name=email_address]').value='david@37signals.com';document.querySelector('input[name=password]').value='secret123456';document.querySelector('input[name=email_address]').form.requestSubmit()`);
 await until('document.querySelector("#composer") && document.querySelector("lexxy-editor") && document.querySelector("#shared_rooms")');
 const room=await evaluate('document.querySelector("meta[name=current-room-id]").content');
 await evaluate(`document.querySelector('#composer lexxy-editor').value='<p>Browser native parity needle</p>';document.querySelector('#composer').requestSubmit(document.querySelector('#composer button[name=send]'))`);
 await until(`Array.from(document.querySelectorAll('#messages_rooms_open_${room} .message')).some(e=>e.textContent.includes('Browser native parity needle'))`);
 const message=await evaluate(`Array.from(document.querySelectorAll('.message')).find(e=>e.textContent.includes('Browser native parity needle')).dataset.messageId`);
 await evaluate(`document.querySelector('[data-message-id="${message}"] a.message__edit-btn').click()`);
 await until(`document.querySelector('[data-message-id="${message}"] lexxy-editor[aria-label="Edit message"]')`);
 await evaluate(`const editor=document.querySelector('[data-message-id="${message}"] lexxy-editor');editor.value='<p>Browser edit parity needle</p>';editor.closest('form').requestSubmit()`);
 await until(`Array.from(document.querySelectorAll('[data-message-id="${message}"] [data-reply-target=body]')).some(e=>e.textContent.includes('Browser edit parity needle'))`);
 await evaluate(`document.querySelector('[data-message-id="${message}"] form[action="/messages/${message}/boosts"] button').click()`);
 await until(`document.querySelector('[data-message-id="${message}"] .boost-item')`);
 const screenshot=await call('Page.captureScreenshot',{format:'png'});await fs.writeFile(`parity/results/browser-${port}.png`,Buffer.from(screenshot.data,'base64'));
 const result={passed:exceptions.length===0 && !responses.some(r=>r.status>=400),flows:['real Chromium login','sidebar frame loading','native composer submit','Turbo message edit','quick boost'],room,message,exceptions,responses};
 await fs.writeFile(`parity/results/browser-${port}.json`,JSON.stringify(result,null,2)+'\n');
 if(exceptions.length || responses.some(r=>r.status>=400))throw new Error('Browser console/network failures: '+JSON.stringify({exceptions,responses:responses.filter(r=>r.status>=400)}));
 console.log(JSON.stringify({passed:true,room,message,requests:responses.length}));
} catch(error) { await fs.writeFile(`parity/results/browser-${port}.json`,JSON.stringify({passed:false,error:String(error),exceptions,responses},null,2)+'\n');throw error; } finally { await fetch(`http://127.0.0.1:47080/json/close/${target.id}`);socket.close(); }
