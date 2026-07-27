extends Node3D

## On-device feel check for the workshop showcase.
##
## Settled by David on 2026-07-25 and therefore no longer switchable here:
## hand conditioning is ON (the resolver default) and throw_peak_bias is 0.80
## (the XRGrabInteractable default). Both are now plain defaults in the suite,
## so this scene no longer overrides them -- what you feel here is what every
## scene gets.
##
## Still open, so still switchable: whether the microgesture recognizers do
## better on conditioned or raw joints. Their thresholds were tuned against
## raw, and conditioning trades 18-28 ms of lag for a smoother signal, so it
## is a genuine on-device question rather than a settled default.

var _gesture_label: Label3D
var _mode_label: Label3D
var _micro_source_label: Label3D
var _arbiter: XRInteractionArbiter

func _ready() -> void:
	_gesture_label = _make_label(Vector3(-0.3, 1.3, -0.55))
	_make_button(Vector3(-0.3, 1.0, -0.55), _on_toggle_gesture_source)

	# Which microgesture DETECTOR drives locomotion, session-wide: PORTABLE
	# is the joint recognizer -- the code path WebXR, Galaxy XR and Link
	# actually run -- and is the default, because testing on a Quest with the
	# platform extension active measures Meta's recognizer, not ours.
	# PLATFORM is the runtime detector (Quest-only), the parity reference.
	_micro_source_label = _make_label(Vector3(-0.9, 1.3, -0.55))
	_make_button(Vector3(-0.9, 1.0, -0.55), _on_toggle_micro_source)

	# The arbiter is opt-in, so the earn-in scene creates its own rather than
	# relying on the rig prefab carrying one.
	_arbiter = XRInteractionArbiter.new()
	add_child(_arbiter)
	_mode_label = _make_label(Vector3(0.3, 1.3, -0.55))
	_make_button(Vector3(0.3, 1.0, -0.55), _on_toggle_arbiter)
	_refresh()

func _process(_delta: float) -> void:
	# The live mode is the point of the label: the state machine should be
	# legible in the headset rather than inferred from what the ray is doing.
	if _mode_label != null:
		_mode_label.text = "ARBITER: %s\nL %s   R %s\n(poke to A/B)" % [
			"ON" if _arbiter.enabled else "OFF",
			_mode_name(_arbiter.mode_for(0)),
			_mode_name(_arbiter.mode_for(1))]

func _mode_name(mode: int) -> String:
	match mode:
		XRInteractionArbiter.Mode.NEAR: return "NEAR"
		XRInteractionArbiter.Mode.FAR: return "FAR"
		XRInteractionArbiter.Mode.TELEPORT: return "TELE"
		_: return "-"

func _on_toggle_arbiter() -> void:
	_arbiter.enabled = not _arbiter.enabled
	_refresh()

func _make_label(where: Vector3) -> Label3D:
	var label := Label3D.new()
	label.font_size = 56
	label.outline_size = 16
	label.pixel_size = 0.002
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = where
	add_child(label)
	return label

func _make_button(where: Vector3, on_press: Callable) -> void:
	var button := XRPokeButton.new()
	button.position = where
	add_child(button)
	button.pressed.connect(on_press)

func _on_toggle_gesture_source() -> void:
	for runtime in _all_gesture_runtimes(self):
		runtime.set_use_conditioned_hands(not runtime.use_conditioned_hands)
	_refresh()

func _micro_platform_active() -> bool:
	if XRMicrogestureLocomotionDriver.session_platform_override >= 0:
		return XRMicrogestureLocomotionDriver.session_platform_override == 1
	# No override yet: the default is the driver export's default, PORTABLE.
	return false

func _on_toggle_micro_source() -> void:
	XRMicrogestureLocomotionDriver.session_platform_override = 0 if _micro_platform_active() else 1
	_refresh()

func _all_gesture_runtimes(root: Node) -> Array:
	var found: Array = []
	if root is XRGestureRuntime:
		found.append(root)
	for child in root.get_children():
		found.append_array(_all_gesture_runtimes(child))
	return found

func _refresh() -> void:
	var runtimes := _all_gesture_runtimes(self)
	if runtimes.is_empty():
		_gesture_label.text = "GESTURES: no runtime in scene"
		_gesture_label.modulate = Color(0.6, 0.6, 0.6)
		print("feel_check: no XRGestureRuntime in scene")
		return
	var on: bool = runtimes[0].use_conditioned_hands
	_gesture_label.text = "MICROGESTURE INPUT: %s\n(poke to A/B)" % ("CONDITIONED" if on else "RAW")
	_gesture_label.modulate = Color(0.3, 1.0, 0.5) if on else Color(1.0, 0.55, 0.3)
	if _micro_source_label != null:
		var platform := _micro_platform_active()
		_micro_source_label.text = "MICRO DETECTOR: %s\n(poke to A/B)" % ("PLATFORM (Quest ML)" if platform else "PORTABLE (ours)")
		_micro_source_label.modulate = Color(0.4, 0.7, 1.0) if platform else Color(0.3, 1.0, 0.5)
		print("feel_check: micro_detector=%s" % ("PLATFORM" if platform else "PORTABLE"))
	if _mode_label != null:
		_mode_label.modulate = Color(0.3, 1.0, 0.5) if _arbiter.enabled else Color(1.0, 0.55, 0.3)
	print("feel_check: microgesture_input=%s arbiter=%s" % [
		"CONDITIONED" if on else "RAW", "ON" if _arbiter.enabled else "OFF"])
