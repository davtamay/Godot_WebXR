# Session handoff — 2026-07-25

Written at the end of a long cross-device session (Quest 3 over Link, Quest 3
standalone APK, WebXR on Quest, Galaxy XR APK). Everything below is either
committed, measured on device, or explicitly marked unverified.

**Read this first, then `CLAUDE.md`, then the two logs it names.**

---

## 1. Branch state

| Repo | Branch | Pushed | Unmerged commits |
|---|---|---|---|
| `godot-xr-suite` | `agent/interaction-arbitration` | yes | **88** vs `master` |
| `Godot_WebXR_gh` | `agent/hand-conditioning` | yes | **16** vs `feature/xr-interaction-toolkit-addon` |

Other live suite branches: `agent/grab-feel`, `agent/hand-conditioning`,
`agent/webxr-session-ui`. Demo also has `agent/universal-xr-demo`.

**The merge-down is the largest single piece of outstanding work** and has been
deferred repeatedly. Four long-lived agent branches across two repos, all
descended from overlapping work. Do this before adding features.

Remember the coupling: `Godot_WebXR_gh/demo/addons/*` are **symlinks into the
`godot-xr-suite` working tree**, not pinned commits. Whatever branch the suite
has checked out is what the demo builds against. Keep them on corresponding
branches or builds silently test the wrong code.

---

## 2. Shipped today

### godot-xr-suite (`agent/interaction-arbitration`)

| Commit | Change |
|---|---|
| `00b2350` | UI panel hands its cursor back instead of wedging one hand |
| `0355c2b` | Release after the scene is gone no longer writes a garbage grab offset |
| `4ff58a9` | Microgesture contact calibrates itself per hand |
| `3510fd1` | Correct an implausible eye height from a mis-calibrated runtime floor |
| `08a90dc` | Change-gated arbitration diagnostics; later world-environment lookup |

### Godot_WebXR_gh (`agent/hand-conditioning`)

| Commit | Change |
|---|---|
| `e52a413` | Outgoing scene released instead of leaking on every scene change |
| `777e2d3` | `serve_web.py` can host TLS for headset testing |

### Test suites (all mutation-tested)

```bash
godot --headless --xr-mode off --path demo --script res://addons/<path>.gd
```

| Suite | Status |
|---|---|
| `godot_xr_interaction_toolkit/tests/test_hand_conditioning` | pass |
| `godot_xr_interaction_toolkit/tests/test_grab_feel` | pass |
| `godot_xr_interaction_toolkit/tests/test_interaction_arbiter` | pass |
| `godot_xr_interaction_toolkit/tests/test_ui_canvas_pointer` | pass (new) |
| `godot_xr_hands/tests/test_gesture_foundation` | pass |
| `godot_xr_hands/tests/test_adaptive_contact` | pass (new) |
| `godot_webxr_kit/tests/test_eye_height_calibrator` | pass (new) |

Headless boot: **0 errors of any class** (`--quit-after 150`, grepping
`ERROR:|SCRIPT ERROR|Parse Error` — note the first pattern; earlier in the
session only the last two were counted and a real bug hid behind that).

---

## 3. Open bugs, by platform

Ordered by how well-understood they are, not by severity.

### 3.1 Snap microgesture on Android XR — PARTIAL

**Symptom.** Snap left/right unreliable on Galaxy XR; works on Quest.

**Fixed so far.** The *contact* gate. `thumb_index_side_distance` is palm-width
normalized so it survives hand size, but not a different joint skeleton:
measured 0.09–0.39 on Meta vs 0.40–1.11 on Android XR for the same physical
pinch. Now self-calibrating (percentile ring per hand, no device table).

**Still open — different gate.** The last device log showed:

```
avgCurl=0.13-0.43  (requires >= 0.28)   idxCurl=0.19-0.40 (requires >= 0.16)
pos=[0.97..1.00]                        (thumb past the fingertip)
```

The **posture gate** (`gate_score`, requiring a curled loose fist) is failing
intermittently, which arms nothing regardless of the contact threshold. That is
`minimum_finger_curl` / `minimum_index_curl` in
`xr_thumb_microgesture_recognizer.gd`.

**Next step.** Do *not* retune blind. `_finger_curl` sums joint-to-joint angles
normalized by `PI * 0.5` per joint — a skeleton-dependent quantity, exactly like
the contact distance was. The same self-calibration argument applies. Instrument
first: log per-finger curls during a successful Quest snap and a failed Galaxy
snap, and compare distributions before touching a threshold.

