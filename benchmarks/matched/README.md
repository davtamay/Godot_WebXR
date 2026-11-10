# Matched 3D benchmark

Procedural, shared indexed geometry and JSON transforms; no third-party art. Babylon.js 9.35.0 and PlayCanvas 2.24.0 are pinned in package-lock.json. Install with npm ci --ignore-scripts. Do not commit node_modules or generated exports/results.

The initial workload isolates independent opaque unlit mesh submission (100, 1000, 5000 cubes), not PBR quality or XR. All adapters use the same vertices, indices, transforms, orthographic view, 1280x720 target, white objects, black background, no MSAA, no shadows and disabled culling. No explicit instancing/batching. Verify observed draw counts and screenshots before comparisons. Browser startup is not part of timed windows.

Godot uses RenderingServer viewport CPU/GPU measurements plus frame setup CPU, and frame_post_draw as the render heartbeat. Babylon measures scene.render CPU and EngineInstrumentation GPU timestamp counters. PlayCanvas uses AppStats cpuRenderTime and gpuFrameTime with GPU profiling enabled. These CPU scopes differ; never publish them as identical whole-engine CPU work. GPU values are asynchronous latest-completed samples, potentially repeated across adjacent callbacks. Missing/nonpositive GPU readings are null, never zero-cost measurements. Frame cadence is from engine callbacks, not a separate browser RAF loop.

Link only godot_webgpu from the isolated suite provenance branch into godot/addons; import with the validated editor. Commit source before exporting. Use tools/export-web-matrix.py --project benchmarks/matched/godot --editor <editor> --templates-dir <templates> --output benchmarks/matched/build. The helper restores preset bytes; schema-2 provenance verifies its sole controlled source mutation. Other dirty source still makes identity incomplete.

Set GODOT_WEBGPU_TESTBED to the existing Playwright installation and run node benchmarks/matched/run.mjs --out <results>. Default five counterbalanced repetitions per engine/count, five seconds warm-up and ten seconds sampling. GPU runs are serial. Raw samples, profiler scopes, screenshots, browser/GPU inventory, artifact provenance and dependency/workload hashes accompany summaries. A visual mismatch or unsupported metric invalidates the corresponding comparison, even if a page boots.

No engine patches, Monday sync changes or headset claims. This is an isolated desktop benchmark foundation; larger PBR scenes, long reliability soaks and XR lifecycle testing remain separate work.
