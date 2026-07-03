class_name XRSocketInteractor
extends "res://addons/godot_xr_interaction_toolkit/runtime/xr_base_interactor.gd"

## Socket/snap-zone interactor. It watches a local sphere, hovers the closest
## compatible interactable, and can automatically select it so grab objects snap
## to the socket attach pose.

@export_group("Socket")
@export_range(0.01, 5.0, 0.01, "or_greater") var socket_radius := 0.35
@export_range(1, 128, 1, "or_greater") var max_results := 24
@export_flags_3d_physics var collision_mask := 1
@export var collide_with_areas := true
@export var auto_select := true
@export var keep_selected := true
@export var attach_transform_path: NodePath

var _shape := SphereShape3D.new()
var _socket_state := {"valid": false}

func _physics_process(_delta: float) -> void:
	_update_socket()

func get_socket_state() -> Dictionary:
	return _socket_state

func get_attach_pose() -> Transform3D:
	var attach_node := get_node_or_null(attach_transform_path) as Node3D
	return attach_node.global_transform if attach_node else global_transform

func release_selected() -> void:
	_release_select()

func _update_socket() -> void:
	if _selected != null and keep_selected:
		_set_hovered(_selected)
		_socket_state = {
			"valid": true,
			"origin": global_position,
			"hovered": _selected,
			"selected": _selected,
			"radius": socket_radius,
		}
		return

	var hovered = _closest_interactable()
	_set_hovered(hovered)
	if auto_select and _selected == null and hovered != null:
		_try_select()

	_socket_state = {
		"valid": true,
		"origin": global_position,
		"hovered": _hovered,
		"selected": _selected,
		"radius": socket_radius,
	}

func _closest_interactable():
	if _manager == null:
		_resolve_manager()
	if _manager == null:
		return null

	_shape.radius = socket_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = true

	var hits := get_world_3d().direct_space_state.intersect_shape(query, max_results)
	var best = null
	var best_distance := INF
	for hit in hits:
		var collider = hit.get("collider")
		var interactable = _manager.get_interactable_for_collider(collider)
		if interactable == null or not interactable.can_hover(self):
			continue

		var node_3d := collider as Node3D
		var distance := global_position.distance_squared_to(node_3d.global_position) if node_3d else 0.0
		if distance < best_distance:
			best_distance = distance
			best = interactable
	return best
