# Godot XR Interaction Toolkit Addon — First Deliverable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the validated WebXR prototype into a reusable `addons/godot_xr_interaction_toolkit/` addon whose first deliverable is `XRInteractionManager` + `XRRayInteractor` + `XRGrabInteractable`, with the demo scene consuming addon APIs only.

**Architecture:** Pure-GDScript addon (no engine builds, no export-template changes) following `docs/xr_interaction_toolkit_architecture.md`: interaction logic (manager/interactor/interactable) is isolated from input sources behind `XRInputAdapter`; WebXR specifics live only in `WebXRInputAdapter`; visual affordances (highlight materials) stay in the demo scene, not the toolkit. All runtime classes use `class_name`, so the editor plugin is optional.

**Tech Stack:** Godot 4.7 (GDScript), Compatibility renderer, WebXR via `WebXRInterface`, hand tracking via `XRHandTracker`, headless test runner (`SceneTree` script — no external test framework).

## Global Constraints

- Godot binary for ALL commands: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe` (verified: `4.7.stable.official.5b4e0cb0f`). Referred to below as `$GODOT`. In every Bash command block, first run: `GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"`.
- Repo root: `c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff`. All paths below are relative to it. The Godot **project** root is `demo/`, so the addon lives at `demo/addons/godot_xr_interaction_toolkit/`.
- Test command (used in every task): `$GODOT --headless --path demo -s res://tests/run_tests.gd` — exits 0 on all-pass, 1 on any failure.
- No Godot engine source modification, no custom export templates, no renderer/backend work (CLAUDE.md Phase 1 boundary).
- Do NOT claim WebGPU rendering anywhere. Web export = WASM + WebGL2 + Compatibility renderer.
- Addon must not reference any `res://scripts/` or `res://scenes/` file (addon is drop-in reusable). Demo may reference addon.
- GDScript style: 4-space indentation (matches existing `demo/scripts/*.gd`), tabs are NOT used in this project.
- Toolkit emits signals only; it never changes materials/scales of interactables (affordances are the consumer's job).
- Quest-on-device verification happens once at the end (Task 10); every prior task verifies headless.
- Git: commit at the end of every task. Do not push. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## File Structure (end state)

```text
demo/addons/godot_xr_interaction_toolkit/
  plugin.cfg                     # addon manifest
  plugin.gd                      # @tool EditorPlugin (empty for now; optional to enable)
  README.md                      # usage doc
  runtime/
    xr_interaction_layers.gd     # XRInteractionLayerMask — pure bitmask helper
    xr_interaction_manager.gd    # XRInteractionManager — collider registry + select arbitration
    xr_base_interactable.gd      # XRBaseInteractable — registration, hover/select state + signals
    xr_base_interactor.gd        # XRBaseInteractor — adapter wiring, hover/select transitions
    xr_ray_interactor.gd         # XRRayInteractor — raycast, hover, grab distance, attach pose
    xr_grab_interactable.gd      # XRGrabInteractable — follows interactor attach pose, movement modes
    xr_interactor_line_visual.gd # XRInteractorLineVisual — world-space beam
    xr_reticle_visual.gd         # XRReticleVisual — world-space hit reticle
    input/
      xr_input_adapter.gd        # XRInputAdapter — abstract poses + select signals
      xr_hand_gesture_provider.gd# XRHandGestureProvider — XRHandTracker ray geometry (static)
      webxr_input_adapter.gd     # WebXRInputAdapter — WebXR signals + controller/hand poses
demo/tests/run_tests.gd          # headless test runner (grows task by task)
demo/scripts/xr_demo_affordance.gd  # demo-side hover/select visual feedback
demo/scenes/Main.tscn            # MODIFIED: consumes addon nodes
demo/project.godot               # MODIFIED: plugin enabled
demo/scripts/xr_ray_interactor.gd   # DELETED in Task 9 (replaced by addon)
docs/DECISION_LOG.md             # appended
docs/EVIDENCE_LOG.md             # appended
```

Class dependency order (why tasks are ordered as they are): `XRInteractionLayerMask` (no deps) → `XRInputAdapter`/`XRHandGestureProvider` (no deps) → `XRBaseInteractable`+`XRInteractionManager`+`XRBaseInteractor` (mutually referential, one task) → `XRRayInteractor` → `WebXRInputAdapter` → `XRGrabInteractable` → visuals → scene.

---

### Task 1: Prototype checkpoint commit + addon skeleton + test harness

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/plugin.cfg`
- Create: `demo/addons/godot_xr_interaction_toolkit/plugin.gd`
- Create: `demo/addons/godot_xr_interaction_toolkit/README.md`
- Create: `demo/tests/run_tests.gd`
- Modify: `demo/project.godot` (enable plugin)

**Interfaces:**
- Produces: test runner `res://tests/run_tests.gd` with `check(condition: bool, message: String) -> void` helper and `_initialize()` entry; all later tasks add `_test_*()` methods to it and call them from `_initialize()`.

- [ ] **Step 1: Commit the pending prototype work as a checkpoint** (working tree currently has modified `demo/scenes/Main.tscn`, `demo/scripts/webxr_bootstrap.gd` and untracked `demo/scripts/webxr_hand_visualizer.gd`, `demo/scripts/xr_ray_interactor.gd`, `demo/web/webxr_webgl_matrix.html`, `demo/web/webxr_webgl_probe.html`, `docs/xr_interaction_toolkit_architecture.md`). This preserves the prototype in history before the refactor deletes/replaces parts of it.

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git add demo/scenes/Main.tscn demo/scripts/webxr_bootstrap.gd demo/scripts/webxr_hand_visualizer.gd demo/scripts/xr_ray_interactor.gd demo/web/webxr_webgl_matrix.html demo/web/webxr_webgl_probe.html docs/xr_interaction_toolkit_architecture.md
git commit -m "Checkpoint: hand visualizer + ray interactor prototype, Phase 0 architecture doc

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Create `demo/addons/godot_xr_interaction_toolkit/plugin.cfg`**

```ini
[plugin]

name="Godot XR Interaction Toolkit"
description="XR Interaction Toolkit-style interactors, interactables, and input adapters for Godot 4.4+/4.7+. WebXR-first, OpenXR-ready. Pure GDScript."
author="OSE"
version="0.1.0"
script="plugin.gd"
```

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/plugin.gd`**

```gdscript
@tool
extends EditorPlugin

## All runtime classes are plain class_name scripts, so the toolkit works even
## when this plugin is disabled. The plugin exists to host future editor
## conveniences (custom-type icons, gizmos).
```

- [ ] **Step 4: Create `demo/addons/godot_xr_interaction_toolkit/README.md`**

```markdown
# Godot XR Interaction Toolkit

XR Interaction Toolkit-style interaction for Godot 4.4+/4.7+: interactors,
interactables, a select-arbitration manager, and input adapters that keep
WebXR/OpenXR specifics out of interaction logic. Pure GDScript — no engine
builds, no export-template changes.

Architecture: see `docs/xr_interaction_toolkit_architecture.md` in this repo.

Usage docs land with the first deliverable (manager + ray interactor + grab
interactable). See `samples/` in later phases.
```

- [ ] **Step 5: Enable the plugin in `demo/project.godot`** — add this section between `[display]` and `[rendering]` (alphabetical section order is convention, not required; anywhere works, keep it tidy):

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_xr_interaction_toolkit/plugin.cfg")
```

- [ ] **Step 6: Create `demo/tests/run_tests.gd`** — the headless runner every later task extends:

```gdscript
extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    print("%d checks, %d failures" % [_checks, _failures])
    quit(1 if _failures > 0 else 0)

func check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS: " + message)
    else:
        _failures += 1
        printerr("FAIL: " + message)
```

(`_run_all` is `await`-ed so later physics-integration tests can `await physics_frame`; with zero tests it must print `0 checks, 0 failures` and exit 0.)

- [ ] **Step 7: Run the test runner and the project load check**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd
echo "runner exit: $?"
"$GODOT" --headless --path demo --quit
echo "project load exit: $?"
```

Expected: runner prints `0 checks, 0 failures`, exit 0. Project load exits 0 (Godot 4.7 may reimport assets on first open — that is fine; commit any regenerated `*.uid` files it creates).

- [ ] **Step 8: Commit**

```bash
git add demo/addons demo/tests demo/project.godot
git add -A demo   # pick up any *.uid files Godot 4.7 generated
git commit -m "Addon skeleton: plugin manifest, headless test runner, plugin enabled

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: XRInteractionLayerMask

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd`
- Test: `demo/tests/run_tests.gd` (add `_test_layer_mask`)

**Interfaces:**
- Produces: `XRInteractionLayerMask.overlaps(layers_a: int, layers_b: int) -> bool` (static). Used by `XRBaseInteractable.can_hover/can_select` (Task 4).

- [ ] **Step 1: Write the failing test** — in `demo/tests/run_tests.gd`, add the call `_test_layer_mask()` as the first line of `_run_all()` (before the summary print), and add the method:

```gdscript
func _test_layer_mask() -> void:
    check(XRInteractionLayerMask.overlaps(1, 1), "layer 1 overlaps layer 1")
    check(XRInteractionLayerMask.overlaps(0b0110, 0b0100), "masks sharing one bit overlap")
    check(not XRInteractionLayerMask.overlaps(0b0011, 0b0100), "disjoint masks do not overlap")
    check(not XRInteractionLayerMask.overlaps(0, 0), "zero masks never overlap")
```

- [ ] **Step 2: Run tests to verify failure**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd; echo "exit: $?"
```

Expected: parse error mentioning `XRInteractionLayerMask` not declared; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd`**

```gdscript
class_name XRInteractionLayerMask
extends RefCounted

## Interaction-layer arbitration, deliberately decoupled from physics layers
## (mirrors Unity XRITK's Interaction Layer Mask vs physics layers split).

static func overlaps(layers_a: int, layers_b: int) -> bool:
    return (layers_a & layers_b) != 0
```

- [ ] **Step 4: Run tests to verify pass** — same command as Step 2. Expected: `4 checks, 0 failures`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add XRInteractionLayerMask with headless tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: XRInputAdapter base + XRHandGestureProvider

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd`
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd`
- Test: `demo/tests/run_tests.gd` (add `_test_hand_ray_geometry`, `_set_joint` helper)

**Interfaces:**
- Produces: `XRInputAdapter` (Node) with `enum Hand { LEFT = 0, RIGHT = 1 }`, `enum SourceKind { NONE, CONTROLLER, HAND }`, signals `select_started(hand: int)` / `select_ended(hand: int)`, virtual `get_aim_pose(hand: int) -> Dictionary` returning `{origin: Vector3, direction: Vector3, basis: Basis}` in GLOBAL space or `{}` when untracked, `is_hand_active(hand: int) -> bool`, `get_source_kind(hand: int) -> int`.
- Produces: `XRHandGestureProvider` (RefCounted) statics: `joint_position_valid(tracker: XRHandTracker, joint: int) -> bool`, `get_hand_ray_pose(tracker: XRHandTracker) -> Dictionary` returning **XROrigin3D-local** `{origin: Vector3, direction: Vector3}` or `{}`, `basis_from_forward(direction: Vector3) -> Basis` (basis whose -Z is the direction), and constant `RAY_ORIGIN_FORWARD_OFFSET := 0.025`.
- Consumed by: `WebXRInputAdapter` (Task 6), `XRBaseInteractor` (Task 4).

- [ ] **Step 1: Write the failing test** — in `demo/tests/run_tests.gd`, add `_test_hand_ray_geometry()` to `_run_all()` after `_test_layer_mask()`, and add:

```gdscript
func _test_hand_ray_geometry() -> void:
    check(XRHandGestureProvider.get_hand_ray_pose(null).is_empty(), "null tracker yields empty pose")

    var tracker := XRHandTracker.new()
    tracker.has_tracking_data = true
    var valid := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
    _set_joint(tracker, XRHandTracker.HAND_JOINT_WRIST, Vector3.ZERO, valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_PALM, Vector3(0, 0, -0.05), valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_THUMB_TIP, Vector3(0.01, 0, -0.15), valid)
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), valid)

    var pose := XRHandGestureProvider.get_hand_ray_pose(tracker)
    check(not pose.is_empty(), "valid joints yield a ray pose")
    if not pose.is_empty():
        # cursor = midpoint(thumb tip, index tip) = (0,0,-0.15); seed = palm; direction = palm->cursor.
        check((pose["direction"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "direction points palm to cursor")
        var expected_origin := Vector3(0, 0, -0.15) + Vector3(0, 0, -1) * XRHandGestureProvider.RAY_ORIGIN_FORWARD_OFFSET
        check((pose["origin"] as Vector3).is_equal_approx(expected_origin), "origin is cursor nudged forward along the ray")

    # Index tip invalid -> no pose (wrist+index are the required minimum).
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), 0)
    check(XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "invalid index tip yields empty pose")
    _set_joint(tracker, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, Vector3(-0.01, 0, -0.15), valid)

    tracker.has_tracking_data = false
    check(XRHandGestureProvider.get_hand_ray_pose(tracker).is_empty(), "no tracking data yields empty pose")

    var forward := Vector3(1, 0, 0)
    var ray_basis := XRHandGestureProvider.basis_from_forward(forward)
    check((-ray_basis.z).is_equal_approx(forward), "basis_from_forward points -Z along the ray")
    var up_basis := XRHandGestureProvider.basis_from_forward(Vector3.UP)
    check((-up_basis.z).is_equal_approx(Vector3.UP), "basis_from_forward survives the straight-up singularity")

