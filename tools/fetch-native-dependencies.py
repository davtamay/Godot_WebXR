"""Fetch the pinned native benchmark libraries and reject any checksum mismatch."""
import hashlib
import json
import urllib.request
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'benchmarks/native-pbr'
manifest=json.loads((root/'dependencies.json').read_text(encoding='utf-8'))
assert manifest['playcanvas']=='2.23.3'
for name,digest in manifest['files_sha256'].items():
    relative=name.replace('\\','/')
    target=(root/relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError('Dependency path escapes benchmark directory')
    if target.exists():
        data=target.read_bytes()
    else:
        suffix=relative.removeprefix('playcanvas/lib/')
        url=manifest['source'] if suffix=='playcanvas.mjs' else 'https://raw.githubusercontent.com/playcanvas/engine/v2.23.3/examples/assets/wasm/'+suffix
        with urllib.request.urlopen(url,timeout=60) as response:
            data=response.read()
    if hashlib.sha256(data).hexdigest()!=digest:
        raise ValueError('Dependency checksum mismatch: '+relative)
    if not target.exists():
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
    print(relative,'verified')
