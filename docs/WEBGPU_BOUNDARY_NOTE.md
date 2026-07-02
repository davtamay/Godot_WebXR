# WebGPU Boundary Note

## Summary

WebGPU is a strategic requirement, but it is not a Phase 1 Godot renderer target.

For this feasibility effort, there are three separate meanings:

## 1. WebGPU capability detection

This is allowed in Phase 1.

The custom web shell can check:

```js
const hasWebGPU = !!navigator.gpu;
const adapter = hasWebGPU ? await navigator.gpu.requestAdapter() : null;
```

This proves the browser/device exposes WebGPU. It does not prove Godot renders through WebGPU.

## 2. Separate WebGPU benchmark

This is allowed in Phase 1 or Phase 1.5.

A separate Babylon.js, PlayCanvas, Three.js, or raw WebGPU canvas can benchmark what the browser/device can do. This helps leadership compare Godot’s WebGL2 output against a browser-native WebGPU path.

## 3. Godot rendering through WebGPU

This is not Phase 1.

That would require renderer/platform/backend work. It likely touches:

- rendering backend
- shader translation/compilation
- buffer/texture ownership
- frame submission
- XR compositor integration
- web export runtime
- export templates
- build system

This is a source/upstream/fork-level investment, not normal plugin or GDExtension work.

## Leadership wording

Use:

> The demo detects WebGPU and proves WebXR/WebGL2 delivery in Godot. Godot-rendered WebGPU remains a future renderer/backend investment to evaluate after the WebGL2/WebXR feasibility pass.

Do not use:

> We added WebGPU to Godot through a plugin.