func _set_joint(tracker: XRHandTracker, joint: int, position: Vector3, flags: int) -> void:
    tracker.set_hand_joint_transform(joint, Transform3D(Basis.IDENTITY, position))
    tracker.set_hand_joint_flags(joint, flags)
```

- [ ] **Step 2: Run tests to verify failure**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd; echo "exit: $?"
```

Expected: parse error mentioning `XRHandGestureProvider`; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd`**

```gdscript
class_name XRInputAdapter
extends Node

## Abstract input source for interactors. Interaction logic must never know
## whether poses/select events come from WebXR or OpenXR — subclasses do.

enum Hand { LEFT = 0, RIGHT = 1 }
enum SourceKind { NONE, CONTROLLER, HAND }

signal select_started(hand: int)
signal select_ended(hand: int)

## Returns {origin: Vector3, direction: Vector3, basis: Basis} in GLOBAL space,
## or {} when this hand has no tracked aim pose.
func get_aim_pose(_hand: int) -> Dictionary:
    return {}

func is_hand_active(hand: int) -> bool:
    return not get_aim_pose(hand).is_empty()

func get_source_kind(_hand: int) -> int:
    return SourceKind.NONE
```

- [ ] **Step 4: Create `demo/addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd`** — the exact hand-ray geometry validated on Quest 3 in the prototype (`demo/scripts/xr_ray_interactor.gd` lines 166-197 before deletion):

```gdscript
class_name XRHandGestureProvider
extends RefCounted

## XRHandTracker geometry helpers. Returned transforms are XROrigin3D-local,
## matching XRHandTracker joint data; callers convert to global space.
## Ray recipe (validated on Quest 3 Browser): cursor = midpoint(thumb tip,
## index tip) [index tip alone if thumb invalid]; direction = normalize(cursor
## - palm [wrist if palm invalid]); origin = cursor nudged forward 2.5 cm.

const POSITION_VALID_FLAGS := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
const RAY_ORIGIN_FORWARD_OFFSET := 0.025

static func joint_position_valid(tracker: XRHandTracker, joint: int) -> bool:
    return (tracker.get_hand_joint_flags(joint) & POSITION_VALID_FLAGS) != 0

static func get_hand_ray_pose(tracker: XRHandTracker) -> Dictionary:
    if tracker == null or not tracker.has_tracking_data:
        return {}
    var wrist := XRHandTracker.HAND_JOINT_WRIST
    var palm := XRHandTracker.HAND_JOINT_PALM
    var index_tip := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
    var thumb_tip := XRHandTracker.HAND_JOINT_THUMB_TIP
    if not joint_position_valid(tracker, wrist) or not joint_position_valid(tracker, index_tip):
        return {}

    var cursor := tracker.get_hand_joint_transform(index_tip).origin
    if joint_position_valid(tracker, thumb_tip):
        cursor = (tracker.get_hand_joint_transform(thumb_tip).origin + cursor) * 0.5

    var direction_seed := tracker.get_hand_joint_transform(wrist).origin
    if joint_position_valid(tracker, palm):
        direction_seed = tracker.get_hand_joint_transform(palm).origin

    var direction := cursor - direction_seed
    if direction.length_squared() < 0.000001:
        return {}
    direction = direction.normalized()
    return {
        "origin": cursor + direction * RAY_ORIGIN_FORWARD_OFFSET,
        "direction": direction,
    }

static func basis_from_forward(direction: Vector3) -> Basis:
    var forward := direction.normalized()
    var up := Vector3.UP
    if absf(forward.dot(up)) > 0.95:
        up = Vector3.FORWARD
    return Basis.looking_at(forward, up)
```

- [ ] **Step 5: Run tests to verify pass** — same command as Step 2. Expected: `12 checks, 0 failures`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add XRInputAdapter base and XRHandGestureProvider hand-ray geometry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: XRBaseInteractable + XRInteractionManager + XRBaseInteractor

These three form one mutually-referential contract (registration, arbitration, hover/select state) and land together.

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_base_interactable.gd`
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd`
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd`
- Test: `demo/tests/run_tests.gd` (add `FakeAdapter` inner class, `_test_manager_registry_and_arbitration`, `_test_interactor_hover_and_select`)

**Interfaces:**
- Consumes: `XRInteractionLayerMask.overlaps` (Task 2), `XRInputAdapter` signals/enums (Task 3).
- Produces `XRBaseInteractable` (Node3D): signals `hover_entered/hover_exited/select_entered/select_exited(interactor: XRBaseInteractor)`; export `interaction_layers: int` (default 1); export `collider_paths: Array[NodePath]` (empty = auto-collect `CollisionObject3D` descendants); `get_colliders() -> Array[CollisionObject3D]`; `is_hovered() -> bool`; `is_selected() -> bool`; `get_selecting_interactor() -> XRBaseInteractor`; `can_hover(interactor) -> bool`; `can_select(interactor) -> bool`; internal `_notify_hover_entered/_notify_hover_exited/_notify_select_entered/_notify_select_exited(interactor)`.
- Produces `XRInteractionManager` (Node): `static find(from: Node) -> XRInteractionManager` (group `xr_interaction_manager`); `register_interactable(interactable)`; `unregister_interactable(interactable)`; `get_interactable_for_collider(collider: Object) -> XRBaseInteractable`; `request_select(interactor, interactable) -> bool`; `request_deselect(interactor) -> bool`.
- Produces `XRBaseInteractor` (Node3D): signals `hover_entered/hover_exited/select_entered/select_exited(interactable: XRBaseInteractable)`; exports `input_adapter_path: NodePath`, `hand: XRInputAdapter.Hand`, `interaction_layers: int` (default 1); `set_input_adapter(adapter: XRInputAdapter)`; `get_hovered() / get_selected() -> XRBaseInteractable`; `get_attach_pose() -> Transform3D` (virtual, base returns `global_transform`); internal `_set_hovered(interactable)`, `_try_select()`, `_release_select()`, `_notify_select_granted(interactable)`, `_notify_select_released(interactable)`; protected members `_manager: XRInteractionManager`, `_adapter: XRInputAdapter` used by subclasses.

