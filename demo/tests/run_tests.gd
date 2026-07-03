extends SceneTree

## Headless test runner for the XR Interaction Toolkit addon.
## Run: c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd
## Exit code 0 = all checks passed, 1 = at least one failure.

var _checks := 0
var _failures := 0

func _initialize() -> void:
    await _run_all()

func _run_all() -> void:
    print("== XR Interaction Toolkit tests ==")
    print("%d checks, %d failures" % [_checks, _failures])
    quit(1 if _failures > 0 else 0)

func check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS: " + message)
    else:
        _failures += 1
        printerr("FAIL: " + message)
