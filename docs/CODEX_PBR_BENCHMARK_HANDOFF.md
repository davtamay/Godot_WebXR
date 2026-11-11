# PBR benchmarks and common timing scopes — completed

Codex completed this batch on isolated local branch codex/pbr-benchmarks in C:/Users/davta/work/engine-demo-merge/demo. No engine or suite source changes were needed. No push/merge was performed. Preserve all Monday refs, published heads and original dirty checkouts. Read this before overlapping benchmark work; earlier PBR/common-timing TODOs are now completed for this canonical desktop workload.

## Implementation

benchmarks/pbr contains one manifest of indexed sphere geometry, UVs, texture bytes, six materials and 24/96/384 layouts; shared GGX/Schlick direct-lighting equations; Godot, Babylon.js 9.35.0 and PlayCanvas 2.24.0 adapters; common queue-submit GPU timing; renderer-process CPU deltas including workers; paired profiling-off CPU controls; image, draw, hosting and provenance validation. The image gate caught and led to fixing PlayCanvas texture/sampler binding declarations. The magenta background preserves black metallic silhouettes in image validation.

This compares execution of a shared PBR shader, not built-in PBR features/quality. No shadows, IBL, transparency, MSAA, instancing or XR. Grid screen coverage stays approximately constant while draw/vertex work increases. Godot bakes FP16/FP32; shader precision/binaries are not identical, so visual agreement is checked.

## Proven

120 runs passed: four engine/thread configurations, three counts, five repetitions, profiling off/on; 3-second warm-up and 5-second observation. Engine order rotates, profiling order alternates. All 120 images have silhouette IoU 1.0; maximum normalized foreground RGB RMSE 0.00350523 against a declared 0.02 limit. Correct draw counts, hosting mode and complete Godot provenance pass. All 14,426 profiled submissions resolve without missing/duplicate samples or captured WebGPU errors.

Eight positive/negative timing controls and three image controls pass. Separate real-GPU calibration (after the matrix): 12 empty submissions total 0 ms at browser resolution; 12 sustained compute submissions total 2.555904 ms. Threaded/single packs have the same 142 resources, excluding xr_build_provenance.json.

At 384 spheres, median renderer CPU ms/frame with profiling off: Godot single 2.982, threaded 2.362, Babylon 2.678, PlayCanvas 1.737. These are process CPU totals, not frame latency. GPU intervals are short/quantized: zero-sample fractions range roughly 11–84% by configuration. Do not claim a meaningful overall GPU ranking or best-in-class engine from this fixture.

## Identity and limits

Exact exports: demo a852fdbf214a8c0a4ec5233997494a20b413e87b; unchanged engine 2f3fd8aa21aea891bffef4558d4b60655641073c; suite d261d8cc9efd68faed57881344b632d80bce359d. Existing validated Closure templates were reused. Measured harness revision ff1d528; later validation/docs commits do not change runtime artifacts. Source hashes in summary.json match measured files. Generator is idempotent. Do not rebuild over the measured exports and call them the same artifacts.

CPU scope includes browser renderer/harness plus engine workers, excludes browser/GPU/utility processes. GPU scope brackets every application queue.submit and excludes queue.write uploads, inter-submit gaps, compositor/presentation and profiler readback copies after the end marker. Native GPU profilers are disabled. Marker/readback overhead remains; paired CPU controls quantify only its CPU component. Do not reuse earlier incompatible native-counter ratios as fair results.

Results and exact exports: C:/Users/davta/work/engine-demo-merge/pbr-results and demo/benchmarks/pbr/build. Deliverables: C:/Users/davta/Documents/Codex/2026-11-09/explore-and-compare-architectural-approaches-x20-2/outputs/PBR-benchmark-results.md and PBR-benchmark-manifest.json, raw data, source bundle and build archives. README has reproduction commands. Host is Chrome 157.0.8103.39, RTX 5080, Core Ultra 9 285K, Windows 11 Pro build 26200, Balanced power plan.

Monday remains engine 667765342213009c068e48d6ba6413e657bc3340, suite 5f7b6f60a3d1ed44a3728e9d9a61f4e54dbd2172, demo 6ffbe9de2461531ddacc712bc12bf4f5e1c3200b. Headset testing is deferred by the user. Native material breadth, heavier fill-rate scenes and other devices/browsers remain separate future evidence work, not failed gates for this completed batch.
