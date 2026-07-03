extends Node3D

## Minimal XR Interaction Toolkit-style ray interactor.
## Uses XRController3D poses when available and falls back to index-finger hand rays.

@export var left_controller_path: NodePath
@export var right_controller_path: NodePath
@export var status_label_path: NodePath
@export var max_distance := 6.0
@export_flags_3d_physics var collision_mask := 1

const TRACKER_LEFT := &"/user/hand_tracker/left"
const TRACKER_RIGHT := &"/user/hand_tracker/right"
const POSITION_VALID_FLAGS := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED

var _webxr: XRInterface
var _left_controller: XRController3D
var _right_controller: XRController3D
var _status_label: Label
var _reticle_mesh: SphereMesh
var _ray_material: StandardMaterial3D
var _hover_material: StandardMaterial3D
var _selected_material: StandardMaterial3D
var _default_materials := {}
var _rays := {}
var _ray_poses := {}
var _hovered: MeshInstance3D
var _hovered_hand := ""
var _hovered_distance := 0.0
var _selected: MeshInstance3D
var _grabbed: MeshInstance3D
var _grab_hand := ""
var _grab_distance := 0.0
var _last_status := ""

func _ready() -> void:
    _left_controller = get_node_or_null(left_controller_path) as XRController3D
    _right_controller = get_node_or_null(right_controller_path) as XRController3D
    _status_label = get_node_or_null(status_label_path) as Label
    _create_materials()
    _create_ray_visual("Left", Color(0.2, 0.75, 1.0, 1.0))
    _create_ray_visual("Right", Color(1.0, 0.58, 0.2, 1.0))

    if OS.has_feature("web"):
        _webxr = XRServer.find_interface("WebXR")
        if _webxr:
            _connect_webxr_input_signal("select", _on_select)
            _connect_webxr_input_signal("selectstart", _on_select_start)
            _connect_webxr_input_signal("selectend", _on_select_end)

func _physics_process(_delta: float) -> void:
    if not get_viewport().use_xr:
        _set_ray_visible(_rays["Left"], false)
        _set_ray_visible(_rays["Right"], false)
        return

    var candidates: Array[Dictionary] = []
    _ray_poses.clear()
    _update_ray("Left", _left_controller, TRACKER_LEFT, candidates)
    _update_ray("Right", _right_controller, TRACKER_RIGHT, candidates)
    _apply_hover(_find_nearest_target(candidates))
    _update_grabbed()

func _create_materials() -> void:
    _reticle_mesh = SphereMesh.new()
    _reticle_mesh.radius = 1.0
    _reticle_mesh.height = 2.0
    _reticle_mesh.radial_segments = 16
    _reticle_mesh.rings = 8

    _ray_material = _make_emissive_material(Color(0.7, 0.88, 1.0, 0.85))
    _hover_material = _make_emissive_material(Color(1.0, 0.9, 0.25, 1.0))
    _selected_material = _make_emissive_material(Color(0.28, 1.0, 0.55, 1.0))

func _make_emissive_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.65
    material.roughness = 0.55
    return material

func _create_ray_visual(hand_name: String, color: Color) -> void:
    var root := Node3D.new()
    root.name = "%sRayInteractor" % hand_name
    root.visible = false
    add_child(root)

    var ray_material := _make_emissive_material(color)
    ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

    var line_mesh := ImmediateMesh.new()
    var beam := MeshInstance3D.new()
    beam.name = "Beam"
    beam.mesh = line_mesh
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beam.material_override = ray_material
    root.add_child(beam)

    var reticle := MeshInstance3D.new()
    reticle.name = "Reticle"
    reticle.mesh = _reticle_mesh
    reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    reticle.set_surface_override_material(0, _hover_material)
    root.add_child(reticle)

    _rays[hand_name] = {
        "root": root,
        "beam": beam,
        "line_mesh": line_mesh,
        "reticle": reticle,
    }

