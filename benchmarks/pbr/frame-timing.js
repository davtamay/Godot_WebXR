(() => {
 const request=window.requestAnimationFrame;window.frameCallbackTimes=[];
 window.requestAnimationFrame=function(callback){return request.call(this,function(time){
  const collecting=window.bench?.collecting;const before=window.bench?.frames.length;const start=performance.now();
  try{return callback(time);}finally{if(collecting&&window.bench.frames.length>before)frameCallbackTimes.push(performance.now()-start);}
 });};
})();
