"""Validate and summarize paired CPU-optimization runs against preserved baseline images."""
from pathlib import Path
import json,statistics,argparse,random,csv
import numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('root');p.add_argument('references');a=p.parse_args();root=Path(a.root);refs=Path(a.references)
plan=json.loads((root/'plan.json').read_text());cases=[];visual=[]
for task in plan['cases']:
 d=root/f"n{task['count']}-r{task['repeat']}-{task['profile']}-{task['build']}";summary=json.loads((d/'summary.json').read_text());assert summary.get('finished')
 for stub in summary['cases']:
  c=json.loads((d/(stub['id']+'.json')).read_text());assert c['status']=='passed',c.get('failure');assert c['queue']['submissions']>0
  if task['profile']=='on':assert len(c['queue']['samples'])==c['queue']['submissions'] and len({x['ordinal'] for x in c['queue']['samples']})==c['queue']['submissions']
  assert c['frameCallbackTimes'] and abs(len(c['frameCallbackTimes'])-len(c['frames']))<=1
  expected='3130ee0622' if task['build']=='candidate' else '2f3fd8aa21';assert c['metadata']['provenance']['engine_source']['revision'].startswith(expected)
  image=np.array(Image.open(d/(stub['id']+'.png')));reference=np.array(Image.open(refs/f"godot-single-{task['count']}-1-off.png"));same=bool(np.array_equal(image,reference));assert same,str(d)+' image differs'
  visual.append(dict(case=str(d.name)+'/'+stub['id'],pixel_identical=same))
  cases.append(dict(count=task['count'],repeat=task['repeat'],profile=task['profile'],build=task['build'],engine=c['engine'],cpu=c['metrics']['rendererCpuMsPerFrame'],callback=statistics.mean(c['frameCallbackTimes']),gpu=c['metrics']['gpuCommandMsPerFrame']))
rows=[];rng=random.Random(1337)
for count in sorted({x['count'] for x in cases}):
 for engine in ['godot-single','godot-threaded']:
  for metric,profile in [('cpu','off'),('callback','off'),('gpu','on')]:
   base={x['repeat']:x[metric] for x in cases if x['count']==count and x['engine']==engine and x['profile']==profile and x['build']=='baseline'}
   cand={x['repeat']:x[metric] for x in cases if x['count']==count and x['engine']==engine and x['profile']==profile and x['build']=='candidate'}
   if not base:continue
   delta=[base[i]-cand[i] for i in sorted(base)];boots=sorted(statistics.mean(rng.choices(delta,k=len(delta))) for _ in range(10000));lo,hi=boots[250],boots[9749]
   rows.append(dict(count=count,engine=engine,metric=metric,baseline_ms=statistics.median(base.values()),candidate_ms=statistics.median(cand.values()),paired_mean_saving_ms=statistics.mean(delta),ci95_low_ms=lo,ci95_high_ms=hi,rounds=len(delta)))
result=dict(passed=True,runs=len(cases),visual=visual,metrics=rows,cases=cases)
(root/'validated-results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
with (root/'metrics.csv').open('w',newline='',encoding='utf-8') as f:w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
print('Passed',len(cases),'runtime cases and pixel-identical images')
for r in rows:print(r)
