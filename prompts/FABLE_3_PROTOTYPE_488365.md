# Fable Prompt — 488365 Prototype

Do this only after 488360 research is reviewed.

## Goal

Build a minimal tangible Godot WebGL2/WebXR feasibility demo.

## Constraints

- Use stock Godot 4.7 first.
- Do not fork Godot.
- Do not modify Godot source.
- Use Compatibility renderer.
- Use Web export.
- Use WebXRInterface.
- Use a custom HTML shell.
- Use JavaScriptBridge only where appropriate.
- Include browser feature detection for WebGL2, WebXR, immersive-vr, immersive-ar, WebGPU adapter availability, SharedArrayBuffer, and crossOriginIsolated.
- Do not claim Godot is rendering through WebGPU.

## Demo requirements

1. Load a simple optimized 3D scene.
2. Show a browser capability panel before launch.
3. Show a Start App button.
4. Start Godot web app.
5. Start WebXR session through Godot WebXRInterface.
6. Support one simple interaction: ray select, gaze select, or object inspect.
7. Display performance stats: FPS/frame time at minimum.
8. Document browser/device test results.

## Starter files

Use or adapt:

- `prototype_starter/web_shell/company_webxr_shell.html`
- `prototype_starter/gdscript/browser_capabilities.gd`
- `prototype_starter/gdscript/webxr_bootstrap.gd`
- `prototype_starter/server/serve_with_headers.py`

## Deliverables

- Godot project
- custom HTML shell
- feature detection script or embedded shell detection
- build/export instructions
- known limitations
- screenshots/video capture if available
- test matrix

Additional required benchmark work:

After the Godot demo runs, create a repeatable performance/build-size measurement plan. If Unity is installed and available, build the closest equivalent Unity WebGL2 baseline. If Unity is not available, create the Unity build checklist and measurement harness so the team can run it.

Measure:
- uncompressed exported folder size
- gzip size
- Brotli size if Brotli CLI is available
- largest file
- WASM/framework size
- data/resource pack size
- request count
- startup timing
- time to first rendered frame
- time to interactive
- WebXR startup time
- FPS/frame-time p50/p95/p99 where possible

Output:
- reports/final-benchmark-summary.md
- reports/build-size-godot-stock.json
- reports/build-size-unity-webgl2.json if Unity build is available
- notes on what visual/graphics sacrifices were required
- recommendation on whether Godot is viable for the product class


Additional benchmark requirement:
- Run `prototype_starter/tools/measure_web_build.py` against the Godot export.
- If a Unity baseline is available, run the same size measurement against Unity's web export.
- Capture startup timing from shell load to first interactive frame.
- Capture a 60-second runtime frame-timing sample where possible.
- Report cold-cache and warm-cache results separately.
- Do not compare Unity WebGPU to Godot WebGPU unless Godot actually renders through WebGPU; Godot Phase 1 is WebGL2 Compatibility with WebGPU detection only.

Output files to create:
- research/performance_results/summary.md
- research/performance_results/godot_build_size.json
- research/performance_results/unity_build_size.json, if Unity baseline exists
- research/performance_results/runtime_metrics.csv or JSON


## Spec Challenge Protocol

Read `docs/SPEC_CHALLENGE_PROTOCOL.md`. You are encouraged to challenge the spec if you find a better, cheaper, more maintainable, more performant, or more honest path. Do not silently change scope. Produce a Spec Challenge Proposal with evidence, tradeoffs, maintenance impact, rebase impact, and smallest prototype. Maintain `docs/INNOVATION_BACKLOG.md` and `docs/DECISION_LOG.md` when relevant.

Hard boundaries remain: no false Godot WebGPU rendering claims, no Phase 1 renderer/backend work, no Phase 1 Godot source modifications without approval, and no skipping ecosystem inventory or benchmark evidence.
