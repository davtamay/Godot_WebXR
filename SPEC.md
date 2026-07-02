# Godot Web Export / WebXR / WebGPU Feasibility Spec

## Executive recommendation

Proceed with a **Godot-first feasibility prototype**, but keep the promise precise:

> We will prove a browser-delivered Godot WebGL2/WebXR app using stock Godot 4.7, a custom HTML shell, JavaScriptBridge capability detection, and existing XR ecosystem tooling where appropriate. We will not claim Godot WebGPU rendering in Phase 1. WebGPU will be tracked through browser capability detection and, if needed, a separate browser-native benchmark.

The target architecture is:

```text
Official Godot upstream
→ company plugins/project templates
→ custom web shell + JavaScriptBridge
→ optional GDExtension/C++ modules
→ custom export templates
→ minimal source patches only when necessary
→ automated rebase/regression testing
```


## Spec challenge principle

This spec is the baseline plan, not the ceiling of the solution. Fable should challenge the plan when evidence shows a better architecture, cheaper maintenance model, stronger benchmark, or different engine recommendation. Any challenge must be documented with evidence, tradeoffs, maintenance impact, rebase impact, and the smallest prototype that can prove it. See `docs/SPEC_CHALLENGE_PROTOCOL.md`.

The goal is the best company decision, not defending the initial Godot plan.

## Why this path

Unity gives mature workflow but company leadership is concerned about pricing and proprietary control. Unreal has excellent graphics but is not the right browser-native WebGL/WebGPU export path. Godot gives source access, open-source licensing, a real editor, a strong community, built-in WebXR support, and a feasible browser export path. The tradeoff is that Godot’s current web renderer path is WebGL2 Compatibility, not WebGPU Forward+/Mobile.

## Phase 1 truth statement

Godot Phase 1 equals:

```text
Godot 4.7 standard build
+ Compatibility renderer
+ Web export templates
+ custom HTML shell
+ JavaScriptBridge browser capability detection
+ WebXRInterface startup flow
+ simple optimized 3D/XR scene
```

Godot Phase 1 does not equal:

```text
Godot Forward+ on web
Godot Mobile renderer on web
Godot compute shaders on web
Godot-rendered WebGPU
C# Godot 4 web export
```

## What “ultimate demo” means

The ultimate tangible demo should be a browser-hosted app that proves the path honestly:

1. Loads as a Godot web export.
2. Displays a browser capability panel.
3. Confirms WebGL2, WebXR, WebGPU, SharedArrayBuffer, and cross-origin isolation status.
4. Runs a Godot 3D scene in WebGL2 Compatibility renderer.
5. Allows an immersive WebXR session on at least one target headset/browser.
6. Provides one meaningful XR interaction: gaze select, controller ray select, grab, inspect, or UI press.
7. Captures performance metrics and device/browser results.
8. Optionally links to a separate WebGPU benchmark/comparison canvas.

The strongest leadership demo is not pretending WebGPU is solved. It is showing a real product slice, plus the exact remaining gap.

## In scope

- WebGL2 web export.
- WebXR runtime initialization.
- Browser feature detection.
- Custom HTML shell.
- JavaScriptBridge integration.
- XR Tools ecosystem inventory.
- Editor plugin/tooling feasibility.
- GDExtension and C++ module boundary investigation.
- Source modification map.
- Rebase strategy.
- Cross-platform browser/device test matrix.

## Out of scope for Phase 1

- Full WebGPU renderer backend.
- Forking the renderer.
- Making Forward+/Mobile work on web.
- Production migration from Unity.
- Production-grade asset pipeline.
- Production-grade hand tracking across all devices.
- Deep GDExtension-on-web dependency unless source research proves it is needed.

## Conceptual model

There are three runtime owners:

```text
Browser owns:
- HTTPS/security policy
- WebXR permission/session lifecycle
- WebGL/WebGPU availability
- user activation requirements
- headset/browser compatibility
- canvas/device context

Godot owns:
- scene tree
- resources/imports
- rendering through its supported backend
- input abstraction
- WebXRInterface integration
- physics/game loop

Company owns:
- product UX
- assets/performance budgets
- custom shell
- validation tooling
- build/export pipeline
- test matrix
- any fork/module/plugin maintenance
```

## Structural model

```text
godot-webxr-feasibility/
  godot/                       # optional upstream source checkout for Phase 2
  demo/                        # Godot project
  addons/                      # optional Godot XR Tools, company tools
  web_shell/                   # custom HTML shell and JS feature detection
  docs/                        # spec, evidence, matrices, decision records
  research/                    # repo inventory and source maps
  ci/                          # future export/rebase/test automation
```

