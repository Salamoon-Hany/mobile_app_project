"""Refresh existing Flutter Web assets after a source build (standard message codec)."""
from pathlib import Path
import argparse,base64,json,struct,shutil,re,hashlib

def length(n):
    if n<254:return bytes([n])
    if n<=65535:return b'\xfe'+struct.pack('<H',n)
    return b'\xff'+struct.pack('<I',n)
def codec(value):
    if isinstance(value,str):
        b=value.encode();return b'\x07'+length(len(b))+b
    if isinstance(value,list):return b'\x0c'+length(len(value))+b''.join(codec(x) for x in value)
    if isinstance(value,dict):return b'\x0d'+length(len(value))+b''.join(codec(k)+codec(v) for k,v in value.items())
    raise TypeError(value)

def refresh(source,destination):
    manifest=json.loads((destination/'assets/AssetManifest.json').read_text())
    for file in (source/'Pics & Icons').iterdir():
        if not file.is_file():continue
        key='Pics & Icons/'+file.name
        manifest[key]=[key]
        shutil.copy2(file,destination/'assets/Pics%20&%20Icons'/file.name)
    (destination/'assets/AssetManifest.json').write_text(json.dumps(manifest,separators=(',',':')))
    binary=codec({k:[{'asset':p} for p in paths] for k,paths in manifest.items()})
    (destination/'assets/AssetManifest.bin').write_bytes(binary)
    (destination/'assets/AssetManifest.bin.json').write_text(json.dumps(base64.b64encode(binary).decode()))
    for name in ['sanad-intro.css','sanad-intro.js','sanad-launch-state.mjs']:
        shutil.copy2(source/'web'/name,destination/name)
    (destination/'index.html').write_text((source/'web/index.html').read_text().replace('$FLUTTER_BASE_HREF','/'))
    worker=destination/'flutter_service_worker.js'
    text=worker.read_text();m=re.search(r'const RESOURCES = (\{.*?\});',text,re.S)
    resources=json.loads(m[1])
    for key in list(resources):
        p=destination/key.replace('%2520','%20')
        if key=='/':p=destination/'index.html'
        if p.is_file():resources[key]=hashlib.md5(p.read_bytes()).hexdigest()
    for file in (source/'Pics & Icons').glob('service-*'):
        resources['assets/Pics%2520&%2520Icons/'+file.name]=hashlib.md5(file.read_bytes()).hexdigest()
    worker.write_text(text[:m.start(1)]+json.dumps(resources,indent=2)+text[m.end(1):])
    print('Flutter asset manifests and service worker refreshed.')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('destination',type=Path);a=p.parse_args();refresh(Path(__file__).resolve().parent.parent,a.destination.resolve())
