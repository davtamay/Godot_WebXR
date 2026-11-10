"""Reject missing geometry, draw-count mismatch, source ambiguity and visual drift."""
import argparse,json
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('results',type=Path);a=p.parse_args()
summary=json.loads((a.results/'summary.json').read_text());assert summary.get('finished'),'run incomplete'
results=[]
for entry in summary['cases']:
 d=json.loads((a.results/(entry['id']+'.json')).read_text());assert d['status']=='passed',(d['id'],d.get('failure'))
 assert not d['errors'] and d['frames'],d['id']
 assert all(f['draws']==d['count'] for f in d['frames']),(d['id'],'draws')
 assert d['metrics']['cpuMs']['samples']>0 and d['metrics']['gpuMs']['samples']>0,(d['id'],'timing unavailable')
 if d['engine'].startswith('godot'):
  assert d['metadata']['provenance']['identity_complete'],d['id']
  expected=d['engine']=='godot-threaded'
  assert d['hosting']=={'isolated':expected,'shared':expected},d['id']
 image=Image.open(a.results/(d['id']+'.png')).convert('RGB');assert image.size==(1280,720)
 # White-geometry masks: reject blank or grossly overdrawn images before IoU.
 mask=bytes(1 if min(pixel)>127 else 0 for pixel in image.getdata());coverage=sum(mask)/len(mask)
 assert .01<coverage<.8,(d['id'],coverage)
 reference=Image.open(a.results/f"godot-single-{d['count']}-1.png").convert('RGB')
 reference=bytes(1 if min(pixel)>127 else 0 for pixel in reference.getdata())
 union=sum(bool(x or y) for x,y in zip(mask,reference));intersection=sum(bool(x and y) for x,y in zip(mask,reference));iou=intersection/union
 assert iou>=.999,(d['id'],iou)
 results.append({'id':d['id'],'coverage':coverage,'geometry_iou':iou})
(a.results/'verification.json').write_text(json.dumps({'passed':True,'cases':results},indent=2))
print(f'PASS {len(results)} cases: geometry, draw counts, CPU/GPU samples, hosting and provenance')
