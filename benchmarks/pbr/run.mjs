import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { parseArgs } from 'node:util';
const root = path.dirname(fileURLToPath(import.meta.url));
const { values: o } = parseArgs({ options: { out: { type: 'string' }, frameTiming:{type:'boolean',default:false}, audioControl:{type:'string',default:'normal'}, buildDir:{type:'string',default:'build'}, cpuProfile: {type:'boolean',default:false}, commandAudit: {type:'boolean',default:false}, browserTrace: {type:'boolean',default:false}, repeats: { type: 'string', default: '5' }, seconds: { type: 'string', default: '10' }, warmup: { type: 'string', default: '5' }, counts: { type: 'string', default: '24,96,384' }, profile: {type:'string',default:'both'}, engines: { type: 'string', default: 'godot-single,babylon,godot-threaded,playcanvas' }, channel: { type: 'string', default: 'chrome' } } });
if (!o.out) throw new Error('--out DIRECTORY required');
if(!['normal','suspended'].includes(o.audioControl))throw new Error('Invalid audio control');
for (const k of ['repeats','seconds','warmup']) if (!Number.isFinite(Number(o[k])) || Number(o[k]) <= 0) throw new Error(`Invalid ${k}`);
const require = createRequire(path.join(process.env.GODOT_WEBGPU_TESTBED || process.cwd(), 'package.json'));
const { chromium } = require('playwright');
const out = path.resolve(o.out); fs.mkdirSync(out, { recursive: true });
const sha = p => createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const metadata = { schema: 1, configuration: o, scopeSha256:sha(path.join(root,'common-scope.js')), kernelSha256:sha(path.join(root,'pbr.wgsl')), harnessSha256: sha(fileURLToPath(import.meta.url)), adapterSha256: sha(path.join(root,'adapters.mjs')), workloadSha256: sha(path.join(root,'godot/workload.json')), dependencyLockSha256: sha(path.join(root,'package-lock.json')), started: new Date().toISOString(), cases: [], gpuTimingNote: 'Common timestamp brackets around every application queue.submit. Sum of command-buffer intervals divided by engine frames; excludes queue.write uploads and presentation. No native GPU counters. CPU uses renderer-process CPU deltas including worker threads; off-profile runs are primary CPU controls.' };
const server = http.createServer((req,res) => {
    const name = decodeURIComponent(new URL(req.url,'http://local').pathname);
    if (name === '/favicon.ico') { res.writeHead(204).end(); return; }
    const servingRoot=name.startsWith('/build/')?path.resolve(root,o.buildDir):root;
    const relative=name.startsWith('/build/')?name.slice(6):(name==='/'?'/index.html':name);
    const file = path.resolve(servingRoot,'.'+relative);
    if (!file.startsWith(servingRoot+path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {res.writeHead(404).end();return;}
    const headers = {'Cache-Control':'no-store','Content-Type':{'.html':'text/html','.js':'application/javascript','.mjs':'application/javascript','.wasm':'application/wasm','.json':'application/json'}[path.extname(file)]||'application/octet-stream'};
    if (!name.startsWith('/build/Web/')) Object.assign(headers,{'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
    res.writeHead(200,headers);fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const base = `http://127.0.0.1:${server.address().port}`;
const engines = o.engines.split(','), counts = o.counts.split(',').map(Number);
const stats = values => { const a = values.filter(Number.isFinite).sort((a,b)=>a-b);return { samples:a.length, median:a.length?a[Math.ceil(a.length*.5)-1]:null,p95:a.length?a[Math.ceil(a.length*.95)-1]:null,p99:a.length?a[Math.ceil(a.length*.99)-1]:null }; };
try {
    for (const count of counts) for(let repeat=0; repeat<Number(o.repeats); repeat++) {
        // Rotate order per repetition; only one browser/GPU workload at a time.
        const order=engines.map((_,i)=>engines[(i+repeat)%engines.length]);
        for(const profile of (o.profile==='both'?(repeat%2?['on','off']:['off','on']):[o.profile])) for(const engine of order) {
            const id=`${engine}-${count}-${repeat+1}-${profile}`, errors=[], item={id,engine,count,repeat:repeat+1,errors};
            let browser;
            try {
                browser=await chromium.launch({channel:o.channel}); item.browserVersion=browser.version();
                const cdp=await browser.newBrowserCDPSession(); const system=await cdp.send('SystemInfo.getInfo'); item.gpu=system.gpu.devices;
                const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
                await page.addInitScript({content:`window.PROFILE_GPU=${profile==='on'};`+fs.readFileSync(path.join(root,'common-scope.js'),'utf8')});
                if(o.frameTiming)await page.addInitScript({path:path.join(root,'frame-timing.js')});
                if(o.audioControl==='suspended')await page.addInitScript(()=>{window.audioContexts=[];for(const name of ['AudioContext','webkitAudioContext']){if(window[name])window[name]=new Proxy(window[name],{construct(target,args,newTarget){const ctx=Reflect.construct(target,args,newTarget);audioContexts.push(ctx);return ctx;}});}});
                if(o.commandAudit)await page.addInitScript({path:path.join(root,'audit-commands.js')});
                page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
                const url=engine.startsWith('godot')?`${base}/build/${engine==='godot-single'?'Web':'WebThreads'}/index.html?count=${count}`:`${base}/index.html?engine=${engine}&count=${count}`;
                await page.goto(url,{waitUntil:'domcontentloaded'});
                await page.waitForFunction(()=>window.bench?.ready||window.bench?.error,null,{timeout:90000});
                const error=await page.evaluate(()=>bench.error);if(error)throw new Error(error);
                if(o.audioControl==='suspended')await page.evaluate(async()=>{await Promise.all(audioContexts.map(c=>c.suspend()));if(!audioContexts.length)throw new Error('No audio context for control');});
                await page.waitForTimeout(Number(o.warmup)*1000);
                if(o.commandAudit)item.driverPerf=await page.evaluate(()=>window.__godotWebGPUPerf);
                item.hosting=await page.evaluate(()=>({isolated:crossOriginIsolated,shared:typeof SharedArrayBuffer!=='undefined'}));
                const profiler=o.cpuProfile?await page.context().newCDPSession(page):null;
                if(profiler){await profiler.send('Profiler.enable');await profiler.send('Profiler.setSamplingInterval',{interval:100});await profiler.send('Profiler.start');}
                if(o.browserTrace)await cdp.send('Tracing.start',{categories:'toplevel,devtools.timeline,renderer.scheduler,blink,webgpu',transferMode:'ReturnAsStream'});
                const cpuBefore=await cdp.send('SystemInfo.getProcessInfo');
                const start=Date.now();
                await page.evaluate(()=>{bench.frames=[];bench.collecting=true;queueScope.start();});
                await page.waitForTimeout(Number(o.seconds)*1000);
                const captured=await page.evaluate(async()=>{bench.collecting=false;return {frames:bench.frames,metadata:bench.metadata,queue:await queueScope.stop()};});
                const cpuAfter=await cdp.send('SystemInfo.getProcessInfo');
                if(o.browserTrace){const done=new Promise(r=>cdp.once('Tracing.tracingComplete',r));await cdp.send('Tracing.end');const {stream}=await done;let trace='';for(;;){const chunk=await cdp.send('IO.read',{handle:stream});trace+=chunk.data;if(chunk.eof)break;}await cdp.send('IO.close',{handle:stream});fs.writeFileSync(path.join(out,id+'.trace.json'),trace);}
                if(profiler){const {profile}=await profiler.send('Profiler.stop');fs.writeFileSync(path.join(out,id+'.cpuprofile'),JSON.stringify(profile));}
                item.windowWallMs=Date.now()-start; item.cpuProcessesBefore=cpuBefore.processInfo;item.cpuProcessesAfter=cpuAfter.processInfo;
                Object.assign(item,captured);
                if(o.frameTiming){item.frameCallbackTimes=await page.evaluate(()=>window.frameCallbackTimes);item.frameCallbackStats=stats(item.frameCallbackTimes);}
                if(o.audioControl==='suspended'){item.audioStates=await page.evaluate(()=>audioContexts.map(c=>c.state));if(item.audioStates.some(s=>s!=='suspended'))throw new Error('Audio control resumed unexpectedly');}
                if(o.commandAudit)item.commandAudit=await page.evaluate(()=>window.commandAudit);
                const before=new Map(cpuBefore.processInfo.map(p=>[p.id,p]));
                const renderBefore=cpuBefore.processInfo.filter(p=>p.type==='renderer');
                const renderAfter=cpuAfter.processInfo.filter(p=>p.type==='renderer');
                if(!renderBefore.length||renderAfter.length!==renderBefore.length||renderAfter.some(p=>!before.has(p.id)))throw new Error('Renderer process identity changed');
                item.rendererCpuMs=renderAfter.reduce((sum,p)=>sum+(p.cpuTime-before.get(p.id).cpuTime)*1000,0);
                item.metrics={rendererCpuMsPerFrame:item.rendererCpuMs/item.frames.length,gpuCommandMsPerFrame:profile==='on'?item.queue.samples.reduce((sum,s)=>sum+s.gpuMs,0)/item.frames.length:null,frames:item.frames.length,submissions:item.queue.submissions,gpuSamples:item.queue.samples.length,draws:stats(item.frames.map(f=>f.draws))};
                if(item.queue.errors.length||item.queue.dropped||(profile==='on'&&item.queue.samples.length!==item.queue.submissions))throw new Error('Incomplete common GPU scope');
                if(item.frames.some(f=>f.draws!==count))throw new Error('Unexpected draw count');
                if(item.rendererCpuMs<=0)throw new Error('Renderer CPU time unavailable');
                await page.screenshot({path:path.join(out,id+'.png')});
                if(!item.frames.length||errors.length)throw new Error('Missing frames or browser errors');
                if(engine.startsWith('godot') && !item.metadata.provenance?.identity_complete)throw new Error('Incomplete Godot build provenance');
                item.gpuStatus=profile==='on'?'measured-command-buffers':'disabled-for-cpu-control';
                item.status='passed';
            } catch(e) {item.status='failed';item.failure=String(e);process.exitCode=1;}
            finally {await browser?.close();fs.writeFileSync(path.join(out,id+'.json'),JSON.stringify(item,null,2));metadata.cases.push({id,status:item.status,failure:item.failure,metrics:item.metrics,gpuStatus:item.gpuStatus});fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(metadata,null,2));}
            console.log(id,item.status,item.failure||JSON.stringify(item.metrics));
        }
    }
} finally {metadata.finished=new Date().toISOString();fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(metadata,null,2));await new Promise(r=>server.close(r));}
