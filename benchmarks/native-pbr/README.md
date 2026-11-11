# Native PBR regression workload

The three xbench Godot source files and shared callback timer are copied from the existing local C:/ws/xr/testbed workload used for Claude's November 7 benchmark. They preserve the scene, material definitions and seeded generation. The new project configuration selects Forward+ and the complete current WebGPU bake. This is a separate workload from benchmarks/pbr's canonical shared shader.

Export with tools/export-web-matrix.py, using the godot_webgpu addon from the pinned XR Suite checkout. Copy godot/xbench_timer.js beside each exported index.html. Run `node benchmarks/native-pbr/run.mjs <exports-root> <results-dir>` to check batched/unique rendering in both thread modes. Every browser or engine console error fails; null shaders are not ignored. The screenshots and complete console are retained.

The default 500-object check is correctness coverage, not a performance ranking. Historical shader errors must not be carried forward as a tolerated baseline. Build source and compiler identities belong in the export manifests; retain the original historical logs separately.
