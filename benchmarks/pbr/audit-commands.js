(() => {
 const encoders=new WeakMap(),buffers=new WeakMap();window.commandAudit=[];
 const create=GPUDevice.prototype.createCommandEncoder;GPUDevice.prototype.createCommandEncoder=function(...a){const e=create.apply(this,a);encoders.set(e,[]);return e;};
 for(const name of ['beginRenderPass','beginComputePass','copyBufferToBuffer','copyBufferToTexture','copyTextureToBuffer','copyTextureToTexture','clearBuffer','resolveQuerySet']){const old=GPUCommandEncoder.prototype[name];GPUCommandEncoder.prototype[name]=function(...a){encoders.get(this)?.push(name);return old.apply(this,a);};}
 const finish=GPUCommandEncoder.prototype.finish;GPUCommandEncoder.prototype.finish=function(...a){const b=finish.apply(this,a);buffers.set(b,encoders.get(this));return b;};
 const submit=GPUQueue.prototype.submit;GPUQueue.prototype.submit=function(b){if(window.bench?.collecting)commandAudit.push(Array.from(b,x=>buffers.get(x)));return submit.call(this,b);};
})();
