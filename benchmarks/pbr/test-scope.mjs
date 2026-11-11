import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('./common-scope.js',import.meta.url),'utf8');
async function fixture({profile=true,feature=true,reversed=false,fail=false,delayed=false}={}){
 const calls=[],release=[];let listener;
 class GPUQueue {submit(buffers){calls.push(buffers);}}
 const device={queue:new GPUQueue(),features:new Set(feature?['timestamp-query']:[]),addEventListener(_,f){listener=f;},createQuerySet(){return {};},createBuffer(){return {mapState:'unmapped',async mapAsync(){if(delayed)await new Promise(r=>release.push(r));if(fail)throw Error('map failed');this.mapState='mapped';},getMappedRange(){return new BigUint64Array(reversed?[2000n,1000n]:[1000n,3000n]).buffer;},unmap(){this.mapState='unmapped';}};},createCommandEncoder(){return {beginComputePass(){return {end(){}};},resolveQuerySet(){},copyBufferToBuffer(){},finish(){return 'marker';}};}};
 class GPUAdapter {constructor(){this.features=device.features;}async requestDevice(){return device;}}
 const window={PROFILE_GPU:profile};vm.runInNewContext(source,{window,GPUQueue,GPUAdapter,GPUBufferUsage:{QUERY_RESOLVE:1,COPY_SRC:2,COPY_DST:4,MAP_READ:8},GPUMapMode:{READ:1},performance:{now:()=>0},BigUint64Array,Set,WeakMap,Promise});
 await new GPUAdapter().requestDevice();return {scope:window.queueScope,device,calls,release,error:()=>listener({error:Error('validation failed')})};
}
let f=await fixture();f.scope.start();f.device.queue.submit(['work']);let r=await f.scope.stop();assert.equal(r.samples.length,1);assert.equal(r.samples[0].gpuMs,.002);assert.deepEqual(Array.from(f.calls[0]),['marker','work','marker']);
f=await fixture({profile:false});f.scope.start();f.device.queue.submit(['work']);r=await f.scope.stop();assert.equal(r.samples.length,0);assert.deepEqual(Array.from(f.calls[0]),['work']);
f=await fixture({feature:false});f.scope.start();f.device.queue.submit(['work']);r=await f.scope.stop();assert.equal(r.submissions,1);assert.equal(r.samples.length,0);
for(const options of [{reversed:true},{fail:true}]){f=await fixture(options);f.scope.start();f.device.queue.submit([]);r=await f.scope.stop();assert.equal(r.errors.length,1);assert.equal(r.samples.length,0);}
f=await fixture({delayed:true});f.scope.start();for(let i=0;i<33;i++)f.device.queue.submit([]);assert.equal(f.scope.dropped,1);f.release.forEach(r=>r());r=await f.scope.stop();assert.equal(r.samples.length,32);assert.equal(r.submissions,33);
f=await fixture();f.error();f.scope.start();r=await f.scope.stop();assert.equal(r.errors.length,1);
console.log('7 common-scope controls passed: interval, off, unsupported, reversed, map failure, pool exhaustion, validation error');