- [ ] **Step 1: Write the failing tests** — in `demo/tests/run_tests.gd` add both test calls to `_run_all()` after `_test_hand_ray_geometry()`, add the inner class at the bottom of the file, and the two test methods below. Tests free nodes with `free()` (immediate), never `queue_free()`, so group lookups in later tests cannot resolve stale managers.

```gdscript
class FakeAdapter extends XRInputAdapter:
    var pose := {}
    func get_aim_pose(_hand: int) -> Dictionary:
        return pose
```

```gdscript
func _test_manager_registry_and_arbitration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    var body := StaticBody3D.new()
    interactable.add_child(body)
    root.add_child(interactable)

    check(manager.get_interactable_for_collider(body) == interactable, "collider resolves to its interactable")
    check(manager.get_interactable_for_collider(null) == null, "null collider resolves to null")

    var interactor_a := XRBaseInteractor.new()
    var interactor_b := XRBaseInteractor.new()
    root.add_child(interactor_a)
    root.add_child(interactor_b)

    check(manager.request_select(interactor_a, interactable), "first select is granted")
    check(interactor_a.get_selected() == interactable, "interactor tracks its selection")
    check(interactable.get_selecting_interactor() == interactor_a, "interactable tracks its selector")
    check(not manager.request_select(interactor_b, interactable), "second interactor refused: interactable is exclusive")
    check(not manager.request_select(interactor_a, interactable), "interactor cannot select twice")
    check(manager.request_deselect(interactor_a), "deselect succeeds")
    check(not interactable.is_selected(), "interactable is free after deselect")
    check(interactor_a.get_selected() == null, "interactor is free after deselect")
    check(manager.request_select(interactor_b, interactable), "freed interactable can be selected by another interactor")
    manager.request_deselect(interactor_b)

    interactable.interaction_layers = 2
    interactor_a.interaction_layers = 1
    check(not manager.request_select(interactor_a, interactable), "disjoint interaction layers refuse select")
    interactable.interaction_layers = 1

    root.remove_child(interactable)
    check(manager.get_interactable_for_collider(body) == null, "collider unregistered when interactable exits tree")

    interactor_a.free()
    interactor_b.free()
    interactable.free()
    manager.free()

func _test_interactor_hover_and_select() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)
    var interactor := XRBaseInteractor.new()
    root.add_child(interactor)

    var events: Array[String] = []
    interactor.hover_entered.connect(func(i: XRBaseInteractable) -> void: events.append("in:" + str(i == interactable)))
    interactor.hover_exited.connect(func(i: XRBaseInteractable) -> void: events.append("out:" + str(i == interactable)))
    interactable.select_entered.connect(func(_i: XRBaseInteractor) -> void: events.append("sel"))
    interactable.select_exited.connect(func(_i: XRBaseInteractor) -> void: events.append("desel"))

    interactor._set_hovered(interactable)
    check(interactable.is_hovered(), "interactable reports hovered")
    interactor._set_hovered(interactable)
    interactor._set_hovered(null)
    check(not interactable.is_hovered(), "interactable reports unhovered")
    check(events == (["in:true", "out:true"] as Array[String]), "hover signals fire once per transition, got %s" % str(events))

    events.clear()
    var adapter := FakeAdapter.new()
    root.add_child(adapter)
    interactor.set_input_adapter(adapter)
    interactor.hand = XRInputAdapter.Hand.RIGHT
    interactor._set_hovered(interactable)

    adapter.select_started.emit(XRInputAdapter.Hand.LEFT)
    check(interactor.get_selected() == null, "select for the other hand is ignored")
    adapter.select_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == interactable, "select via adapter selects the hovered interactable")
    adapter.select_ended.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == null, "select end releases the selection")
    check("sel" in events and "desel" in events, "interactable select signals fired, got %s" % str(events))

    interactor._set_hovered(null)
    adapter.select_started.emit(XRInputAdapter.Hand.RIGHT)
    check(interactor.get_selected() == null, "select with nothing hovered is a no-op")

    adapter.free()
    interactor.free()
    interactable.free()
    manager.free()
```

- [ ] **Step 2: Run tests to verify failure** — same command as before. Expected: parse errors for `XRInteractionManager` / `XRBaseInteractable` / `XRBaseInteractor`; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_base_interactable.gd`**

```gdscript
class_name XRBaseInteractable
extends Node3D

## Base interactable: registers its colliders with the XRInteractionManager
## and tracks hover/select state. Emits signals only — visual affordances are
## the consuming scene's responsibility (XRITK affordance-system split).

signal hover_entered(interactor: XRBaseInteractor)
signal hover_exited(interactor: XRBaseInteractor)
signal select_entered(interactor: XRBaseInteractor)
signal select_exited(interactor: XRBaseInteractor)

@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8") var interaction_layers := 1
## Colliders to register. Empty = auto-collect all CollisionObject3D descendants.
@export var collider_paths: Array[NodePath] = []

var _hovering_interactors: Array[XRBaseInteractor] = []
var _selecting_interactor: XRBaseInteractor

func _ready() -> void:
    var manager := XRInteractionManager.find(self)
    if manager:
        manager.register_interactable(self)
    else:
        push_warning("%s: no XRInteractionManager in the scene tree." % name)

func _exit_tree() -> void:
    var manager := XRInteractionManager.find(self)
    if manager:
        manager.unregister_interactable(self)

func get_colliders() -> Array[CollisionObject3D]:
    var colliders: Array[CollisionObject3D] = []
    if collider_paths.is_empty():
        _collect_colliders(self, colliders)
    else:
        for path in collider_paths:
            var collider := get_node_or_null(path) as CollisionObject3D
            if collider:
                colliders.append(collider)
    return colliders

func is_hovered() -> bool:
    return not _hovering_interactors.is_empty()

func is_selected() -> bool:
    return _selecting_interactor != null

func get_selecting_interactor() -> XRBaseInteractor:
    return _selecting_interactor

func can_hover(interactor: XRBaseInteractor) -> bool:
    return XRInteractionLayerMask.overlaps(interaction_layers, interactor.interaction_layers)

func can_select(interactor: XRBaseInteractor) -> bool:
    return _selecting_interactor == null and can_hover(interactor)

func _notify_hover_entered(interactor: XRBaseInteractor) -> void:
    _hovering_interactors.append(interactor)
    hover_entered.emit(interactor)

func _notify_hover_exited(interactor: XRBaseInteractor) -> void:
    _hovering_interactors.erase(interactor)
    hover_exited.emit(interactor)

func _notify_select_entered(interactor: XRBaseInteractor) -> void:
    _selecting_interactor = interactor
    select_entered.emit(interactor)

func _notify_select_exited(interactor: XRBaseInteractor) -> void:
    _selecting_interactor = null
    select_exited.emit(interactor)

func _collect_colliders(node: Node, out: Array[CollisionObject3D]) -> void:
    if node is CollisionObject3D:
        out.append(node)
    for child in node.get_children():
        _collect_colliders(child, out)
```

- [ ] **Step 4: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd`**

```gdscript
class_name XRInteractionManager
extends Node

## Collider registry + select arbitration. One per scene (found via group).
## Rules: an interactor selects at most one interactable; an interactable is
## selected by at most one interactor (two-hand grab relaxes this in Phase 4).

const GROUP_NAME := &"xr_interaction_manager"

var _collider_map := {}  # collider instance_id (int) -> XRBaseInteractable
var _selections := {}    # XRBaseInteractor -> XRBaseInteractable

static func find(from: Node) -> XRInteractionManager:
    return from.get_tree().get_first_node_in_group(GROUP_NAME) as XRInteractionManager

func _enter_tree() -> void:
    add_to_group(GROUP_NAME)

func register_interactable(interactable: XRBaseInteractable) -> void:
    for collider in interactable.get_colliders():
        _collider_map[collider.get_instance_id()] = interactable

func unregister_interactable(interactable: XRBaseInteractable) -> void:
    for id in _collider_map.keys():
        if _collider_map[id] == interactable:
            _collider_map.erase(id)
    var interactor := interactable.get_selecting_interactor()
    if interactor:
        request_deselect(interactor)

func get_interactable_for_collider(collider: Object) -> XRBaseInteractable:
    if collider == null:
        return null
    return _collider_map.get(collider.get_instance_id())

func request_select(interactor: XRBaseInteractor, interactable: XRBaseInteractable) -> bool:
    if interactor == null or interactable == null:
        return false
    if _selections.has(interactor):
        return false
    if not interactable.can_select(interactor):
        return false
    _selections[interactor] = interactable
    interactable._notify_select_entered(interactor)
    interactor._notify_select_granted(interactable)
    return true

func request_deselect(interactor: XRBaseInteractor) -> bool:
    if not _selections.has(interactor):
        return false
    var interactable: XRBaseInteractable = _selections[interactor]
    _selections.erase(interactor)
    interactable._notify_select_exited(interactor)
    interactor._notify_select_released(interactable)
    return true
```

- [ ] **Step 5: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd`**

```gdscript
class_name XRBaseInteractor
extends Node3D

## Base interactor: wires an XRInputAdapter's select events to manager-arbitrated
## selection and owns hover-transition bookkeeping. Subclasses compute WHAT is
## hovered (ray, proximity, socket) and call _set_hovered().

signal hover_entered(interactable: XRBaseInteractable)
signal hover_exited(interactable: XRBaseInteractable)
signal select_entered(interactable: XRBaseInteractable)
signal select_exited(interactable: XRBaseInteractable)

@export var input_adapter_path: NodePath
@export var hand: XRInputAdapter.Hand = XRInputAdapter.Hand.LEFT
@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8") var interaction_layers := 1

var _manager: XRInteractionManager
var _adapter: XRInputAdapter
var _hovered: XRBaseInteractable
var _selected: XRBaseInteractable

func _ready() -> void:
    _manager = XRInteractionManager.find(self)
    if _manager == null:
        push_warning("%s: no XRInteractionManager in the scene tree." % name)
    var adapter := get_node_or_null(input_adapter_path) as XRInputAdapter
    if adapter:
        set_input_adapter(adapter)

