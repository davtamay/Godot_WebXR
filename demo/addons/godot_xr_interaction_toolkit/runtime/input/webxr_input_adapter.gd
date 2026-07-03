class_name WebXRInputAdapter
extends "res://addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd"

const XRHandGestureProvider := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd")

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

var _webxr
var _origin: Node3D
var _controllers := {}

func _ready() -> void:
    _origin = get_node_or_null(xr_origin_path) as Node3D
    _controllers[Hand.LEFT] = get_node_or_null(left_controller_path) as XRController3D
    _controllers[Hand.RIGHT] = get_node_or_null(right_controller_path) as XRController3D
    if not OS.has_feature("web"):
        return

    _webxr = XRServer.find_interface("WebXR")
    if _webxr == null:
        return

    _connect_interface_signal(&"selectstart", _on_selectstart)
    _connect_interface_signal(&"selectend", _on_selectend)

func get_aim_pose(hand_id: int) -> Dictionary:
    if not _valid_hand(hand_id):
        return {}
    if prefer_hand_ray:
        var hand_pose := _hand_aim_pose(hand_id)
        return hand_pose if not hand_pose.is_empty() else _controller_aim_pose(hand_id)

    var controller_pose := _controller_aim_pose(hand_id)
    return controller_pose if not controller_pose.is_empty() else _hand_aim_pose(hand_id)

func get_source_kind(hand_id: int) -> int:
    if not _valid_hand(hand_id):
        return SourceKind.NONE

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
    if _webxr == null:
        return -1

    var tracker = _webxr.get_input_source_tracker(input_source_id)
    if tracker == null:
        return -1

    match tracker.hand:
        XRPositionalTracker.TRACKER_HAND_LEFT:
            return Hand.LEFT
        XRPositionalTracker.TRACKER_HAND_RIGHT:
            return Hand.RIGHT
    return -1

func _controller_aim_pose(hand_id: int) -> Dictionary:
    if not _valid_hand(hand_id):
        return {}

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
    if not _valid_hand(hand_id) or _origin == null:
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

func _valid_hand(hand_id: int) -> bool:
    return hand_id == Hand.LEFT or hand_id == Hand.RIGHT