## Runtime model

```text
User opens HTTPS page
→ custom shell checks WebGL2/WebXR/WebGPU/SAB/isolation
→ user clicks Start App
→ Godot WASM + PCK load
→ Godot scene starts in Compatibility renderer
→ user presses Enter XR in Godot UI or controlled startup scene
→ WebXRInterface requests immersive-vr/immersive-ar
→ browser grants/denies XR session
→ Godot sets viewport.use_xr = true
→ XR frame loop renders stereo through WebGL2
```

## Customization boundary

Use the lowest layer that solves the problem:

```text
Project code > editor plugin > custom HTML shell > JavaScriptBridge > GDExtension > C++ module > custom export template > source patch
```

A feature may move into source modification only when the report shows why the higher layers cannot solve it.

## Decision checkpoints

### Checkpoint 1

Can we build a useful Godot WebGL2/WebXR demo with zero Godot source modification?

### Checkpoint 2

Can we identify exactly what requires source modification, custom export templates, or upstream contribution?

### Checkpoint 3

Does Godot’s editor/community/source-control value outweigh the current web rendering limitations compared to Unity and browser-native engines?

## Success criteria

- Stock Godot web export runs.
- Custom HTML shell reports browser/device capabilities.
- WebXR support is detected.
- XR session starts on at least one target device/browser.
- Basic interaction works.
- Performance stats are captured.
- WebGPU is detected but not misrepresented.
- Existing ecosystem inventory is completed.
- Source modification map is completed.
- Leadership receives a clear go/no-go recommendation.



## Performance and package-size comparison

A major part of the feasibility work is comparing Godot against Unity honestly.

Do not assume Godot is smaller or faster. Do not assume Unity is heavier or better. Build the same reference scene and measure both.

The benchmark must compare:

```text
Godot 4.7 WebGL2 Compatibility + WebXR
Unity WebGL2 baseline
Optional Unity WebGPU experimental build
Optional browser-native WebGPU benchmark
```

Required package-size metrics:

- total exported folder size
- total gzip transfer size
- total Brotli transfer size
- largest single file
- WASM size
- JS loader/framework size
- PCK/data/resource size
- texture payload size
- audio payload size
- request count
- cached repeat-load behavior

Required runtime metrics:

- time to first app shell
- time to first rendered frame
- time to interactive
- time to WebXR session start
- FPS
- p50/p95/p99 frame time
- long frames over target frame budget
- memory usage
- draw calls
- triangle count
- approximate texture memory
- browser/device test results

Required quality metrics:

- lighting parity
- material/shader parity
- UI readability in XR
- interaction quality
- audio limitations
- browser/device compatibility

The final demo should produce a leadership-readable performance and build-size report, not just a runnable build.

See `docs/PERFORMANCE_BUILD_SIZE_PLAN.md` for the full benchmark plan.



## Performance and build-size comparison requirement

The feasibility decision must include a measured comparison against the current Unity baseline if a Unity baseline is available.

The comparison must not rely on anecdotal claims like "Godot is lighter" or "Unity is heavier." Both engines should be tested with:

```text
- release/non-development web exports
- the same or equivalent scene content
- the same texture/model budgets
- the same browser/device/network conditions
- raw and compressed build-size reporting
- cold-cache and warm-cache startup timing
- runtime frame timing in browser and headset where possible
```

Required metrics:

```text
total raw export size
gzip/brotli estimated transfer size
largest files
WASM/JS/runtime size
asset/data size
time to first paint
time to capability panel
time to engine loaded
time to first interactive frame
time to Enter XR
time to first immersive XR frame
average FPS
p95/p99 frame time
long frames over 50 ms
browser console errors/warnings
release build time
```

The meaningful product metric is not just package size. The meaningful product metric is:

```text
Time from opening the URL to useful interaction in the headset/browser,
while maintaining stable XR frame timing and acceptable visual quality.
```

See `docs/UNITY_PERFORMANCE_BUILD_SIZE_COMPARISON.md`, `docs/PERFORMANCE_BENCHMARK_PLAN.md`, and `prototype_starter/tools/measure_web_build.py`.

## Strategic outcome options

1. **Proceed with Godot WebGL2/WebXR** for product classes that fit web constraints.
2. **Proceed with Godot + browser-native WebGPU benchmark** when WebGPU graphics are strategically important.
3. **Continue Unity** where immediate production stability matters more than licensing/source control.
4. **Use Unreal Pixel Streaming** only for high-fidelity streamed experiences, not browser-native export.
5. **Invest in Godot source/upstream WebGPU** only after the demo proves Godot workflow is worth preserving and the business case justifies renderer/backend ownership.
