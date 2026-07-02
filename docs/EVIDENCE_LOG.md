# Evidence Log

Fable must fill this with exact links and file paths.

| Claim | Source | Evidence | Confidence | Notes |
|---|---|---|---|---|
| Godot 4.7 is latest stable on this system target | TBD | TBD | TBD | Verify installed editor version |
| Godot web export requires WebAssembly + WebGL2 | TBD | TBD | TBD | Official docs |
| Godot web export uses Compatibility renderer | TBD | TBD | TBD | Official docs |
| Godot does not currently support WebGPU for web exports | TBD | TBD | TBD | Official docs/source |
| Godot 4 C# projects cannot export to web | TBD | TBD | TBD | Official docs |
| WebXRInterface only works in web exports | TBD | TBD | TBD | Official docs/source |
| WebXR session checks are asynchronous/signals | TBD | TBD | TBD | Official docs/source |
| JavaScriptBridge exists only for web export | TBD | TBD | TBD | Official docs/source |
| Custom HTML shell supports startup customization | TBD | TBD | TBD | Official docs/source |
| Default web export templates do not include GDExtension support | TBD | TBD | TBD | Official docs/source |
| dlink_enabled web templates enable GDExtension support | TBD | TBD | TBD | Official docs/source |
| Godot XR Tools can be reused for WebXR/OpenXR setup | TBD | TBD | TBD | Check repo/version/license |
| WebGPU detection is not renderer support | TBD | TBD | TBD | Explain renderer boundary |

## Current Validation Status

| Check | Status | Notes |
|---|---|---|
| Editor run | Pass | `Godot_v4.4.1-stable_win64_console.exe --headless --path demo --quit` exited 0 and loaded the scene; non-web status message printed as expected. |
| Web export load | Pass | `Godot_v4.4.1-stable_win64_console.exe --headless --path demo --export-release Web build/web/index.html` exited 0 using the custom shell. Browser load not tested. |
| Desktop WebXR support | Not tested | Browser/device capability probing exists in the custom shell. |
| Headset XR session | Not tested | Must be validated from an HTTPS-hosted build on a WebXR-capable headset/browser. |
| XR select input | Not tested on device | `webxr_bootstrap.gd` now connects native WebXR `select`, `selectstart`, and `selectend` signals when available; a real select increments a counter, updates `StatusLabel`, and toggles `InspectObject` scale/material. |
