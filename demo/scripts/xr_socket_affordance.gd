extends Node

## Demo-side visual feedback for XRSocketInteractor state.

## Preloaded so the shader baker can precompile it for web/WebGPU exports.
const SOCKET_MATERIAL := preload("res://scripts/socket_affordance_material.tres")

@export var socket_path: NodePath
@export var pad_mesh_path: NodePath
@export var status_label_path: NodePath

var _socket: Node
var _pad_mesh: MeshInstance3D
var _status_label: Label
var _materials := {}
var _last_key := ""

func _ready() -> void:
	_socket = get_node_or_null(socket_path)
	_pad_mesh = get_node_or_null(pad_mesh_path) as MeshInstance3D
	_status_label = get_node_or_null(status_label_path) as Label
	if _socket == null or _pad_mesh == null:
		push_warning("xr_socket_affordance: assign socket_path and pad_mesh_path.")
		return

	_materials[&"ready"] = _make_material(Color(0.14, 0.82, 0.95, 0.55))
	_materials[&"hovering"] = _make_material(Color(1.0, 0.9, 0.25, 0.78))
	_materials[&"occupied"] = _make_material(Color(0.28, 1.0, 0.55, 0.82))
	_materials[&"disabled"] = _make_material(Color(0.22, 0.24, 0.26, 0.36))

func _process(_delta: float) -> void:
	if _socket == null or not _socket.has_method("get_socket_state"):
		return

	var state: Dictionary = _socket.get_socket_state()
	var state_name: StringName = state.get("state", &"ready")
	var selected = state.get("selected")
	var candidate = state.get("candidate")
	var key := "%s:%s:%s" % [state_name, _node_name(selected), _node_name(candidate)]
	if key == _last_key:
		return

	_last_key = key
	_pad_mesh.set_surface_override_material(0, _materials.get(state_name, _materials[&"ready"]))
	_set_status_for_state(state_name, selected, candidate)

func _make_material(color: Color) -> StandardMaterial3D:
	# Duplicate of a baked .tres; colors/energy/roughness are uniforms, so the
	# baked shader hash is kept.
	var material := SOCKET_MATERIAL.duplicate() as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 0.55
	material.roughness = 0.42
	return material

func _set_status_for_state(state_name: StringName, selected, candidate) -> void:
	if _status_label == null:
		return

	match state_name:
		&"hovering":
			_status_label.text = "Socket hover: %s" % _node_name(candidate)
		&"occupied":
			_status_label.text = "Socket occupied: %s" % _node_name(selected)
		&"disabled":
			_status_label.text = "Socket disabled"

func _node_name(node) -> String:
	if node == null:
		return ""
	if node is Node:
		return (node as Node).name
	return str(node)
