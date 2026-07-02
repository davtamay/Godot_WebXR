# Prototype Starter

These files are not a complete Godot project. They are starter pieces Fable can adapt into the demo.

## Files

- `web_shell/company_webxr_shell.html`: Godot custom HTML shell with feature detection.
- `gdscript/browser_capabilities.gd`: Reads shell capabilities through JavaScriptBridge.
- `gdscript/webxr_bootstrap.gd`: Minimal WebXRInterface startup flow.
- `server/serve_with_headers.py`: Local static server with COOP/COEP headers for testing.
- `server/Caddyfile`: Example HTTPS/static hosting config.

## Intended flow

1. Export the Godot project with the custom HTML shell.
2. Serve the export folder.
3. Open in desktop browser first.
4. Validate capability panel.
5. Test WebXR on headset over HTTPS.

## Note

The shell detects WebGPU. It does not make Godot render through WebGPU.
