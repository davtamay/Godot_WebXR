class_name BackToMenuButton
extends CanvasLayer

## Drop-in "≡ Menu" button that returns to the launcher. Add it to any scene with
## one line: `add_child(BackToMenuButton.new())`. Works in the flat browser view;
## if a WebXR session is active it drops out of XR first so the flat menu shows.

const MENU := "res://scenes/launcher.tscn"

func _ready() -> void:
	layer = 100   # above the scene's own UI
	var b := Button.new()
	b.text = "≡ Menu"
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -132
	b.offset_top = 16
	b.offset_right = -16
	b.offset_bottom = 60
	b.pressed.connect(_go)
	add_child(b)

func _go() -> void:
	if get_viewport().use_xr:
		get_viewport().use_xr = false
	get_tree().change_scene_to_file(MENU)
