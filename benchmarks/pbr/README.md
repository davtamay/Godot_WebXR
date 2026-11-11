# Canonical PBR benchmark and common timing scopes

This isolated desktop workload compares engine execution of the same textured GGX metallic/roughness shader, not the quality/features of built-in PBR materials. The shared manifest contains identical sphere geometry, normals, UVs, texture bytes, six material settings and 24/96/384-object layouts. Two directional radiance vectors, Schlick Fresnel, GGX distribution, Schlick-GGX masking, energy-conserving Lambert diffuse, Reinhard mapping and sRGB output are explicit. No shadows, IBL, transparency, MSAA or instancing. Godot's engine output conversion supplies sRGB; the WGSL adapters encode it explicitly. Image validation is mandatory.

CPU scope: Chrome SystemInfo.getProcessInfo renderer-process CPU deltas (all renderer threads, including workers), divided by engine-rendered frames in the observation window. This includes engine, browser renderer and harness work; it is not isolated render-method wall time. Browser/GPU/utility process CPU is excluded. Primary CPU comparisons use --profile off. Process identity changes or unavailable counters fail. Window-boundary control calls add small overhead, so use multi-second windows and repetitions; do not infer CPU p95 from the process aggregate.

GPU scope: identical timestamp brackets around each application GPUQueue.submit, summing command-buffer execution intervals per engine frame. This includes all application command buffers in each submit, unlike engine-specific profiler boundaries. It excludes queue.write* uploads preceding submit, idle time between submits, compositor/presentation and profiler readback copies after the end marker. Browser timestamp quantization remains visible; zero is below resolution, not free rendering. Every submission must have a resolved measurement; missing samples, pool exhaustion, reversed timestamps or mapping failures fail. No native engine GPU profiler is enabled. Profiling adds empty marker passes and asynchronous readbacks; paired off/on runs expose observer cost.

Validation thresholds declared before results: exact requested draw counts, stable renderer processes, positive CPU delta, complete timestamp coverage in on mode, zero captured errors, complete Godot provenance, geometry silhouette IoU >=0.999, and foreground normalized RGB RMSE <=0.02 across engines. Differences outside those thresholds require investigation; do not silently relax gates or declare a winner.

Dependencies remain pinned to the existing Babylon.js 9.35.0 and PlayCanvas 2.24.0 lock. node_modules is linked to ../matched/node_modules locally; npm ci --ignore-scripts can install it independently. Link godot_webgpu from the validated isolated suite into godot/addons. Source generator: python benchmarks/pbr/generate.py. Import, commit source, then export with tools/export-web-matrix.py using the existing validated editor/templates and both Tint binaries. The engine and Monday snapshots are unchanged.

Set GODOT_WEBGPU_TESTBED to the Playwright testbed. Run node benchmarks/pbr/run.mjs --out <results> --profile both. This alternates on/off order by repetition and rotates engine order. No headset testing or overall renderer ranking is implied.

The grid keeps approximately constant screen coverage while raising draw/vertex work: 24, 96 and 384 draws with 1,024 indexed triangles each (including degenerate pole triangles). It does not increase fill rate with count. All engines disable back-face culling for this canonical shader. Godot bakes FP16 and FP32 variants and selects according to device support; shader binaries/precision are not identical across engines, so visual equivalence is tested rather than presumed.

Reproduction and acceptance:

1. Run `node benchmarks/pbr/test-scope.mjs` for positive/negative timestamp controls.
2. Export both variants, then run `python tools/compare-thread-packs.py benchmarks/pbr/build/Web/index.pck benchmarks/pbr/build/WebThreads/index.pck`.
3. Run `node benchmarks/pbr/run.mjs --counts 24,96,384 --repeats 5 --seconds 5 --warmup 3 --profile both --out <results>` with no other GPU benchmark running.
4. Run `python benchmarks/pbr/verify.py <results>` and `python benchmarks/pbr/summarize.py <results>`. Do not use results that fail either gate.
5. Separately run `node benchmarks/pbr/calibrate.mjs <calibration.json>` to check that real GPU timestamps distinguish empty command buffers from sustained compute work. Never run this concurrently with the matrix.

The report uses medians of five independent observation windows. GPU sample counts are submissions, not frame-time percentiles. The extra marker passes and readbacks can affect GPU scheduling; profiling-off CPU controls quantify CPU observer cost but do not remove GPU observer cost. Tiny GPU differences near browser timestamp resolution must not be ranked as meaningful speedups. This remains a desktop/headless scene test, not a headset, native-material completeness, or end-to-end frame-latency result.

Renderer-process CPU totals measure work across threads, not latency. They can exceed elapsed wall time when threads execute concurrently; a threaded build's CPU total alone does not establish its frame-rate advantage or disadvantage.

## Isolated CPU follow-up

`run-paired.py` alternates preserved baseline and candidate builds for each count, repetition and profiling mode. It rotates thread-mode order and uses the same scene, audio behavior, browser settings and observation duration. `verify-paired.py` requires pixel-identical output against the preserved baseline, complete GPU samples, frame-callback coverage and the expected engine revisions. The initial comparison uses baseline 2f3fd8aa21 and candidate 3130ee0622.

Optional diagnostics in `run.mjs`:

- `--cpuProfile`: Chrome sampling profile of the page; diagnostic overhead makes these runs unsuitable for performance claims.
- `--browserTrace`: browser-thread activity, written separately; also diagnostic only.
- `--commandAudit`: records commands in each submission to check whether submissions are truly empty.
- `--frameTiming`: records wall time inside frame callbacks that actually render an engine frame. This is separate from renderer-process CPU and includes waits within the callback. Timestamp resolution differs with cross-origin isolation; compare baseline/candidate within the same mode.
- `--audioControl suspended`: explicitly suspends captured AudioContexts after startup. This is an attribution control, not an engine optimization or a production setting. Primary optimization comparisons retain normal audio.
- `--buildDir`: serves an explicitly selected export directory without overwriting prior measured artifacts.

The baseline browser trace found a real audio worklet contribution in this silent scene. Claude's older xbench results use frame-callback time, native PBR materials, lights/shadows and much higher object counts; batch mode also exercises automatic draw merging. Do not compare those results directly with process-wide CPU totals or present either fixture as a universal engine ranking. Preserve the shader-error notes present in the older xbench logs.
