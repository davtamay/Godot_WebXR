extends Node3D

## Procedural hand-tracking visualizer for WebXR/OpenXR.
## Attach under XROrigin3D so XRHandTracker joint transforms can be used directly.

@export var status_label_path: NodePath
@export var joint_radius_min := 0.012
@export var joint_radius_max := 0.026
@export var bone_radius := 0.006
@export var pinch_threshold := 0.035
@export var show_tracking_diagnostics := true

const TRACKER_LEFT := &"/user/hand_tracker/left"
const TRACKER_RIGHT := &"/user/hand_tracker/right"

const HAND_JOINTS := [
    XRHandTracker.HAND_JOINT_PALM,
    XRHandTracker.HAND_JOINT_WRIST,
    XRHandTracker.HAND_JOINT_THUMB_METACARPAL,
    XRHandTracker.HAND_JOINT_THUMB_PHALANX_PROXIMAL,
    XRHandTracker.HAND_JOINT_THUMB_PHALANX_DISTAL,
    XRHandTracker.HAND_JOINT_THUMB_TIP,
    XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL,
    XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL,
    XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE,
    XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL,
    XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
    XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL,
    XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL,
    XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE,
    XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL,
    XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP,
    XRHandTracker.HAND_JOINT_RING_FINGER_METACARPAL,
    XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL,
    XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE,
    XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL,
    XRHandTracker.HAND_JOINT_RING_FINGER_TIP,
    XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL,
    XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL,
    XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE,
    XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL,
    XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP,
]

const BONE_PAIRS := [
    [XRHandTracker.HAND_JOINT_WRIST, XRHandTracker.HAND_JOINT_PALM],
    [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_THUMB_METACARPAL],
    [XRHandTracker.HAND_JOINT_THUMB_METACARPAL, XRHandTracker.HAND_JOINT_THUMB_PHALANX_PROXIMAL],
    [XRHandTracker.HAND_JOINT_THUMB_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_THUMB_PHALANX_DISTAL],
    [XRHandTracker.HAND_JOINT_THUMB_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_THUMB_TIP],
    [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL],
    [XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL],
    [XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE],
    [XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL],
    [XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP],
    [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL],
    [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL],
    [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE],
    [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL],
    [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP],
    [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_RING_FINGER_METACARPAL],
    [XRHandTracker.HAND_JOINT_RING_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL],
    [XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE],
    [XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL],
    [XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_RING_FINGER_TIP],
    [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL],
    [XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL],
    [XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE],
    [XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL],
    [XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP],
]

const POSITION_VALID_FLAGS := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED

var _status_label: Label
var _joint_mesh: SphereMesh
var _bone_mesh: CylinderMesh
var _hands := {}
var _last_hand_debug := {}
var _last_tracking_summary := ""
var _status_elapsed := 0.0

func _ready() -> void:
    _status_label = get_node_or_null(status_label_path) as Label
    _create_shared_meshes()
    _create_hand("Left", TRACKER_LEFT, Color(0.15, 0.72, 1.0, 1.0))
    _create_hand("Right", TRACKER_RIGHT, Color(1.0, 0.48, 0.18, 1.0))

func _process(delta: float) -> void:
    _status_elapsed += delta

    if not get_viewport().use_xr:
        for hand_data in _hands.values():
            hand_data["root"].visible = false
        return

    var active_hands: Array[String] = []
    for hand_name in _hands.keys():
        if _update_hand(_hands[hand_name]):
            active_hands.append(hand_name)

    if _status_elapsed >= 0.5:
        _status_elapsed = 0.0
        var summary := ", ".join(active_hands) if not active_hands.is_empty() else "none"
        if show_tracking_diagnostics:
            var details: Array[String] = []
            for hand_name in _hands.keys():
                details.append("%s %s" % [hand_name.substr(0, 1), _last_hand_debug.get(hand_name, "pending")])
            summary = "%s | %s" % [summary, " | ".join(details)]
        if summary != _last_tracking_summary:
            _last_tracking_summary = summary
            _set_status("Hand tracking: %s." % summary)

func _create_shared_meshes() -> void:
    _joint_mesh = SphereMesh.new()
    _joint_mesh.radius = 1.0
    _joint_mesh.height = 2.0
    _joint_mesh.radial_segments = 12
    _joint_mesh.rings = 6

    _bone_mesh = CylinderMesh.new()
    _bone_mesh.top_radius = 1.0
    _bone_mesh.bottom_radius = 1.0
    _bone_mesh.height = 1.0
    _bone_mesh.radial_segments = 8
    _bone_mesh.rings = 1

