// Native-material throughput comparison. GPU timing uses the same queue markers for every engine.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {parseArgs} from 'node:util';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const {values:o}=parseArgs({options:{build:{type:'string'},out:{type:'string'},revision:{type:'string'},repeats:{type:'string',default:'3'},count:{type:'string',default:'8000'},seconds:{type:'string',default:'5'},profiles:{type:'string',default:'off,on'}}});
if(!o.build||!o.out||!o.revision)throw Error('Required: --build --out --revision');
const root=path.dirname(fileURLToPath(import.meta.url)),build=path.resolve(o.build),out=path.resolve(o.out);
if(fs.existsSync(out)&&fs.readdirSync(out).length)throw Error('Use a new output directory');
fs.mkdirSync(out,{recursive:true});
const dependencies=JSON.parse(fs.readFileSync(path.join(root,'dependencies.json'),'utf8'));
for(const [name,digest] of Object.entries(dependencies.files_sha256)){
 if(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,name.replaceAll('\\','/')))).digest('hex')!==digest)throw Error('Dependency hash mismatch: '+name);
}
const require=createRequire(path.join(process.env.GODOT_WEBGPU_TESTBED||'C:/Users/davta/work/engine-demo-merge/testbed','package.json'));
const {chromium}=require('playwright');
const server=http.createServer((req,res)=>{
 const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
 if(name==='/favicon.ico'){res.writeHead(204).end();return;}
 const base=name.startsWith('/build/')?build:root,relative=name.startsWith('/build/')?name.slice(6):name;
 const file=path.resolve(base,'.'+relative);
 if(!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return;}
 const headers={'Cache-Control':'no-store','Content-Type':{'.html':'text/html','.js':'application/javascript','.mjs':'application/javascript','.wasm':'application/wasm'}[path.extname(file)]||'application/octet-stream'};
 if(!name.startsWith('/build/Web/'))Object.assign(headers,{'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
 res.writeHead(200,headers);fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const base=`http://127.0.0.1:${server.address().port}`,results=[];
try{
 for(const mode of ['batch','unique'])for(let repeat=0;repeat<Number(o.repeats);repeat++){
  const engines=['godot-single','godot-threaded','playcanvas'];
  const order=engines.map((_,i)=>engines[(i+repeat)%engines.length]);
  const profiles=o.profiles.split(',');if(repeat%2)profiles.reverse();
  for(const profile of profiles)for(const engine of order){
   const id=`${mode}-${engine}-${repeat+1}-${profile}`,item={id,mode,engine,repeat:repeat+1,profile,count:Number(o.count),console:[],errors:[]};let browser;
   try{
    browser=await chromium.launch({channel:'chrome',args:['--force-high-performance-gpu','--mute-audio','--autoplay-policy=no-user-gesture-required']});
    item.browser=browser.version();const cdp=await browser.newBrowserCDPSession();item.gpu=(await cdp.send('SystemInfo.getInfo')).gpu.devices;
    const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
    await page.addInitScript({content:`window.PROFILE_GPU=${profile==='on'};`+fs.readFileSync(path.join(root,'../pbr/common-scope.js'),'utf8')});
    page.on('pageerror',e=>item.errors.push(String(e)));
    page.on('console',m=>{item.console.push(m.type()+': '+m.text());if(m.type()==='error')item.errors.push(m.text());});
    const url=engine==='playcanvas'?'/playcanvas/index.html':`/build/${engine==='godot-single'?'Web':'WebThreads'}/index.html`;
    await page.goto(`${base}${url}?n=${o.count}&common_scope=1${mode==='unique'?'&unique=1':''}`);
    await page.waitForFunction(()=>document.body.innerText.includes('XBENCH DONE'),null,{timeout:120000,polling:100});
    if(item.errors.length)throw Error('Startup errors');
    item.hosting=await page.evaluate(()=>({isolated:crossOriginIsolated,shared:typeof SharedArrayBuffer!=='undefined'}));
    if(engine.startsWith('godot')){
     item.version=await page.evaluate(()=>nativeBenchVersion);item.provenance=await page.evaluate(()=>nativeBenchProvenance);
     if(!item.provenance.identity_complete)throw Error('Incomplete build provenance');
     if(!item.version.hash.startsWith(o.revision)||!item.provenance.engine_source.revision.startsWith(o.revision))throw Error('Wrong engine identity');
     if(item.hosting.shared!==(engine==='godot-threaded'))throw Error('Wrong shared-memory hosting');
    }
    // The scene continues orbiting after its historical ramp report. Measure a fresh,
    // common window with native engine profilers disabled on both implementations.
    const before=await cdp.send('SystemInfo.getProcessInfo');
    await page.evaluate(()=>{queueScope.start();__xbench.begin();});
    await page.waitForTimeout(Number(o.seconds)*1000);
    const captured=await page.evaluate(async()=>{const callback=__xbench.end();return {callback,queue:await queueScope.stop()};});
    const after=await cdp.send('SystemInfo.getProcessInfo');Object.assign(item,captured);
    item.cpuProcessesBefore=before.processInfo;item.cpuProcessesAfter=after.processInfo;
    const previous=new Map(before.processInfo.filter(p=>p.type==='renderer').map(p=>[p.id,p.cpuTime]));
    const current=after.processInfo.filter(p=>p.type==='renderer');
    if(!current.length||current.length!==previous.size||current.some(p=>!previous.has(p.id)))throw Error('Renderer process identity changed');
    const cpuMs=current.reduce((sum,p)=>sum+(p.cpuTime-previous.get(p.id))*1000,0);
    if(!item.callback.frames||!item.queue.submissions||item.queue.errors.length||item.queue.dropped)throw Error('Incomplete measurement');
    if(profile==='on'&&(item.queue.samples.length!==item.queue.submissions||new Set(item.queue.samples.map(x=>x.ordinal)).size!==item.queue.submissions))throw Error('Missing GPU timestamps');
    item.metrics={rendererCpuMsPerFrame:cpuMs/item.callback.frames,callbackWallMs:item.callback.cpu_ms,gpuCommandMsPerFrame:profile==='on'?item.queue.samples.reduce((sum,x)=>sum+x.gpuMs,0)/item.callback.frames:null,frames:item.callback.frames};
    await page.screenshot({path:path.join(out,id+'.png')});
    if(item.errors.length)throw Error('Runtime console errors');item.passed=true;
   }catch(e){item.passed=false;item.failure=String(e);process.exitCode=1;}finally{
    await browser?.close();results.push(item);fs.writeFileSync(path.join(out,id+'.json'),JSON.stringify(item,null,2));
    fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({configuration:o,dependencies,finished:false,cases:results.map(({id,passed,failure})=>({id,passed,failure}))},null,2));
    console.log(id,item.passed,item.metrics||item.failure);
   }
   if(!item.passed)throw Error('Stopped after failed case '+id);
  }
 }
}finally{await new Promise(r=>server.close(r));}
fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({configuration:o,dependencies,finished:true,cases:results.map(({id,passed,failure})=>({id,passed,failure}))},null,2));
