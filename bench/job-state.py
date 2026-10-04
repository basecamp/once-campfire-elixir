#!/usr/bin/env python3
"""Record external Resque backlog; Go and Rust own their queues internally."""
import json,socket
try:
 s=socket.create_connection(('127.0.0.1',6379),timeout=1);f=s.makefile('rb');out={}
 for name,cmd,key in [('queued','LLEN','resque:queue:default'),('processed','GET','resque:stat:processed'),('failed','GET','resque:stat:failed')]:
  args=[cmd,key];s.sendall(('*2\r\n'+''.join(f'${len(x)}\r\n{x}\r\n' for x in args)).encode());line=f.readline();kind=line[:1];value=int(line[1:])
  if kind==b'$':value=int(f.read(value+2)[:-2]) if value>=0 else 0
  out[name]=value
 s.close();print(json.dumps(out))
except OSError:print(json.dumps({'external_resque':False,'runtime_queue':'internal_or_absent'}))
