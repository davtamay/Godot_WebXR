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