### 3.2 Hand vanishes mid-gesture (Android XR) — NOT FIXED

`hand_visualizer.gd` hides the hand only when the tracker is null or
`has_tracking_data` is false; there is no "hide during teleport" logic. Device
data confirms `raw` goes to `-1.00` at those moments — the **runtime** stops
reporting, likely self-occlusion during the pose.

**Next step.** This is presentation, not recognition. The conditioning layer
already has confidence gating and shadow trackers; bridging a short dropout by
holding the last good pose belongs there. Touches on-device-tuned behaviour, so
it needs an on-device verification plan per `CLAUDE.md`.

### 3.3 WebXR panel renders dark — PARKED, engine-level

**Confirmed at source level.** `webxr_interface_js.cpp` wraps the browser's
`XRWebGLLayer` texture as `Image::FORMAT_RGBA8` (linear). The GLES3 blit code
*assumes* the XR target is sRGB-formatted ("*99% likely our texture uses the
GL_SRGB8_ALPHA8 texture format... Godot does not track this*") so the hardware
would encode. True on Meta's OpenXR swapchain, false on WebXR. `git blame`: this
is stock upstream Godot, 2022, not a fork change.

**A theory was tested on device and DISPROVEN.** Patching the built `index.js` to
request `colorFormat: gl.SRGB8_ALPHA8` was verified to take effect — a beacon
confirmed `fmt-0x8c43`, multiview, 2 views — and the panel stayed dark. So the
projection layer's colour format is **not** the lever. Do not retry that.

Also ruled out: hand scale (features are palm-width normalized), lighting (the
panel material is `shading_mode = 0`, unshaded), and project-level compensation
(environment adjustments are **not implemented** in the Compatibility renderer —
`environment_set_adjustment` exists only under `servers/`, nothing in
`drivers/gles3/`).

**Corroborating evidence.** It looks correct on the 2D page and dark only in
session. Same content, two output paths; only the XR one skips the encode.

**Next step if resumed.** A controlled A/B with screenshots from both targets,
then the fork. It is a `CLAUDE.md` stop-and-ask (engine source).

### 3.4 WebXR on Galaxy XR — UNTESTED

Chrome's renderer process died (`Child process died (type=6)`) before fetching
anything past `index.html`. Never got a session.

Note the pre-existing `EVIDENCE_LOG` entry: **Galaxy XR browsers expose WebXR +
WebGL2 but not `OVR_multiview2`/`OCULUS_multiview`, and Godot WebXR stereo
fails there.** That may make this a known dead end rather than a new bug —
check that before spending time.

### 3.5 `texture_free` render-target errors (Galaxy XR) — NOTED

```
ERROR: Condition "t->is_render_target" is true.
  at: texture_free (drivers/gles3/storage/texture_storage.cpp:1024)   ×8
```

Clustered around scene changes. Godot's WebXR path carries an explicit
workaround for exactly this ("*Forcibly mark as not part of a render target so
we can free it*"); the OpenXR path appears to lack the equivalent. A texture
leak per scene switch, not a crash. Engine-side.

### 3.6 Teleport arc occasionally stuck on hand — OPEN, UNOBSERVED SINCE

Reported earlier in the session. The arbitration trace later showed teleport
entering and exiting cleanly many times, so it did not reproduce under
observation. One suspicious trace line: `NEAR -> TELEPORT` while
`direct sel=true` — teleport aiming began while that hand was **holding an
object**. `resolve_mode` lets teleport win unconditionally, which was written
for "reaching past a table", not for "already holding something". Worth deciding
deliberately.

### 3.7 Four authored grab points are 4.58 cm stale — USER TASK

`pen`, `blaster`, `spray_can`, `coffee_cup`. Needs re-authoring in the editor
after the palm-anchor change.

### 3.8 Foveation disabled on Quest — BENIGN, UNEXPLAINED

> Foveation with subsampled images was enabled, but rendering features are in
> use that have forced it to be disabled.

Costs GPU headroom, not correctness. Likely the SubViewport UI panels or the
passthrough blend. Worth chasing only if frame timing gets tight.

---

## 4. Meta hand-tracking enhancements (ISDK gap analysis)

Full analysis in `docs/INNOVATION_BACKLOG.md`. **Licensing is absolute**: the
ISDK is under the Oculus SDK License, which is not compatible. Technique
transfers; code, transcription and adaptation do not. Meta's constants are
order-of-magnitude sanity checks, never values to ship.

| # | Item | Size | Status |
|---|---|---|---|
| 1 | Tweened grab movement with perceived distance | S | **Done** — `transit_duration`/`transit_blend` |
| 2 | Consensus throw velocity with release dead-zone | S | **Done** — `throw_consensus`, `throw_peak_bias = 0.80` (earned in) |
| 3 | Adaptive signal conditioning (One Euro) | M | **Done** — conditioning on, all consumers routed |
| 7 | Analog pinch strength / general "use" axis | S | **Done** — `use_value`, `set_use_value` |
| 4 | Synthetic/display hand | L | **Not started** |
| 5 | Joint translation+rotation grab scoring over *surfaces* | L | **Not started** |
| 6 | Poke fidelity beyond hysteresis | M | **Not started** |
| 8 | Locomotion mode gate | M | **Not started** |

**Recommended next**: item 6 (poke fidelity) — medium size, no dependencies, and
approach-angle gating is what makes slapping buttons work without false fires.
Item 4 (synthetic hand) is the highest-value but is L and underpins items that
follow it.

**Unfinished wiring from item 7**: `spray_can` and `blaster` are still bespoke
and do not consume `use_value`. Also unresolved: `trigger_progress` vs
`use_value` duplication — decide and collapse one.

---

## 5. Traps for the next session

These cost real time today.

1. **`--xr-mode off` is mandatory** on every headless Godot invocation, or it
   hangs forever.
2. **`xr/shaders/enabled=true`** must stay in `demo/project.godot`. Without it
   desktop XR renders nothing — this looked like "only passthrough" / a black
   headset for ~8 failed launches.
3. **Count `ERROR:` too**, not just `SCRIPT ERROR|Parse Error`. A real bug hid
   behind that gap for hours.
4. **Check indentation before editing a `.gd` file.** This repo mixes tabs and
   spaces *between* files. Mixed indentation inside one file is a parse error
   and cost a wasted APK build. Verify with a tab/space line count.
5. **Prefer the `Edit` tool over scripted pattern replacement.** Two python
   replacements silently matched nothing and were reported as applied; the
   "fix" was dead code and the diagnostic never ran.
6. **`console.log` does not reach logcat on Oculus Browser.** A `fetch()`
   beacon to the local server does, and shows up in the server log.
7. **PowerShell: never `2>&1` a native exe.** It wraps stderr as ErrorRecords and
   reports failure on a successful export.
8. **`adb reverse` dies silently.** Verify with `adb reverse --list` before
   concluding a page will not load.
9. **Both headsets cannot reach the PC over LAN** (100% packet loss, measured on
   Quest and Galaxy). Windows Firewall / AP isolation. `adb reverse` +
   `http://localhost` is the working route; `localhost` is a secure context so
   WebXR needs no HTTPS there.
10. **Launch the Quest browser by explicit component**
    (`-n com.oculus.browser/.BrowserActivity`); the implicit VIEW intent is
    swallowed by the VR home launcher.

### Method note

The single biggest inefficiency this session was **testing hypotheses one at a
time in the headset instead of instrumenting once**. Every useful conclusion
came from one diagnostic build that logged the actual gate values; the
theory-first rounds before it produced nothing and consumed most of the user's
device time. Instrument first.

---

## 6. Verification commands

```bash
cd Godot_WebXR_gh/demo && for t in \
  godot_xr_interaction_toolkit/tests/test_hand_conditioning \
  godot_xr_interaction_toolkit/tests/test_grab_feel \
  godot_xr_interaction_toolkit/tests/test_interaction_arbiter \
  godot_xr_interaction_toolkit/tests/test_ui_canvas_pointer \
  godot_xr_hands/tests/test_gesture_foundation \
  godot_xr_hands/tests/test_adaptive_contact \
  godot_webxr_kit/tests/test_eye_height_calibrator; do \
  godot --headless --xr-mode off --path . --script "res://addons/$t.gd"; done
```

```bash
pwsh tools/export-xr.ps1 -Target APK
```

```bash
adb install -r -g demo/build/android/universal/GodotXR-universal-debug.apk
```

```bash
adb reverse tcp:8000 tcp:8000
```
