"""Serial desktop regression gate across the engine, demo and XR Suite repositories."""
import argparse
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--config',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--skip-build',action='store_true')
args=parser.parse_args()
cfg=json.loads(args.config.read_text(encoding='utf-8'))
repo=Path(__file__).resolve().parents[1]
engine=Path(cfg['engine']);suite=Path(cfg['suite']);testbed=Path(cfg['testbed'])
stock_templates=Path(cfg['stock_templates'])
for name in ['web_release.zip','web_nothreads_release.zip']:
 if not (stock_templates/name).is_file():raise FileNotFoundError(stock_templates/name)
out=args.output.resolve()
if out.exists() and any(out.iterdir()):raise ValueError('Use a new output directory.')
out.mkdir(parents=True,exist_ok=True)
def git(path,*words):return subprocess.check_output(['git','-c','core.fsmonitor=false','-C',str(path),*words],text=True).strip()
heads={name:git(path,'rev-parse','HEAD') for name,path in [('engine',engine),('suite',suite),('demo',repo)]}
for name,path in [('engine',engine),('suite',suite),('demo',repo)]:
 if git(path,'status','--porcelain'):raise ValueError(name+' source must be committed before provenance checks.')
env=os.environ.copy();sdk=Path(cfg['emsdk'])
node=next(iter(sorted(sdk.glob('node/*/bin/node.exe'))),None)
if node is None:raise FileNotFoundError('Emscripten Node runtime')
env.update(EMSDK=str(sdk),EMSDK_ROOT=str(sdk),GODOT_WEBGPU_TESTBED=str(testbed),GODOT_TINT_PATH=str(engine/'bin/tint.exe'),GODOT_TINT_PATH_FALLBACK=str(engine/'bin/tint-extended.exe'),PLAYWRIGHT_CHANNEL='chrome',PYTHONDONTWRITEBYTECODE='1')
env['PATH']=os.pathsep.join([str(sdk),str(sdk/'upstream/emscripten'),str(node.parent),env['PATH']])
steps=[]
def run(name,command,cwd=repo,custom_env=None,timeout=1200):
 with (out/(name+'.log')).open('w',encoding='utf-8') as log:
  result=subprocess.run([str(x) for x in command],cwd=cwd,env=custom_env or env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 steps.append({'name':name,'exit_code':result.returncode})
 (out/'status.json').write_text(json.dumps({'passed':False,'sources':heads,'steps':steps},indent=2),encoding='utf-8')
 print(name,'PASS' if result.returncode==0 else 'FAIL',flush=True)
 if result.returncode:raise RuntimeError(name+' failed; see saved log.')
run('link-suite',[shutil.which('pwsh') or 'powershell','-NoProfile','-File',repo/'setup.ps1','-SuiteDirectory',suite,'-UseExistingCheckout'])
if not args.skip_build:
 for mode in ['no','yes']:
  run('build-threads-'+mode,['scons','platform=web','target=template_release','threads='+mode,'webgpu=yes','use_closure_compiler=yes','-j'+str(cfg.get('jobs',12))],engine,timeout=14400)
 run('build-editor',['scons','platform=windows','target=editor','accesskit=no','d3d12=no','-j'+str(cfg.get('jobs',12))],engine,timeout=14400)
editor=engine/'bin/godot.windows.editor.x86_64.console.exe'
version=subprocess.check_output([str(editor),'--version'],text=True).strip()
if heads['engine'][:9] not in version:raise RuntimeError('Editor does not match engine HEAD: '+version)
run('rendering-gates',[cfg['bash'],'misc/webgpu_scripts/run-local-gates.sh','--skip-build','--forward-plus','--no-install'],engine)
run('stack-boundaries',[cfg['bash'],'misc/webgpu_scripts/check-stack.sh'],engine)
for label in ['mobile','forward-plus']:
 text=(testbed/f'gate-logs/boot-{label}.png.stream.log').read_text(encoding='utf-8',errors='replace')
 if any(token in text for token in ['[error]','[pageerror]','Invalid CommandBuffer']):raise RuntimeError('Strict boot log failed: '+label)
 if not all('MSAA_CASE_OK:'+str(i) in text for i in range(4)):raise RuntimeError('Missing MSAA coverage: '+label)
single=out/'no-sab-template';single.mkdir()
with zipfile.ZipFile(engine/'bin/godot.web.template_release.wasm32.nothreads.zip') as z:z.extractall(single)
no_sab=env.copy();no_sab.update(GLUE_NO_ISOLATION='1',IWER_JS=cfg['iwer'])
run('no-sab-xr',[node,engine/'misc/webgpu_scripts/glue-smoke.mjs',single,testbed/'gate-logs/glue/glue.pck'],testbed,no_sab)
projects={'audio':'benchmarks/audio-worker/godot','native':'benchmarks/native-pbr/godot','demo':'demo'}
for name,project in projects.items():
 destination=out/'exports'/name
 if name=='audio':destination=destination/'Candidate'
 run('export-'+name,[sys.executable,'tools/export-web-matrix.py','--project',project,'--editor',editor,'--templates-dir',engine/'bin','--output',destination])
 run('parity-'+name,[sys.executable,'tools/compare-thread-packs.py',destination/'Web/index.pck',destination/'WebThreads/index.pck'])
 if name=='native':
  for mode in ['Web','WebThreads']:shutil.copyfile(repo/project/'xbench_timer.js',destination/mode/'xbench_timer.js')
# Baseline is evidence, not an installed project: copy its immutable exported files.
shutil.copytree(cfg['baseline_audio'],out/'exports/audio/Baseline')
run('audio-lifecycle',[node,'benchmarks/audio-worker/verify.mjs',out/'exports/audio',out/'audio-results',heads['engine']])
run('native-pbr-clean',[node,'benchmarks/native-pbr/run.mjs',out/'exports/native',out/'native-results'])
for mode in ['Web','WebThreads']:
 mode_env=env.copy();mode_env['XR_TEST_THREADS']='1' if mode=='WebThreads' else '0'
 run('demo-'+mode,[node,'tools/verify-p0-export.mjs',out/'exports/demo'/mode,out/('demo-'+mode)],custom_env=mode_env)
run('suite-package',[sys.executable,'tools/test_xr_suite_package.py'],suite)
run('suite-shell',[node,'tools/test_webxr_shell.mjs'],suite)
run('suite-compatibility',[sys.executable,'tools/verify_engine_compatibility.py','--stock-editor',cfg['stock_editor'],'--custom-editor',editor,'--custom-revision',heads['engine'],'--output',out/'suite-compatibility'],suite,timeout=1200)
run('suite-browser-export',[sys.executable,'tools/export_suite_browser.py','--stock-editor',cfg['stock_editor'],'--stock-templates',stock_templates,'--custom-engine',engine,'--output',out/'suite-browser-builds'],suite)
run('suite-browser-runtime',[node,'tools/verify_suite_browser.mjs',out/'suite-browser-builds',out/'suite-browser-results',heads['engine']],suite)
for name,path in [('engine',engine),('suite',suite),('demo',repo)]:
 if git(path,'rev-parse','HEAD')!=heads[name] or git(path,'status','--porcelain'):raise RuntimeError('Source changed during regression run: '+name)
(out/'status.json').write_text(json.dumps({'passed':True,'sources':heads,'editor_version':version,'steps':steps},indent=2),encoding='utf-8')
print('ALL DESKTOP REGRESSION GATES PASSED',flush=True)
