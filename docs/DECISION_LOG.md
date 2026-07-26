# Decision Log

Record decisions and pivots here. Do not silently change direction without documenting why.

## 2026-07-02 - XR Interaction As A Pure-GDScript Addon

Decision: implement XRITK-style interaction as
`addons/godot_xr_interaction_toolkit/` using pure GDScript, `class_name`
runtime classes, and an optional editor plugin. No engine modules, custom
export templates, or renderer/backend changes are part of this phase.

Reason: an engine module would force custom editor and export-template builds
for every consumer, which breaks drop-in reuse. The first deliverable only needs
scene-level interaction logic, ray selection, WebXR input adaptation, visuals,
and grab movement. Input adapters isolate WebXR from future OpenXR support, so
interaction logic ports by swapping one node.

Evidence: the demo scene now consumes addon APIs only, the old prototype ray
script was removed, the headless suite reports 65 checks and 0 failures, and the
Godot 4.7 Web export to `demo/build/web47/index.html` exits 0.

## 2026-07-03 - Raw Browser Hand Bridge Is A Deliberate Layer-4 Escalation

Decision: `WebXRInputAdapter` and the custom HTML shell now include a raw
JavaScript hand/pose bridge (patched `navigator.xr.requestSession` /
`requestAnimationFrame`, joints read from `XRFrame` and handed to GDScript via
`JavaScriptBridge`). Commits: cc42a01, cace513, 7a4d0c0, 6dded5f.

Reason: on Quest 3 Quest Browser, Godot 4.7's `XRHandTracker` joints arrive
late and partially validated at session start (hands invisible or snapping for
the first seconds), and the runtime aim pose alone cannot drive the hand
visualizer. Reading joints directly from the WebXR frame removes the startup
gap. This is the architecture-preference ladder's layer 4 (JavaScriptBridge) -
project code and stock interface (layers 1-2) were tried first and were
insufficient for acceptable hand UX; no engine or template change is involved.

Cost: a browser-API maintenance surface (WebXR joint names, session patching)
lives in the shell and adapter. Mitigation: the stock `XRHandTracker` path
remains the fallback and the bridge is toggleable; if a future Godot release
delivers joints promptly, the bridge can be deleted without API changes.

## 2026-07-03 - Far Rays Prefer The Runtime Aim Pose

Decision: `WebXRInputAdapter.prefer_hand_ray` defaults to `false`; the
`XRController3D` aim pose (which Quest maps to the system hand cursor) drives
far rays, with the joint-derived hand ray kept as fallback/experiment.
Commit: 7c2f191. This reverses the prototype's hand-ray-first order after
on-device comparison showed the OS aim pose is steadier.

## 2026-07-03 - AR Session Path, Floor-First Reference Spaces, Optional Hand Tracking

Decision: the demo bootstrap requests either immersive-vr or immersive-ar
(separate buttons, 91b685a), prefers floor reference spaces (7ed7330), and -
after review - requests `hand-tracking` as an OPTIONAL feature by default
(`require_hand_tracking = false`): requiring it rejected whole sessions on
devices/browsers without it. AR mode enables transparent background +
depth-sensing (optional feature) for the depth-mesh preview.

## 2026-07-03 - Demo Is An Interaction Sample Lab; Scope Grew Beyond The First Deliverable

Decision: after the first deliverable passed, the demo expanded into a sample
lab (a34cd25 onward): `XRDirectInteractor` (near grabs with far-ray
suppression), `XRScreenRayInteractor` (desktop/touch preview), `XRUICanvasInteractable`
(Control UI via ray), two-hand grab rotate/scale, `XRSocketInteractor` with
snap, activate/use events, and throw velocity sampling. The addon stays
consumer-independent; all features are headless-tested (163 checks).

## 2026-07-03 - Review Fixes (Multi-Agent Review, Adversarially Verified)

Decision: applied five of the seven panel-confirmed defects from the
2026-07-03 deep review, plus two feature-invalidating web claims verified by
hand:

- Collider refresh (child added/reordered) no longer routes through
  `unregister_interactable`, so it cannot cancel the very selection whose
  handler added the child.
- `request_select`/`request_activate` re-check state after emitting enter
  signals (reentrancy-safe grants).
- Interactor `_exit_tree` clears hover; `_set_hovered` tolerates freed nodes.
- Stale/freed manager recovery: interactors re-resolve the manager and fall
  back to local cleanup, so a manager swap mid-grab cannot wedge them.
- Distance-manipulation deadzone gates accumulated motion (frame-rate
  independent; slow pulls work).
- Close grabs keep their true distance (no pop to `min_grab_distance`).
- Depth bridge: `frame.session.mode` does not exist in the WebXR spec, so the
  gate never passed; the session mode is now recorded in the patched
  `requestSession`. Needs on-device AR retest.
- `hand-tracking` demoted from required to optional session feature.

Each fix carries a headless regression test (163 checks, 0 failures).

Still open from the confirmed list (both minor, grab physics): the two-hand
scale clamp is per-grab-session so repeated regrabs compound scale without an
absolute bound, and VELOCITY_TRACKED teleports RigidBody3D rotation instead of
tracking angular velocity. ~27 further findings from the review were never
adversarially verified (the verification run was cut short); they are leads,
not verdicts.

## 2026-07-03 - Descopes For This Phase

Explicitly deferred, not forgotten:

- Bezier/curved ray visual: straight line shipped; curve is cosmetic.
- Locomotion (Phase 6): not started; re-evaluate reusing Godot XR Tools'
  locomotion before building (per architecture doc).
- `OpenXRInputAdapter`: deferred until a native OpenXR smoke path exists to
  test it against; the adapter seam is in place.
- Addon `samples/` directory: demo scene currently doubles as the sample; a
  minimal copy-in sample scene is still owed to consumers.
- Two earlier descopes are now DONE and off this list: socket interactor
  (1388e1b, 74a9cf0) and throw velocity estimation (a2e1b39).

## 2026-07-06 - Depth-Mesh Preview Descoped On Quest (Browser Capability Gap)

Decision: the AR depth-mesh preview stays in the tree but is documented as
non-functional on Quest Browser for now, rather than pursued further. The CPU
readback code and its clean failure guard remain.

Finding (confirmed on device + against the W3C WebXR Depth Sensing spec and
Meta's release notes): Quest Browser 146.0's WebXR depth is experimental
("depth projection", Horizon Browser 146.0, 2026-04-21) and is granted
**gpu-optimized only** (depth delivered as a WebGL texture via
`XRWebGLBinding.getDepthInformation`). Our bridge reads depth on the CPU
(`XRFrame.getDepthInformation` + `getDepthInMeters`), which the spec REQUIRES
to throw in gpu-optimized mode - the observed `InvalidStateError`. Requesting
`usagePreference:['cpu-optimized']` with no gpu fallback still yielded
`depthUsage='gpu-optimized'`, so the CPU path is unreachable on Quest today.

Two genuine bugs were found and fixed along the way (both real, both committed):
the capture gate keyed on the nonexistent `frame.session.mode`, and the request
biased toward gpu-optimized formats. Neither was the whole story; the platform
only offers gpu depth.

Rejected alternative (GPU-texture readback): consuming gpu-optimized depth would
mean binding the depth texture to a framebuffer and `readPixels` in the shell,
sharing Godot's WebGL2 context. That risks perturbing the main renderer (the
core, working deliverable) for an innovation-backlog extra. Not worth the risk
now; revisit if depth occlusion becomes a real requirement, or when Meta ships
cpu-optimized depth (then the existing CPU path works unchanged).

This is the same class of finding as the Galaxy XR multiview gap: a browser
capability limit, tracked and bounded, not an addon or export defect. The
interaction toolkit and WebGL2/WebXR feasibility conclusions are unaffected.

## 2026-07-06 - Split Into Three Drop-In Packages (toolkit / webxr_kit / xr_hands)

