"""Reject missing/blank geometry and mismatched PBR colors; save auditable comparisons."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('directory');a=p.parse_args();root=Path(a.directory)
rows=[];fail=[]
for f in sorted(root.glob('*.json')):
 if f.name in ('summary.json','validation.json'):continue
 j=json.loads(f.read_text());
 if 'engine' not in j:continue
 if j['status']!='passed':fail.append(f.name+': runtime failed');continue
 image=root/(f.stem+'.png')
 ref=root/f"godot-single-{j['count']}-{j['repeat']}-{f.stem.rsplit('-',1)[1]}.png"
 x=np.array(Image.open(image).convert('RGB'));y=np.array(Image.open(ref).convert('RGB'))
 # Magenta is clear color, never a material color. Dark metallic pixels remain geometry.
 m=np.any(x!=[255,0,255],axis=2);n=np.any(y!=[255,0,255],axis=2)
 union=(m|n).sum();common=m&n
 iou=float(common.sum()/union) if union else 0
 rmse=float(np.sqrt(np.mean(((x[common].astype(float)-y[common])/255)**2))) if common.any() else 1
 ok=iou>=.999 and rmse<=.02 and m.sum()>1000
 rows.append(dict(case=f.stem,iou=iou,rgb_rmse=rmse,foreground_pixels=int(m.sum()),passed=bool(ok)))
 if not ok:fail.append(f.stem+': visual mismatch')
result=dict(passed=bool(rows) and not fail,cases=rows,failures=fail)
(root/'validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2));raise SystemExit(0 if result['passed'] else 1)