func _exit_tree() -> void:
    if _selected and _manager:
        _manager.request_deselect(self)

func set_input_adapter(adapter: XRInputAdapter) -> void:
    if _adapter:
        _adapter.select_started.disconnect(_on_adapter_select_started)
        _adapter.select_ended.disconnect(_on_adapter_select_ended)
    _adapter = adapter
    if _adapter:
        _adapter.select_started.connect(_on_adapter_select_started)
        _adapter.select_ended.connect(_on_adapter_select_ended)

func get_hovered() -> XRBaseInteractable:
    return _hovered

func get_selected() -> XRBaseInteractable:
    return _selected

## Global-space pose grabbed objects follow. Base: this node's transform.
func get_attach_pose() -> Transform3D:
    return global_transform

func _on_adapter_select_started(event_hand: int) -> void:
    if event_hand != hand:
        return
    _try_select()

func _on_adapter_select_ended(event_hand: int) -> void:
    if event_hand != hand:
        return
    _release_select()

func _try_select() -> void:
    if _selected or _hovered == null or _manager == null:
        return
    _manager.request_select(self, _hovered)

func _release_select() -> void:
    if _selected == null or _manager == null:
        return
    _manager.request_deselect(self)

func _set_hovered(interactable: XRBaseInteractable) -> void:
    if interactable == _hovered:
        return
    if _hovered:
        _hovered._notify_hover_exited(self)
        hover_exited.emit(_hovered)
    _hovered = interactable
    if _hovered:
        _hovered._notify_hover_entered(self)
        hover_entered.emit(_hovered)

func _notify_select_granted(interactable: XRBaseInteractable) -> void:
    _selected = interactable
    select_entered.emit(interactable)

func _notify_select_released(interactable: XRBaseInteractable) -> void:
    _selected = null
    select_exited.emit(interactable)
```

- [ ] **Step 6: Run tests to verify pass** — same command. Expected: `31 checks, 0 failures`, exit 0. (If the check count differs but failures are 0 and every test method printed its PASSes, update the expected count in this plan and move on.)

- [ ] **Step 7: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add interactable/manager/interactor core with arbitration tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: XRRayInteractor

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_ray_interactor.gd`
- Test: `demo/tests/run_tests.gd` (add `_test_ray_grab_distance_clamp`, `_test_ray_hover_and_grab_integration`)

**Interfaces:**
- Consumes: `XRBaseInteractor` (extends it), `XRInteractionManager.get_interactable_for_collider`, `XRInputAdapter.get_aim_pose`.
- Produces `XRRayInteractor` (extends `XRBaseInteractor`): exports `max_distance := 6.0`, `collision_mask := 1` (`@export_flags_3d_physics`), `collide_with_areas := true`, `min_grab_distance := 0.25`; `get_ray_state() -> Dictionary` — `{valid: bool}` when inactive, else `{valid: true, origin: Vector3, direction: Vector3, end: Vector3, hit: bool, hovered: XRBaseInteractable|null}`; overrides `get_attach_pose()` to return the pose at grab distance along the current ray. Visuals (Task 8) poll `get_ray_state()` each frame.
- Behavior contract: pose lost while selecting → visuals invalid but selection and last attach pose FROZEN (arch doc rule); hover is not re-evaluated while selecting; on select grant, grab distance = `clampf(hover_distance, min_grab_distance, max_distance)`.
- There is deliberately NO `viewport.use_xr` check: adapters return `{}` when their platform/session is inactive, which hides visuals and stops interaction in flat preview automatically (and keeps this class headless-testable).

- [ ] **Step 1: Write the failing tests** — add both calls to `_run_all()` after `_test_interactor_hover_and_select()`, and add:

```gdscript
func _test_ray_grab_distance_clamp() -> void:
    var ray := XRRayInteractor.new()
    root.add_child(ray)
    var interactable := XRBaseInteractable.new()
    root.add_child(interactable)

    ray._hover_distance = 2.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, 2.0), "grab distance = hover distance in range")
    ray._notify_select_released(interactable)

    ray._hover_distance = 0.05
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, ray.min_grab_distance), "grab distance clamps up to min_grab_distance")
    ray._notify_select_released(interactable)

    ray._hover_distance = 100.0
    ray._notify_select_granted(interactable)
    check(is_equal_approx(ray._grab_distance, ray.max_distance), "grab distance clamps down to max_distance")
    ray._notify_select_released(interactable)

    interactable.free()
    ray.free()

func _test_ray_hover_and_grab_integration() -> void:
    var manager := XRInteractionManager.new()
    root.add_child(manager)

    # 1m box centered at (0, 0, -2): near face at z = -1.5.
    var interactable := XRBaseInteractable.new()
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    body.add_child(shape)
    interactable.add_child(body)
    root.add_child(interactable)
    interactable.global_position = Vector3(0, 0, -2)

    var adapter := FakeAdapter.new()
    adapter.pose = {"origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    root.add_child(adapter)

    var ray := XRRayInteractor.new()
    root.add_child(ray)
    ray.set_input_adapter(adapter)
    ray.hand = XRInputAdapter.Hand.LEFT

    await physics_frame
    await physics_frame

    check(ray.get_hovered() == interactable, "ray hovers the box straight ahead")
    var state := ray.get_ray_state()
    check(state.get("valid", false), "ray state is valid with a tracked pose")
    check(state.get("hit", false), "ray state reports a hit")
    check((state["end"] as Vector3).is_equal_approx(Vector3(0, 0, -1.5)), "hit point is on the near face")

    adapter.select_started.emit(XRInputAdapter.Hand.LEFT)
    check(ray.get_selected() == interactable, "select grabs the hovered box")
    check(is_equal_approx(ray._grab_distance, 1.5), "grab distance captured from hover distance")
    var attach := ray.get_attach_pose()
    check(attach.origin.is_equal_approx(Vector3(0, 0, -1.5)), "attach pose sits at grab distance on the ray")

    # Move the ray pose; attach pose follows on the next physics frame.
    adapter.pose = {"origin": Vector3(0, 0.5, 0), "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    await physics_frame
    await physics_frame
    check(ray.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.5, -1.5)), "attach pose follows the moving ray at fixed grab distance")

    # Pose loss while selecting freezes selection and attach pose.
    adapter.pose = {}
    await physics_frame
    check(ray.get_selected() == interactable, "selection survives pose loss")
    check(ray.get_attach_pose().origin.is_equal_approx(Vector3(0, 0.5, -1.5)), "attach pose frozen during pose loss")
    check(not ray.get_ray_state().get("valid", true), "ray state invalid during pose loss")

    adapter.pose = {"origin": Vector3(0, 0.5, 0), "direction": Vector3(0, 0, -1), "basis": Basis.IDENTITY}
    adapter.select_ended.emit(XRInputAdapter.Hand.LEFT)
    check(ray.get_selected() == null, "release clears the selection")

    ray.free()
    adapter.free()
    interactable.free()
    manager.free()
```

- [ ] **Step 2: Run tests to verify failure** — same command. Expected: parse error for `XRRayInteractor`; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_ray_interactor.gd`**

```gdscript
class_name XRRayInteractor
extends XRBaseInteractor

## Raycasting interactor: hovers the nearest interactable along the adapter's
## aim ray and, while selecting, exposes an attach pose at the captured grab
## distance so XRGrabInteractable can follow the ray.

@export var max_distance := 6.0
@export_flags_3d_physics var collision_mask := 1
@export var collide_with_areas := true
@export var min_grab_distance := 0.25

var _ray_state := {"valid": false}
var _grab_distance := 0.0
var _hover_distance := 0.0
var _attach_pose := Transform3D.IDENTITY

func _physics_process(_delta: float) -> void:
    _update_ray()

## {valid: bool} when inactive, else {valid: true, origin, direction, end: Vector3,
## hit: bool, hovered: XRBaseInteractable or null}. Global space.
func get_ray_state() -> Dictionary:
    return _ray_state

func get_attach_pose() -> Transform3D:
    return _attach_pose

func _update_ray() -> void:
    var pose := _adapter.get_aim_pose(hand) if _adapter else {}
    if pose.is_empty():
        # Pose lost: hide visuals; keep any selection frozen at the last attach pose.
        _ray_state = {"valid": false}
        if _selected == null:
            _set_hovered(null)
        return

    var origin: Vector3 = pose["origin"]
    var direction: Vector3 = pose["direction"]
    var pose_basis: Basis = pose.get("basis", Basis.IDENTITY)
    var hit := _intersect(origin, direction)
    var hit_anything := not hit.is_empty()
    var end := hit["position"] as Vector3 if hit_anything else origin + direction * max_distance
    var hovered: XRBaseInteractable = null
    if hit_anything and _manager:
        var interactable := _manager.get_interactable_for_collider(hit["collider"])
        if interactable and interactable.can_hover(self):
            hovered = interactable

    _hover_distance = origin.distance_to(end)
    if _selected == null:
        _set_hovered(hovered)
        _attach_pose = Transform3D(pose_basis, end)
    else:
        _attach_pose = Transform3D(pose_basis, origin + direction * _grab_distance)

    _ray_state = {
        "valid": true,
        "origin": origin,
        "direction": direction,
        "end": end,
        "hit": hit_anything,
        "hovered": hovered,
    }

func _intersect(origin: Vector3, direction: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)
    query.collision_mask = collision_mask
    query.collide_with_areas = collide_with_areas
    query.collide_with_bodies = true
    return get_world_3d().direct_space_state.intersect_ray(query)

func _notify_select_granted(interactable: XRBaseInteractable) -> void:
    _grab_distance = clampf(_hover_distance, min_grab_distance, max_distance)
    super(interactable)
```

- [ ] **Step 4: Run tests to verify pass** — same command. Expected: all checks pass (roughly `47 checks, 0 failures`), exit 0. The integration test exercises a REAL physics raycast headlessly via `await physics_frame`.

- [ ] **Step 5: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add XRRayInteractor with physics-integration tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: WebXRInputAdapter

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd`
- Test: `demo/tests/run_tests.gd` (add `_test_webxr_adapter_inert_on_desktop`)

