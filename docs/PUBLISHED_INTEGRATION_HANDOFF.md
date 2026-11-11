# Published demo integration and Claude coordination

The demo consumes XR Suite from https://github.com/davtamay/godot-xr-suite.
setup.ps1 pins the validated suite commit 4dcbceeb0c57f92c8b952021a18cd0f3de67bf15
(XR Suite 1.45.0) so a fresh checkout is reproducible. Bump that pin deliberately
when validating a newer suite. Addons remain linked from their single source;
do not copy/fork them into the demo.

This integration includes aligned threaded/single-threaded export presets,
build provenance, explicit WebGL/WebGPU selection and runtime/GPU-depth reports.
The matching validated engine candidate is codex/runtime-error-cleanup at 7ee03402ba.
Keep the engine's linear patch-stack/upstream-sync protocol; this demo change
must not rewrite engine or Monday candidate refs. Full Closure and desktop XR
checks are distinct from deferred Quest 3/Galaxy XR headset validation.

The default branch here is feature/xr-interaction-toolkit-addon. Subsequent demo
work should start from its published head, not reapply the P0/depth commits.
Preserve uncommitted work in the original local checkout. The separate publish
worktree is used for clean export validation and promotion.
