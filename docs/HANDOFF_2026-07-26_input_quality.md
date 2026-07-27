# Handoff: hand-input quality — aim rays done, microgesture parity in progress

Self-contained brief for a fresh session. Everything here is measured on
device or read from source. Read `docs/XR_INPUT_PRACTICES.md` for the aim
evidence and `docs/DECISION_LOG.md` (2026-07-26 entries) for the microgesture
decisions.

## Where things stand

Both repos pushed as of this handoff:

- `Repos/godot-xr-suite`, branch `agent/far-grab-modes`
- `Repos/Godot_WebXR_gh`, branch `feature/xr-interaction-toolkit-addon`

`Godot_WebXR_gh/demo/addons/*` are symlinks into the godot-xr-suite working
tree. Keep both repos on corresponding branches.

## DONE this session, verified in-headset by David

1. **Platform hand-aim (handoff item 1, closed).** Standalone Quest 3
   advertises XR_EXT_hand_interaction and publishes an aim pose; the derived
   wrist->knuckle ray sits 29-48 deg away from it. `_hand_aim_pose` now
   prefers the platform pose; gaps are palm-driven (never frozen on a
   tracked hand), long-loss parks expire after 10 s. Two switches were both
   required: the action-map profile AND
   `xr/openxr/extensions/hand_interaction_profile=true`. Five on-device
   iterations; two hysteresis designs rejected and pinned by tests. Verdict:
   "behaves way better" / "works well".
2. **Teleport/arc lifecycle holes fixed** (`xr_locomotion.gd`): hidden arc
   kills its target (no stale-target commits — the literal "teleport out of
   nowhere"); other-hand aim handoff cancels observably; snap turn cancels
   an active aim; disable mid-aim cancels. Pinned in
   `test_microgesture_locomotion.gd`.
3. **Runtime microgestures adopted, additively.** The open OpenXR extension
   XR_META_hand_tracking_microgestures (no ISDK license involvement) is
   bound in the action map (mg_* actions);
   `xr_native_microgesture_source.gd` surfaces it through the existing
   XRMicrogestureSource contract; the locomotion driver muxes per hand.
   **Default is PORTABLE** (`use_platform_microgestures = false`) —
   David's call: Quest testing must measure the joint recognizer that
   WebXR/Galaxy XR actually run, not Meta's detector. Feel Check has a
   MICRO DETECTOR dial (session-wide static override) to A/B.
4. **Thumb-down commit race closed consumer-side**: `pose_release_grace`
   0.20 -> 0.45 (worst-case commit chain measured at ~0.36 s). Recognizer
   untouched (standing rule).
5. **Project skills**: `/local-web-server` (HTTPS + LAN IP serving, cert
   reuse, VirtualBox-adapter trap) and `/link-session`
   (xr_retry_launch.ps1 discipline). In `.claude/skills/`.

## TODOs, ranked

### 1. Portable microgesture recognizer hardening (the parity gap itself)

The recognizer is PROTECTED by standing rule (no silent threshold/logic
changes) — bring proposals + an on-device plan. Known, measured defects:

- **Silent dead band**: swipe travel in (maximum_tap_travel 0.09,
  minimum_index_travel 0.12) emits NOTHING — a fumbled swipe is a silent
  miss; slightly shorter still becomes TAP (which arms/commits teleport).
- **One bad frame resets everything**: `_reset_state` zeroes the cooldown
  and re-arms mid-gesture on any invalid/low-quality frame.
- **The FOV freeze is invisible to it**: frozen conditioned joints keep
  tracking_quality high; the reacquisition jump can satisfy
  confident_commit_travel and fire a phantom swipe. The gate exposes
  `consume_discontinuity(hand)` that the recognizer never reads.
- Use the Feel Check PLATFORM dial as the reliability reference to tune
  against — that is what "as reliable as Meta" feels like on the same
  hardware.

### 2. Meta's session-gate model, portably (headline deferred technique)

From the ISDK sweep (technique only, no code/constants — full report notes
in DECISION_LOG): locomotion gestures exist only inside an explicitly
entered mode; arming = tap + a shoulder-relative wrist-angle precondition
(gate by disabling the listener, not by if-guards); **exit = straightening
the index finger** — the physical negation of the thumb-on-index gesture
surface, so it can never collide with a gesture; distinct enter/exit audio;
invalid commits get explicit rejection feedback, never silence.

### 3. Galaxy XR / Android XR measurement pass

- One `--verbose` boot capture answers: does it advertise
  XR_EXT_hand_interaction (aim parity) and/or the microgesture extension?
  Same workflow as Quest (memory: quest-standalone-apk-workflow).
- Known from SESSION_HANDOFF_2026-07-25 §3.1: the posture gate fails on
  Android XR's skeleton (curls below thresholds, contact position 0.97-1.0
  outside the start zone). Instrument first; likely needs the same
  self-calibration treatment the contact gate got.

