class_name XRRayInteractor
extends "res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd"

## Raycasting interactor: hovers the nearest interactable along the adapter's
## aim ray and, while selecting, exposes an attach pose at the captured grab
## distance so XRGrabInteractable can follow the ray.

@export var max_distance := 6.0
@export_flags_3d_physics var collision_mask := 1
@export var collide_with_areas := true
@export var min_grab_distance := 0.25
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

func _ready() -> void:
    super()
    _resolve_suppression_interactor()

func _physics_process(_delta: float) -> void:
    _update_ray()

## {valid: bool} when inactive, else {valid: true, origin, direction, end,
## hit, hovered}. All vectors are in global space.
func get_ray_state() -> Dictionary:
    return _ray_state

func get_attach_pose() -> Transform3D:
    return _attach_pose

func _update_ray() -> void:
    if _selected == null and _is_suppressed_by_linked_interactor():
        _ray_state = {"valid": false, "suppressed": true}
        _set_hovered(null)
        return

    var pose: Dictionary = _adapter.get_aim_pose(hand) if _adapter else {}
    if pose.is_empty():
        _ray_state = {"valid": false}
        if _selected == null:
            _set_hovered(null)
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

func _notify_select_granted(interactable) -> void:
    _grab_distance = clampf(_hover_distance, min_grab_distance, max_distance)
    super(interactable)

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