**Interfaces:**
- Consumes: `XRInputAdapter` (extends), `XRHandGestureProvider.get_hand_ray_pose` / `basis_from_forward`.
- Produces `WebXRInputAdapter`: exports `xr_origin_path`, `left_controller_path`, `right_controller_path` (NodePaths), `prefer_hand_ray := true`. Full `XRInputAdapter` contract. On non-web platforms it is inert (returns `{}` poses, emits nothing).
- Design notes baked in: WebXR select events are interface-level signals with an `input_source_id`, resolved to a hand via `WebXRInterface.get_input_source_tracker(id).hand`; Quest generates system pinch selectstart for hands so no custom pinch detector is needed. `prefer_hand_ray = true` reproduces the prototype's on-device behavior (hand ray beats controller aim when both track); flip it on-device in Task 10 if the browser's aim pose proves better.

- [ ] **Step 1: Write the failing test** — add the call to `_run_all()` after `_test_ray_hover_and_grab_integration()`, and add:

```gdscript
func _test_webxr_adapter_inert_on_desktop() -> void:
    var adapter := WebXRInputAdapter.new()
    root.add_child(adapter)
    check(adapter.get_aim_pose(XRInputAdapter.Hand.LEFT).is_empty(), "no aim pose without a WebXR session")
    check(adapter.get_aim_pose(XRInputAdapter.Hand.RIGHT).is_empty(), "no aim pose for either hand")
    check(adapter.get_source_kind(XRInputAdapter.Hand.LEFT) == XRInputAdapter.SourceKind.NONE, "source kind NONE on desktop")
    check(not adapter.is_hand_active(XRInputAdapter.Hand.LEFT), "hand inactive on desktop")
    adapter.free()
```

- [ ] **Step 2: Run tests to verify failure** — same command. Expected: parse error for `WebXRInputAdapter`; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd`**

```gdscript
class_name WebXRInputAdapter
extends XRInputAdapter

## WebXR input source: interface-level selectstart/selectend signals resolved
## to handedness, controller aim poses from XRController3D, and the validated
## XRHandTracker hand-ray fallback. Inert outside web exports.

@export var xr_origin_path: NodePath
@export var left_controller_path: NodePath
@export var right_controller_path: NodePath
## true (prototype-validated on Quest 3): prefer the computed hand ray over the
## controller aim pose when both report tracking. false: controller aim wins.
@export var prefer_hand_ray := true

const TRACKER_PATHS := {
    Hand.LEFT: &"/user/hand_tracker/left",
    Hand.RIGHT: &"/user/hand_tracker/right",
}

var _webxr: WebXRInterface
var _origin: Node3D
var _controllers := {}

func _ready() -> void:
    _origin = get_node_or_null(xr_origin_path) as Node3D
    _controllers[Hand.LEFT] = get_node_or_null(left_controller_path) as XRController3D
    _controllers[Hand.RIGHT] = get_node_or_null(right_controller_path) as XRController3D
    if not OS.has_feature("web"):
        return
    _webxr = XRServer.find_interface("WebXR") as WebXRInterface
    if _webxr == null:
        return
    _connect_interface_signal(&"selectstart", _on_selectstart)
    _connect_interface_signal(&"selectend", _on_selectend)

func get_aim_pose(hand_id: int) -> Dictionary:
    if prefer_hand_ray:
        var hand_pose := _hand_aim_pose(hand_id)
        return hand_pose if not hand_pose.is_empty() else _controller_aim_pose(hand_id)
    var controller_pose := _controller_aim_pose(hand_id)
    return controller_pose if not controller_pose.is_empty() else _hand_aim_pose(hand_id)

func get_source_kind(hand_id: int) -> int:
    var hand_tracked := not _hand_aim_pose(hand_id).is_empty()
    var controller_tracked := not _controller_aim_pose(hand_id).is_empty()
    if prefer_hand_ray and hand_tracked:
        return SourceKind.HAND
    if controller_tracked:
        return SourceKind.CONTROLLER
    if hand_tracked:
        return SourceKind.HAND
    return SourceKind.NONE

func _connect_interface_signal(signal_name: StringName, callback: Callable) -> void:
    if not _webxr.has_signal(signal_name):
        push_warning("WebXR signal unavailable in this Godot build: %s" % signal_name)
        return
    if not _webxr.is_connected(signal_name, callback):
        _webxr.connect(signal_name, callback)

func _on_selectstart(input_source_id: int) -> void:
    var hand_id := _hand_for_input_source(input_source_id)
    if hand_id >= 0:
        select_started.emit(hand_id)

func _on_selectend(input_source_id: int) -> void:
    var hand_id := _hand_for_input_source(input_source_id)
    if hand_id >= 0:
        select_ended.emit(hand_id)

func _hand_for_input_source(input_source_id: int) -> int:
    var tracker := _webxr.get_input_source_tracker(input_source_id)
    if tracker == null:
        return -1
    match tracker.hand:
        XRPositionalTracker.TRACKER_HAND_LEFT:
            return Hand.LEFT
        XRPositionalTracker.TRACKER_HAND_RIGHT:
            return Hand.RIGHT
    return -1

func _controller_aim_pose(hand_id: int) -> Dictionary:
    var controller := _controllers.get(hand_id) as XRController3D
    if controller == null or not controller.get_is_active() or not controller.get_has_tracking_data():
        return {}
    var xf := controller.global_transform
    return {
        "origin": xf.origin,
        "direction": (-xf.basis.z).normalized(),
        "basis": xf.basis.orthonormalized(),
    }

func _hand_aim_pose(hand_id: int) -> Dictionary:
    if _origin == null:
        return {}
    var tracker := XRServer.get_tracker(TRACKER_PATHS[hand_id]) as XRHandTracker
    var local_pose := XRHandGestureProvider.get_hand_ray_pose(tracker)
    if local_pose.is_empty():
        return {}
    var origin_xf := _origin.global_transform
    var direction := (origin_xf.basis * (local_pose["direction"] as Vector3)).normalized()
    return {
        "origin": origin_xf * (local_pose["origin"] as Vector3),
        "direction": direction,
        "basis": XRHandGestureProvider.basis_from_forward(direction),
    }
```

- [ ] **Step 4: Run tests to verify pass** — same command. Expected: all checks pass, exit 0. (Real WebXR behavior is device-verified in Task 10; this task proves the desktop-inert contract and that the class parses.)

- [ ] **Step 5: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add WebXRInputAdapter (select routing + controller/hand aim poses)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: XRGrabInteractable

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_grab_interactable.gd`
- Test: `demo/tests/run_tests.gd` (add `FakeInteractor` inner class, `_test_grab_follow`)

**Interfaces:**
- Consumes: `XRBaseInteractable` (extends), `XRBaseInteractor.get_attach_pose()`.
- Produces `XRGrabInteractable`: `enum MovementType { INSTANT, KINEMATIC_SMOOTH, VELOCITY_TRACKED }`; exports `target_path: NodePath` (empty = this node), `attach_transform_path: NodePath` (optional grip point), `snap_to_attach := false`, `movement_type := MovementType.INSTANT`, `smoothing_speed := 12.0`, `track_rotation := false`, `max_tracked_speed := 20.0`; `get_target() -> Node3D`.
- Grab math: at select, `_grab_offset = interactor.get_attach_pose().affine_inverse() * target.global_transform` (object keeps its pose relative to the ray point — no snap). With `snap_to_attach` and an attach node, `_grab_offset = attach_node.global_transform.affine_inverse() * target.global_transform` (grip point lands on the ray point). Each physics frame while grabbed: `desired = interactor.get_attach_pose() * _grab_offset`; with `track_rotation` false, desired basis is replaced by the target's current basis (position-only follow — the stable default for hand rays).

- [ ] **Step 1: Write the failing test** — add the call to `_run_all()` after `_test_webxr_adapter_inert_on_desktop()`, add the inner class next to `FakeAdapter`, and the test:

```gdscript
class FakeInteractor extends XRBaseInteractor:
    var attach := Transform3D.IDENTITY
    func get_attach_pose() -> Transform3D:
        return attach
```

```gdscript
func _test_grab_follow() -> void:
    var grab := XRGrabInteractable.new()
    root.add_child(grab)
    grab.global_transform = Transform3D(Basis.IDENTITY, Vector3(1, 1, -2))
    var interactor := FakeInteractor.new()
    root.add_child(interactor)

    check(grab.get_target() == grab, "default target is the interactable itself")

    # INSTANT follow preserving the grab offset: attach at origin, object 1m ahead of it.
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3(1, 1, -1))
    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 2, -1)
    grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(Vector3(0, 2, -2)), "INSTANT keeps the grab offset while following")

    # Rotation is preserved by default (track_rotation = false).
    interactor.attach = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2, -1))
    grab._physics_process(1.0 / 60.0)
    check(grab.global_transform.basis.is_equal_approx(Basis.IDENTITY), "rotation preserved with track_rotation off")

    # Release stops following.
    grab._notify_select_exited(interactor)
    interactor.attach.origin = Vector3(9, 9, 9)
    grab._physics_process(1.0 / 60.0)
    check(not grab.global_position.is_equal_approx(Vector3(8, 9, 8)), "released object stops following")

    # KINEMATIC_SMOOTH converges toward the desired point without teleporting.
    grab.movement_type = XRGrabInteractable.MovementType.KINEMATIC_SMOOTH
    grab.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    interactor.attach = Transform3D(Basis.IDENTITY, Vector3.ZERO)
    grab._notify_select_entered(interactor)
    interactor.attach.origin = Vector3(0, 0, -1)
    grab._physics_process(1.0 / 60.0)
    var after_one := grab.global_position
    check(after_one.z < -0.01 and after_one.z > -1.0, "KINEMATIC_SMOOTH moves partway toward the target")
    for i in range(300):
        grab._physics_process(1.0 / 60.0)
    check(grab.global_position.is_equal_approx(Vector3(0, 0, -1)), "KINEMATIC_SMOOTH converges on the target")
    grab._notify_select_exited(interactor)

    interactor.free()
    grab.free()
```

