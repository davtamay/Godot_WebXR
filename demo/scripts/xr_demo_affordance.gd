extends Node

## Demo-side visual feedback for one interactable. The toolkit only emits
## hover/select/activate signals; highlight materials are the consumer's job.

## Preloaded so the shader baker can precompile it for web/WebGPU exports.
const AFFORDANCE_MATERIAL := preload("res://scripts/affordance_material.tres")

@export var interactable_path: NodePath
@export var mesh_path: NodePath
@export var status_label_path: NodePath
@export var display_name := ""

var _interactable: Node
var _mesh: MeshInstance3D
var _status_label: Label
var _base_material: Material
var _hover_material: StandardMaterial3D
var _select_material: StandardMaterial3D
var _activate_material: StandardMaterial3D

func _ready() -> void:
    _interactable = get_node_or_null(interactable_path)
    _mesh = get_node_or_null(mesh_path) as MeshInstance3D
    _status_label = get_node_or_null(status_label_path) as Label
    if _interactable == null or _mesh == null:
        push_warning("xr_demo_affordance: assign interactable_path and mesh_path.")
        return

    _base_material = _mesh.get_active_material(0)
    _hover_material = _make_material(Color(1.0, 0.9, 0.25))
    _select_material = _make_material(Color(0.28, 1.0, 0.55))
    _activate_material = _make_material(Color(0.18, 0.92, 1.0))
    _interactable.hover_entered.connect(_on_hover_entered)
    _interactable.hover_exited.connect(_on_hover_exited)
    _interactable.select_entered.connect(_on_select_entered)
    _interactable.select_exited.connect(_on_select_exited)
    if _interactable.has_signal("activate_entered"):
        _interactable.activate_entered.connect(_on_activate_entered)
    if _interactable.has_signal("activate_exited"):
        _interactable.activate_exited.connect(_on_activate_exited)

func _make_material(color: Color) -> StandardMaterial3D:
    # Duplicate of a baked .tres; colors/energy are uniforms, so the baked
    # shader hash is kept.
    var material := AFFORDANCE_MATERIAL.duplicate() as StandardMaterial3D
    material.albedo_color = color
    material.emission = color
    material.emission_energy_multiplier = 0.65
    return material

func _on_hover_entered(_interactor) -> void:
    _apply_state_material()
    _set_status("Hover: %s" % _name())

func _on_hover_exited(_interactor) -> void:
    _apply_state_material()
    _set_status("Hover exit: %s" % _name())

func _on_select_entered(_interactor) -> void:
    _apply_state_material()
    _set_status("Grab: %s" % _name())

func _on_select_exited(_interactor) -> void:
    _apply_state_material()
    _set_status("Release: %s" % _name())

func _on_activate_entered(_interactor) -> void:
    _apply_state_material()
    _set_status("Use: %s" % _name())

func _on_activate_exited(_interactor) -> void:
    _apply_state_material()
    _set_status("Use end: %s" % _name())

func _apply_state_material() -> void:
    if _interactable.has_method("is_activated") and _interactable.is_activated():
        _mesh.set_surface_override_material(0, _activate_material)
    elif _interactable.is_selected():
        _mesh.set_surface_override_material(0, _select_material)
    elif _interactable.is_hovered():
        _mesh.set_surface_override_material(0, _hover_material)
    else:
        _mesh.set_surface_override_material(0, _base_material)

func _set_status(message: String) -> void:
    if _status_label:
        _status_label.text = message
    print(message)

func _name() -> String:
    return display_name if not display_name.is_empty() else _interactable.name
