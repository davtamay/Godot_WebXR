extends Node3D

@onready var status_label: Label = %StatusLabel
@onready var caps_label: Label = %CapsLabel
@onready var fps_label: Label = %FpsLabel
@onready var inspect_object: MeshInstance3D = %InspectObject

var _rotation_speed := 0.6

func _ready() -> void:
    status_label.text = "Godot WebGL2/WebXR feasibility starter. Render path: Compatibility/WebGL2 on web."
    _refresh_capabilities()

func _process(delta: float) -> void:
    inspect_object.rotate_y(delta * _rotation_speed)
    fps_label.text = "FPS: %d | Frame: %.2f ms" % [Engine.get_frames_per_second(), delta * 1000.0]

func _refresh_capabilities() -> void:
    if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
        var js_bridge = Engine.get_singleton("JavaScriptBridge")
        var caps_json = js_bridge.eval("JSON.stringify(window.CompanyWebCaps || {}, null, 2)", true)
        caps_label.text = str(caps_json)
    else:
        caps_label.text = "Running inside the editor/native build. Export to Web to see browser capability data."
