extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

const XRInteractionLayerMask := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd")

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    _test_layer_mask()
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
