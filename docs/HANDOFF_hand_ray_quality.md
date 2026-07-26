# Handoff: hand ray quality

Self-contained brief for a fresh session. Everything below is measured on
device or read from source, not recalled.

## Where things stand

Two repos, both pushed:

- `Repos/godot-xr-suite` @ `ac7afad`, branch `agent/far-grab-modes` (unmerged to
  `master`)
- `Repos/Godot_WebXR_gh` @ `0249de3`, branch
  `feature/xr-interaction-toolkit-addon`

`Godot_WebXR_gh/demo/addons/*` are **symlinks into the godot-xr-suite working
tree**. Editing either path edits the suite. Keep both repos on corresponding
branches.

Read `docs/XR_INPUT_PRACTICES.md` in `Godot_WebXR_gh` first. It has the full
evidence trail and the Unity/Meta source analysis.

The user's verdict on the current build: *"eh i feel like we can do better."*
Not broken; not good enough.

## The bug that was actually found and fixed

`godot-xr-suite/addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd`,
`get_hand_ray_pose`.

The ray's pitch axis runs index-knuckle to pinky-knuckle. That axis mirrors
between hands, so the code flips the pitch sign for the right hand to cancel
it. When the pinky was not reported it fell back to `fwd.cross(Vector3.UP)` --
fixed chirality, does not mirror -- while still applying the handedness flip.
The two hands therefore pitched in **opposite directions**, and that fallback
is taken exactly when a hand is leaving camera view.

Measured by reverting the fix: right hand keeps its correct slight downward
pitch (y ~ -0.15), left flips to a sharp upward deflection (y ~ +0.88).

`tests/test_hand_ray_symmetry.gd` pins it and fails against the old code.

**This survived eight attempted fixes** aimed at tracking confidence. Do not
re-litigate; it is fixed and tested.

## Do not repeat these dead ends

Each was measured, not assumed.

1. **`POSITION_VALID` carries no information.** The raw tracker reports
   `valid=26` permanently. Only `POSITION_TRACKED` varies (26 <-> 2).
2. **`XRHandTracker` exposes no confidence signal.** Enumerated: `hand`,
   `has_tracking_data`, `hand_tracking_source`, and per-joint
   flags/transform/radius/linear_velocity/angular_velocity. Meta's
   `IsHighConfidence` has no equivalent. Unity's `XRHandJointTrackingState` has
   none either -- OpenXR core does not define one.
3. **`hand_tracking_source` is not a usable discriminator.** WebXR never sets
   it; OpenXR only populates it with a further extension
   (`XR_EXT_hand_tracking_data_source`). Otherwise `UNKNOWN`.
4. **Quest Link does not advertise `XR_EXT_hand_interaction`.** Oculus runtime
   1.205.0. The profile is bound in `default_action_map.tres` but is inert
   there; a probe measured `platform=false` on every sample. Godot only
   registers the profile when the runtime advertises the extension.
5. **The FOV cone must stay ON.** It was defaulted off on the theory that the
   chirality fix made it redundant, and the hand then **disappeared** on
   look-away. Its real job is classifying a loss as unobservable-but-present
   (freeze) versus gone (expire) -- the only signal that separates them.
   `_test_fov_gate_ships_enabled` pins it. Its measured tuning: hands in
   ordinary use sit 50-92 degrees off the head's forward axis, so a narrow cone
   suppresses hands the user can see; `fov_half_angle_deg` is 120.

## Ranked next steps

### 1. Test on STANDALONE, not Link. Highest value, and Link cannot do it.

The derived ray takes its direction from a wrist-to-knuckle baseline of ~8 cm,
so a few mm of joint noise becomes degrees of angular error, which is tens of
centimetres at the far end of a multi-metre ray. Every filter in this codebase
is downstream of that amplification. The structural fix is to stop deriving and
use the runtime's own aim pose -- which Link cannot provide (dead end 4) but
standalone Quest may.

Everything needed is already wired:

- the profile is bound in
  `godot-xr-suite/addons/godot_webxr_kit/openxr/default_action_map.tres`
- set `debug_platform_aim = true` on the adapter
  (`runtime/input/xr_controller_hand_adapter.gd`) and read the `[aim-probe]`
  lines

If `platform=true` appears while `hand_live=true`, prefer that pose over the
derived one in `_hand_aim_pose` and the amplification problem disappears at the
source. If it does not appear, that is a real finding too -- record it and stop
pursuing this branch.