- [ ] **Step 2: Run tests to verify failure** — same command. Expected: parse error for `XRGrabInteractable`; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_grab_interactable.gd`**

```gdscript
class_name XRGrabInteractable
extends XRBaseInteractable

## Interactable that follows its selecting interactor's attach pose.
## Movement modes: INSTANT (set transform), KINEMATIC_SMOOTH (exponential
## lerp), VELOCITY_TRACKED (drive RigidBody3D.linear_velocity; falls back to
## INSTANT for non-rigid targets). Phase 4 adds throw estimation and two-hand.

enum MovementType { INSTANT, KINEMATIC_SMOOTH, VELOCITY_TRACKED }

## Node3D to move. Empty = this node.
@export var target_path: NodePath
## Optional grip-point child. Only used when snap_to_attach is true.
@export var attach_transform_path: NodePath
## true: the attach point snaps onto the interactor's attach pose (XRITK-style
## grip). false (default): the object keeps its pose relative to the ray point.
@export var snap_to_attach := false
@export var movement_type := MovementType.INSTANT
@export var smoothing_speed := 12.0
## false (default): position-only follow, world rotation preserved — stable for
## hand rays. true: follow the attach pose's rotation too.
@export var track_rotation := false
@export var max_tracked_speed := 20.0

var _grab_offset := Transform3D.IDENTITY
var _grabbing: XRBaseInteractor

func get_target() -> Node3D:
    if target_path.is_empty():
        return self
    return get_node_or_null(target_path) as Node3D

func _notify_select_entered(interactor: XRBaseInteractor) -> void:
    super(interactor)
    _grabbing = interactor
    _grab_offset = _compute_grab_offset(interactor)

func _notify_select_exited(interactor: XRBaseInteractor) -> void:
    super(interactor)
    _grabbing = null

func _physics_process(delta: float) -> void:
    if _grabbing == null:
        return
    var target := get_target()
    if target == null:
        return
    var desired := _grabbing.get_attach_pose() * _grab_offset
    if not track_rotation:
        desired.basis = target.global_transform.basis
    _apply_movement(target, desired, delta)

func _compute_grab_offset(interactor: XRBaseInteractor) -> Transform3D:
    var target := get_target()
    if target == null:
        return Transform3D.IDENTITY
    if snap_to_attach:
        var attach_node := get_node_or_null(attach_transform_path) as Node3D
        if attach_node:
            return attach_node.global_transform.affine_inverse() * target.global_transform
    return interactor.get_attach_pose().affine_inverse() * target.global_transform

func _apply_movement(target: Node3D, desired: Transform3D, delta: float) -> void:
    match movement_type:
        MovementType.INSTANT:
            target.global_transform = desired
        MovementType.KINEMATIC_SMOOTH:
            var weight := 1.0 - exp(-smoothing_speed * delta)
            var xf := target.global_transform
            xf.origin = xf.origin.lerp(desired.origin, weight)
            if track_rotation:
                xf.basis = xf.basis.orthonormalized().slerp(desired.basis.orthonormalized(), weight)
            target.global_transform = xf
        MovementType.VELOCITY_TRACKED:
            var body := target as RigidBody3D
            if body == null:
                target.global_transform = desired
                return
            var velocity := (desired.origin - body.global_position) / maxf(delta, 0.0001)
            body.linear_velocity = velocity.limit_length(max_tracked_speed)
```

- [ ] **Step 4: Run tests to verify pass** — same command. Expected: all checks pass, exit 0.

- [ ] **Step 5: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add XRGrabInteractable with movement modes and offset tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: XRInteractorLineVisual + XRReticleVisual

**Files:**
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interactor_line_visual.gd`
- Create: `demo/addons/godot_xr_interaction_toolkit/runtime/xr_reticle_visual.gd`
- Test: `demo/tests/run_tests.gd` (add `_test_visuals_follow_ray_state`)

**Interfaces:**
- Consumes: `XRRayInteractor.get_ray_state()` (must be the direct parent node).
- Produces `XRInteractorLineVisual` (MeshInstance3D): export `color: Color`; world-space `ImmediateMesh` beam from ray origin to ray end; hidden when ray invalid. Produces `XRReticleVisual` (MeshInstance3D): exports `color: Color`, `hit_radius := 0.02`, `hover_radius := 0.04`; sphere at the hit point, visible only when the ray hit something, larger when hovering an interactable (prototype behavior: 0.04 hovering / 0.02 plain hit). Both set `top_level = true` and draw in global space, so the interactor node's own transform is irrelevant.

- [ ] **Step 1: Write the failing test** — add the call to `_run_all()` after `_test_grab_follow()`, and add:

```gdscript
func _test_visuals_follow_ray_state() -> void:
    var ray := XRRayInteractor.new()
    var line := XRInteractorLineVisual.new()
    var reticle := XRReticleVisual.new()
    ray.add_child(line)
    ray.add_child(reticle)
    root.add_child(ray)

    line._process(0.016)
    reticle._process(0.016)
    check(not line.visible, "line hidden while the ray is invalid")
    check(not reticle.visible, "reticle hidden while the ray is invalid")

    ray._ray_state = {"valid": true, "origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "end": Vector3(0, 0, -3), "hit": true, "hovered": null}
    line._process(0.016)
    reticle._process(0.016)
    check(line.visible, "line visible with a valid ray")
    check(reticle.visible, "reticle visible on a hit")
    check(reticle.global_position.is_equal_approx(Vector3(0, 0, -3)), "reticle sits at the hit point")

    ray._ray_state = {"valid": true, "origin": Vector3.ZERO, "direction": Vector3(0, 0, -1), "end": Vector3(0, 0, -6), "hit": false, "hovered": null}
    line._process(0.016)
    reticle._process(0.016)
    check(line.visible, "line visible on a miss (full length)")
    check(not reticle.visible, "reticle hidden on a miss")

    ray.free()

```

- [ ] **Step 2: Run tests to verify failure** — same command. Expected: parse errors for the two visual classes; nonzero exit.

- [ ] **Step 3: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_interactor_line_visual.gd`**

```gdscript
class_name XRInteractorLineVisual
extends MeshInstance3D

## Straight-line beam for an XRRayInteractor parent. Draws in world space
## (top_level), so the interactor's transform never bends the visual.

@export var color := Color(0.7, 0.88, 1.0, 0.85)

var _ray: XRRayInteractor
var _line_mesh := ImmediateMesh.new()

func _ready() -> void:
    _ray = get_parent() as XRRayInteractor
    if _ray == null:
        push_warning("%s: parent is not an XRRayInteractor." % name)
    mesh = _line_mesh
    top_level = true
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material_override = material

func _process(_delta: float) -> void:
    _line_mesh.clear_surfaces()
    var state := _ray.get_ray_state() if _ray else {}
    if not state.get("valid", false):
        visible = false
        return
    var from_point := state["origin"] as Vector3
    var to_point := state["end"] as Vector3
    if from_point.distance_squared_to(to_point) < 0.000001:
        visible = false
        return
    visible = true
    global_transform = Transform3D.IDENTITY
    _line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    _line_mesh.surface_add_vertex(from_point)
    _line_mesh.surface_add_vertex(to_point)
    _line_mesh.surface_end()
```

- [ ] **Step 4: Create `demo/addons/godot_xr_interaction_toolkit/runtime/xr_reticle_visual.gd`**

```gdscript
class_name XRReticleVisual
extends MeshInstance3D

## Hit-point reticle for an XRRayInteractor parent. Visible only when the ray
## hits geometry; grows when the hit is a hoverable interactable.

@export var color := Color(1.0, 0.9, 0.25, 1.0)
@export var hit_radius := 0.02
@export var hover_radius := 0.04

var _ray: XRRayInteractor

func _ready() -> void:
    _ray = get_parent() as XRRayInteractor
    if _ray == null:
        push_warning("%s: parent is not an XRRayInteractor." % name)
    top_level = true
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 16
    sphere.rings = 8
    mesh = sphere
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material_override = material

func _process(_delta: float) -> void:
    var state := _ray.get_ray_state() if _ray else {}
    var should_show: bool = state.get("valid", false) and state.get("hit", false)
    visible = should_show
    if not should_show:
        return
    var radius := hover_radius if state.get("hovered") != null else hit_radius
    global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), state["end"] as Vector3)
```

- [ ] **Step 5: Run tests to verify pass** — same command. Expected: all checks pass, exit 0.

- [ ] **Step 6: Commit**

```bash
git add demo/addons demo/tests
git commit -m "Add ray line and reticle visuals driven by ray state

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Demo scene consumes the addon; delete the prototype interactor

