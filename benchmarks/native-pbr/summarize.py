"""Validate a complete native-material matrix and summarize distinct timing scopes."""
import argparse,csv,itertools,json,re,statistics
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('results',type=Path);a=p.parse_args();root=a.results
summary=json.loads((root/'summary.json').read_text(encoding='utf-8'));assert summary['finished']
config=summary['configuration'];repeats=int(config['repeats']);profiles=config['profiles'].split(',')
expected={f'{mode}-{engine}-{repeat}-{profile}' for mode,engine,repeat,profile in itertools.product(['batch','unique'],['godot-single','godot-threaded','playcanvas'],range(1,repeats+1),profiles)}
assert {x['id'] for x in summary['cases']}==expected
cases=[];adapters=set()
for stub in summary['cases']:
 c=json.loads((root/(stub['id']+'.json')).read_text(encoding='utf-8'));assert c['passed'] and not c['errors'],c['id']
 assert c['metrics']['frames']>0 and c['queue']['submissions']>0
 assert not c['queue']['errors'] and not c['queue']['dropped']
 assert any(re.search(r'XBENCH engine=.* n='+str(c['count'])+r' ',x) for x in c['console'])
 if c['engine'].startswith('godot'):
  assert c['provenance']['identity_complete']
  assert c['version']['hash'].startswith(config['revision'])
  assert c['provenance']['engine_source']['revision'].startswith(config['revision'])
  assert c['hosting']['shared']==(c['engine']=='godot-threaded')
 if c['profile']=='on':
  assert len(c['queue']['samples'])==c['queue']['submissions']
  assert len({x['ordinal'] for x in c['queue']['samples']})==c['queue']['submissions']
 for f in c['queue']['features']:adapters.add(json.dumps(f['adapter'],sort_keys=True))
 cases.append(c)
assert len(adapters)==1,'Different GPU adapters selected'
rows=[]
for mode,engine in itertools.product(['batch','unique'],['godot-single','godot-threaded','playcanvas']):
 row={'mode':mode,'engine':engine,'objects':int(config['count']),'repetitions':repeats}
 for field,profile in [('rendererCpuMsPerFrame','off'),('callbackWallMs','off'),('gpuCommandMsPerFrame','on')]:
  values=[x['metrics'][field] for x in cases if x['mode']==mode and x['engine']==engine and x['profile']==profile]
  if not values:continue
  assert len(values)==repeats and all(v is not None and v>0 for v in values)
  row[field]=statistics.median(values);row[field+'_min']=min(values);row[field+'_max']=max(values)
 rows.append(row)
with (root/'metrics.csv').open('w',newline='',encoding='utf-8') as stream:
 writer=csv.DictWriter(stream,fieldnames=rows[0]);writer.writeheader();writer.writerows(rows)
(root/'validated.json').write_text(json.dumps({'passed':True,'cases':len(cases),'adapter':json.loads(next(iter(adapters))),'metrics':rows,'visual_equivalence_claimed':False,'cpu_includes_audio_and_workers':True},indent=2),encoding='utf-8')
print('Validated',len(cases),'cases and one selected adapter.')
for row in rows:print(row)
