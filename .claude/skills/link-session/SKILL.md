---
name: link-session
description: Launch the demo on the headset over Quest Link using the retry launcher. Use whenever the user asks to "push it to link", "run on link", "open the app in link", or to start a desktop XR session.
---

# Launch a Quest Link session

Always use the retry launcher - never hand-roll a Godot invocation for
Link (earned-in rule; the headset takes a variable time to present and a
plain launch dies with FORM_FACTOR_UNAVAILABLE).

**BEFORE launching, check nothing is already attached** (earned-in
2026-07-30: relaunching over a still-live session put two Godot
instances in a fight over one OpenXR session -- the second hung, Link
wedged, and the user could not reopen it until every instance was
killed):

```powershell
Get-Process | Where-Object { $_.ProcessName -like "*godot*" } | Select-Object Id, ProcessName, Responding
```

If anything is listed, the previous session is still live or stuck. Ask
the user to quit the scene first (or confirm it is stuck), then
`Stop-Process -Force` the leftovers, and only then launch:

```powershell
& "C:\Users\davta\Desktop\xr_retry_launch.ps1"
```

If Link itself is wedged after a stuck session, killing the Godot
processes is the fix - the user then restarts Link from the headset.
Restarting OVRService has never yet been required.

Run it in **background** - it retries up to 40 times (~16 minutes) and
then stays attached to the running session until the user quits the scene.

## What it does

- Launches the STOCK Godot 4.8-dev2 binary (`Godot R&D\_tools\Godot-4.8-dev2`)
  with the demo project's main scene (the launcher menu, so every showcase
  and the Feel Check bench are reachable). The WebGPU fork is deliberately
  NOT used: it cannot compile the stereo multiview shader variants.
- Retries while logs show `FORM_FACTOR_UNAVAILABLE` / "not initialized";
  succeeds on "Running on OpenXR runtime".
- Per-attempt logs: `%TEMP%\xr_retry_launch\attempt_N.{out,err}.log`.

## Operating it

1. Start it in background, then tell the user to put the headset on and
   start Quest Link - the script waits for them.
2. Watch the task output: `[N] headset not presenting yet` means keep
   waiting; `XR SESSION LIVE - scene is in the headset` means they are in;
   `scene exited` + exit 0 means the user quit the session (normal).
   `gave up after 40 attempts` means Link was never enabled.
3. Do not kill it while "XR SESSION LIVE" - that kills the user's session.

## Link-specific expectations (so results are read correctly)

- The Oculus PC runtime advertises neither XR_EXT_hand_interaction nor the
  microgesture extension: hand rays use the derived wrist->knuckle
  fallback and microgestures are always the portable joint recognizer,
  regardless of any platform flags. This is measured, not configurable.
- `xr/shaders/enabled=true` must be set in the project or desktop XR
  renders nothing (already set in the demo).
