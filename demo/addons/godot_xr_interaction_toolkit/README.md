# Godot XR Interaction Toolkit

XR Interaction Toolkit-style interaction for Godot 4.4+/4.7+: interactors,
interactables, a select-arbitration manager, and input adapters that keep
WebXR/OpenXR specifics out of interaction logic. Pure GDScript — no engine
builds, no export-template changes.

Architecture: see `docs/xr_interaction_toolkit_architecture.md` in this repo.

## Quick start (WebXR)

1. Copy `addons/godot_xr_interaction_toolkit/` into your project and optionally
   enable the plugin in Project Settings.
2. Scene setup:
   - Add an `XRInteractionManager` as a plain `Node` anywhere in the scene.
   - Add a `WebXRInputAdapter` as a plain `Node`; point `xr_origin_path` at your
     `XROrigin3D` and the controller paths at your two `XRController3D` nodes
     with tracker `left_hand`/`right_hand` and pose `aim`.
   - Under `XROrigin3D`, add one `XRDirectInteractor` (`Node3D`) per hand for
     near hand grabs, then one `XRRayInteractor` (`Node3D`) per hand for far
     grabs; set `hand` (`0` = left, `1` = right) and `input_adapter_path` at
     the adapter. Put direct interactors before rays in the scene tree so a
     nearby object gets first chance on pinch. Point each ray's
     `suppress_interactor_path` at that hand's direct interactor so the far ray
     hides while near hover/grab is active. Add `XRInteractorLineVisual` and
     `XRReticleVisual` (`MeshInstance3D`) children to ray interactors for the
     beam and cursor.
   - For desktop/mobile preview, add one `XRScreenRayInteractor` (`Node3D`) and
     point `camera_path` at the scene camera. It turns mouse hover/click and
     touch press/drag into the same hover/select pipeline as XR rays.
   - Make objects grabbable by giving them an `XRGrabInteractable` (`Node3D`)
     root with a `CollisionObject3D` descendant for the ray to hit.
   - Add an `XRSocketInteractor` (`Node3D`) anywhere you need a snap zone.
     Set `socket_radius` and place it at the desired attach pose. Objects with
     `XRGrabInteractable.snap_to_attach = true` snap to the socket when the
     socket auto-selects them.
3. Feedback: connect to `hover_entered`, `hover_exited`, `select_entered`, and
   `select_exited` on interactors or interactables. The toolkit never changes
   your materials.
4. Session lifecycle, including requesting the WebXR session and setting
   `viewport.use_xr`, stays in your project. See
   `demo/scripts/webxr_bootstrap.gd` for a working example that requests
   optional `hand-tracking` and required `layers`.

Interaction layers: `interaction_layers` bitmasks on interactor and interactable
must share a bit (default: both `1`). They are independent of physics layers;
`XRDirectInteractor.collision_mask`, `XRRayInteractor.collision_mask`, and
`XRScreenRayInteractor.collision_mask` control what each interactor can
physically hit.

Inspector customization: runtime scripts are Godot components. Add the script
to a node and tune its exported properties in the Inspector. The major
components group their settings by target/attach/movement, raycast,
suppression, direct hover, UI panel, WebXR input, pinch select, and browser
bridge behavior.

Two-hand grab: enable `two_hand_grab_enabled` on `XRGrabInteractable` to allow
a second interactor to select the same object. With `two_hand_rotate` enabled,
the object rotates with the hand-to-hand span. With `two_hand_scale` enabled,
the object uniformly scales as the hands move closer/farther apart. Use
`track_position`, `track_rotation`, and `two_hand_track_position` to constrain
which transform channels follow the hands. One-hand grab behavior remains
unchanged for objects that do not opt in.

Throw on release: `XRGrabInteractable.throw_on_release` samples the selecting
interactor's attach-pose velocity and applies it to a `RigidBody3D` target when
the final interactor releases. Tune `throw_velocity_scale` and
`max_throw_speed` per object.

`WebXRInputAdapter.prefer_hand_ray` defaults to `false`, so far rays use the
runtime `XRController3D` aim pose first. On Quest hand tracking this better
matches the stable Meta OS cursor. The joint-derived hand ray remains available
as a fallback or experiment by setting `prefer_hand_ray = true`.

## Platform Notes

- Quest 3 / Quest Browser: works in the feasibility spike path; this addon
  export is ready for the manual acceptance pass.
- Samsung Galaxy XR / tested Android XR browsers: WebXR and WebGL2 are present,
  but Godot WebXR stereo fails when the browser does not expose
  `OVR_multiview2` or `OCULUS_multiview`. This is a browser capability gap, not
  an addon or export-flag issue.
- Desktop with no XR session: adapters report no poses, interactors idle, and
  the scene stays usable as a flat preview.
