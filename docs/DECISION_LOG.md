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
