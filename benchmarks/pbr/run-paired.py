"""Alternate preserved baseline and candidate builds; never run GPU cases concurrently."""
from pathlib import Path
import argparse,subprocess,os,json
p=argparse.ArgumentParser();p.add_argument('--baseline',required=True);p.add_argument('--candidate',required=True);p.add_argument('--out',required=True);p.add_argument('--rounds',type=int,default=5);p.add_argument('--seconds',type=int,default=5);p.add_argument('--counts',default='24,96,384');p.add_argument('--profiles',default='off,on');p.add_argument('--audio',default='normal');a=p.parse_args()
repo=Path(__file__).resolve().parents[2];root=Path(a.out);root.mkdir(parents=True,exist_ok=True);env=os.environ.copy();env.setdefault('GODOT_WEBGPU_TESTBED','C:/Users/davta/work/engine-demo-merge/testbed')
plan=[]
for count in map(int,a.counts.split(',')):
 for repeat in range(a.rounds):
  profiles=a.profiles.split(',');profiles=profiles[::-1] if repeat%2 else profiles
  engines=['godot-single','godot-threaded'];engines=engines[::-1] if repeat%2 else engines
  for profile in profiles:
   builds=['baseline','candidate'];builds=builds[::-1] if (repeat+(profile=='on'))%2 else builds
   for build in builds:plan.append(dict(count=count,repeat=repeat+1,profile=profile,build=build,engines=engines))
(root/'plan.json').write_text(json.dumps({'configuration':vars(a),'cases':plan},indent=2),encoding='utf-8')
for item in plan:
 dest=root/f"n{item['count']}-r{item['repeat']}-{item['profile']}-{item['build']}"
 args=['node','benchmarks/pbr/run.mjs','--buildDir',getattr(a,item['build']),'--out',str(dest),'--counts',str(item['count']),'--repeats','1','--seconds',str(a.seconds),'--warmup','3','--profile',item['profile'],'--engines',','.join(item['engines']),'--frameTiming','--audioControl',a.audio]
 subprocess.run(args,cwd=repo,env=env,check=True)
print('PAIRED MATRIX COMPLETE',flush=True)
