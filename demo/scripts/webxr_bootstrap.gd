extends Node3D

## Minimal WebXR startup flow.
## Attach to a Node3D in the demo scene and wire a Button plus optional status Label.
## This intentionally uses Godot's WebXRInterface, not custom WebGPU rendering.

@export var enter_xr_button_path: NodePath
@export var status_label_path: NodePath
@export var inspect_object_path: NodePath
@export var enable_legacy_select_visuals := false

var _webxr: XRInterface
var _vr_supported := false
var _enter_button: Button
var _status_label: Label
var _inspect_object: MeshInstance3D
var _select_count := 0
var _base_scale := Vector3.ONE
var _base_material: Material
var _highlight_material: StandardMaterial3D
var _last_session_failed := false

func _ready() -> void:
    _enter_button = get_node_or_null(enter_xr_button_path) as Button
    _status_label = get_node_or_null(status_label_path) as Label
    _inspect_object = get_node_or_null(inspect_object_path) as MeshInstance3D

    if _enter_button:
        _enter_button.pressed.connect(_on_enter_xr_pressed)
        _enter_button.disabled = true
    else:
        _set_status("Enter XR button path is not assigned or does not point to a Button.")

    if _inspect_object:
        _base_scale = _inspect_object.scale
        _base_material = _inspect_object.get_active_material(0)
        _highlight_material = StandardMaterial3D.new()
        _highlight_material.albedo_color = Color(0.25, 0.95, 0.68, 1.0)
        _highlight_material.emission_enabled = true
        _highlight_material.emission = Color(0.25, 0.95, 0.68, 1.0)
        _highlight_material.emission_energy_multiplier = 1.2
    else:
        _set_status("Inspect object path is not assigned or does not point to a MeshInstance3D.")

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
    _connect_webxr_input_signal("select", _on_webxr_select)
    _connect_webxr_input_signal("selectstart", _on_webxr_select_start)
    _connect_webxr_input_signal("selectend", _on_webxr_select_end)

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
    _webxr.requested_reference_space_types = "local"
    _webxr.required_features = "layers"
    _webxr.optional_features = "local-floor, bounded-floor, hand-tracking"

    _set_status("Requesting WebXR session…")
    if not _webxr.initialize():
        _set_status("WebXR initialize() returned false. Session was not requested.")

func _on_session_started() -> void:
    _last_session_failed = false
    get_viewport().use_xr = true
    _set_status("WebXR session started. Reference space: %s. Enabled features: %s." % [_webxr.reference_space_type, _webxr.enabled_features])

func _on_session_ended() -> void:
    get_viewport().use_xr = false
    if _last_session_failed:
        return
    _set_status("WebXR session ended.")

func _on_session_failed(message: String) -> void:
    _last_session_failed = true
    get_viewport().use_xr = false
    _set_status("WEBXR FAILED: " + message)
    _show_browser_failure("WEBXR FAILED: " + message)

func _connect_webxr_input_signal(signal_name: StringName, callback: Callable) -> void:
    if not _webxr.has_signal(signal_name):
        _set_status("WebXR signal unavailable in this Godot build: " + str(signal_name))
        return

    if not _webxr.is_connected(signal_name, callback):
        _webxr.connect(signal_name, callback)

func _on_webxr_select(input_source_id: int) -> void:
    _select_count += 1
    if enable_legacy_select_visuals:
        _apply_select_visual_state()
        _set_status("XR select received: %d (input source %d)" % [_select_count, input_source_id])
    else:
        print("XR select received: %d (input source %d)" % [_select_count, input_source_id])

func _on_webxr_select_start(input_source_id: int) -> void:
    print("XR select started (input source %d)" % input_source_id)

func _on_webxr_select_end(input_source_id: int) -> void:
    print("XR select ended (input source %d)" % input_source_id)

func _apply_select_visual_state() -> void:
    if not _inspect_object:
        _set_status("XR select received but inspect object is unavailable.")
        return

    var highlighted := _select_count % 2 == 1
    _inspect_object.scale = _base_scale * (1.25 if highlighted else 1.0)
    _inspect_object.set_surface_override_material(0, _highlight_material if highlighted else _base_material)

func _set_status(message: String) -> void:
    if _status_label:
        _status_label.text = message
    print(message)

func _show_browser_failure(message: String) -> void:
    if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
        return

    var js_bridge = Engine.get_singleton("JavaScriptBridge")
    var encoded_message := JSON.stringify(message)
    js_bridge.eval("window.CompanyWebXRFailure = %s; console.error(%s);" % [encoded_message, encoded_message], true)
