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
   - Under `XROrigin3D`, add one `XRRayInteractor` (`Node3D`) per hand; set
     `hand` (`0` = left, `1` = right) and `input_adapter_path` at the adapter.
     Add `XRInteractorLineVisual` and `XRReticleVisual` (`MeshInstance3D`)
     children for the beam and cursor.
   - For desktop/mobile preview, add one `XRScreenRayInteractor` (`Node3D`) and
     point `camera_path` at the scene camera. It turns mouse hover/click and
     touch press/drag into the same hover/select pipeline as XR rays.
   - Make objects grabbable by giving them an `XRGrabInteractable` (`Node3D`)
     root with a `CollisionObject3D` descendant for the ray to hit.
3. Feedback: connect to `hover_entered`, `hover_exited`, `select_entered`, and
   `select_exited` on interactors or interactables. The toolkit never changes
   your materials.
4. Session lifecycle, including requesting the WebXR session and setting
   `viewport.use_xr`, stays in your project. See
   `demo/scripts/webxr_bootstrap.gd` for a working example that requests
   optional `hand-tracking` and required `layers`.

Interaction layers: `interaction_layers` bitmasks on interactor and interactable
must share a bit (default: both `1`). They are independent of physics layers;
`XRRayInteractor.collision_mask` and `XRScreenRayInteractor.collision_mask`
control what each ray can physically hit.

## Platform Notes

- Quest 3 / Quest Browser: works in the feasibility spike path; this addon
  export is ready for the manual acceptance pass.
- Samsung Galaxy XR / tested Android XR browsers: WebXR and WebGL2 are present,
  but Godot WebXR stereo fails when the browser does not expose
  `OVR_multiview2` or `OCULUS_multiview`. This is a browser capability gap, not
  an addon or export-flag issue.
- Desktop with no XR session: adapters report no poses, interactors idle, and
  the scene stays usable as a flat preview.
