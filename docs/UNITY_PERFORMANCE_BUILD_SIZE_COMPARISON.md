# Unity vs Godot Web Performance and Build Size Comparison

## Purpose

Leadership will ask whether Godot is actually lighter, faster, or cheaper to operate than Unity. This document defines how to answer that honestly.

The answer must come from a benchmark, not vibes. Web performance and package size vary heavily by engine version, renderer, exported scenes, compression settings, build flags, shader variants, asset imports, texture formats, and hosting configuration.

## Executive truth statement

Godot is not automatically faster or smaller than Unity on the web. Unity is not automatically heavier in a way that matters to users. The meaningful product metric is:

```text
Time from opening the URL to useful interaction in a headset/browser,
while maintaining stable XR frame timing and acceptable visual quality.
```

Raw build size matters, but it is only one part of the web experience. A smaller build that decompresses slowly, initializes slowly, stutters in XR, or lacks visual quality can be worse than a larger build with better streaming, profiling, and asset management.

## What must be measured

For both Godot and Unity, capture the same metrics on the same hardware, browser, network, and scene content.

### Package/build metrics

| Metric | Why it matters |
|---|---|
| Total raw export size | Shows actual hosted footprint before compression. |
| Total gzip/brotli size | Closer to CDN/browser download cost. |
| Largest files | Identifies WASM/data/PCK/texture bottlenecks. |
| WASM/JS/framework size | Measures engine/runtime overhead. |
| Asset/data size | Measures content footprint. |
| Number of requests | Affects loading and CDN behavior. |
| Release build time | Affects iteration and CI cost. |
| Development build time | Affects developer workflow. |

### Startup metrics

| Metric | Why it matters |
|---|---|
| Time to first byte | Hosting/CDN/server baseline. |
| Time to first paint | Whether the page feels alive. |
| Time to capability panel | Browser shell responsiveness. |
| Time to app load complete | Engine/runtime startup. |
| Time to first interactive frame | Main user-perceived metric. |
| Time to Enter XR available | XR UX readiness. |
| Time to immersive XR frame | Headset launch performance. |

### Runtime metrics

| Metric | Why it matters |
|---|---|
| Average FPS | Basic performance signal. |
| p95 / p99 frame time | XR comfort depends on consistency, not just average FPS. |
| Long frames / hitches | Identifies shader compilation, GC, asset loading, or CPU spikes. |
| Draw calls | Stereo rendering magnifies render submission cost. |
| Triangle count | Helps compare scene complexity. |
| Texture memory estimate | Web browser memory is constrained. |
| JS heap / WASM heap trend | Detects leaks and memory pressure. |
| Browser console errors/warnings | WebXR/WebGL/WebGPU support frequently fails noisily. |

## Required benchmark scenes

### Scene A: Empty baseline

Purpose: measure engine/runtime overhead.

```text
- Empty scene
- One camera
- One basic UI label
- No imported assets
- Release export
```

### Scene B: Product slice

Purpose: measure realistic product cost.

```text
- Same optimized glTF environment in Godot and Unity
- Same texture resolution targets
- Similar baked lighting strategy
- One interactable object
- One floating UI panel
- One XR interaction path
- Same canvas resolution / device pixel ratio
- Same target browser/headset
```

### Scene C: Stress ramp

Purpose: find breaking points.

```text
- Increment draw calls
- Increment texture size/count
- Increment dynamic lights
- Increment skinned/animated objects if needed
- Record the first point where XR frame timing fails
```

## Apples-to-apples rules

The benchmark is invalid unless:

```text
- Both engines use release/non-development builds.
- Both exports use comparable compression.
- Both scenes use the same or equivalent assets.
- Texture sizes and import compression are documented.
- Browser cache is cleared between cold-load tests.
- Warm-load tests are reported separately.
- Desktop browser and headset browser are reported separately.
- WebGPU detection is not counted as Godot WebGPU rendering.
- Unity WebGPU is reported separately from Unity WebGL2 because Unity marks WebGPU as experimental.
```

