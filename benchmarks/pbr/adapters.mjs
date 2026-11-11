const q = new URLSearchParams(location.search), engineName = q.get('engine'), count = Number(q.get('count') || 24);
const manifest = await (await fetch('./godot/workload.json')).json();
const positions = manifest.workloads[count], canvas = document.getElementById('canvas');
window.bench = { ready: false, collecting: false, frames: [], metadata: { engine: engineName, count } };
const kernel=await (await fetch('./pbr.wgsl')).text();
let frame = 0, last = performance.now();
function record(cpuMs, gpuMs, draws, primitives) {
    const now = performance.now();
    const sample = { frame: ++frame, frameMs: now - last, cpuMs, gpuMs: Number.isFinite(gpuMs) && gpuMs >= 0 ? gpuMs : null, draws, primitives };
    last = now; bench.ready = true;
    if (bench.collecting) bench.frames.push(sample);
}
try {
    if (!positions) throw new Error('Unsupported workload count');
    if (engineName === 'babylon') {
        const B = await import('./node_modules/@babylonjs/core/index.js');
        const engine = new B.WebGPUEngine(canvas, { antialias: false, enableAllFeatures: true });
        await engine.initAsync();
        engine.setSize(1280, 720);
        const scene = new B.Scene(engine); scene.useRightHandedSystem = true;
        scene.clearColor = new B.Color4(1, 0, 1, 1);
        const camera = new B.FreeCamera('camera', new B.Vector3(0, 0, 30), scene);
        camera.setTarget(B.Vector3.Zero()); camera.mode = B.Camera.ORTHOGRAPHIC_CAMERA;
        camera.orthoTop = 11; camera.orthoBottom = -11; camera.orthoLeft = -11 * 16 / 9; camera.orthoRight = 11 * 16 / 9;
        camera.minZ = .1; camera.maxZ = 100;
        const vertex=`attribute position:vec3f; attribute normal:vec3f; attribute uv:vec2f;
uniform worldViewProjection:mat4x4f; varying vNormal:vec3f; varying vUV:vec2f;
@vertex fn main(input:VertexInputs)->FragmentInputs {vertexOutputs.position=uniforms.worldViewProjection*vec4f(vertexInputs.position,1.0);vertexOutputs.vNormal=vertexInputs.normal;vertexOutputs.vUV=vertexInputs.uv;}`;
        const fragment=`varying vNormal:vec3f; varying vUV:vec2f; uniform params:vec4f; uniform rough:f32;
var pattern:texture_2d<f32>;
var patternSampler:sampler;
${kernel}
@fragment fn main(input:FragmentInputs)->FragmentOutputs {let a=textureSample(pattern,patternSampler,fragmentInputs.vUV).rgb*uniforms.params.rgb;fragmentOutputs.color=vec4f(encodeSrgb(pbr(fragmentInputs.vNormal,a,uniforms.params.a,uniforms.rough)),1.0);}`;
        const texture=B.RawTexture.CreateRGBATexture(new Uint8Array(manifest.texture),16,16,scene,false,false,B.Texture.NEAREST_SAMPLINGMODE);
        const materials=manifest.materials.map((p,i)=>{const m=new B.ShaderMaterial('pbr-'+i,scene,{vertexSource:vertex,fragmentSource:fragment},{attributes:['position','normal','uv'],uniforms:['worldViewProjection','params','rough'],samplers:['pattern'],shaderLanguage:B.ShaderLanguage.WGSL});m.backFaceCulling=false;m.setVector4('params',new B.Vector4(...p.slice(0,4)));m.setFloat('rough',p[4]);m.setTexture('pattern',texture);return m;});
        const data = new B.VertexData(); data.positions = manifest.vertices; data.indices = manifest.indices;data.normals=manifest.normals;data.uvs=manifest.uvs;
        const base = new B.Mesh('sphere-0', scene); data.applyToMesh(base);
        positions.forEach((p,i)=>{const m=i?base.clone('sphere-'+i):base;m.material=materials[p[4]];m.position.set(p[0],p[1],p[2]);m.scaling.setAll(p[3]);});
        bench.metadata={...bench.metadata,version:B.Engine.Version,shader:'canonical GGX',nativeProfiler:false};
        engine.runRenderLoop(() => {
            const drawsBefore = engine._drawCalls.current; const start = performance.now(); scene.render();
            record(performance.now() - start, null, engine._drawCalls.current - drawsBefore, scene.getActiveIndices() / 3);
        });
    } else if (engineName === 'playcanvas') {
        const P = await import('./node_modules/playcanvas/build/playcanvas.mjs');
        const device = await P.createGraphicsDevice(canvas, { deviceTypes: ['webgpu'], antialias: false });
        if (device.deviceType !== 'webgpu') throw new Error('PlayCanvas WebGPU fallback is not a matched case');
        const app = new P.Application(canvas, { graphicsDevice: device });
        app.setCanvasResolution(P.RESOLUTION_FIXED, 1280, 720);
        app.scene.toneMapping = P.TONEMAP_NONE;
        const camera = new P.Entity('camera');
        camera.addComponent('camera', { projection: P.PROJECTION_ORTHOGRAPHIC, orthoHeight: 11, nearClip: .1, farClip: 100, clearColor: new P.Color(1, 0, 1, 1) });
        camera.setPosition(0, 0, 30); app.root.addChild(camera);
        const mesh = new P.Mesh(device);mesh.setPositions(manifest.vertices);mesh.setNormals(manifest.normals);mesh.setUvs(0,manifest.uvs);mesh.setIndices(manifest.indices);mesh.update();
        const vertex=`attribute vertex_position:vec3f;
attribute vertex_normal:vec3f;
attribute vertex_texCoord0:vec2f;
uniform matrix_model:mat4x4f;
uniform matrix_viewProjection:mat4x4f;
varying vNormal:vec3f;
varying vUV:vec2f;
@vertex fn vertexMain(input:VertexInput)->VertexOutput{var o:VertexOutput;o.position=uniform.matrix_viewProjection*uniform.matrix_model*vec4f(input.vertex_position,1.0);o.vNormal=input.vertex_normal;o.vUV=input.vertex_texCoord0;return o;}`;
        const fragment=`varying vNormal:vec3f;
varying vUV:vec2f;
uniform params:vec4f;
uniform rough:f32;
var pattern:texture_2d<f32>;
var patternSampler:sampler;
${kernel}
@fragment fn fragmentMain(input:FragmentInput)->FragmentOutput{var o:FragmentOutput;let a=textureSample(pattern,patternSampler,input.vUV).rgb*uniform.params.rgb;o.color=vec4f(encodeSrgb(pbr(input.vNormal,a,uniform.params.a,uniform.rough)),1.0);return o;}`;
        const texture=new P.Texture(device,{width:16,height:16,format:P.PIXELFORMAT_RGBA8,mipmaps:false,minFilter:P.FILTER_NEAREST,magFilter:P.FILTER_NEAREST});texture.lock().set(new Uint8Array(manifest.texture));texture.unlock();
        const materials=manifest.materials.map(p=>{const m=new P.ShaderMaterial({uniqueName:'CanonicalGGX',vertexWGSL:vertex,fragmentWGSL:fragment,attributes:{vertex_position:P.SEMANTIC_POSITION,vertex_normal:P.SEMANTIC_NORMAL,vertex_texCoord0:P.SEMANTIC_TEXCOORD0}});m.cull=P.CULLFACE_NONE;m.setParameter('params',p.slice(0,4));m.setParameter('rough',p[4]);m.setParameter('pattern',texture);return m;});
        for(const p of positions){const entity=new P.Entity();entity.setPosition(p[0],p[1],p[2]);entity.setLocalScale(p[3],p[3],p[3]);entity.addComponent('render',{meshInstances:[new P.MeshInstance(mesh,materials[p[4]])],castShadows:false,receiveShadows:false});app.root.addChild(entity);}
        device.gpuProfiler.enabled=false;
        bench.metadata={...bench.metadata,version:P.version,shader:'canonical GGX',nativeProfiler:false};
        app.on('frameend',()=>record(null,null,app.stats.drawCallCount,null));
        app.start();
    } else throw new Error('Unknown engine');
} catch (e) { bench.error = String(e); console.error(e); }


