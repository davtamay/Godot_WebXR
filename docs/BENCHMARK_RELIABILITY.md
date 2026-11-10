# Desktop benchmarks and reliability

This branch adds a measurement tool, not renderer or interaction changes. Engine 2f3fd8aa21, the published demo, XR Suite and Monday snapshots remain unchanged. Existing Playwright hosting/report hooks are reused; customization is confined to demo tools and this protocol. Engine performance monitors were checked in the fork's doc/classes/Performance.xml; release memory counters cannot be assumed available.

## What the current runner measures

`tools/benchmark-reliability.mjs` runs one exported demo serially at 1280x720, DPR 1, in a fresh headless Chromium browser. It records the exact browser version, artifact SHA-256s, runtime provenance, selected driver, isolation/SAB state, repeat navigations, screenshots, browser RAF intervals (median/p95/p99), long tasks, CDP main-target JavaScript heap samples, console errors and crashes. Every navigation disables HTTP caching; this does not reset OS or GPU driver caches. Warm-up is excluded from cadence samples.

The final window is a soak. WebGPU then deliberately destroys captured devices and checks whether an explicit page reload reaches runtime-ready again. GPUDevice.destroy() is an intentional loss, not a physical GPU reset. Godot deliberately ignores the `destroyed` reason in its automatic-loss handler; this test MUST NOT claim it tested that handler, automatic renderer recovery, or saved state restoration. A live HTML RAF alone does not prove the renderer is still drawing.

JavaScript heap excludes GPU allocations and may omit WASM/worker memory. Heap growth without GC-controlled repetitions is a lead, not proof of a leak. RAF intervals measure browser scheduling, not engine render throughput, GPU duration, motion-to-photon latency or compositor dropped frames. Screenshots require visual review. A passed short screen is not a 30-minute soak pass. Every result must state its actual duration.

## Run

Use Node with Playwright installed in the directory named by GODOT_WEBGPU_TESTBED. Chrome or Edge must be installed. Exports are the existing Web and WebThreads folders produced by export-web-matrix.py.

```powershell
$env:GODOT_WEBGPU_TESTBED = 'C:/path/to/testbed'
node tools/benchmark-reliability.mjs --root C:/exports/Web --out C:/results/chrome-single.json --channel chrome
node tools/benchmark-reliability.mjs --root C:/exports/WebThreads --out C:/results/chrome-threaded.json --channel chrome --threads
```

Defaults: five 120-second measurement windows, ten-second warm-up per navigation, then a 1,800-second soak. Use `--channel msedge` for Edge and `--renderer webgl` for the WebGL control. Keep GPU runs serial. For a short diagnostic screen use `--seconds 20 --soak 120 --repeats 3 --warmup 5`. Nonzero exit means startup, hosting, renderer, unexpected loss, crash or console-error checks failed. Results are written even on failure. No numeric performance budget is silently treated as a passing score.

## Matched comparison before any leadership claim

Compare our Godot build, pinned Babylon.js and pinned PlayCanvas releases, first on desktop, then Quest 3 and Galaxy XR. Do not compare unrelated vendor demos. Implement these shared workloads in each engine from one manifest and the same licensed assets:

| Workload | Fixed inputs | What it isolates |
|---|---|---|
| Draw submission | deterministic grid; 100/1,000/5,000 independently submitted meshes; same mesh/material/camera | CPU submission scaling; report batching/instancing separately |
| PBR scene | one shared glTF, textures and IBL; fixed camera path; equivalent lights, shadows, tone mapping, MSAA and output resolution | visual parity and realistic GPU cost |
| XR interaction | same room/assets, controller/hand action recording and object count | session lifecycle and interaction overhead; emulator versus hardware kept separate |

Freeze asset hashes, engine versions, device/browser/OS/flags, power mode, resolution, refresh rate, renderer features and shader warm-up. Confirm rendered images before comparing timings. If a capability is unsupported, report unsupported, not a faster zero-cost result. Separate fixed-quality and equal-frame-budget comparisons.

Use at least five runs in counterbalanced engine order, with cold and warm startup reported separately. Report median and p95/p99 frame time, per-run dispersion, GPU timestamp-query durations when supported, engine CPU phase time, startup/download size, memory categories and image differences. GPU timestamps need engine-specific adapters; JS wall time is not a substitute. Define acceptance budgets from the target refresh rate and product requirements before judging winners. Do not infer an engine-wide ranking from one scene.

Reuse references:
- Babylon GPU timing capability: https://doc.babylonjs.com/lite/typedoc/functions/isGpuTimingSupported
- PlayCanvas AppStats: https://developer.playcanvas.com/user-manual/optimization/app-stats/
- PlayCanvas GPU profiling: https://developer.playcanvas.com/user-manual/optimization/gpu-profiling/
- Godot monitors: https://docs.godotengine.org/en/stable/classes/class_performance.html

These describe instrumentation, not measured competitor results. Cross-engine adapters and shared scenes are still required.

## Reliability earn-in

| Priority | Test | Evidence required | Current coverage |
|---|---|---|---|
| P0 | Both thread modes, WebGL/WebGPU, Chrome/Edge | correct driver + provenance, no unexpected errors, screenshots | runner available; record actual executed matrix |
| P0 | 30-minute then 2-hour runs | rendering heartbeat + periodic screenshots, bounded memory trend, no errors | runner supports duration; current RAF alone cannot certify rendered heartbeat |
| P0 | Unexpected GPU loss | actual loss callback, clear UI, saved state, bounded reload, repeated-loss guard | intentional destroy/reload screen only; unexpected-loss path needs separate fault-injection test |
| P0 | XR enter/exit 100 cycles | stereo frames each session, restored viewport, no stale inputs/resources | prior IWER smoke covers GL lifecycle; repeated-cycle suite still needed |
| P1 | Background/resume, resize, input churn | rendered recovery, stable resources, no runaway reload | separate scripted scenarios still needed |
| P1 | Browser/device matrix | pinned Chrome/Edge desktop plus headset browsers and OS versions | desktop screen first; headset deferred |
| P1 | Network/startup failure | meaningful error, retry succeeds, cache/version consistency | existing startup gates; offline/throttled matrix still needed |

The smallest next implementation is a shared deterministic scene plus engine render-heartbeat/CPU metrics adapters, followed by Babylon/PlayCanvas versions of that same scene. Keep this tooling in the demo repository; only introduce engine patches if a required metric cannot be obtained at project/JavaScriptBridge level. Headset behavior and tuned interaction values must stay unchanged until measured on-device.
