"""Summarize independent repetitions, keeping CPU-off and GPU-on scopes separate."""
import json,statistics,csv,argparse,math
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory');a=p.parse_args();root=Path(a.directory)
summary=json.loads((root/'summary.json').read_text());validation=json.loads((root/'validation.json').read_text())
assert summary.get('finished') and validation['passed'], 'Complete, visually validated runs required'
cases=[json.loads((root/(c['id']+'.json')).read_text()) for c in summary['cases']]
assert len(cases)==120 and all(c['status']=='passed' for c in cases)
for c in cases:
 assert c['metrics']['frames']>0 and c['queue']['submissions']>0
 assert math.isfinite(c['metrics']['rendererCpuMsPerFrame']) and c['metrics']['rendererCpuMsPerFrame']>0
 if c['id'].endswith('-on'):
  assert len(c['queue']['samples'])==c['queue']['submissions']
  assert all(math.isfinite(x['gpuMs']) and x['gpuMs']>=0 for x in c['queue']['samples'])
  assert len({x['ordinal'] for x in c['queue']['samples']})==c['queue']['submissions']
rows=[]
for count in [24,96,384]:
 for engine in ['godot-single','godot-threaded','babylon','playcanvas']:
  off=[c for c in cases if c['count']==count and c['engine']==engine and c['id'].endswith('-off')]
  on=[c for c in cases if c['count']==count and c['engine']==engine and c['id'].endswith('-on')]
  assert len(off)==len(on)==5
  cpu=[c['metrics']['rendererCpuMsPerFrame'] for c in off];gpu=[c['metrics']['gpuCommandMsPerFrame'] for c in on]
  overhead=[c['metrics']['rendererCpuMsPerFrame']-next(o['metrics']['rendererCpuMsPerFrame'] for o in off if o['repeat']==c['repeat']) for c in on]
  samples=[s['gpuMs'] for c in on for s in c['queue']['samples']]
  rows.append(dict(count=count,engine=engine,cpu_off_median_ms=statistics.median(cpu),cpu_off_min_ms=min(cpu),cpu_off_max_ms=max(cpu),gpu_on_median_ms=statistics.median(gpu),gpu_on_min_ms=min(gpu),gpu_on_max_ms=max(gpu),cpu_observer_delta_median_ms=statistics.median(overhead),gpu_zero_fraction=sum(x==0 for x in samples)/len(samples),gpu_submissions=len(samples)))
with (root/'metrics.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
(root/'metrics.json').write_text(json.dumps(rows,indent=2))
print('| Spheres | Engine | CPU off, ms/frame | GPU on, ms/frame | CPU observer delta, ms/frame |')
print('|---:|---|---:|---:|---:|')
for r in rows:print(f"| {r['count']} | {r['engine']} | {r['cpu_off_median_ms']:.3f} | {r['gpu_on_median_ms']:.4f} | {r['cpu_observer_delta_median_ms']:+.3f} |")
