extends Node3D

## Task 6 feel check: the full workshop (grab, poke, throw, gestures) with
## in-headset dials, so tuned values are settled BY FEEL rather than guessed
## offline. Left button A/Bs hand conditioning; the two throw buttons walk
## throw_peak_bias, which decides how much of the release dead-zone's speed
## loss is handed back. Expect a small snap on each conditioning flip -- the
## toggle re-seeds the filter by design.

const _BIAS_STEP := 0.1

var _mode_label: Label3D
var _throw_label: Label3D
var _peak_bias := 0.8
var _gesture_label: Label3D

func _ready() -> void:
	_mode_label = _make_label(Vector3(-0.35, 1.25, -0.55))
	_throw_label = _make_label(Vector3(0.35, 1.25, -0.55))

	_make_button(Vector3(-0.35, 1.0, -0.55), _on_toggle_conditioning)
	_make_button(Vector3(0.2, 1.0, -0.55), func() -> void: _nudge_bias(-_BIAS_STEP))
	_make_button(Vector3(0.5, 1.0, -0.55), func() -> void: _nudge_bias(_BIAS_STEP))
	_make_button(Vector3(0.0, 0.75, -0.55), _on_toggle_gesture_source)

	_gesture_label = _make_label(Vector3(0.0, 1.45, -0.55))

	_apply_bias()
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

## Microgestures were reading RAW joints until now (the gesture runtime
## defaulted to the source that feeds the conditioning chain). Which input the
## recognizers prefer is an on-device question -- their thresholds were tuned
## against raw -- so it gets its own switch rather than a silent default.
func _on_toggle_gesture_source() -> void:
	for runtime in _all_of_type(self, "XRGestureRuntime"):
		runtime.set_use_conditioned_hands(not runtime.use_conditioned_hands)
	_refresh()

func _all_of_type(root: Node, type_name: String) -> Array:
	var found: Array = []
	if root.is_class(type_name) or (root.get_script() != null and root.get_script().get_global_name() == type_name):
		found.append(root)
	for child in root.get_children():
		found.append_array(_all_of_type(child, type_name))
	return found

func _on_toggle_conditioning() -> void:
	XRHandTrackerResolver.set_conditioned(not XRHandTrackerResolver.is_conditioned())
	_refresh()

func _nudge_bias(delta: float) -> void:
	_peak_bias = clampf(_peak_bias + delta, 0.0, 1.0)
	_apply_bias()
	_refresh()

## Applies the live value to every grabbable in the scene, so a dial turn is
## felt on the next throw instead of needing a relaunch.
func _apply_bias() -> void:
	for node in _all_grabbables(self):
		node.throw_peak_bias = _peak_bias

func _all_grabbables(root: Node) -> Array:
	var found: Array = []
	if root is XRGrabInteractable:
		found.append(root)
	for child in root.get_children():
		found.append_array(_all_grabbables(child))
	return found

func _refresh() -> void:
	var conditioned := XRHandTrackerResolver.is_conditioned()
	_mode_label.text = "HANDS: CONDITIONED\n(poke to A/B)" if conditioned else "HANDS: RAW\n(poke to A/B)"
	_mode_label.modulate = Color(0.3, 1.0, 0.5) if conditioned else Color(1.0, 0.55, 0.3)
	# 0.0 is the pure cluster mean (throws ~12% weaker than before this branch);
	# 1.0 hands all of that back by taking the fastest clean sample.
	_throw_label.text = "THROW POWER: %d%%\n(- / + to tune)" % roundi(_peak_bias * 100.0)
	_throw_label.modulate = Color(0.55, 0.75, 1.0)
	var runtimes := _all_of_type(self, "XRGestureRuntime")
	if _gesture_label != null:
		if runtimes.is_empty():
			_gesture_label.text = "GESTURES: no runtime in scene"
			_gesture_label.modulate = Color(0.6, 0.6, 0.6)
		else:
			var on: bool = runtimes[0].use_conditioned_hands
			_gesture_label.text = "MICROGESTURE INPUT: %s
(poke to A/B)" % ("CONDITIONED" if on else "RAW")
			_gesture_label.modulate = Color(0.3, 1.0, 0.5) if on else Color(1.0, 0.55, 0.3)
	var gesture_mode := "n/a"
	if not runtimes.is_empty():
		gesture_mode = "CONDITIONED" if runtimes[0].use_conditioned_hands else "RAW"
	print("feel_check: hands=%s throw_peak_bias=%.2f microgesture_input=%s" % [
		"CONDITIONED" if conditioned else "RAW", _peak_bias, gesture_mode])
