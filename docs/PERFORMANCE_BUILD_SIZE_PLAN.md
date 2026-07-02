# Performance and Package Size Benchmark Plan

## Purpose

This benchmark exists to answer the question leadership will ask immediately:

> If we move from Unity to Godot for browser XR, what happens to load size, runtime performance, graphics quality, and maintenance cost?

Do not answer this with assumptions. Answer it by building the same reference scene in Godot and Unity, exporting both, measuring both, and documenting what was sacrificed to get the result.

## Required truth boundary

The Phase 1 Godot demo is a **Godot WebGL2 Compatibility renderer + WebXR** app. It may detect WebGPU in the browser, and it may include a separate WebGPU benchmark, but it must not claim Godot is rendering through WebGPU.

Godot 4 web export uses WebAssembly and WebGL2, and Godot 4 web export uses the Compatibility renderer. Godot Forward+/Mobile are not supported on web because Godot does not currently support WebGPU for web exports.

Unity can be used as the baseline because Unity has a mature Web export path, C# workflow, and WebGL build optimization settings. Unity also has experimental WebGPU support in recent Unity versions, but WebGPU should be treated as experimental and device/browser-dependent unless proven on the target device matrix.

## What to compare

Build the same visual/product slice in both engines:

1. Godot 4.7 standard build, WebGL2 Compatibility renderer, WebXRInterface.
2. Unity Web export, WebGL2 baseline.
3. Optional Unity WebGPU experimental export if the installed Unity version supports it.
4. Optional browser-native WebGPU comparison using Babylon.js, PlayCanvas, Three.js, or raw WebGPU.

The comparison must use the same or equivalent assets:

- same environment scale
- same texture resolutions
- same triangle budget
- same number of interactable objects
- same UI complexity
- same lighting target
- same audio target if audio is included
- same browser/device matrix

## Metrics

### Package/build-size metrics

Measure both raw and compressed output:

| Metric | Why it matters |
|---|---|
| Total exported folder size, uncompressed | Shows local build footprint |
| Total network transfer size, gzip | Common web server compression baseline |
| Total network transfer size, Brotli | Best practical web compression case |
| Largest single file | Large WASM/data files block startup |
| WASM size | Engine/runtime payload cost |
| JS loader/framework size | Browser startup overhead |
| Data/resource pack size | Asset payload cost |
| Texture payload size | Usually the largest controllable cost |
| Audio payload size | Can dominate if not compressed/streamed |
| Number of requests | Affects startup waterfall |
| Cached repeat-load size | Shows real repeat-user behavior |

### Runtime performance metrics

| Metric | Why it matters |
|---|---|
| Time to first byte | Hosting/network baseline |
| Time to first app shell | User sees progress |
| Time to first rendered frame | First visual feedback |
| Time to interactive | Real usability |
| Time to WebXR session start | XR entry friction |
| FPS | Basic health metric |
| Frame time p50/p95/p99 | XR comfort depends on consistency |
| Long frames over 16.6 ms / 11.1 ms | 60Hz/90Hz comfort risk |
| JS heap / WASM memory | Browser memory pressure |
| Draw calls | Stereo rendering multiplies cost |
| Triangle count | Geometry budget |
| Texture memory estimate | GPU pressure |
| CPU main-thread time | Browser bottleneck indicator |
| GPU timing if available | Graphics bottleneck indicator |

### Quality metrics

| Metric | Why it matters |
|---|---|
| Lighting parity | WebGL2 may require baked/static lighting compromises |
| Shader/material parity | Some Unity/Godot/native materials will not survive web unchanged |
| Transparency correctness | Common web/mobile rendering problem |
| Post-processing parity | WebGL2 budgets are tighter |
| UI readability in XR | Product usability |
| Controller/gaze interaction quality | XR viability |
| Audio latency/feature parity | Web exports often differ from native |

## Required build variants

### Godot variants

