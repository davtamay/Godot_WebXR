# Cost and Tradeoff Model

## Executive framing

The Godot path is not “free Unity.” It shifts cost from vendor licensing to internal platform ownership.

The company should compare:

```text
Unity cost = licenses + vendor risk + limited source control + faster known workflow
Godot cost = no royalties + source control + internal tooling/testing/maintenance ownership
```

The correct decision is not which engine is ideologically better. The correct decision is which path gives the company the best long-term product economics for browser-delivered XR.

## What we gain with Godot

- Lower proprietary licensing exposure.
- Source access.
- Ability to build company-specific tools.
- Open-source/community ecosystem.
- Real editor workflow.
- Built-in WebXR interface.
- Path to upstream contributions instead of vendor lock-in.
- Ability to keep a thin company distribution instead of a black-box dependency.
- Lower legal/procurement friction for prototypes and internal tooling.

## What we sacrifice with Godot

### Rendering ceiling

Godot web export currently means WebGL2 Compatibility renderer. The cost is a lower browser graphics ceiling compared with native Godot Forward+/Mobile, Unity native/mobile, Unreal native, and browser-native WebGPU engines.

Practical sacrifices:

- no Godot Forward+ web path in Phase 1
- no Godot Mobile renderer web path in Phase 1
- no Godot-rendered WebGPU path in Phase 1
- no compute-shader-dependent design for Godot web
- more baked lighting
- stricter material budgets
- fewer dynamic lights
- fewer post-processing assumptions
- tighter draw-call/texture budgets
- more manual validation of assets intended for web

### Language/runtime

Godot 4 C# is not the right web export path. Use GDScript first, with C++/GDExtension/modules only where needed.

This is a major tradeoff for a Unity-heavy team because Unity’s C# workflow is one of its strongest advantages.

### Browser/XR constraints

- HTTPS/secure context requirements.
- User-activation requirements for immersive sessions.
- Browser-specific WebXR support differences.
- Device-specific controller/hand tracking differences.
- WebAssembly startup size and memory pressure.
- Cross-origin isolation/SharedArrayBuffer complications if threaded export is needed.
- WebXR feature variability across Quest Browser, desktop Chromium, Firefox, Safari/visionOS, and mobile browsers.

### Maintenance

The cost moves from license fees to engineering ownership.

Maintenance areas:

- export templates
- custom web shell
- browser compatibility testing
- Godot version upgrades
- plugin compatibility
- XR Tools compatibility
- CI/export automation
- optional GDExtension builds
- optional C++ modules
- optional source patches/rebase conflicts
- internal documentation and onboarding
- performance budget enforcement
- support for multiple deployment targets and hosting constraints

## What Unity still gives us

Unity remains very strong if the goal is production speed and proven workflow.

Unity benefits:

- mature editor and production workflow
- C# familiarity for the existing team
- large ecosystem and package/asset marketplace
- mature asset import and profiling workflows
- broad platform/export story
- strong native XR path
- established WebGL build optimization settings
- optional experimental WebGPU path in newer Unity versions
- less internal engine/tooling ownership if the team stays inside supported paths

Unity tradeoffs:

- proprietary pricing/licensing exposure
- limited engine/source/platform control compared with Godot
- roadmap and policy dependency
- potential vendor lock-in
- WebGPU support is still experimental and not universal
- WebXR/product behavior may still require plugins, browser glue, and custom web work

## Package size and performance: do not assume, measure

We should not claim Godot will be smaller or faster than Unity without measuring the same scene.

Both engines export a WebAssembly/browser runtime plus project data. Build size depends heavily on:

- engine version
- export template/build profile
- debug vs release
- threading mode
- compression mode
- asset payload
- texture formats
- audio compression
- included plugins/packages
- shader variants
- stripping/removal of unused code
- custom export template usage

### Likely pattern

Godot may have an advantage for small, focused projects if the project stays simple and especially if a custom optimized export template is used later.

Unity may remain competitive or better for large production teams because it has mature stripping, compression, profiling, content pipeline, and C# tooling.

The only valid answer for this company is a benchmark.

## Cost levels

