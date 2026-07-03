class_name XRRayInteractor
extends "res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd"

## Raycasting interactor: hovers the nearest interactable along the adapter's
## aim ray and, while selecting, exposes an attach pose at the captured grab
## distance so XRGrabInteractable can follow the ray.

@export_group("Raycast")
@export_range(0.1, 100.0, 0.1, "or_greater") var max_distance := 6.0
@export_flags_3d_physics var collision_mask := 1
@export var collide_with_areas := true
@export_range(0.0, 20.0, 0.01, "or_greater") var min_grab_distance := 0.25

@export_group("Distance Manipulation")
## While far-grabbing, hand motion along the ray changes the held distance.
## Pulling the hand back along the ray brings the object closer; pushing forward
## moves it away. This approximates XR Interaction Toolkit-style attach
## distance manipulation for hand rays.
@export var enable_motion_distance_manipulation := true
@export_range(0.0, 4.0, 0.01, "or_greater") var distance_motion_scale := 1.0
@export_range(0.0, 0.2, 0.001, "or_greater") var distance_motion_deadzone := 0.006
@export var allow_push_distance_manipulation := true
@export_range(0.0, 20.0, 0.1, "or_greater") var max_distance_change_per_second := 4.0

@export_group("Suppression")
## Optional linked near/direct interactor. When it is active, this far ray is
## suppressed so one hand does not show or select with near and far at once.
@export var suppress_interactor_path: NodePath
@export var suppress_on_linked_hover := true
@export var suppress_on_linked_select := true

var _ray_state := {"valid": false}
var _grab_distance := 0.0
var _hover_distance := 0.0
var _attach_pose := Transform3D.IDENTITY
var _suppress_interactor: Node
var _last_ray_origin := Vector3.ZERO
var _last_ray_direction := Vector3.FORWARD
var _has_last_ray_pose := false

func _ready() -> void:
    super()
    _resolve_suppression_interactor()

func _physics_process(delta: float) -> void:
    _update_ray(delta)

## {valid: bool} when inactive, else {valid: true, origin, direction, end,
## hit, hovered}. All vectors are in global space.
func get_ray_state() -> Dictionary:
    return _ray_state

func get_attach_pose() -> Transform3D:
    return _attach_pose

func _update_ray(delta := 0.0) -> void:
    if _selected == null and _is_suppressed_by_linked_interactor():
        _ray_state = {"valid": false, "suppressed": true}
        _set_hovered(null)
        _has_last_ray_pose = false
        return

    var pose: Dictionary = _adapter.get_aim_pose(hand) if _adapter else {}
    if pose.is_empty():
        _ray_state = {"valid": false}
        if _selected == null:
            _set_hovered(null)
            _has_last_ray_pose = false
        return

    var origin: Vector3 = pose["origin"]
    var direction: Vector3 = (pose["direction"] as Vector3).normalized()
    var pose_basis: Basis = pose.get("basis", Basis.IDENTITY)
    var hit := _intersect(origin, direction)
    var hit_anything := not hit.is_empty()
    var end := origin + direction * max_distance
    if hit_anything:
        end = hit["position"]

    var hovered = null
    if hit_anything and _manager:
        var interactable = _manager.get_interactable_for_collider(hit["collider"])
        if interactable and interactable.can_hover(self):
            hovered = interactable

    _hover_distance = origin.distance_to(end)
    if _selected == null:
        _set_hovered(hovered)
        _attach_pose = Transform3D(pose_basis, end)
    else:
        _apply_motion_distance_manipulation(origin, direction, delta)
        _attach_pose = Transform3D(pose_basis, origin + direction * _grab_distance)
        end = _attach_pose.origin
        hit_anything = true
        hovered = _selected

    _ray_state = {
        "valid": true,
        "origin": origin,
        "direction": direction,
        "end": end,
        "hit": hit_anything,
        "hovered": hovered,
        "grab_distance": _grab_distance,
    }
    _last_ray_origin = origin
    _last_ray_direction = direction
    _has_last_ray_pose = true

func _intersect(origin: Vector3, direction: Vector3) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)
    query.collision_mask = collision_mask
    query.collide_with_areas = collide_with_areas
    query.collide_with_bodies = true
    return get_world_3d().direct_space_state.intersect_ray(query)

func _notify_select_granted(interactable) -> void:
    _grab_distance = clampf(_hover_distance, min_grab_distance, max_distance)
    _seed_last_ray_pose_from_state()
    super(interactable)

func _notify_select_released(interactable) -> void:
    super(interactable)
    _seed_last_ray_pose_from_state()

func _apply_motion_distance_manipulation(origin: Vector3, direction: Vector3, delta: float) -> void:
    if not enable_motion_distance_manipulation or not _has_last_ray_pose:
        return

    var movement := origin - _last_ray_origin
    var distance_delta := movement.dot(_last_ray_direction.normalized()) * distance_motion_scale
    if absf(distance_delta) < distance_motion_deadzone:
        return
    if distance_delta > 0.0 and not allow_push_distance_manipulation:
        return

    if delta > 0.0 and max_distance_change_per_second > 0.0:
        var max_step := max_distance_change_per_second * delta
        distance_delta = clampf(distance_delta, -max_step, max_step)

    _grab_distance = clampf(_grab_distance + distance_delta, min_grab_distance, max_distance)

func _seed_last_ray_pose_from_state() -> void:
    if not _ray_state.get("valid", false):
        _has_last_ray_pose = false
        return
    _last_ray_origin = _ray_state["origin"]
    _last_ray_direction = (_ray_state["direction"] as Vector3).normalized()
    _has_last_ray_pose = true

func _resolve_suppression_interactor() -> void:
    _suppress_interactor = null
    if suppress_interactor_path.is_empty():
        return
    _suppress_interactor = get_node_or_null(suppress_interactor_path)

func _is_suppressed_by_linked_interactor() -> bool:
    if suppress_interactor_path.is_empty():
        return false
    if _suppress_interactor == null or not is_instance_valid(_suppress_interactor):
        _resolve_suppression_interactor()
    if _suppress_interactor == null:
        return false

    if suppress_on_linked_select and _suppress_interactor.has_method("get_selected") and _suppress_interactor.get_selected() != null:
        return true
    if suppress_on_linked_hover and _suppress_interactor.has_method("get_hovered") and _suppress_interactor.get_hovered() != null:
        return true
    return false
