const q = new URLSearchParams(location.search), engineName = q.get('engine'), count = Number(q.get('count') || 100);
const manifest = await (await fetch('./godot/workload.json')).json();
const positions = manifest.workloads[count], canvas = document.getElementById('canvas');
window.bench = { ready: false, collecting: false, frames: [], metadata: { engine: engineName, count } };
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
        scene.clearColor = new B.Color4(0, 0, 0, 1);
        const camera = new B.FreeCamera('camera', new B.Vector3(0, 0, 30), scene);
        camera.setTarget(B.Vector3.Zero()); camera.mode = B.Camera.ORTHOGRAPHIC_CAMERA;
        camera.orthoTop = 11; camera.orthoBottom = -11; camera.orthoLeft = -11 * 16 / 9; camera.orthoRight = 11 * 16 / 9;
        camera.minZ = .1; camera.maxZ = 100;
        const material = new B.StandardMaterial('white', scene);
        material.disableLighting = true; material.emissiveColor = B.Color3.White(); material.backFaceCulling = false;
        const data = new B.VertexData(); data.positions = manifest.vertices; data.indices = manifest.indices;
        data.normals = Array(manifest.vertices.length).fill(0); B.VertexData.ComputeNormals(data.positions, data.indices, data.normals);
        const base = new B.Mesh('cube-0', scene); data.applyToMesh(base); base.material = material;
        positions.forEach((p, i) => { const m = i ? base.clone(`cube-${i}`) : base; m.position.set(p[0], p[1], p[2]); m.scaling.setAll(p[3]); });
        const instrumentation = new B.EngineInstrumentation(engine); instrumentation.captureGPUFrameTime = true;
        bench.metadata = { ...bench.metadata, version: B.Engine.Version, gpu_scope: 'Babylon GPU frame timestamp interval; latest completed readback', cpu_scope: 'wall time inside scene.render; excludes engine endFrame' };
        engine.runRenderLoop(() => {
            const drawsBefore = engine._drawCalls.current; const start = performance.now(); scene.render();
            record(performance.now() - start, instrumentation.gpuFrameTimeCounter?.count ? instrumentation.gpuFrameTimeCounter.current / 1e6 : null, engine._drawCalls.current - drawsBefore, scene.getActiveIndices() / 3);
        });
    } else if (engineName === 'playcanvas') {
        const P = await import('./node_modules/playcanvas/build/playcanvas.mjs');
        const device = await P.createGraphicsDevice(canvas, { deviceTypes: ['webgpu'], antialias: false });
        if (device.deviceType !== 'webgpu') throw new Error('PlayCanvas WebGPU fallback is not a matched case');
        const app = new P.Application(canvas, { graphicsDevice: device });
        app.setCanvasResolution(P.RESOLUTION_FIXED, 1280, 720);
        app.scene.toneMapping = P.TONEMAP_NONE;
        const camera = new P.Entity('camera');
        camera.addComponent('camera', { projection: P.PROJECTION_ORTHOGRAPHIC, orthoHeight: 11, nearClip: .1, farClip: 100, clearColor: new P.Color(0, 0, 0, 1) });
        camera.setPosition(0, 0, 30); app.root.addChild(camera);
        const mesh = new P.Mesh(device); mesh.setPositions(manifest.vertices); mesh.setNormals(P.calculateNormals(manifest.vertices, manifest.indices)); mesh.setIndices(manifest.indices); mesh.update();
        const material = new P.StandardMaterial(); material.useLighting = false; material.emissive = new P.Color(1, 1, 1); material.cull = P.CULLFACE_NONE; material.update();
        for (const p of positions) {
            const entity = new P.Entity(); entity.setPosition(p[0], p[1], p[2]); entity.setLocalScale(p[3], p[3], p[3]);
            entity.addComponent('render', { meshInstances: [new P.MeshInstance(mesh, material)], castShadows: false, receiveShadows: false }); app.root.addChild(entity);
        }
        device.gpuProfiler.enabled = true;
        bench.metadata = { ...bench.metadata, version: P.version, gpu_scope: 'PlayCanvas GPU profiler frame interval; latest completed readback', cpu_scope: 'AppStats cpuRenderTime; excludes update' };
        app.on('frameend', () => record(app.stats.cpuRenderTime, app.stats.gpuFrameTime, app.stats.drawCallCount, app.stats.primitiveCount ?? null));
        app.start();
    } else throw new Error('Unknown engine');
} catch (e) { bench.error = String(e); console.error(e); }
