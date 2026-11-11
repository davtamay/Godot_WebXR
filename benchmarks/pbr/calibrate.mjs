// Run separately from benchmark matrix: validate timestamp sensitivity on the real GPU.
import fs from 'node:fs';
import {createRequire} from 'node:module';
import path from 'node:path';
const require=createRequire(path.join(process.env.GODOT_WEBGPU_TESTBED,'package.json'));
const {chromium}=require('playwright');
const browser=await chromium.launch({channel:'chrome'});
try{
 const page=await browser.newPage();

 // A trustworthy localhost origin with an in-memory response needs no server.
 await page.route('http://localhost:8123/**',r=>r.fulfill({contentType:'text/html',body:'<html></html>'}));
 await page.goto('http://localhost:8123/');
 await page.addScriptTag({content:fs.readFileSync(new URL('./common-scope.js',import.meta.url),'utf8')});
 const result=await page.evaluate(async()=>{
  const adapter=await navigator.gpu.requestAdapter();const device=await adapter.requestDevice();
  const buffer=device.createBuffer({size:65536*4,usage:GPUBufferUsage.STORAGE|GPUBufferUsage.COPY_SRC});
  const shader=device.createShaderModule({code:`@group(0) @binding(0) var<storage,read_write> data:array<f32>;
@compute @workgroup_size(64) fn main(@builtin(global_invocation_id) id:vec3u){var x=f32(id.x)*0.0001;for(var i=0u;i<8192u;i++){x=sin(x+f32(i)*0.001)+0.1;}data[id.x]=x;}`});
  const pipeline=device.createComputePipeline({layout:'auto',compute:{module:shader,entryPoint:'main'}});
  const group=device.createBindGroup({layout:pipeline.getBindGroupLayout(0),entries:[{binding:0,resource:{buffer}}]});
  async function batch(heavy){queueScope.start();for(let i=0;i<12;i++){const e=device.createCommandEncoder();if(heavy){const p=e.beginComputePass();p.setPipeline(pipeline);p.setBindGroup(0,group);p.dispatchWorkgroups(1024);p.end();}device.queue.submit([e.finish()]);await device.queue.onSubmittedWorkDone();}return await queueScope.stop();}
  await batch(true);const empty=await batch(false);const heavy=await batch(true);
  const total=r=>r.samples.reduce((s,x)=>s+x.gpuMs,0);return {empty,heavy,emptyTotalMs:total(empty),heavyTotalMs:total(heavy)};
 });
 result.passed=result.empty.samples.length===12&&result.heavy.samples.length===12&&!result.empty.errors.length&&!result.heavy.errors.length&&result.heavyTotalMs>result.emptyTotalMs+.5;
 fs.writeFileSync(process.argv[2],JSON.stringify(result,null,2));console.log(JSON.stringify({passed:result.passed,emptyMs:result.emptyTotalMs,heavyMs:result.heavyTotalMs}));if(!result.passed)process.exitCode=1;
}finally{await browser.close();}


