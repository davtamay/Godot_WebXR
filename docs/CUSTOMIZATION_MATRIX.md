# Customization Capability Matrix

Fable must complete this with evidence from docs/source/repos.

| Capability | Project code | Editor plugin | Custom HTML shell | JavaScriptBridge | GDExtension | C++ module | Custom export template | Core source mod | Notes/evidence |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| WebGL2 web export | Yes | No | Maybe | No | No | No | No | No | Supported path |
| WebXR scene flow | Yes | Maybe | Maybe | Maybe | No | No | No | No | Verify with WebXRInterface |
| WebXR enter/start UX | Yes | Maybe | Yes | Yes | No | No | No | No | Must respect user activation |
| WebXR capability detection | Maybe | Maybe | Yes | Yes | No | Maybe | No | No | Browser and Godot routes |
| WebGPU capability detection | No | No | Yes | Yes | No | No | No | No | Detection only |
| Godot scene rendering through WebGPU | No | No | No | No | No | Maybe | Maybe | Yes | Requires renderer/backend evidence |
| Forward+/Mobile renderer on web | No | No | No | No | No | Maybe | Maybe | Yes | Not Phase 1 |
| Asset/material validator | Maybe | Yes | No | No | Maybe | No | No | No | Good company plugin |
| Export preset generator | No | Yes | No | No | No | No | No | No | Good company plugin |
| Browser loading UI | No | No | Yes | Yes | No | No | No | No | Custom shell |
| Analytics/auth/LMS | Maybe | No | Yes | Yes | No | Maybe | Maybe | No | Browser integration |
| PWA/offline | Maybe | No | Yes | Yes | No | No | Maybe | No | Validate export settings |
| GDExtension runtime logic | No | No | No | No | Maybe | Maybe | Maybe | No | Requires web support research |
| Web export template optimization | No | No | No | No | No | Maybe | Yes | Maybe | Build ownership |
| Smaller custom WASM build | No | No | No | No | No | Maybe | Yes | Maybe | Phase 2 |
| Custom renderer backend | No | No | No | No | No | Maybe | Maybe | Yes | High risk |
