# Evidence Log

Fable must fill this with exact links and file paths.

| Claim | Source | Evidence | Confidence | Notes |
|---|---|---|---|---|
| Godot 4.7 is latest stable on this system target | Local binary + godotengine.org releases | `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --version` prints `4.7.stable.official.5b4e0cb0f`; 4.7-stable released 2026-06-18 | High | 4.4.1 editor also present; 4.7 is the spec target and produced all current builds |
| Godot web export requires WebAssembly + WebGL2 | Official docs: Exporting for the Web (docs.godotengine.org, tutorials/export/exporting_for_web) | Exported `demo/build/web47/index.wasm` (39.5 MB) + WebGL2 context requirement observed in browser probes (`demo/web/webxr_webgl_probe.html`) | High | Browsers without WebGL2 fail to boot the export |
| Godot web export uses Compatibility renderer | Official docs: Web platform limitations; `demo/project.godot` | `renderer/rendering_method="gl_compatibility"` is forced for web; Forward+/Mobile are unavailable on the web platform | High | Matches CLAUDE.md Phase 1 assumption |
| Godot does not currently support WebGPU for web exports | Godot source: `drivers/` has GLES3 + Vulkan/D3D12 RenderingDevice backends, no WebGPU; docs/WEBGPU_BOUNDARY_NOTE.md | No WebGPU rendering path exists in stock 4.x web templates; web rendering is WebGL2 via GLES3 driver | High | WebGPU detection in our probes is capability detection only |
| Godot 4 C# projects cannot export to web | Official docs: C# platform support matrix | .NET-enabled builds exclude the web platform in 4.x through 4.7 | High | GDScript-only project; not affected |
| WebXRInterface only works in web exports | Godot class reference: WebXRInterface | Desktop headless run prints our guard message "Not a web export. WebXRInterface is available only in web builds." (`demo/scripts/webxr_bootstrap.gd`) | High | Verified on every headless run |
| WebXR session checks are asynchronous/signals | Godot class reference: WebXRInterface (`session_supported`, `session_started`, `session_failed` signals) | `webxr_bootstrap.gd` drives support checks and session lifecycle purely from these signals; validated on Quest 3 | High | `is_session_supported()` returns via signal, not return value |
| JavaScriptBridge exists only for web export | Godot class reference: JavaScriptBridge | All bridge use is guarded by `OS.has_feature("web")` / `Engine.has_singleton("JavaScriptBridge")`; desktop runs skip it cleanly | High | Used by capability probe, hand bridge, depth bridge |
| Custom HTML shell supports startup customization | Official docs: Customizing HTML page for Web export | `demo/export_presets.cfg` sets `html/custom_html_shell="res://web/company_webxr_shell.html"`; shell patches `navigator.xr.requestSession` (hand/depth bridges) and loads on Quest 3 | High | The whole hand/depth bridge rides on this mechanism |
| Default web export templates do not include GDExtension support | Official docs: Web export options (`variant/extensions_support`) | `demo/export_presets.cfg` has `variant/extensions_support=false` (default); GDExtension web use requires the dlink template variant | High | We ship pure GDScript, so default templates suffice |
| dlink_enabled web templates enable GDExtension support | Official docs: Web export options | dlink template variant exists in the 4.7 templates archive (`c:/tmp/Godot_v4.7-stable_export_templates.tpz`) | High | Not used; kept as an option if GDExtension ever becomes necessary |
| Godot XR Tools can be reused for WebXR/OpenXR setup | github.com/GodotVR/godot-xr-tools (MIT) | Reviewed for Phase 0; scene-composition toolkit, OpenXR-staging-first, known Quest-Browser perf issue in its demo (#453) | High | Decision: stay independent (see docs/xr_interaction_toolkit_architecture.md); a project may still use both |
| WebGPU detection is not renderer support | docs/WEBGPU_BOUNDARY_NOTE.md; `demo/web/webxr_webgl_probe.html` | Probe reports `navigator.gpu` presence as a browser capability only; Godot still renders via WebGL2 | High | Hard boundary from CLAUDE.md; no renderer claims made |

## Current Validation Status

| Check | Status | Notes |
|---|---|---|
| Editor run | Pass | `Godot_v4.4.1-stable_win64_console.exe --headless --path demo --quit` exited 0 and loaded the scene; non-web status message printed as expected. |
| Web export load | Pass | `Godot_v4.4.1-stable_win64_console.exe --headless --path demo --export-release Web build/web/index.html` exited 0 using the custom shell. Browser load not tested. |
| Desktop WebXR support | Not tested | Browser/device capability probing exists in the custom shell. |
| Headset XR session | Pass (VR, Quest 3) | Quest 3 Quest Browser entered immersive-vr sessions throughout the spike; AR session path added later (91b685a) and exercised on device during depth-mesh iteration. |
| XR select input | Pass (Quest 3) | Controller trigger and system hand pinch drive select through `WebXRInputAdapter`; validated during the interaction-lab iteration. |
| Addon headless tests | Pass | `Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd` — 163 checks, 0 failures (2026-07-03: layers, arbitration, hand rays, direct/ray/screen interactors, two-hand grab, sockets, UI canvas, review-fix regressions). |
| Web export (4.7) | Pass | `--export-release Web build/web47/index.html` exited 0 (2026-07-03); addon scripts confirmed inside `index.pck`; served for Quest at `https://10.0.0.76:8444/`. |
| Review fixes regression | Pass | 2026-07-03 fixes each carry a headless regression test: collider refresh keeps selection, reentrant deselect, exit-tree hover cleanup, stale-manager recovery, slow-motion distance accumulation, close-grab no-pop. |
| Depth bridge produces data | PENDING MANUAL RETEST | 2026-07-03 fix: capture was gated on `frame.session.mode`, which does not exist in the WebXR spec (always undefined → capture never ran). Now gated on the mode recorded in the patched `requestSession`. Needs an AR session on Quest 3 to confirm samples arrive. |
| Session without hand tracking | PENDING MANUAL | `require_hand_tracking` now defaults to false (hand-tracking is an optional feature). Verify a controller-only or hands-disabled session still starts. |
| Quest 3 acceptance matrix | PENDING MANUAL | Base 9-item checklist in Task 10 Step 5 of `docs/superpowers/plans/2026-07-02-xr-interaction-toolkit-addon.md`, extended with: direct near-grab vs far-ray priority, two-hand grab rotate/scale, socket snap, activate events, UI panel press/drag (ray + pinch), screen-ray preview on desktop, depth mesh preview (AR), throw release feel. Record `prefer_hand_ray` winner (current default: false = runtime aim pose). |
| Galaxy XR stereo | Fail (documented) | Samsung Galaxy XR / tested Android XR browsers expose WebXR + WebGL2 but not `OVR_multiview2`/`OCULUS_multiview`; Godot WebXR stereo fails. Browser capability gap, not an export flag. |