1. **Godot stock single-threaded web export**
   - First feasibility target.
   - Best compatibility baseline.
   - Lower runtime performance ceiling than threaded.

2. **Godot threaded web export**
   - Only if hosting can provide required cross-origin isolation headers.
   - Measure the performance gain and deployment cost.

3. **Godot custom optimized export template**
   - Phase 2 only.
   - Disable unused modules/features if feasible.
   - Measure payload reduction and maintenance cost.

### Unity variants

1. **Unity WebGL2 release build**
   - Baseline Unity comparison.
   - Enable standard size optimizations where appropriate: high managed stripping, size-oriented IL2CPP settings, Brotli compression, disable debug symbols.

2. **Unity WebGPU experimental build**
   - Optional.
   - Use only if the installed Unity version supports it.
   - Keep WebGL2 fallback if broad compatibility is part of the requirement.
   - Document unsupported browsers/devices and visual differences.

## Measurement commands and artifacts

Fable should create scripts to produce a repeatable report.

Suggested local report format:

```text
reports/
  build-size-godot-stock.json
  build-size-godot-threaded.json
  build-size-unity-webgl2.json
  build-size-unity-webgpu.json
  runtime-chrome-desktop.json
  runtime-firefox-desktop.json
  runtime-quest-browser.json
  screenshots/
  videos/
  final-benchmark-summary.md
```

Suggested build-size script behavior:

- recursively scan exported build folders
- record file sizes
- compute gzip sizes
- compute Brotli sizes if Brotli CLI is available
- group files by extension: wasm, js, pck/data, textures, audio, html, symbols, other
- output Markdown and JSON

## Honest expected outcomes

### Godot may win on

- open-source licensing and source control
- simpler engine distribution story
- smaller/cleaner project architecture for the right product class
- no Unity-style pricing exposure
- easier company-specific editor/tooling customization
- lower fork risk if we stay in project/plugin/shell layers
- strong strategic ownership story

### Unity may win on

- mature production workflow
- C# team familiarity
- asset store/package ecosystem
- richer web optimization tooling
- existing enterprise support paths
- broader platform support
- mature native XR support
- faster production delivery if the team already uses Unity
- experimental WebGPU path available in newer Unity versions

### Godot sacrifices in Phase 1

- no Godot WebGPU renderer
- no Forward+/Mobile renderer on web
- no Godot 4 C# web export
- stricter graphics budgets
- more baked/static lighting
- more custom web shell ownership
- more browser/device testing ownership
- more internal tooling ownership

### Unity sacrifices

- proprietary vendor risk
- licensing/pricing exposure
- less source-level control
- less ability to modify engine/platform behavior freely
- larger organizational dependency on Unity roadmap and policies
- WebGPU still experimental and browser/device-dependent

## Decision rule

Do not decide based on ideology. Decide based on measured product fit.

Godot is a good candidate if:

- the Godot WebGL2/WebXR demo hits visual and interaction goals
- load size is acceptable after normal optimization
- runtime frame times are stable on target devices
- source modifications are not required for Phase 1
- most company value comes from plugins/templates/web shell, not core engine patches
- leadership values source control/no-royalty/open-source benefits enough to fund tooling ownership

Unity remains the better choice if:

- the same scene performs significantly better in Unity WebGL2/WebGPU
- C# web export is a hard requirement
- Unity WebGPU experimental support is required now
- Godot WebGL2 visual compromises are unacceptable
- the company cannot fund internal tooling/build/test ownership
- time-to-production matters more than licensing/source-control risk

## Final benchmark deliverable

The final output should be a leadership-readable report:

```text
Godot vs Unity Web Export Feasibility Report

1. Executive summary
2. Demo links/builds
3. Package size comparison
4. Startup timing comparison
5. Runtime performance comparison
6. WebXR support matrix
7. WebGPU status and caveats
8. Visual quality comparison
9. Engineering ownership comparison
10. Recommendation
```