| Level | Path | Value | Maintenance cost | Risk |
|---|---|---|---|---|
| 0 | Stock Godot project | Proves baseline | Low | Low |
| 1 | Custom shell + JSBridge + editor plugins | Company workflow and browser UX | Low/Medium | Low |
| 2 | XR Tools + validators + export automation | Reusable internal platform | Medium | Medium |
| 3 | Custom export templates / GDExtension web | More runtime power and size control | Medium/High | Medium/High |
| 4 | C++ modules / minimal source patches | Deep integration | High | High |
| 5 | Godot WebGPU renderer/backend | Strategic engine investment | Very High | Very High |

## Recommended investment boundary

Fund Levels 0–2 immediately for this sprint.

Investigate Level 3, but do not depend on it for the first demo.

Do not fund Levels 4–5 until the tangible demo proves Godot’s workflow and business value.

## Maintenance cost model

### Low ongoing cost

- stock Godot project
- GDScript demo
- custom HTML shell
- simple JavaScriptBridge capability detection
- documentation and manual test matrix

### Medium ongoing cost

- company editor plugins
- export preset generator
- asset validation plugin
- automated web export scripts
- XR Tools version tracking
- browser/device test scripts

### High ongoing cost

- custom web export templates
- web GDExtension builds
- source-built Godot distribution
- automated rebase testing
- company C++ modules

### Very high ongoing cost

- renderer backend patches
- WebGPU backend ownership
- shader pipeline changes
- XR compositor integration
- upstream merge conflict resolution in rendering/platform code

## Decision rule

Move forward with Godot if the demo proves product fit without source modification.

Stay with Unity for product lines where:

- C# web delivery is required
- Unity WebGPU experimental support is required immediately
- WebGL2 Compatibility visuals are unacceptable
- the team cannot absorb internal platform/tooling ownership
- time-to-market is more important than licensing/source-control risk


## Performance and package-size tradeoff

The company should not assume Godot wins or loses on package size without measurement.

### Honest expectations

- For very small prototypes, Godot standard web exports may feel simpler, but the fixed engine/WASM/PCK overhead is still real.
- For large product scenes, assets usually dominate size in both engines.
- Unity may have stronger mature tooling for profiling, Addressables, URP optimization, shader stripping, and team workflows.
- Godot may offer stronger ownership and custom-template control, especially if the company later chooses to build stripped export templates.
- Custom Godot export templates can reduce or specialize runtime footprint, but that creates build-system and upgrade ownership.

### Build-size cost categories

| Category | Godot | Unity |
|---|---|---|
| Engine/runtime overhead | WASM + JS + PCK/export template | WASM + framework JS + data files |
| Content payload | PCK/assets/resources | Data files/AssetBundles/Addressables |
| Compression | Server/CDN gzip/brotli; must be configured | Server/CDN gzip/brotli; must be configured |
| Stripping/minimization | Stock export first; custom templates later | Managed stripping, shader stripping, build settings |
| Iteration cost | Fast simple exports; custom templates add CI cost | Mature workflow; release optimization can add build time |

### Runtime performance cost categories

| Category | Godot WebGL2/WebXR | Unity WebGL2/WebXR/WebGPU |
|---|---|---|
| Graphics ceiling | WebGL2 Compatibility only | WebGL2 default; WebGPU experimental in current Unity docs |
| XR reliability | Must verify WebXRInterface on target browsers | Mature ecosystem, but WebXR path depends on packages/plugins/browser support |
| CPU/runtime | GDScript/C++ architecture must be profiled | C#/IL2CPP/WebAssembly pipeline, mature profiler support |
| Memory | Browser/WASM pressure; careful asset budgets | Browser/WASM pressure; Unity docs emphasize restricted memory environment |
| Startup | Must measure WASM/PCK load and initialization | Must measure framework/data/WASM load and initialization |

### Decision rule

Choose Godot for web products when:

```text
licensing/source control + custom platform ownership + acceptable WebGL2/WebXR performance
beats
Unity's mature tooling + C# workflow + existing team/product momentum.
```

Stay on Unity for a product when:

```text
Unity reaches the target visual quality, frame timing, and ship date materially faster,
and the licensing/policy risk is acceptable for that product.
```
