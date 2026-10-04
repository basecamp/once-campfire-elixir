"""Small RFC 6455 client for isolated parity tests; no third-party dependency."""
import base64,hashlib,json,os,socket,struct,time
class WebSocket:
 def __init__(self,port,cookies=None):
  self.socket=socket.create_connection(('127.0.0.1',port),timeout=10);self.buffer=b''
  key=base64.b64encode(os.urandom(16)).decode()
  headers={'Host':'campfire.test','Origin':'http://campfire.test','Upgrade':'websocket','Connection':'Upgrade','Sec-WebSocket-Key':key,'Sec-WebSocket-Version':'13','Sec-WebSocket-Protocol':'actioncable-v1-json'}
  if cookies:headers['Cookie']='; '.join(f'{k}={v}' for k,v in cookies.items())
  self.socket.sendall(('GET /cable HTTP/1.1\r\n'+''.join(f'{k}: {v}\r\n' for k,v in headers.items())+'\r\n').encode())
  while b'\r\n\r\n' not in self.buffer:self.buffer+=self.socket.recv(65536)
  header,self.buffer=self.buffer.split(b'\r\n\r\n',1)
  assert header.startswith(b'HTTP/1.1 101'),header
  expected=base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
  assert expected in header
 def _read(self,n):
  while len(self.buffer)<n:
   more=self.socket.recv(65536)
   if not more:raise EOFError('WebSocket closed')
   self.buffer+=more
  result,self.buffer=self.buffer[:n],self.buffer[n:];return result
 def send(self,value,opcode=1):
  data=json.dumps(value,separators=(',',':')).encode() if opcode==1 else value
  length=len(data);mask=os.urandom(4)
  header=bytes([128|opcode,128|min(length,126)])
  if length>=126:header+=struct.pack('!H',length)
  self.socket.sendall(header+mask+bytes(c^mask[i%4] for i,c in enumerate(data)))
 def receive(self):
  deadline=time.monotonic()+10
  while True:
   self.socket.settimeout(max(.001,deadline-time.monotonic()))
   if time.monotonic()>=deadline:raise TimeoutError("No non-ping Cable event within 10 seconds")
   first,second=self._read(2);opcode=first&15;size=second&127
   if size==126:size=struct.unpack('!H',self._read(2))[0]
   if size==127:size=struct.unpack('!Q',self._read(8))[0]
   assert not second&128
   data=self._read(size)
   if opcode==8:raise EOFError('WebSocket close frame')
   if opcode==9:self.send(data,10);continue
   if opcode==1:
    value=json.loads(data)
    if value.get('type')!='ping':return value
 def subscribe(self,params):
  id=json.dumps(params,separators=(',',':'));self.send({'command':'subscribe','identifier':id});result=self.receive();assert result['identifier']==id;return id,result['type']
 def unsubscribe(self,id):self.send({'command':'unsubscribe','identifier':id})
 def perform(self,id,action):self.send({'command':'message','identifier':id,'data':json.dumps({'action':action})})
 def close(self):
  try:self.send(b'',8)
  except OSError:pass
  self.socket.close()
