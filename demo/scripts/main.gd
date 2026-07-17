extends Node3D

@onready var status_label: Label = %StatusLabel
@onready var caps_label: Label = %CapsLabel
@onready var fps_label: Label = %FpsLabel
@onready var inspect_object: MeshInstance3D = $InspectObject/Mesh

var _rotation_speed := 0.6

func _ready() -> void:
	status_label.text = "Godot WebGL2/WebXR feasibility starter. Render path: Compatibility/WebGL2 on web."
	_refresh_capabilities()
	add_child(BackToMenuButton.new())
	_setup_xr_rig()
	_wire_affordance_status()

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


func _setup_xr_rig() -> void:
	# The dropped-in WebXRRig replaces the old inline rig. Restore the two
	# scene-specific bits the rig defaults differently.
	var origin := get_node_or_null("WebXRRig/XROrigin3D")
	if origin == null:
		return
	# Right-hand interactors + screen ray also reach interaction layer 2, so the
	# "Layer Filtered Cube" (LayerTwoGrab) stays grabbable by the right hand.
	for path in ["RightDirectInteractor", "RightRayInteractor"]:
		var it := origin.get_node_or_null(path)
		if it:
			it.interaction_layers = 3
	var screen := get_node_or_null("WebXRRig/ScreenRayInteractor")
	if screen:
		screen.interaction_layers = 3
	# Tracked hands now come from the rig's own "Hands" node (XRHandsMount,
	# default REALISTIC) - no manual mount needed. Configure it on
	# WebXRRig/XROrigin3D/Hands.


func _wire_affordance_status() -> void:
	# The highlight/socket affordances are self-contained children of their
	# objects now; the HUD status line is demo telemetry, wired here by signal.
	for affordance in find_children("*", "XRHighlightAffordance", true, false):
		affordance.interaction_event.connect(_on_affordance_event.bind(affordance))
	for socket_affordance in find_children("*", "XRSocketAffordance", true, false):
		socket_affordance.socket_state_changed.connect(_on_socket_state_changed)


func _on_affordance_event(event: StringName, _interactor: Node, affordance) -> void:
	const VERBS := {
		&"hover_entered": "Hover", &"hover_exited": "Hover exit",
		&"select_entered": "Grab", &"select_exited": "Release",
		&"activate_entered": "Use", &"activate_exited": "Use end",
	}
	status_label.text = "%s: %s" % [VERBS.get(event, str(event)), affordance.get_display_name()]


func _on_socket_state_changed(state: StringName, selected: Node, candidate: Node) -> void:
	match state:
		&"hovering":
			status_label.text = "Socket hover: %s" % (candidate.name if candidate else "")
		&"occupied":
			status_label.text = "Socket occupied: %s" % (selected.name if selected else "")
		&"disabled":
			status_label.text = "Socket disabled"