Decision: the single `godot_xr_interaction_toolkit` addon became three
independent pure-GDScript addons so a project can take only what it needs.
Dependency DAG with the engine-agnostic core at the base:
`godot_webxr_kit → godot_xr_interaction_toolkit` and
`godot_xr_hands → godot_xr_interaction_toolkit`; nothing makes the toolkit or
`godot_xr_hands` load-time-depend on `godot_webxr_kit`.

What moved:
- `godot_xr_interaction_toolkit` (core, depends on nothing): interactors,
  interactables, manager, grab/socket/UI, visuals, the ABSTRACT `XRInputAdapter`
  seam, and the `XRHandTracker` gesture/resolver helpers.
- `godot_webxr_kit` (WebXR layer): the concrete `WebXRInputAdapter` (moved out of
  the core), the custom HTML shell, `webxr_bootstrap.gd`, `browser_capabilities.gd`,
  and `webxr_depth_mesh_visualizer.gd`.
- `godot_xr_hands` (presentation): the procedural hand visualizer, renamed
  `webxr_hand_visualizer.gd → hand_visualizer.gd`.

Coupling fixed: the core toolkit previously contained `WebXRInputAdapter`, which
reads `window.CompanyWebXRHandBridge` — a JS global only the shell provides. That
hidden shell dependency lived in the "engine-agnostic" core. Moving the adapter
into `godot_webxr_kit` alongside the shell removes it; the core is now verified
free of `CompanyWebXR` / `res://scripts` / `res://web` references. The hand
visualizer keeps only an OPTIONAL, feature-detected use of that same global (a
`JavaScriptBridge.eval` string, not a Godot path), so `godot_xr_hands` stays
usable standalone on native OpenXR.

Why depth stayed in the WebXR kit (not grouped with hands): the depth-mesh
visualizer has no engine-agnostic data source — it reads only
`CompanyWebXRDepthBridge` from the shell, and depth is Quest-WebXR-only. Grouping
it with the hand visual would have forced `godot_xr_hands` to hard-depend on
`godot_webxr_kit`, defeating the independence goal.

Verification: headless suite 163 checks / 0 failures after the split; headless
load exits 0; Web export exits 0 with the shell embedded from its new location;
separation greps confirm the DAG. A stale `.godot` class cache produced a
transient "hides a global script class" error after moving a `class_name` file;
resolved by an editor rescan (`--editor --headless --quit`) — a consumer/CI hits
this once on first import and it self-heals.

Deferred follow-up (unchanged): 5 toolkit files use absolute-path `preload(...)`,
so the toolkit folder cannot be renamed without edits. Out of scope for this split.

## 2026-07-26 - Hand Rays Source The Platform Aim Pose; The Derivation Is The Fallback

Decision: `XRControllerHandAdapter._hand_aim_pose` prefers the runtime's own
aim pose for a tracked hand (`prefer_platform_aim`, default true) and keeps
the wrist->knuckle derivation as the fallback; the shipped rig sets
`prefer_hand_ray = true` so the hand modality flows through that path -- and
through the on-device-tuned aim stabilizer and pinch-select anchoring --
instead of taking the controller node's raw pose.

Measured basis (standalone Quest 3, runtime 205.206.0): the runtime
advertises `XR_EXT_hand_interaction` and publishes an aim pose on >95% of
tracked-hand samples; the derived ray separates from it by 29.5 deg mean
(right) / 48.1 deg (left). Two switches were both required: the action-map
profile binding AND `xr/openxr/extensions/hand_interaction_profile=true` --
Godot requests the extension only when the setting is on
(openxr_hand_interaction_extension.cpp:59), so the 2026-07-25 binding alone
was inert on every runtime.

This supersedes the rationale (not the outcome) of 2026-07-03 "Far Rays
Prefer The Runtime Aim Pose": that decision picked the OS pose by taking the
controller node's pose raw. The hand path now sources the same OS pose, so
preferring the hand path keeps that decision's winner while adding the tuned
conditioning. Physical controllers are unaffected (the hand tracker is dead
while one is held). Quest Link keeps the derived ray: its runtime does not
advertise the extension at all.