func _create_hand(hand_name: String, tracker_path: StringName, color: Color) -> void:
    var root := Node3D.new()
    root.name = "%sHandTracking" % hand_name
    root.visible = false
    add_child(root)

    var material := _create_material(color)
    var pinch_material := _create_material(Color(0.25, 1.0, 0.55, 1.0))

    var joint_nodes := {}
    for joint_id in HAND_JOINTS:
        var joint_node := MeshInstance3D.new()
        joint_node.name = "Joint_%02d" % joint_id
        joint_node.mesh = _joint_mesh
        joint_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        joint_node.set_surface_override_material(0, material)
        root.add_child(joint_node)
        joint_nodes[joint_id] = joint_node

    var bone_nodes: Array[MeshInstance3D] = []
    for bone_index in range(BONE_PAIRS.size()):
        var bone_node := MeshInstance3D.new()
        bone_node.name = "Bone_%02d" % bone_index
        bone_node.mesh = _bone_mesh
        bone_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        bone_node.set_surface_override_material(0, material)
        root.add_child(bone_node)
        bone_nodes.append(bone_node)

    _hands[hand_name] = {
        "label": hand_name,
        "root": root,
        "tracker_path": tracker_path,
        "material": material,
        "pinch_material": pinch_material,
        "joints": joint_nodes,
        "bones": bone_nodes,
    }
    _last_hand_debug[hand_name] = "pending"

func _create_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.45
    material.roughness = 0.7
    return material

func _update_hand(hand_data: Dictionary) -> bool:
    var hand_name: String = hand_data["label"]
    var root := hand_data["root"] as Node3D
    var tracker := XRServer.get_tracker(hand_data["tracker_path"]) as XRHandTracker
    if tracker == null:
        _last_hand_debug[hand_name] = "no tracker"
        root.visible = false
        return false

    var joint_positions := {}
    var joint_valid := {}
    var joint_nodes := hand_data["joints"] as Dictionary
    var valid_joint_count := 0

    for joint_id in HAND_JOINTS:
        var valid := _is_joint_position_valid(tracker, joint_id)
        joint_valid[joint_id] = valid
        var joint_node := joint_nodes[joint_id] as MeshInstance3D
        joint_node.visible = valid
        if not valid:
            continue

        valid_joint_count += 1
        var joint_transform := tracker.get_hand_joint_transform(joint_id)
        var radius: float = clamp(tracker.get_hand_joint_radius(joint_id), joint_radius_min, joint_radius_max)
        joint_positions[joint_id] = joint_transform.origin
        joint_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), joint_transform.origin)

    if valid_joint_count == 0:
        _last_hand_debug[hand_name] = "0 joints tracking=%s" % str(tracker.has_tracking_data)
        root.visible = false
        return false

    _last_hand_debug[hand_name] = "%d joints tracking=%s" % [valid_joint_count, str(tracker.has_tracking_data)]
    root.visible = true
    _update_bones(hand_data["bones"], joint_positions, joint_valid)
    _update_pinch_materials(hand_data, joint_positions, joint_valid)
    return true

func _is_joint_position_valid(tracker: XRHandTracker, joint_id: int) -> bool:
    return (tracker.get_hand_joint_flags(joint_id) & POSITION_VALID_FLAGS) != 0

func _update_bones(bone_nodes: Array[MeshInstance3D], joint_positions: Dictionary, joint_valid: Dictionary) -> void:
    for bone_index in range(BONE_PAIRS.size()):
        var bone_node := bone_nodes[bone_index]
        var pair: Array = BONE_PAIRS[bone_index]
        var from_joint: int = pair[0]
        var to_joint: int = pair[1]
        var visible := bool(joint_valid.get(from_joint, false)) and bool(joint_valid.get(to_joint, false))
        bone_node.visible = visible
        if not visible:
            continue

        var from_position: Vector3 = joint_positions[from_joint]
        var to_position: Vector3 = joint_positions[to_joint]
        var delta := to_position - from_position
        var length := delta.length()
        if length < 0.001:
            bone_node.visible = false
            continue

        var basis := _basis_from_y_axis(delta).scaled(Vector3(bone_radius, length, bone_radius))
        bone_node.transform = Transform3D(basis, from_position + delta * 0.5)

func _update_pinch_materials(hand_data: Dictionary, joint_positions: Dictionary, joint_valid: Dictionary) -> void:
    var thumb_tip := XRHandTracker.HAND_JOINT_THUMB_TIP
    var index_tip := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
    var is_pinching := bool(joint_valid.get(thumb_tip, false)) and bool(joint_valid.get(index_tip, false))

    if is_pinching:
        var thumb_position: Vector3 = joint_positions[thumb_tip]
        var index_position: Vector3 = joint_positions[index_tip]
        var distance := thumb_position.distance_to(index_position)
        is_pinching = distance <= pinch_threshold

    var joint_nodes := hand_data["joints"] as Dictionary
    var material: Material = hand_data["pinch_material"] if is_pinching else hand_data["material"]
    (joint_nodes[thumb_tip] as MeshInstance3D).set_surface_override_material(0, material)
    (joint_nodes[index_tip] as MeshInstance3D).set_surface_override_material(0, material)

func _basis_from_y_axis(direction: Vector3) -> Basis:
    var y_axis := direction.normalized()
    var helper := Vector3.UP
    if absf(y_axis.dot(helper)) > 0.95:
        helper = Vector3.FORWARD

    var x_axis := helper.cross(y_axis).normalized()
    var z_axis := x_axis.cross(y_axis).normalized()
    return Basis(x_axis, y_axis, z_axis)

func _set_status(message: String) -> void:
    if _status_label:
        _status_label.text = message
    print(message)