**Files:**
- Create: `demo/scripts/xr_demo_affordance.gd`
- Modify: `demo/scenes/Main.tscn` (full replacement content below)
- Delete: `demo/scripts/xr_ray_interactor.gd` (tracked since Task 1's checkpoint commit — history preserved)
- Test: headless project load + full test suite

**Interfaces:**
- Consumes: every addon class. `demo/scripts/webxr_bootstrap.gd` is NOT modified (session lifecycle stays demo-side); only its `inspect_object_path` in the scene now points at `InspectObject/Mesh` because `InspectObject` is no longer itself a MeshInstance3D.
- Produces: the acceptance scene — `XRInteractionManager` + `WebXRInputAdapter` at root, two `XRRayInteractor`s (with line/reticle children) under `XROrigin3D`, `InspectObject` as an `XRGrabInteractable`, and demo-side affordances via `xr_demo_affordance.gd`.

- [ ] **Step 1: Create `demo/scripts/xr_demo_affordance.gd`** — affordances live in the demo, not the toolkit:

```gdscript
extends Node

## Demo-side visual feedback for one interactable. The toolkit only emits
## hover/select signals; highlight materials are the consumer's job.

@export var interactable_path: NodePath
@export var mesh_path: NodePath
@export var status_label_path: NodePath

var _interactable: XRBaseInteractable
var _mesh: MeshInstance3D
var _status_label: Label
var _base_material: Material
var _hover_material: StandardMaterial3D
var _select_material: StandardMaterial3D

func _ready() -> void:
    _interactable = get_node_or_null(interactable_path) as XRBaseInteractable
    _mesh = get_node_or_null(mesh_path) as MeshInstance3D
    _status_label = get_node_or_null(status_label_path) as Label
    if _interactable == null or _mesh == null:
        push_warning("xr_demo_affordance: assign interactable_path and mesh_path.")
        return
    _base_material = _mesh.get_active_material(0)
    _hover_material = _make_material(Color(1.0, 0.9, 0.25))
    _select_material = _make_material(Color(0.28, 1.0, 0.55))
    _interactable.hover_entered.connect(_on_hover_entered)
    _interactable.hover_exited.connect(_on_hover_exited)
    _interactable.select_entered.connect(_on_select_entered)
    _interactable.select_exited.connect(_on_select_exited)

func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.65
    return material

func _on_hover_entered(_interactor: XRBaseInteractor) -> void:
    if not _interactable.is_selected():
        _mesh.set_surface_override_material(0, _hover_material)
    _set_status("Hover: %s" % _interactable.name)

func _on_hover_exited(_interactor: XRBaseInteractor) -> void:
    if not _interactable.is_selected():
        _mesh.set_surface_override_material(0, _base_material)
    _set_status("Hover exit: %s" % _interactable.name)

func _on_select_entered(_interactor: XRBaseInteractor) -> void:
    _mesh.set_surface_override_material(0, _select_material)
    _set_status("Grab: %s" % _interactable.name)

func _on_select_exited(_interactor: XRBaseInteractor) -> void:
    _mesh.set_surface_override_material(0, _hover_material if _interactable.is_hovered() else _base_material)
    _set_status("Release: %s" % _interactable.name)

func _set_status(message: String) -> void:
    if _status_label:
        _status_label.text = message
    print(message)
```

- [ ] **Step 2: Replace `demo/scenes/Main.tscn` with this exact content.** Changes vs the prototype: old `RayInteractor` node + `5_ray` ext_resource removed; manager/adapter/interactor/visual nodes added; `InspectObject` became a plain `Node3D` with the `XRGrabInteractable` script and its mesh moved to a `Mesh` child; `WebXRBootstrap.inspect_object_path` retargeted to that child; `DemoAffordance` added. Everything else (environment, lights, UI, hand visualizer, bootstrap, capabilities) is byte-identical to before.

```text
[gd_scene load_steps=20 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]
[ext_resource type="Script" path="res://scripts/webxr_bootstrap.gd" id="2_webxr"]
[ext_resource type="Script" path="res://scripts/browser_capabilities.gd" id="3_caps"]
[ext_resource type="Script" path="res://scripts/webxr_hand_visualizer.gd" id="4_hands"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd" id="5_manager"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd" id="6_adapter"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/xr_ray_interactor.gd" id="7_ray"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/xr_grab_interactable.gd" id="8_grab"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/xr_interactor_line_visual.gd" id="9_line"]
[ext_resource type="Script" path="res://addons/godot_xr_interaction_toolkit/runtime/xr_reticle_visual.gd" id="10_reticle"]
[ext_resource type="Script" path="res://scripts/xr_demo_affordance.gd" id="11_affordance"]

[sub_resource type="Environment" id="Environment_webxr"]
background_mode = 2
sky_custom_fov = 70.0
ambient_light_source = 1
ambient_light_color = Color(0.7, 0.72, 0.78, 1)
ambient_light_energy = 0.8

[sub_resource type="StandardMaterial3D" id="Material_floor"]
albedo_color = Color(0.22, 0.24, 0.27, 1)
roughness = 0.85

[sub_resource type="PlaneMesh" id="PlaneMesh_floor"]
size = Vector2(6, 6)

[sub_resource type="StandardMaterial3D" id="Material_object"]
albedo_color = Color(0.15, 0.52, 0.85, 1)
metallic = 0.1
roughness = 0.4

[sub_resource type="BoxMesh" id="BoxMesh_object"]
size = Vector3(0.6, 0.6, 0.6)

[sub_resource type="BoxShape3D" id="BoxShape_interactable"]
size = Vector3(0.72, 0.72, 0.72)

[sub_resource type="StandardMaterial3D" id="Material_marker"]
albedo_color = Color(0.9, 0.72, 0.24, 1)
roughness = 0.7

[sub_resource type="SphereMesh" id="SphereMesh_marker"]
radius = 0.12
height = 0.24

[node name="Main" type="Node3D"]
script = ExtResource("1_main")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_webxr")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.25, 0.433013, 0, 0.866025, 0.5, -0.5, -0.433013, 0.75, 0, 3, 0)
light_energy = 1.5
shadow_enabled = true

[node name="XRInteractionManager" type="Node" parent="."]
script = ExtResource("5_manager")

[node name="WebXRInputAdapter" type="Node" parent="."]
script = ExtResource("6_adapter")
xr_origin_path = NodePath("../XROrigin3D")
left_controller_path = NodePath("../XROrigin3D/LeftController")
right_controller_path = NodePath("../XROrigin3D/RightController")

[node name="XROrigin3D" type="XROrigin3D" parent="."]

[node name="XRCamera3D" type="XRCamera3D" parent="XROrigin3D"]
transform = Transform3D(1, 0, 0, 0, 0.965926, 0.258819, 0, -0.258819, 0.965926, 0, 1.6, 3.0)
current = true
fov = 70.0

[node name="LeftController" type="XRController3D" parent="XROrigin3D"]
tracker = &"left_hand"
pose = &"aim"
show_when_tracked = true

[node name="RightController" type="XRController3D" parent="XROrigin3D"]
tracker = &"right_hand"
pose = &"aim"
show_when_tracked = true

[node name="HandVisualizer" type="Node3D" parent="XROrigin3D"]
script = ExtResource("4_hands")
status_label_path = NodePath("../../CanvasLayer/Panel/MarginContainer/VBoxContainer/StatusLabel")

[node name="LeftRayInteractor" type="Node3D" parent="XROrigin3D"]
script = ExtResource("7_ray")
input_adapter_path = NodePath("../../WebXRInputAdapter")
hand = 0

[node name="LineVisual" type="MeshInstance3D" parent="XROrigin3D/LeftRayInteractor"]
script = ExtResource("9_line")
color = Color(0.2, 0.75, 1, 0.85)

[node name="Reticle" type="MeshInstance3D" parent="XROrigin3D/LeftRayInteractor"]
script = ExtResource("10_reticle")

[node name="RightRayInteractor" type="Node3D" parent="XROrigin3D"]
script = ExtResource("7_ray")
input_adapter_path = NodePath("../../WebXRInputAdapter")
hand = 1

[node name="LineVisual" type="MeshInstance3D" parent="XROrigin3D/RightRayInteractor"]
script = ExtResource("9_line")
color = Color(1, 0.58, 0.2, 0.85)

[node name="Reticle" type="MeshInstance3D" parent="XROrigin3D/RightRayInteractor"]
script = ExtResource("10_reticle")

[node name="Floor" type="MeshInstance3D" parent="."]
mesh = SubResource("PlaneMesh_floor")
surface_material_override/0 = SubResource("Material_floor")

[node name="InspectObject" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.1, -1.8)
script = ExtResource("8_grab")

[node name="Mesh" type="MeshInstance3D" parent="InspectObject"]
mesh = SubResource("BoxMesh_object")
surface_material_override/0 = SubResource("Material_object")

[node name="InteractableBody" type="StaticBody3D" parent="InspectObject"]

[node name="CollisionShape3D" type="CollisionShape3D" parent="InspectObject/InteractableBody"]
shape = SubResource("BoxShape_interactable")

[node name="MarkerSphere" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.1, 0.12, -1.2)
mesh = SubResource("SphereMesh_marker")
surface_material_override/0 = SubResource("Material_marker")

[node name="WebXRBootstrap" type="Node3D" parent="."]
script = ExtResource("2_webxr")
enter_xr_button_path = NodePath("../CanvasLayer/Panel/MarginContainer/VBoxContainer/EnterXRButton")
status_label_path = NodePath("../CanvasLayer/Panel/MarginContainer/VBoxContainer/StatusLabel")
inspect_object_path = NodePath("../InspectObject/Mesh")

[node name="DemoAffordance" type="Node" parent="."]
script = ExtResource("11_affordance")
interactable_path = NodePath("../InspectObject")
mesh_path = NodePath("../InspectObject/Mesh")
status_label_path = NodePath("../CanvasLayer/Panel/MarginContainer/VBoxContainer/StatusLabel")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="Panel" type="PanelContainer" parent="CanvasLayer"]
offsets_preset = 1
offset_left = 24.0
offset_top = 24.0
offset_right = 524.0
offset_bottom = 512.0

[node name="MarginContainer" type="MarginContainer" parent="CanvasLayer/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 14
theme_override_constants/margin_top = 14
theme_override_constants/margin_right = 14
theme_override_constants/margin_bottom = 14

[node name="VBoxContainer" type="VBoxContainer" parent="CanvasLayer/Panel/MarginContainer"]
layout_mode = 2

[node name="TitleLabel" type="Label" parent="CanvasLayer/Panel/MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Godot WebXR Feasibility"

[node name="StatusLabel" type="Label" parent="CanvasLayer/Panel/MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Starting..."
autowrap_mode = 3

[node name="EnterXRButton" type="Button" parent="CanvasLayer/Panel/MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Enter WebXR"

[node name="FpsLabel" type="Label" parent="CanvasLayer/Panel/MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "FPS"

[node name="CapsLabel" type="Label" parent="CanvasLayer/Panel/MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Capabilities"
autowrap_mode = 3

[node name="BrowserCapabilities" type="Control" parent="CanvasLayer"]
script = ExtResource("3_caps")
output_label_path = NodePath("../Panel/MarginContainer/VBoxContainer/CapsLabel")
```

Note: the old scene removed the `groups=["xr_interactable"]` tag and `unique_name_in_owner` from `InspectObject` — the group mechanism is dead (the manager registry replaced it), and no script references `%InspectObject`. Before replacing, check `demo/scripts/main.gd` for any `%InspectObject` / `"xr_interactable"` reference (`grep -n "InspectObject\|xr_interactable" demo/scripts/main.gd`); if found, update those references to `$InspectObject/Mesh` semantics as part of this step.

- [ ] **Step 3: Delete the prototype interactor**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git rm demo/scripts/xr_ray_interactor.gd
```

(If Godot generated `demo/scripts/xr_ray_interactor.gd.uid`, `git rm` it too.)

- [ ] **Step 4: Run the full suite + project load**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd; echo "tests exit: $?"
"$GODOT" --headless --path demo --quit; echo "project load exit: $?"
```

Expected: tests all pass (exit 0). Project load exits 0 with no script errors; the bootstrap prints its "Not a web export" message (normal on desktop) and the affordance script prints nothing (no hover without XR). Any `Parse Error` or `Invalid` line in the output = failure, fix before committing.

- [ ] **Step 5: Commit**

```bash
git add -A demo
git commit -m "Demo scene consumes addon (manager + ray interactors + grab interactable); remove prototype interactor

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Web export, docs, Quest verification packet

**Files:**
- Modify: `demo/addons/godot_xr_interaction_toolkit/README.md` (usage section)
- Modify: `docs/EVIDENCE_LOG.md` (append rows)
- Create or append: `docs/DECISION_LOG.md`
- Output: fresh `demo/build/web47/` export

**Interfaces:**
- Consumes: everything. Produces: the on-device acceptance evidence trail.

- [ ] **Step 1: Export the web build with Godot 4.7**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo --import
"$GODOT" --headless --path demo --export-release Web build/web47/index.html; echo "export exit: $?"
ls demo/build/web47
```

Expected: exit 0; `index.html`, `index.js`, `index.pck`, `index.wasm` present with fresh timestamps. (The `Web` preset's default path is `build/web/index.html`; the explicit argument redirects to `build/web47/`, which is what the local HTTPS server at `https://10.0.0.76:8444/` serves.) If the export fails with a missing-template error, install `c:/tmp/Godot_v4.7-stable_export_templates.tpz` via `"$GODOT" --headless --install-android-source-template` is NOT it — instead copy the templates: `mkdir -p "$APPDATA/Godot/export_templates/4.7.stable" && unzip -o c:/tmp/Godot_v4.7-stable_export_templates.tpz -d /tmp/tpl && cp /tmp/tpl/templates/* "$APPDATA/Godot/export_templates/4.7.stable/"` — then re-run the export.

- [ ] **Step 2: Update `demo/addons/godot_xr_interaction_toolkit/README.md`** — replace the placeholder last paragraph ("Usage docs land with the first deliverable...") with:

```markdown
## Quick start (WebXR)

1. Copy `addons/godot_xr_interaction_toolkit/` into your project and (optionally)
   enable the plugin in Project Settings.
2. Scene setup:
   - Add an `XRInteractionManager` (plain `Node`) anywhere in the scene.
   - Add a `WebXRInputAdapter` (plain `Node`); point `xr_origin_path` at your
     `XROrigin3D` and the controller paths at your two `XRController3D` nodes
     (tracker `left_hand`/`right_hand`, pose `aim`).
   - Under `XROrigin3D`, add one `XRRayInteractor` (Node3D) per hand; set
     `hand` (0 = left, 1 = right) and `input_adapter_path` at the adapter.
     Add `XRInteractorLineVisual` and `XRReticleVisual` (MeshInstance3D)
     as children for the beam and cursor.
   - Make anything grabbable by giving it an `XRGrabInteractable` (Node3D)
     root with a `CollisionObject3D` descendant for the ray to hit.
3. Feedback: connect to `hover_entered/hover_exited/select_entered/select_exited`
   on interactors or interactables. The toolkit never changes your materials.
4. Session lifecycle (requesting the WebXR session, `viewport.use_xr`) stays in
   your project — see `demo/scripts/webxr_bootstrap.gd` for a working example
   (request optional features `hand-tracking`, required `layers`).

Interaction layers: `interaction_layers` bitmasks on interactor and interactable
must share a bit (default: both 1). They are independent of physics layers;
`XRRayInteractor.collision_mask` controls what the ray can physically hit.

## Platform notes

- Quest 3 / Quest Browser: works (controllers, hands, system pinch select).
- Samsung Galaxy XR / tested Android XR browsers: WebXR + WebGL2 present but no
  `OVR_multiview2`/`OCULUS_multiview`, so Godot WebXR stereo fails there. This
  is a browser capability gap, not an addon or export-flag issue.
- Desktop (no XR): adapters report no poses; interactors idle; scene stays
  usable as a flat preview.
```

- [ ] **Step 3: Append evidence rows to `docs/EVIDENCE_LOG.md`** (adjust check count to the real number):

```markdown
| Addon headless tests | Pass | `Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd` — N checks, 0 failures (layers, arbitration, hand-ray geometry, physics raycast integration, grab math, visuals). |
| Web export (4.7) | Pass | `--export-release Web build/web47/index.html` exit 0 with addon + refactored scene. |
| Quest 3 acceptance | PENDING MANUAL | Checklist in Task 10 Step 5 of docs/superpowers/plans/2026-07-02-xr-interaction-toolkit-addon.md. |
```

- [ ] **Step 4: Append to `docs/DECISION_LOG.md`** (create the file with a `# Decision Log` heading if it does not exist):

```markdown
## 2026-07-02 — XR interaction as a pure-GDScript addon

Decision: implement XRITK-style interaction as `addons/godot_xr_interaction_toolkit/`
(pure GDScript, class_name-based, editor plugin optional). No engine modules, no
custom export templates: an engine module would force custom editor + template
builds on every consumer, which kills drop-in reuse, and nothing in the phase
plan needs engine code. Input adapters isolate WebXR (proven) from OpenXR
(later) so interaction logic ports by swapping one node. Independent of Godot
XR Tools (different API philosophy: component model vs scene composition; see
docs/xr_interaction_toolkit_architecture.md). First deliverable: manager + ray
interactor + grab interactable, demo scene consuming addon APIs only.
```

- [ ] **Step 5: Manual Quest Browser test matrix** — requires the human with the headset. Serve `demo/build/web47/` over the existing HTTPS setup at `https://10.0.0.76:8444/` (note: `tools/serve_web.py` is HTTP-only; use whatever already provides HTTPS on :8444). On Quest 3 Quest Browser:

| # | Check | Pass looks like |
|---|---|---|
| 1 | Enter WebXR (controllers in hands) | Session starts, stereo renders, two colored rays visible |
| 2 | Ray origin/direction (controllers) | Ray starts at controller tip, matches pointing intent — never vertical/from feet |
| 3 | Hover cube | Cube turns yellow on-ray, reverts off-ray; status label updates |
| 4 | Trigger grab + move | Cube turns green, follows ray at grab distance, releases where dropped |
| 5 | Both hands | Each ray hovers independently; second hand cannot steal a grabbed cube |
| 6 | Set controllers down → hand tracking | Skeleton hands appear, rays switch to hand rays (pinch cursor) |
| 7 | Pinch select with hands | System pinch grabs/releases the cube like the trigger |
| 8 | Pose loss (hand behind back) while grabbing | Ray hides, cube freezes, grip resumes when tracking returns |
| 9 | Exit XR | Session ends cleanly, flat view returns, button re-enabled |

If check 2 fails on hands (ray direction feels wrong), toggle `prefer_hand_ray` to `false` on `WebXRInputAdapter` in `Main.tscn`, re-export, retest — record which setting wins in `docs/EVIDENCE_LOG.md`.

- [ ] **Step 6: Commit**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git add demo/addons docs demo/build/web47 2>/dev/null || git add demo/addons docs
git commit -m "First-deliverable docs, evidence log, Quest test matrix; 4.7 web export

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(If `demo/build/` is gitignored, commit without it — check `.gitignore` first; do not force-add build artifacts if ignored.)

---

## Known limitations / intentionally not done (first deliverable)

- No `XRDirectInteractor`, `XRSocketInteractor`, UI rays, locomotion, two-hand grab, throw velocity, bezier lines — Phases 3-8.
- No `OpenXRInputAdapter` yet (listed in the architecture; lands with the native smoke path so it can actually be tested).
- `VELOCITY_TRACKED` is minimal (no throw estimation, no gravity handling) — Phase 4.
- KINEMATIC_SMOOTH drops target scale when `track_rotation` is on (orthonormalized slerp) — acceptable until Phase 4.
- The samples/ folder waits for Phase 8; the demo scene is the sample for now.
- Galaxy XR stereo failure is a browser multiview gap — documented, not worked around.

## Self-review notes (already applied)

- Spec coverage: first-deliverable classes all present; `XRInteractionLayerMask`, line/reticle visuals, hand-gesture provider, WebXR adapter included; `XRDirectInteractor`/sockets/OpenXR adapter explicitly deferred per phase plan.
- Type consistency: `get_ray_state()` dictionary keys (`valid/origin/direction/end/hit/hovered`) match between Task 5 (producer) and Task 8 (consumer); `get_attach_pose()` contract matches between Tasks 4/5 (producer) and 7 (consumer); `Hand` enum ints match tscn `hand = 0/1`.
- The `use_xr` gate from the prototype was deliberately replaced by adapter-pose emptiness (see Task 5 note) — same observable behavior, headless-testable.
