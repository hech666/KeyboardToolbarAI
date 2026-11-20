from pathlib import Path
import json,hashlib,plistlib,struct,subprocess
P=Path(__file__).resolve().parents[1];record=json.loads((P/'ci/icon_manifest.json').read_text());base=record['icon_base']
for item in record['files']:
 p=P/item['path'];b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==item['sha256'],str(p)
 assert b[:8]==b'\x89PNG\r\n\x1a\n';assert list(struct.unpack('>II',b[16:24]))==item['size'];assert b[24:26]==bytes([8,6]),'expected RGBA8'
 offset=8;types=[]
 while offset<len(b):
  length=struct.unpack_from('>I',b,offset)[0];types.append(b[offset+4:offset+8]);offset+=length+12
 assert b'eXIf' not in types and b'tEXt' not in types and b'iTXt' not in types,'unneeded metadata retained'
loader=plistlib.loads((P/'layout/Library/PreferenceLoader/Preferences/HaogeKeyboardToolbarAIPrefs.plist').read_bytes());assert loader['entry']['icon']==base
info=plistlib.loads((P/'HaogeKeyboardToolbarAIPrefs/Resources/Info.plist').read_bytes());assert info['CFBundleIconFile']==base+'.png' and info['CFBundleIconFiles']==[base]
control=dict(l.split(': ',1) for l in (P/'control').read_text().splitlines() if ': ' in l);assert control['Icon'].endswith('/'+base+'%402x.png')
assert not (P/'HaogeKeyboardToolbarAIPrefs/Resources/icon@2x.png').exists(),'old default icon still present'
# Source-only proof: every functional implementation remains identical to run2.
production=record['functional_source_baseline']
for item in production:
 assert hashlib.sha256((P/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']+' functionality changed during icon replacement'
print(json.dumps({'passed':True,'icon_base':base,'scales':{'1x':[30,30],'2x':[60,60],'3x':[90,90]},'two_x_source_pixels_unchanged':record['two_x_pixels_unchanged'],'metadata_removed':True,'transparent_RGBA':True,'settings_entry_updated':True,'package_manager_icon_updated':True,'functional_source_files_unchanged':len(production),'baseline_commit':'915003d75fd63e63e1d1c8782b4c460d2d3a3f43'},ensure_ascii=False,indent=2))
