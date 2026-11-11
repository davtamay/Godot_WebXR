import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {createRequire} from 'node:module';
const root=path.resolve(process.argv[2]),out=path.resolve(process.argv[3]);
fs.mkdirSync(out,{recursive:true});
const require=createRequire('C:/Users/davta/work/engine-demo-merge/testbed/package.json');
const {chromium}=require('playwright');
const server=http.createServer((req,res)=>{
 const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
 if(name==='/favicon.ico'){res.writeHead(204).end();return;}
 const file=path.resolve(root,'.'+name);
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||fs.statSync(file).isDirectory()){res.writeHead(404).end();return;}
 const headers={'Content-Type':{'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm'}[path.extname(file)]||'application/octet-stream'};
 if(name.startsWith('/WebThreads/'))Object.assign(headers,{'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
 res.writeHead(200,headers);fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const results=[];
try{
 for(const mode of ['Web','WebThreads'])for(const unique of [false,true]){
  const result={mode,unique,console:[],errors:[]};let browser;
  try{
   browser=await chromium.launch({channel:'chrome',args:['--force-high-performance-gpu','--mute-audio','--autoplay-policy=no-user-gesture-required']});
   const page=await browser.newPage({viewport:{width:1280,height:720}});
   page.on('pageerror',e=>result.errors.push(String(e)));
   page.on('console',m=>{result.console.push(m.type()+': '+m.text());if(m.type()==='error')result.errors.push(m.text());});
   await page.goto(`http://127.0.0.1:${server.address().port}/${mode}/index.html?${unique?'unique=1&':''}n=500`);
   await page.waitForFunction(()=>document.body.innerText.includes('DONE'),null,{timeout:90000}).catch(async e=>{if(!result.console.some(x=>x.includes('XBENCH DONE')))throw e;});
   await page.screenshot({path:path.join(out,`${mode}-${unique?'unique':'batch'}.png`)});
   result.passed=result.errors.length===0&&result.console.some(x=>x.includes('XBENCH DONE'));
  }catch(e){result.passed=false;result.failure=String(e);}finally{await browser?.close();results.push(result);fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(results,null,2));console.log(mode,unique,result.passed,result.errors.slice(0,8));}
 }
}finally{await new Promise(r=>server.close(r));}
if(results.some(x=>!x.passed))process.exitCode=1;
