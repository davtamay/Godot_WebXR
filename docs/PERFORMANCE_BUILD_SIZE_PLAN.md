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

## Godot Web Export Optimizer Track

This should be split into two deliverables:

1. **Project/addon tooling** for export hygiene, content manifests,
   compression reports, chunk manifests, and CI checks. This belongs in a
   reusable Godot editor plugin/addon so any project can adopt it without
   rebuilding Godot.
2. **Custom web export templates** for engine-level stripping. This is the
   Godot equivalent to the deepest Unity engine/code stripping path, but it is
   not just an addon: it requires building and maintaining custom templates for
   the exact Godot version and web feature set.

### Phase 0: Immediate Export Hygiene

- Use exclude-only export filtering instead of broad `all_resources` while the
  project still has dynamic script/preload dependencies.
- Exclude `tests/*`, previous `build/*` outputs, and browser probe pages.
- Keep probe pages and benchmark overlays outside the runtime pack unless a
  specific build target requests them.
- Record raw `.wasm`, `.js`, `.pck`, image, audio, gzip, and Brotli sizes for
  every web export.

Current spike result after switching the Web preset to safe exclude-only export:

| Build | PCK size | Notes |
|---|---:|---|
| Previous broad export | 314,852 bytes | Included non-runtime project files. |
| Selected `res://scenes/Main.tscn` export | 84,560 bytes | Too aggressive: world UI and model-hand dependencies were missing on Quest. |
| Safe exclude-only export | 97,360 bytes | Tests, probe pages, and old build names absent from the PCK string scan; UI and hand dependencies present. |

The `.wasm` remains the stock engine/template payload; reducing it belongs to
the custom-template phase, not content filtering.

### Phase 1: Smart Export Manifest Plugin

Create an editor plugin command that:

- Starts from configured entry scenes.
- Traverses scene dependencies, script preloads, exported `Resource` fields,
  custom shell references, and declared runtime-load manifests.
- Writes `export_presets.cfg` selected-scene/selected-resource entries.
- Proves generated manifests on device before replacing safe exclude-only mode.
- Fails CI if `tests/`, `build/`, probe pages, editor-only tools, or old export
  artifacts would enter a web release pack.
- Generates a size report before and after compression.

This mirrors Unity's practical workflow advantage: make the optimized path the
default path, not a checklist everyone remembers manually.

### Phase 2: Streamed Content Chunks

For larger environments, keep the startup PCK small:

- Put only bootstrap, XR interaction core, shell UI, and the first space in the
  main export.
- Put future environments, tutorial rooms, heavy assets, audio, and optional
  samples into separately hosted packs or scene chunks.
- Load chunks explicitly after the first interactive frame and cache them via
  browser/CDN semantics.

### Phase 3: Custom Web Export Templates

Build custom Godot web templates only after Phase 0-2 measurements show the
stock `.wasm` is the dominant problem. Track:

- Godot source revision and build command.
- Disabled modules/features.
- Required web features: WebXR, WebGL2, multiview support, audio, fetch,
  threads if enabled.
- Compatibility matrix across Quest Browser, desktop Chrome/Firefox, and any
  Android XR browser under evaluation.
- Template rebuild cost whenever Godot changes.

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

## Measured findings — material inspector build (2026-07-07)

Measured, not assumed. The web download for the material inspector build:

| Chunk | Size | What it is |
|---|---|---|
| `index.wasm` | 37.7 MB | Godot engine runtime (fixed by the stock export template) |
| `index.pck` | 25.0 MB (uncompressed) → **13.3 MB (Basis)** | 18 material textures (1024², one 2048² normal) + scenes/scripts |
| `index.js` | 0.3 MB | loader |
| **total** | **62.9 → 51.2 MB** | (no transport compression) |

### Texture compression (the cheap pck win — DONE)

`gltf/embedded_image_handling` on `MaterialCollection.glb`:
- `3` = Embed Uncompressed (raw): **lossless**, 25.0 MB pck. This is the committed
  default because it preserves the Blender↔Godot 1:1 parity comparison.
- `2` = Embed as Basis Universal (GPU-transcoded, ETC1S): **lossy**, **13.3 MB pck**
  (−12 MB). The direct analog of Unity's Crunch/ASTC texture compression.

Decision: the repo stays lossless (parity default = the "revert to 1:1" state);
the deployed *inspector* build is a Basis variant (set embed=2, reimport, export,
then `git checkout` the `.import` back). Texture compression is BUILD-TIME, so a
runtime "revert to parity" button is not possible without shipping both texture
sets; the practical revert is the lossless default build. A true runtime toggle
would need Phase 2 streamed chunks (ship Basis in the main pck; load a lossless
`parity_override.pck` on demand via `ProjectSettings.load_resource_pack`).

### "Strip project code" — what it does and does NOT do here

Unity's size magic is largely **managed (C#/IL) code stripping + IL2CPP**. Godot
has no equivalent worth doing at the project layer: GDScript compiles to compact
bytecode inside the pck (kilobytes), so "stripping project code" saves ~nothing.
The 37.7 MB is the **engine wasm**, and the only lever that shrinks it is a
**custom export template** that strips unused *engine modules* (Phase 3) — this is
the real Godot analog of Unity's stripping.

### Custom stripped export template — generalization + safeguards (Phase 3 detail)

Approach (build Godot from source with scons + emscripten):
- Disable modules the project provably does not use, e.g.:
  `module_mono_enabled=no module_csg_enabled=no module_gridmap_enabled=no
  module_navigation_enabled=no module_webrtc_enabled=no module_multiplayer_enabled=no
  module_camera_enabled=no module_mobile_vr_enabled=no module_raycast_enabled=no`
  plus `optimize=size lto=full disable_3d=no` (we DO use 3D). Expect the wasm to
  drop meaningfully (Unity-style), at the cost of a per-Godot-version custom build.

Safeguards against stripping something we use (the key risk):
1. **Start from the full template, remove one module at a time**, re-running the
   gate after each — never a blanket strip.
2. **Gate = the existing headless suite (194 checks) + a scene-load pass over every
   demo/sample scene + a web export**. If a disabled module is actually used, a
   scene fails to load or a test fails — the CI gate catches it before ship.
3. **Maintain a `USED_MODULES.md` allowlist** derived from what the project
   instantiates (XR, GLTF, WebXR, physics 3D, text/Label3D, etc.); disable only
   modules absent from it.
4. **Keep the stock template as the fallback** and diff runtime behavior
   (screenshot/parity) between stock and stripped builds before adopting.
5. **Automate**: a `build_web_template.sh` (module flags + gate) so the template
   is reproducible and re-runnable on Godot upgrades, not a one-off artifact.

### Bottom line (no transport compression)

- pck: texture compression gives ~12 MB (done). ~19% of the total.
- wasm: only a custom stripped template touches the 37.7 MB (Phase 3, high effort).
- The single highest-ROI lever remains **Brotli/Gzip transport compression**
  (~4× on the wasm, near-zero effort) — deferred by choice, but it is precisely
  what makes Unity web builds "load faster." Revisit first when ready.
