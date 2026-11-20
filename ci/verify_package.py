from pathlib import Path
import sys,struct,hashlib,tarfile,io,json,subprocess,plistlib,os

def ar_members(b):
 assert b[:8]==b'!<arch>\n';o=8;out={}
 while o+60<=len(b):
  h=b[o:o+60];assert h[58:60]==b'`\n';n=h[:16].decode().strip().rstrip('/');s=int(h[48:58]);o+=60;out[n]=b[o:o+s];o+=s+(s&1)
 return out

def tar_members(name,b):
 if name.endswith('.zst'):b=subprocess.check_output(['zstd','-dc'],input=b)
 with tarfile.open(fileobj=io.BytesIO(b),mode='r:*') as tf:
  return {m.name.lstrip('./'):tf.extractfile(m).read() for m in tf if m.isfile()}

def code_signature(b):
 assert struct.unpack_from('<I',b,0)[0]==0xfeedfacf
 count=struct.unpack_from('<I',b,16)[0];o=32;signature=None;deps=[]
 for _ in range(count):
  cmd,size=struct.unpack_from('<II',b,o);assert size>=8
  if cmd==0x1d:
   off,length=struct.unpack_from('<II',b,o+8);signature=b[off:off+length]
  if cmd in (0xc,0x18,0x80000018,0x8000001f):
   no=struct.unpack_from('<I',b,o+8)[0];deps.append(b[o+no:o+size].split(b'\0')[0].decode())
  o+=size
 assert signature and len(signature)>=12,'missing LC_CODE_SIGNATURE'
 magic,length,n=struct.unpack_from('>III',signature,0);assert magic==0xfade0cc0 and length<=len(signature)
 directories=[]
 for i in range(n):
  slot,off=struct.unpack_from('>II',signature,12+i*8)
  if struct.unpack_from('>I',signature,off)[0]!=0xfade0c02:continue
  cd=signature[off:];magic,cdlen,version,flags,hashoff,identoff,nspecial,ncode,limit=struct.unpack_from('>9I',cd,0);cd=cd[:cdlen]
  hs,ht,platform,pages=struct.unpack_from('>4B',cd,36);algorithm={1:'sha1',2:'sha256',3:'sha256',4:'sha384'}[ht]
  if version>=0x20100:assert struct.unpack_from('>I',cd,44)[0]==0,'scatter CodeDirectory unsupported'
  if version>=0x20300:
   limit64=struct.unpack_from('>Q',cd,56)[0]
   if limit==0xffffffff:limit=limit64
  pagesize=1<<pages if pages else limit
  assert limit<=len(b) and ncode==(limit+pagesize-1)//pagesize
  assert hashoff+ncode*hs<=len(cd)
  for j in range(ncode):
   actual=hashlib.new(algorithm,b[j*pagesize:min((j+1)*pagesize,limit)]).digest()[:hs]
   assert actual==cd[hashoff+j*hs:hashoff+(j+1)*hs],f'CodeDirectory page mismatch {j}'
  directories.append(dict(slot=slot,hash_type=ht,code_pages=ncode,verified_pages=ncode))
 assert directories,'no CodeDirectory'
 return {'code_directories':directories,'dependencies':deps}

def macho(b):
 magic=struct.unpack_from('>I',b,0)[0];slices=[]
 if magic in (0xcafebabe,0xcafebabf):
  n=struct.unpack_from('>I',b,4)[0];assert 1<=n<=8
  for i in range(n):
   x=8+i*(32 if magic==0xcafebabf else 20)
   if magic==0xcafebabf:cpu,sub,off,size,align,reserved=struct.unpack_from('>IIQQII',b,x)
   else:cpu,sub,off,size,align=struct.unpack_from('>IIIII',b,x)
   slices.append((cpu,sub,b[off:off+size]))
 else:
  cpu,sub=struct.unpack_from('<II',b,4);slices=[(cpu,sub,b)]
 result={}
 for cpu,sub,thin in slices:
  assert cpu==0x100000c and struct.unpack_from('<II',thin,4)==(cpu,sub)
  arch={0:'arm64',2:'arm64e'}.get(sub&0xffffff);assert arch
  assert arch not in result;result[arch]=code_signature(thin)
 assert set(result)=={'arm64','arm64e'},'expected genuine arm64 and arm64e slices'
 return result

def verify(path,scheme):
 deb=path.read_bytes();members=ar_members(deb)
 controlname=next(n for n in members if n.startswith('control.tar'));dataname=next(n for n in members if n.startswith('data.tar'))
 control=tar_members(controlname,members[controlname])['control'].decode();payload=tar_members(dataname,members[dataname]);fields=dict(l.split(': ',1) for l in control.splitlines() if ': ' in l)
 assert fields['Package']=='com.haoge.keyboardtoolbarai'
 if scheme=='roothide':assert fields['Architecture']=='iphoneos-arm64e' and not any(n.startswith('var/jb/') for n in payload)
 targets={}
 for label,suffix in [('main','HaogeKeyboardToolbarAI.dylib'),('prefs','HaogeKeyboardToolbarAIPrefs.bundle/HaogeKeyboardToolbarAIPrefs')]:
  candidates=[(n,b) for n,b in payload.items() if n.endswith(suffix)];assert len(candidates)==1,(label,len(candidates));name,b=candidates[0];targets[label]={'path':name,'sha256':hashlib.sha256(b).hexdigest(),'slices':macho(b)}
 for name,b in payload.items():
  if name.endswith('HaogeKeyboardToolbarAI.plist'):
   root=plistlib.loads(b);assert 'com.apple.UIKit' in root['Filter']['Bundles']
 assert any('PreferenceLoader/Preferences/HaogeKeyboardToolbarAIPrefs.plist' in n for n in payload)
 return dict(package=fields,scheme=scheme,deb=path.name,bytes=len(deb),sha256=hashlib.sha256(deb).hexdigest(),binaries=targets,payload_files=len(payload),commit=os.environ.get('GITHUB_SHA',''),passed=True)
if __name__=='__main__':
 path=Path(sys.argv[1]);scheme=sys.argv[2];output=Path(sys.argv[3]);report=verify(path,scheme);output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
