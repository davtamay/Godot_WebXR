# Godot WebXR / Web Export Feasibility Handoff

This repo packet is the source-of-truth handoff for Claude Fable 5 and ChatGPT collaboration.

## Mission

Evaluate whether Godot 4.7 can become a practical open-source alternative to Unity for browser-delivered interactive/XR experiences.

The intended path is:

```text
Official Godot upstream
→ company project templates/editor plugins
→ custom HTML shell + JavaScriptBridge
→ optional GDExtension/C++ modules
→ custom export templates
→ minimal source patches only when necessary
→ automated rebase/regression testing
```

## Hard technical boundary

Phase 1 targets **Godot WebGL2 + WebXR**, not a Godot WebGPU renderer.

WebGPU can be:

- detected from the custom web shell,
- reported in the browser capability panel,
- benchmarked in a separate browser-native canvas or separate Babylon.js/PlayCanvas/Three.js demo,
- tracked as a future Godot source/upstream renderer investment.

WebGPU must not be described as “working in Godot” unless Godot’s actual renderer is submitting through WebGPU.

## Immediate next action

Give Fable `prompts/FABLE_1_RESEARCH_488360.md` first.

Fable must research and fill the docs before implementing code:

- `docs/CUSTOMIZATION_MATRIX.md`
- `docs/EVIDENCE_LOG.md`
- `research/existing_repos_inventory.md`
- `research/godot_source_map.md`
- `docs/WEBGPU_BOUNDARY_NOTE.md`

Only then move to the prototype task.

## What to install/check before prototype

Required for Phase 1:

- Godot 4.7 standard build, not .NET, if targeting web.
- Godot 4.7 export templates.
- Git.
- Python 3 for local static serving and utility scripts.
- Chromium/Chrome and Firefox for desktop browser tests.
- A WebXR-capable headset/browser for real XR testing, ideally Quest Browser or equivalent.
- HTTPS-capable hosting for headset testing. Localhost works for many desktop secure-context APIs, but headset/browser device testing should use HTTPS.

Optional for Phase 1:

- Caddy or another simple HTTPS server.
- Node.js LTS only if creating a Babylon.js/PlayCanvas/Three.js WebGPU comparison.

Required only for source/custom template investigation:

- Godot source checkout.
- Emscripten SDK.
- Python 3.8+.
- SCons 4.0+.
- Platform C/C++ build tools.

## Important files

- `SPEC.md`: full architecture and sprint plan.
- `CLAUDE.md`: instructions Claude/Fable should load at project start.
- `tasks/`: Jira-ready task specs.
- `prompts/`: copy/paste prompts for Fable and ChatGPT review.
- `prototype_starter/`: custom HTML shell and GDScript starter code.


## Added benchmark focus

- `docs/PERFORMANCE_BUILD_SIZE_PLAN.md` defines the required Godot-vs-Unity package-size and runtime-performance benchmark.
- `docs/COST_TRADEOFFS.md` now includes a more explicit Unity benefits/tradeoffs section and maintenance cost model.


## Added comparison docs

- `docs/UNITY_PERFORMANCE_BUILD_SIZE_COMPARISON.md` — honest Godot vs Unity web performance/build-size tradeoffs and measurement plan.
- `docs/PERFORMANCE_BENCHMARK_PLAN.md` — benchmark procedure and output schema.
- `prototype_starter/tools/measure_web_build.py` — engine-neutral web export size measurement script.
- `prototype_starter/tools/runtime_metrics_overlay.js` — lightweight browser runtime timing helper.

## Spec Challenge Protocol

This workspace includes `docs/SPEC_CHALLENGE_PROTOCOL.md`. Fable should use it to propose better ideas, challenge assumptions, compare Godot against browser-native WebGPU engines or Unity baselines, and document pivots without silently changing scope.

Hard boundaries remain: do not claim Godot WebGPU rendering without source-level evidence, do not start Phase 1 renderer/backend work, and do not modify Godot source without explicit approval.
