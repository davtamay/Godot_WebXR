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

func _ready() -> void:
	_mode_label = _make_label(Vector3(-0.35, 1.25, -0.55))
	_throw_label = _make_label(Vector3(0.35, 1.25, -0.55))

	_make_button(Vector3(-0.35, 1.0, -0.55), _on_toggle_conditioning)
	_make_button(Vector3(0.2, 1.0, -0.55), func() -> void: _nudge_bias(-_BIAS_STEP))
	_make_button(Vector3(0.5, 1.0, -0.55), func() -> void: _nudge_bias(_BIAS_STEP))

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
	print("feel_check: conditioning=%s throw_peak_bias=%.2f" % [
		"CONDITIONED" if conditioned else "RAW", _peak_bias])