Amendment, same day, after the first in-headset run: a publishing runtime
also WITHHOLDS the pose per frame when it stops trusting a hand (measured:
24 of 26 withheld samples were the left hand, in look-away windows), and
falling back to the derived ray for those frames swept the visible line by
the full 40-52 deg separation -- reported on device as the left ray jumping
from the UI to the far right. Once a hand has ever had a platform pose, a
withheld frame now HOLDS the last platform ray; only runtimes that never
publish (Link) use the derived fallback.

Second amendment, same day: a hand leaving view ends in FULL data loss whose
terminal extrapolated frames sit inside the FOV cone, so the gate expires the
hand as "gone" and the ray vanished on look-away (left hand, on device). No
cone angle can classify frames that lie about position. The platform-aim
hold now survives full tracker loss for platform_aim_hold_sec (default 10 s,
both hands), then hides the ray. Ray-only; the gate and mesh are untouched.

Third amendment, same day: the runtime's last ~0.4 s of published poses
before a withhold wander with the dying extrapolation, so parking on the
last published pose parks displaced ("shifts a little on look-away", left
hand, on device). The park now comes from the newest settled sample older
than platform_aim_park_backtime_sec (1.0 s), garbage republish bursts do not
unpark (platform_aim_resume_sec, 0.75 s), and a loss beyond the grace window
clears all park state so reacquisition is a clean slate.

Fourth and fifth amendments, same day, after TWO on-device rejections in a
row: parking on any withheld frame froze the ray in ordinary use ("stuck"),
and its correction still demanded a continuous healthy streak before
un-parking, which dirty-but-usable streams never satisfy -- the ray floated
detached from a visibly tracked hand. Both hysteresis machineries were
deleted. The shipped algorithm is the user's own framing ("right hand
behavior is the role model"): a published pose drives the ray the instant
it exists, unconditionally; memory only fills gaps -- last pose under
platform_aim_fill_sec (0.25 s), the aged pre-wander park pose beyond it,
hidden after platform_aim_hold_sec (10 s) of loss. The accepted cost is the
ray briefly following the loss dance's 150-300 ms garbage republish bursts,
which was never the reported problem; the machineries that suppressed it
were. _test_micro_withhold_resumes_instantly and
_test_republish_after_park_resumes_instantly each fail against one of the
rejected versions.

Sixth amendment, same day, after the simplified shape earned in ("behaves
way better"): a long gap on a STILL-TRACKED hand parked the ray in space
while the visible hand walked away. The gap pose now translates with the
palm-anchored delta since the gap began (the pinch stabilizer's own
mechanism); direction stays held; a fully lost hand still parks in space.

Seventh amendment, same day ("way better", one slight movement left on
look-away): measured left gap showed ~2 deg of actual aim drift -- the
visible movement was gap-boundary seams. The aged history now applies only
when the tail disagrees with it beyond platform_aim_wander_threshold_deg
(5 deg); the gap display is computed once per frame in _process and stays
put across the capture's one-frame liveness blips. Right-vs-left remains a
data difference, not a code difference: five aim-stream gaps in 40 s on the
left, zero on the right.

Eighth amendment, same day ("clear difference in behavior, left has some
issue"): the log showed the real scale -- the LEFT aim stream churns, 11
withhold/republish cycles in 27 s of ordinary use against ZERO on the
right. Under churn any frozen-direction gap display is a visible stutter,
so a gap on a still-tracked hand no longer freezes at all: the palm frame
drives the ray through the offset calibrated at gap start (recalibrated to
the aged history at the fill boundary only if the tail was wander), exact
continuity at gap entry, moving with the hand throughout. Parking now only
happens for a hand that is actually lost.

Full evidence: docs/XR_INPUT_PRACTICES.md "Standalone answered it".
Verification: test_platform_aim (14 checks, 15 mutations caught across its
lifetime); in-headset verdict pending.
