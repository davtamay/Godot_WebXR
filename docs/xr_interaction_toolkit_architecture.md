# Godot XR Interaction Toolkit — Architecture (Phase 0)

Status: adopted 2026-07-02. Governs `addons/godot_xr_interaction_toolkit/`.

## Goal

A reusable, drop-in Godot 4.4+/4.7+ addon that recreates the main Unity XR
Interaction Toolkit (XRITK) concepts in idiomatic Godot, so a Unity-trained team
can carry its interaction vocabulary into Godot projects. Pure GDScript addon —
**no engine modules, no custom export templates** (an engine module would force
custom editor + template builds on every consumer, which kills reuse; nothing in
the phase plan needs engine code).

## Unity XRITK → Godot concept map

| Unity XRITK concept | This addon | Godot mechanism |
|---|---|---|
| XR Interaction Manager | `XRInteractionManager` (Node) | Registry + select arbitration; found via group `xr_interaction_manager` |
| Interactor (base) | `XRBaseInteractor` (Node3D) | `_physics_process` candidate computation; signals |
| Interactable (base) | `XRBaseInteractable` (Node3D) | Registers its colliders with the manager; signals |
| Hover / Select / Activate | `hover_entered/exited`, `select_entered/exited`, (`activated` in Phase 4) | Godot signals, one argument = the other party |
| Ray Interactor | `XRRayInteractor` | `PhysicsRayQueryParameters3D` + `direct_space_state.intersect_ray` |
| Direct Interactor | `XRDirectInteractor` (Phase 3) | `Area3D` overlap tests |
| Socket Interactor | `XRSocketInteractor` (Phase 3+) | `Area3D` + auto-select |
| Grab Interactable | `XRGrabInteractable` | Moves a target `Node3D`/`RigidBody3D`; movement modes below |
| Movement Type (Instant/Kinematic/VelocityTracked) | `MovementType` enum | set transform / lerp / `linear_velocity` drive |
| Attach Transform | `attach_transform_path` | Offset preserved via `Transform3D` math |
| Interaction Layer Mask | `interaction_layers` int flags on both sides | `XRInteractionLayerMask.overlaps(a, b)` — decoupled from physics layers |
| XR Controller (device wrapper) | `XRInputAdapter` + subclasses | See input adapters |
| Line Visual / Reticle | `XRInteractorLineVisual`, `XRReticleVisual` | `ImmediateMesh` beam + mesh reticle, `top_level = true`, world-space |
| UI input module | Phase 5 | `SubViewport` + `Control` ray forwarding |
| Locomotion system | Phase 6 | Teleport ray + turn/move providers |

Naming intentionally mirrors XRITK concepts (concepts and workflows are
recreated from Godot APIs; no Unity source is referenced or copied).

## The load-bearing design decision: input adapters

Interaction logic (hover/select/grab math) must not know where poses and select
events come from. WebXR and OpenXR differ exactly there:

- **WebXR** (proven on Quest 3 Browser): session managed by `WebXRInterface`;
  select events arrive as interface-level signals `selectstart`/`select`/`selectend`
  with an `input_source_id`, resolved to handedness via
  `WebXRInterface.get_input_source_tracker(id).hand`. Controller aim pose comes
  from `XRController3D` (tracker `left_hand`/`right_hand`, pose `aim`). Hand
  tracking arrives via `XRHandTracker` at `/user/hand_tracker/left|right`
  (origin-local transforms), and Quest generates system pinch selectstart events
  for hands, so **no custom pinch detector is needed for select on Quest**.
- **OpenXR** (native, later): per-controller button/float signals on
  `XRController3D` (`trigger_click` etc.); same `XRHandTracker` API.

So the split is:

```text
XRInputAdapter (abstract, Node)
├── signals: select_started(hand:int), select_ended(hand:int)
├── get_aim_pose(hand) -> {origin, direction, basis}   # GLOBAL space, {} if untracked
├── is_hand_active(hand) -> bool
└── get_source_kind(hand) -> NONE | CONTROLLER | HAND

WebXRInputAdapter  — WebXR signals + controller-aim-else-hand-ray fallback
OpenXRInputAdapter — controller signals; native smoke path
XRHandGestureProvider — XRHandTracker geometry: pinch strength/state + hand ray
                        (thumb-tip/index-tip midpoint cursor, palm→cursor direction,
                        the exact geometry validated in the prototype)
```

Interactors reference an adapter by NodePath and never touch `WebXRInterface`
directly. Porting the demo to native OpenXR later = swap one node.

