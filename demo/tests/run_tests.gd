extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

const XRInteractionLayerMask := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd")
const XRHandGestureProvider := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_hand_gesture_provider.gd")

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    _test_layer_mask()
    _test_hand_ray_geometry()
    print("%d checks, %d failures" % [_checks, _failures])
    quit(1 if _failures > 0 else 0)

func check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS: " + message)
    else:
        _failures += 1
        printerr("FAIL: " + message)

func _test_layer_mask() -> void:
    check(XRInteractionLayerMask.overlaps(1, 1), "layer 1 overlaps layer 1")
    check(XRInteractionLayerMask.overlaps(0b0110, 0b0100), "masks sharing one bit overlap")
    check(not XRInteractionLayerMask.overlaps(0b0011, 0b0100), "disjoint masks do not overlap")
    check(not XRInteractionLayerMask.overlaps(0, 0), "zero masks never overlap")

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
        check((pose["direction"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "direction points palm to cursor")
        var expected_origin := Vector3(0, 0, -0.15) + Vector3(0, 0, -1) * XRHandGestureProvider.RAY_ORIGIN_FORWARD_OFFSET
        check((pose["origin"] as Vector3).is_equal_approx(expected_origin), "origin is cursor nudged forward along the ray")

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
