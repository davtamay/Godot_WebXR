# 488365 — Investigate WebXR and Cross-Platform Delivery Through Demo

## Goal

Build a tangible Godot WebGL2/WebXR browser app that demonstrates what is actually possible today.

## Scope

- Stock Godot 4.7 standard build.
- Compatibility renderer.
- Web export.
- Custom HTML shell.
- Browser feature detection.
- WebXRInterface.
- Simple optimized 3D scene.
- One XR interaction.
- Performance/device test report.

## Non-goals

- Do not implement Godot-rendered WebGPU.
- Do not require GDExtension unless research proves it is needed.
- Do not modify Godot source for the first demo.

## Demo requirements

- Browser capability panel:
  - WebGL2
  - WebXR
  - immersive-vr
  - immersive-ar
  - WebGPU adapter availability
  - SharedArrayBuffer
  - crossOriginIsolated
  - browser/device metadata
- Godot scene:
  - simple optimized 3D scene
  - baked/static-friendly lighting
  - basic UI
  - performance display
  - enter XR flow
  - one interaction

## Acceptance criteria

- Web export runs in desktop browser.
- WebXR session starts on at least one target headset/browser.
- Feature detection works.
- WebGPU is detected but not misrepresented.
- Test matrix is completed.
- Final go/no-go recommendation is written.


## Performance/build-size comparison scope

If a Unity baseline is available, export the same empty baseline scene and the same product-slice scene from Unity and compare against Godot.

Required measurements:

- raw export size
- gzip estimated size
- brotli estimated size if tool support is available
- largest files
- file count
- time to capability panel
- time to engine loaded
- time to first interactive frame
- time to Enter XR
- average FPS
- p95/p99 frame time
- browser console errors/warnings
- release build time

Use `prototype_starter/tools/measure_web_build.py` for build-size reporting.

The report must separate:

```text
Godot WebGL2 Compatibility rendering
Unity WebGL2 rendering
Unity WebGPU Experimental rendering, if tested
browser WebGPU capability detection
```

Browser WebGPU detection must not be counted as Godot WebGPU rendering.

## Updated acceptance criteria

- Godot build size report is produced.
- Runtime timing report is produced.
- If Unity baseline exists, Unity build-size/runtime comparison is produced.
- Results identify whether Godot is better, worse, or inconclusive for load size, startup, and XR frame stability.
- Recommendation includes the cost of maintaining custom Godot tooling/templates versus staying on Unity.
