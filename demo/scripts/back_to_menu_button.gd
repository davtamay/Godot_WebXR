class_name BackToMenuButton
extends CanvasLayer

## Drop-in "≡ Menu" button that returns to the launcher. Add it to any scene with
## one line: `add_child(BackToMenuButton.new())`. The shared scene router keeps
## an active WebXR/OpenXR session presenting while the launcher is restored.

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
	XRSceneRouter.change_scene_to_file(MENU)
