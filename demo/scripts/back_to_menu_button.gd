class_name BackToMenuButton
extends Node3D

## Drop-in "menu" control that returns to the launcher, reachable BOTH flat and
## in-headset. Add it to any scene with one line:
## `add_child(BackToMenuButton.new())` -- or let XRSceneRouter inject it, which
## is how every streamed scene gets one without editing the scene.
##
## Was a CanvasLayer holding a 2D Button, which renders to the flat window only,
## so in a headset there was no way back to the menu without taking the headset
## off. It now also carries a WORLD-SPACE poke button anchored in front of the
## camera, so hands, controllers and the mouse can all reach it.

const MENU := "res://scenes/launcher.tscn"

## Where the 3D control sits relative to the camera: low and to the left, clear
## of whatever the scene puts in front of you, but always within reach.
const _ANCHOR_OFFSET := Vector3(-0.28, -0.24, -0.45)

var _panel: Node3D

func _ready() -> void:
	_add_flat_button()
	_add_world_button()

## Kept for flat/desktop testing, where a 2D button is the natural control.
func _add_flat_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var b := Button.new()
	b.text = "≡ Menu"
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -132
	b.offset_top = 16
	b.offset_right = -16
	b.offset_bottom = 60
	b.pressed.connect(_go)
	layer.add_child(b)

## The in-headset control: a real poke button plus a label, so it presses with a
## fingertip and selects with a ray like anything else in the suite.
func _add_world_button() -> void:
	_panel = Node3D.new()
	add_child(_panel)

	var button := XRPokeButton.new()
	button.cap_color = Color(0.95, 0.5, 0.25, 1.0)
	button.pressed_color = Color(0.3, 1.0, 0.55, 1.0)
	_panel.add_child(button)
	button.pressed.connect(_go)

	var label := Label3D.new()
	label.text = "MENU"
	label.font_size = 48
	label.outline_size = 14
	label.pixel_size = 0.0012
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 0.06, 0.0)
	_panel.add_child(label)

func _process(_delta: float) -> void:
	# Follows the ACTIVE camera every frame rather than being parented once: the
	# XR rig builds its camera at runtime and the runtime recentres the play
	# space, so a control placed at _ready can end up behind the user.
	if _panel == null or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var xf := camera.global_transform
	_panel.global_position = xf.origin + xf.basis * _ANCHOR_OFFSET
	# Face the user but stay upright: billboarding the whole panel would tilt
	# the button's press axis with the head, which fights the poke test.
	var flat_forward := xf.basis.z
	flat_forward.y = 0.0
	if flat_forward.length_squared() < 0.000001:
		return
	_panel.global_basis = Basis.looking_at(-flat_forward.normalized(), Vector3.UP)

func _go() -> void:
	XRSceneRouter.change_scene_to_file(MENU)