func _update_ray(hand_name: String, controller: XRController3D, tracker_path: StringName, candidates: Array[Dictionary]) -> void:
    var ray_data := _rays[hand_name] as Dictionary
    var pose := _get_ray_pose(controller, tracker_path)
    if pose.is_empty():
        _set_ray_visible(ray_data, false)
        return

    var origin: Vector3 = pose["origin"]
    var direction: Vector3 = pose["direction"]
    _ray_poses[hand_name] = pose

    var world_origin := global_transform * origin
    var world_direction := (global_transform.basis * direction).normalized()
    var query := PhysicsRayQueryParameters3D.create(world_origin, world_origin + world_direction * max_distance)
    query.collision_mask = collision_mask
    query.collide_with_areas = true
    query.collide_with_bodies = true

    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var end_position := origin + direction * max_distance
    var target: MeshInstance3D
    var distance := max_distance

    if not hit.is_empty():
        end_position = to_local(hit["position"])
        distance = origin.distance_to(end_position)
        target = _find_interactable_mesh(hit["collider"])
        if target:
            candidates.append({
                "target": target,
                "distance": distance,
                "hand": hand_name,
            })

    _draw_ray(ray_data, origin, end_position, target != null)

func _get_ray_pose(controller: XRController3D, tracker_path: StringName) -> Dictionary:
    var hand_pose := _get_hand_ray_pose(tracker_path)
    if not hand_pose.is_empty():
        return hand_pose

    if controller and controller.get_is_active() and controller.get_has_tracking_data():
        var controller_origin := to_local(controller.global_transform.origin)
        var controller_direction := (global_transform.basis.inverse() * -controller.global_transform.basis.z).normalized()
        return {
            "origin": controller_origin,
            "direction": controller_direction,
        }

    return {}

func _get_hand_ray_pose(tracker_path: StringName) -> Dictionary:
    var tracker := XRServer.get_tracker(tracker_path) as XRHandTracker
    if tracker == null or not tracker.has_tracking_data:
        return {}

    var wrist := XRHandTracker.HAND_JOINT_WRIST
    var palm := XRHandTracker.HAND_JOINT_PALM
    var index_tip := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
    var thumb_tip := XRHandTracker.HAND_JOINT_THUMB_TIP
    if not _joint_position_valid(tracker, wrist) or not _joint_position_valid(tracker, index_tip):
        return {}

    var wrist_position := tracker.get_hand_joint_transform(wrist).origin
    var index_position := tracker.get_hand_joint_transform(index_tip).origin
    var cursor_position := index_position

    if _joint_position_valid(tracker, thumb_tip):
        var thumb_position := tracker.get_hand_joint_transform(thumb_tip).origin
        cursor_position = (thumb_position + index_position) * 0.5

    var direction_seed := wrist_position
    if _joint_position_valid(tracker, palm):
        direction_seed = tracker.get_hand_joint_transform(palm).origin

    var direction := (cursor_position - direction_seed).normalized()
    if direction.length_squared() < 0.001:
        return {}

    return {
        "origin": cursor_position + direction * 0.025,
        "direction": direction,
    }

func _joint_position_valid(tracker: XRHandTracker, joint_id: int) -> bool:
    return (tracker.get_hand_joint_flags(joint_id) & POSITION_VALID_FLAGS) != 0

func _find_interactable_mesh(collider: Object) -> MeshInstance3D:
    if not collider:
        return null

    var node := collider as Node
    while node:
        if node.is_in_group("xr_interactable") and node is MeshInstance3D:
            return node as MeshInstance3D
        node = node.get_parent()
    return null

func _find_nearest_target(candidates: Array[Dictionary]) -> Dictionary:
    var best := {}
    var best_distance := INF
    for candidate in candidates:
        var distance: float = candidate["distance"]
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