### 4. Aim follow-ups

- **Stabilizer tuning** (original item 2): `XRAimStabilizer` thresholds are
  still Unity's defaults, never earned in. Plan: sliders on Feel Check;
  still hand pointing far = rock steady, deliberate sweep = not rigid.
- **Mesh ghost** (original item 3): drive the hand MESH from the raw
  tracker while the ray uses the conditioned pose. Untested; check
  consumers of the conditioned shadow first.
- **WebXR aim-probe run**: platform-aim is implemented identically for
  WebXR (targetRaySpace) but the probe was never captured in a browser
  session. Flip `debug_platform_aim` on the rig temporarily and read
  `[aim-probe]`.
- **Teleport aim upgrades from Meta technique** (optional, big feel):
  shoulder-anchored direction blend by pitch, reach-controls-range,
  nonlinear pitch remap.

### 5. Packaging / hygiene

- Consumers must set `hand_interaction_profile=true` themselves — have the
  kit bootstrap warn (or the editor plugin offer) when it is off.
- The `_probe_platform_aim` diagnostic and `debug_platform_aim` flag are
  deletable once the WebXR measurement is taken (their stated retirement
  condition).
- `test_hand_conditioning` has exactly ONE known pre-existing failure (the
  head-pose fixture self-check). Unrelated; do not fold into new work.
- **`agent/far-grab-modes` is 38 commits ahead of `master` and unmerged.**
  The suite's trunk is `master`, and everything since the far-grab work --
  poke fidelity follow-ups, the aim-ray chirality fix, XRAimStabilizer,
  platform aim, teleport lifecycle, runtime microgestures -- lives only on
  that branch. Nothing downstream sees any of it until it merges. Decide
  deliberately whether to merge as-is or to split the branch: it now carries
  several unrelated features under a name that describes only the first.
  Full suite state at handoff: 14 suites, 13 PASS, 1 known pre-existing
  failure above.

## Working rules that were earned the hard way (unchanged + new)

- `--xr-mode off` on every headless Godot invocation or it hangs.
- Suites via `godot-xr-suite/tools/run_tests.ps1 -Suite <addon-relative>`;
  ALWAYS mutation-test (this session: 20+ mutations, every one caught).
- Tabs vs spaces varies PER FILE; check before editing.
- `preload` not `class_name` for new scripts; commit `.uid` files
  (generate via `--import`).
- APK loop: build `tools/export-xr.ps1 -Target APK` / install `adb install
  -r` / launch via `adb shell monkey -p com.davtamay.godotxrsamples -c
  android.intent.category.LAUNCHER 1` (plain `am start` is denied) / read
  probes via `adb logcat -s godot:V`.
- Link via `/link-session`, WebXR via `/local-web-server`.
- The user's verdict in the headset is the only "done". Two of this
  session's designs looked right and were rejected within minutes on
  device; the fix shipped same-session because iteration was fast.