Same probe is worth running under WebXR, where the browser publishes
`targetRaySpace` for hands unconditionally, on any device. Godot already maps it
to the tracker's `aim` pose (`modules/webxr/webxr_interface_js.cpp:1006-1008`).
Caution: on WebXR the **hand** tracker's `default` pose is the palm, while the
**controller** tracker's `default` is the target ray -- read `aim` explicitly.

### 2. Tune XRAimStabilizer on device. Its numbers were never earned in.

`runtime/input/xr_aim_stabilizer.gd`. A range-scaled deadband: error over
threshold, clamped; at or above threshold the raw pose passes through untouched,
below it is damped; the angle budget scales by `1 + log(range)`.

`angle_threshold_deg = 20.0` and `position_threshold_m = 0.25` are **Unity's
XRTransformStabilizer defaults**, which per `CLAUDE.md` are order-of-magnitude
sanity checks and explicitly not values to ship. Nobody has tuned them in a
headset. The user's read on the current feel is "slightly better", which is
consistent with untuned thresholds.

Suggested method: expose both on a debug panel and sweep them in-headset
against the two cases that matter -- a still hand pointing far (should be rock
steady) and a deliberate sweep (must not feel rigid). The user has rejected an
over-stabilized aim on device before: *"their movement is more rigid, i cant
manuever things."* That is the failure mode to watch for.

`use_aim_stabilizer = false` restores the previous One Euro path on the same
build for A/B comparison. Those One Euro values ARE on-device-tuned and are the
baseline to beat.

### 3. Split the mesh source from the ray source. Fixes a known artifact.

Reported: *"my left mesh hand was offseted in front of my actual hand for a
second until it got back."* That is the FOV freeze working as designed -- an
out-of-view hand's pose is frozen, so the mesh parks in space while the real
hand moves on.

The ray needs stability; the mesh only needs to be where the hand is. Drawing
the mesh from the raw tracker while the ray uses the frozen pose should remove
the artifact without giving up the freeze. Untested. Check the mesh's consumers
first for anything that assumes both read the same source
(`runtime/input/xr_conditioned_hand_publisher.gd` publishes the conditioned
shadow that both currently read).

### 4. Pre-existing test failure, unrelated and untouched.

`tests/test_hand_conditioning.gd` has exactly one failure: a fixture
self-check in the head-pose space-conversion test ("this fixture's origin offset
must produce a disagreement"). It fails identically with all of this work
stashed. It was deliberately not fixed so it would not be folded into an
unrelated measurement.

## Working rules that were earned the hard way

- `--xr-mode off` on **every** headless Godot invocation or it hangs forever.
- Run suites via `godot-xr-suite/tools/run_tests.ps1 -Suite <addon-relative
  path>`, e.g. `godot_xr_interaction_toolkit/tests/test_aim_stabilizer`. A
  GDScript test that hits a runtime error aborts silently and the suite still
  prints PASS and exits 0 -- the runner exists because of that, and counts
  `ERROR:` as well as `SCRIPT ERROR`.
- **Always mutation-test.** Break the code deliberately and confirm the suite
  fails. `test_aim_stabilizer` was verified six ways. Twice in this work a test
  was found to be asserting nothing.
- Check a `.gd` file's indentation before editing. This repo mixes tabs and
  spaces **between** files; mixing within one file is a parse error.
  `xr_controller_hand_adapter.gd` is tabs; `xr_ray_interactor.gd` and
  `xr_hand_gesture_provider.gd` are 4-space.
- Use `preload`, not `class_name`, for new scripts referenced by other runtime
  code. A global class name only resolves once the editor has written it to the
  class cache, so it fails to parse in a fresh headless `--script` run.
- New `.gd` files need `.uid` files committed. Generate with
  `godot --headless --xr-mode off --path <demo> --import`.
- Launch Link with `C:\Users\davta\Desktop\xr_retry_launch.ps1` (it retries
  until the headset presents). Do not hand-roll a launcher.
- Prefer the Edit tool over scripted replacement; verify any sed actually
  changed the file before trusting the result.
- Instrument before theorising, and never claim a fix works until the user has
  confirmed it in the headset.

## Licensing

Meta's ISDK (Oculus SDK License) and Unity's XRI (Unity Companion License) are
both **incompatible**. Technique transfers; code and constants do not. Both were
read for approach only. Implement from the described behaviour and cite it.