## Expected tradeoffs before measurement

### Where Godot may win

```text
- Lower licensing exposure.
- Source access.
- Simpler stock runtime for small projects.
- No C#/.NET runtime in standard GDScript web export.
- Custom source/export-template path if the company wants deep control.
- Company can build exactly the validator/export workflow it needs.
```

### Where Unity may win

```text
- Mature Web build pipeline.
- C# continuity for existing Unity engineers.
- URP/SRP Batcher/Addressables/Profiler ecosystem.
- Better established production optimization workflows.
- Larger ecosystem of web/mobile/XR production knowledge.
- Unity currently exposes an experimental WebGPU path; Godot does not render through WebGPU on web today.
- Lower short-term delivery risk if the existing product/team is already Unity-based.
```

### Where Godot likely sacrifices

```text
- Web rendering path is WebGL2 Compatibility, not Forward+/Mobile/WebGPU.
- C# Godot 4 web export is not currently the path.
- More internal responsibility for browser compatibility testing.
- More internal responsibility for export/template/build automation if custom templates or GDExtension-on-web are used.
- Smaller ecosystem for production WebXR compared with Unity or browser-native JS engines.
```

### Where Unity sacrifices

```text
- Proprietary pricing and policy exposure.
- Less source-level control.
- Deeper vendor lock-in.
- Potentially heavier production/editor stack than needed for focused browser XR products.
- Experimental status and browser support caveats for WebGPU.
```

## Decision matrix

| Category | Godot WebGL2/WebXR | Unity WebGL2/WebXR | Unity WebGPU | Browser-native WebGPU engine |
|---|---|---|---|---|
| Licensing/source control | Strong | Weak/Medium | Weak/Medium | Strong/Medium |
| WebXR demo feasibility | Medium | Medium/High | Medium | High |
| WebGPU rendering today | No | No/default | Experimental | Strongest |
| Build-size control | Medium/High with custom templates | Medium with stripping/settings | Medium/Unknown | High |
| Short-term team productivity | Medium | High if Unity team | High if Unity team | Medium/Low |
| Long-term platform control | High | Low | Low | High/Medium |
| Graphics ceiling in browser | Medium | Medium/High | Higher but experimental | Highest web-native path |
| Maintenance ownership | Medium → Very high if forked | Low/Medium | Medium/High | Medium/High |

## Benchmark deliverable format

Fable should produce a table like this:

| Engine | Version | Graphics API | Scene | Raw size | gzip size | brotli size | Cold TTI | Warm TTI | Avg FPS | p95 frame | p99 frame | Notes |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Godot | 4.7 | WebGL2 Compatibility | Empty | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Godot | 4.7 | WebGL2 Compatibility | Product slice | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Unity | TBD | WebGL2 | Empty | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Unity | TBD | WebGL2 | Product slice | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Unity | TBD | WebGPU Experimental | Product slice | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Go/no-go interpretation

### Godot is promising if:

```text
- WebXR startup works reliably on target devices.
- Product-slice cold load is acceptable.
- Frame timing is stable in headset.
- Visual quality is acceptable under WebGL2 Compatibility.
- Team can build needed tooling without source patches.
- The maintenance cost is mostly plugins/shell/templates, not renderer ownership.
```

### Unity remains stronger if:

```text
- Godot WebGL2 visual ceiling fails the product need.
- Godot WebXR support is unreliable on target devices.
- The company must use C# for web delivery.
- Existing Unity pipeline reaches target quality/performance faster.
- WebGPU is mandatory immediately and Unity experimental WebGPU is acceptable to the business.
```

### Browser-native WebGPU should be considered if:

```text
- WebGPU is mandatory for product quality.
- The app is more web product than engine/editor product.
- A JS/TypeScript rendering stack is acceptable.
- The team can own more application architecture and less engine-editor workflow.
```
