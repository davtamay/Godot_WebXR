---
name: local-web-server
description: Serve the demo's web export to a headset - HTTPS on the LAN IP by default (survives without USB), adb-reverse localhost as the cabled fallback. Use whenever the user asks to "push to webxr", "serve the web build", "open the app in the browser/headset", or to restart the local web server.
---

# Serve the web build to a headset

WebXR requires a secure context. Default to **HTTPS + LAN IP** (works
untethered); use the adb-reverse fallback only when asked or when no LAN
route exists.

## 1. Build (skip if the export is current)

```powershell
& "C:\Users\davta\Repos\Godot_WebXR_gh\tools\export-xr.ps1" -Target Web
```

Run in background; do NOT add --headless anywhere - the WebGPU editor needs
its real RenderingDevice to bake shaders. Output lands at
`demo/build/verify/web/index.html`.

## 2. Certificate (reuse, don't regenerate)

The dev cert lives at `demo/build/certs/dev.crt` + `dev.key`. Only if
missing, regenerate (Git Bash):

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout demo/build/certs/dev.key -out demo/build/certs/dev.crt \
  -subj "/CN=godot-webxr-dev"
```

## 3. LAN IP - beware the virtual adapters

```powershell
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
  $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' -and
  $_.IPAddress -notmatch '^(169\.254|192\.168\.56)\.'
}).IPAddress
```

`192.168.56.x` is VirtualBox host-only - the headset can never reach it.
On this machine the real LAN IP has been `10.0.0.x`.

## 4. Serve

```powershell
python "C:\Users\davta\Repos\Godot_WebXR_gh\tools\serve_web.py" 8443 `
  --directory "C:\Users\davta\Repos\Godot_WebXR_gh\demo\build\verify\web" `
  --no-isolation `
  --https "C:\Users\davta\Repos\Godot_WebXR_gh\demo\build\certs\dev.crt" "C:\Users\davta\Repos\Godot_WebXR_gh\demo\build\certs\dev.key"
```

Run in background. `--no-isolation` matches the NOTHREADS export the Web
preset produces; a threaded export would instead need the default
COOP/COEP isolation headers. Verify before telling the user:

```bash
curl -sk -o /dev/null -w "%{http_code}" https://<LAN_IP>:8443/index.html
```

Then tell the user: browse **https://<LAN_IP>:8443** in the headset
browser and accept the self-signed certificate once per device.

## Fallback: adb reverse (USB required)

```bash
adb reverse tcp:8000 tcp:8000
python tools/serve_web.py 8000 --directory demo/build/verify/web --no-isolation
```

Browse **http://localhost:8000** on the device - localhost is a secure
context, no certificate needed. The tunnel dies with the cable.
