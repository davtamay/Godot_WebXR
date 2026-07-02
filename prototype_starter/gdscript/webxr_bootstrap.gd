extends Node3D

## Minimal WebXR startup flow.
## Attach to a Node3D in the demo scene and wire a Button plus optional status Label.
## This intentionally uses Godot's WebXRInterface, not custom WebGPU rendering.

@export var enter_xr_button_path: NodePath
@export var status_label_path: NodePath

var _webxr: XRInterface
var _vr_supported := false
var _enter_button: Button
var _status_label: Label

func _ready() -> void:
    _enter_button = get_node_or_null(enter_xr_button_path) as Button
    _status_label = get_node_or_null(status_label_path) as Label

    if _enter_button:
        _enter_button.pressed.connect(_on_enter_xr_pressed)
        _enter_button.disabled = true

    if not OS.has_feature("web"):
        _set_status("Not a web export. WebXRInterface is available only in web builds.")
        return

    _webxr = XRServer.find_interface("WebXR")
    if not _webxr:
        _set_status("WebXR interface not found.")
        return

    _webxr.session_supported.connect(_on_session_supported)
    _webxr.session_started.connect(_on_session_started)
    _webxr.session_ended.connect(_on_session_ended)
    _webxr.session_failed.connect(_on_session_failed)

    _set_status("Checking immersive-vr support…")
    _webxr.is_session_supported("immersive-vr")

func _on_session_supported(session_mode: String, supported: bool) -> void:
    if session_mode != "immersive-vr":
        return

    _vr_supported = supported
    if _enter_button:
        _enter_button.disabled = not supported

    _set_status("immersive-vr supported." if supported else "immersive-vr not supported in this browser/device.")

func _on_enter_xr_pressed() -> void:
    if not _webxr:
        _set_status("WebXR interface missing.")
        return

    if not _vr_supported:
        _set_status("immersive-vr not supported.")
        return

    _webxr.session_mode = "immersive-vr"
    _webxr.requested_reference_space_types = "bounded-floor, local-floor, local"
    _webxr.required_features = "local-floor"
    _webxr.optional_features = "bounded-floor, hand-tracking"

    _set_status("Requesting WebXR session…")
    if not _webxr.initialize():
        _set_status("WebXR initialize() returned false. Session was not requested.")

func _on_session_started() -> void:
    get_viewport().use_xr = true
    _set_status("WebXR session started. Rendering through Godot WebGL2 Compatibility path.")

func _on_session_ended() -> void:
    get_viewport().use_xr = false
    _set_status("WebXR session ended.")

func _on_session_failed(message: String) -> void:
    get_viewport().use_xr = false
    _set_status("WebXR session failed: " + message)

func _set_status(message: String) -> void:
    if _status_label:
        _status_label.text = message
    print(message)