### Hand-ray fallback (from the validated prototype)

When a controller is not tracked but a hand is: cursor = midpoint(thumb tip,
index tip); direction = normalize(cursor − palm [fallback wrist]); origin =
cursor + direction × 0.025. Joint validity gates on
`HAND_JOINT_FLAG_POSITION_VALID | HAND_JOINT_FLAG_POSITION_TRACKED`.
`XRHandTracker` transforms are **XROrigin3D-local**; the adapter converts to
global using its origin reference.

## Interaction flow per physics frame

```text
XRRayInteractor._physics_process:
  pose = adapter.get_aim_pose(hand)         # empty → hide visuals, keep selection frozen
  hit  = intersect_ray(pose, max_distance, collision_mask)
  interactable = manager.get_interactable_for_collider(hit.collider)   # collider registry
  layer check: XRInteractionLayerMask.overlaps(interactor, interactable)
  hover transition → interactable._notify_hover_* + interactor signals
  if selecting: grab pose = point on ray at grab_distance (basis = ray basis)

adapter.select_started(hand) → interactor:
  manager.request_select(self, hovered)      # exclusivity arbitration
  grab_distance = clamp(hover distance, 0.25, max_distance)

XRGrabInteractable (while selected, its own _physics_process):
  desired = interactor.get_attach_pose() * grab_offset
  INSTANT: set transform | KINEMATIC_SMOOTH: lerp(smoothing_speed)
  VELOCITY_TRACKED (RigidBody3D): linear_velocity = Δpos/Δt  → free throw on release
```

Manager arbitration rules: an interactor selects at most one interactable; an
interactable is selected by at most one interactor (Phase 4 two-hand grab will
relax this behind an opt-in flag). Hover is independent per interactor.

Visual feedback (hover highlight, select tint) is **not** toolkit logic — the
toolkit emits signals; the consuming scene decides affordances. This matches
XRITK (interaction events + affordance system are separate).

## XR Tools decision: stay independent

Godot XR Tools (MIT, GodotVR) is a scene-composition toolkit (function pointers,
staging, snap zones) built primarily around OpenXR staging; its WebXR usage is
secondary and it carries known Quest-Browser performance issues in its demo
(godot-xr-tools issue #453). We are building an XRITK-shaped **component**
model, which is a different API philosophy. Decision: **independent addon, no
XR Tools dependency**; nothing prevents a project from using both. Revisit only
if Phase 6 locomotion turns out to duplicate XR Tools' hardest work.

## Addon layout

```text
addons/godot_xr_interaction_toolkit/
  plugin.cfg
  plugin.gd                      # @tool EditorPlugin (custom-type icons later)
  runtime/
    xr_interaction_layers.gd     # XRInteractionLayerMask helper
    xr_interaction_manager.gd
    xr_base_interactor.gd
    xr_base_interactable.gd
    xr_ray_interactor.gd
    xr_grab_interactable.gd
    xr_interactor_line_visual.gd
    xr_reticle_visual.gd
    input/
      xr_input_adapter.gd
      webxr_input_adapter.gd
      openxr_input_adapter.gd
      xr_hand_gesture_provider.gd
  samples/                       # Phase 8
  README.md
```

All runtime classes use `class_name`, so the addon works without enabling the
editor plugin (the plugin only adds editor conveniences).

## Platform reality constraints (validated on hardware)

- Quest 3 Quest Browser: full path works (controllers, hands, pinch select).
  Godot WebXR **requires `OVR_multiview2`/`OCULUS_multiview`** in the browser's
  WebGL2 context ("layers" is a required feature in the session request).
- Samsung Galaxy XR / tested Android XR browsers: WebXR + WebGL2 present but **no
  multiview extensions → Godot WebXR stereo fails there**. Browser capability
  gap, not an export flag. Track separately; do not burn addon time on it.
- Desktop editor/preview: no WebXR — adapters report inactive; scene must stay
  usable as a flat preview (visuals hide when `use_xr` is false).

## Phase roadmap (from the mission brief)

0 this doc · 1 skeleton + first deliverable (manager + ray + grab refactor) ·
2 ray polish (bezier, scroll-distance, movement modes) · 3 direct interactor ·
4 grab depth (two-hand, throw) · 5 UI rays on `Control` · 6 locomotion ·
7 hands/gestures abstraction · 8 samples + test matrix.

First deliverable acceptance: on Quest Browser, point at the cube, hover it,
pinch/trigger to grab, move it on the ray, release. Ray must originate at the
aim pose and match cursor intent.
