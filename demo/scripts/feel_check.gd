extends Node3D

## Task 10 feel check: the full playground (grab, poke, throw, gestures) with
## an in-headset A/B switch. Poke the button to flip between CONDITIONED and
## RAW hand tracking; the label above it names the active mode. Expect a tiny
## snap on each flip -- the toggle re-seeds the filter by design.

var _label: Label3D
var _button: XRPokeButton

func _ready() -> void:
	_button = XRPokeButton.new()
	_button.position = Vector3(0.0, 1.0, -0.55)
	add_child(_button)
	_button.pressed.connect(_on_toggle)

	_label = Label3D.new()
	_label.font_size = 64
	_label.outline_size = 18
	_label.pixel_size = 0.002
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.no_depth_test = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = _button.position + Vector3(0.0, 0.25, 0.0)
	add_child(_label)
	_refresh()

func _on_toggle() -> void:
	XRHandTrackerResolver.set_conditioned(not XRHandTrackerResolver.is_conditioned())
	_refresh()

func _refresh() -> void:
	var conditioned := XRHandTrackerResolver.is_conditioned()
	_label.text = "HANDS: CONDITIONED\n(poke button to A/B)" if conditioned else "HANDS: RAW\n(poke button to A/B)"
	_label.modulate = Color(0.3, 1.0, 0.5) if conditioned else Color(1.0, 0.55, 0.3)
	print("feel_check: mode -> %s" % ("CONDITIONED" if conditioned else "RAW"))