func _apply_hover(hit: Dictionary) -> void:
    var target: MeshInstance3D
    var hand_name := ""
    var distance := 0.0
    if not hit.is_empty():
        target = hit["target"]
        hand_name = hit["hand"]
        distance = hit["distance"]

    if target == _hovered:
        _hovered_hand = hand_name
        _hovered_distance = distance
        return

    if _hovered and _hovered != _selected and _hovered != _grabbed:
        _restore_material(_hovered)

    _hovered = target
    _hovered_hand = hand_name
    _hovered_distance = distance
    if _hovered and _hovered != _selected and _hovered != _grabbed:
        _store_default_material(_hovered)
        _hovered.set_surface_override_material(0, _hover_material)
        _set_status("Ray hover: %s" % _hovered.name)
    elif not _hovered:
        _set_status("Ray hover: none")

func _on_select(_input_source_id: int) -> void:
    pass

func _on_select_start(_input_source_id: int) -> void:
    if _grabbed or not _hovered or _hovered_hand.is_empty():
        return

    _grabbed = _hovered
    _grab_hand = _hovered_hand
    _grab_distance = clampf(_hovered_distance, 0.25, max_distance)
    if _selected:
        _restore_material(_selected)
        _selected.scale = Vector3.ONE

    _selected = _grabbed
    _store_default_material(_selected)
    _selected.set_surface_override_material(0, _selected_material)
    _selected.scale = Vector3.ONE * 1.18
    _set_status("Ray grab: %s" % _selected.name)

func _on_select_end(_input_source_id: int) -> void:
    if not _grabbed:
        return

    var released := _grabbed
    released.scale = Vector3.ONE
    _restore_material(released)
    _grabbed = null
    _grab_hand = ""
    _grab_distance = 0.0
    _selected = null

    if released == _hovered:
        _store_default_material(released)
        released.set_surface_override_material(0, _hover_material)

    _set_status("Ray release: %s" % released.name)

func _update_grabbed() -> void:
    if not _grabbed or _grab_hand.is_empty() or not _ray_poses.has(_grab_hand):
        return

    var pose: Dictionary = _ray_poses[_grab_hand]
    var origin: Vector3 = pose["origin"]
    var direction: Vector3 = pose["direction"]
    var local_position := origin + direction * _grab_distance
    _grabbed.global_position = global_transform * local_position

func _draw_ray(ray_data: Dictionary, from_position: Vector3, to_position: Vector3, hit_target: bool) -> void:
    _set_ray_visible(ray_data, true)
    var beam := ray_data["beam"] as MeshInstance3D
    var line_mesh := ray_data["line_mesh"] as ImmediateMesh
    var reticle := ray_data["reticle"] as MeshInstance3D
    var delta := to_position - from_position
    var length := delta.length()
    if length < 0.001:
        beam.visible = false
        reticle.visible = false
        return

    beam.visible = true
    line_mesh.clear_surfaces()
    line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    line_mesh.surface_add_vertex(from_position)
    line_mesh.surface_add_vertex(to_position)
    line_mesh.surface_end()

    reticle.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.04 if hit_target else 0.02)), to_position)
    reticle.visible = hit_target

func _set_ray_visible(ray_data: Dictionary, visible: bool) -> void:
    (ray_data["root"] as Node3D).visible = visible

func _basis_from_y_axis(direction: Vector3) -> Basis:
    var y_axis := direction.normalized()
    var helper := Vector3.UP
    if absf(y_axis.dot(helper)) > 0.95:
        helper = Vector3.FORWARD

    var x_axis := helper.cross(y_axis).normalized()
    var z_axis := x_axis.cross(y_axis).normalized()
    return Basis(x_axis, y_axis, z_axis)

func _store_default_material(mesh: MeshInstance3D) -> void:
    if not _default_materials.has(mesh):
        _default_materials[mesh] = mesh.get_active_material(0)

func _restore_material(mesh: MeshInstance3D) -> void:
    if mesh and _default_materials.has(mesh):
        mesh.set_surface_override_material(0, _default_materials[mesh])

func _connect_webxr_input_signal(signal_name: StringName, callback: Callable) -> void:
    if not _webxr.has_signal(signal_name):
        return
    if not _webxr.is_connected(signal_name, callback):
        _webxr.connect(signal_name, callback)

func _set_status(message: String) -> void:
    if message == _last_status:
        return
    _last_status = message
    if _status_label:
        _status_label.text = message
    print(message)
