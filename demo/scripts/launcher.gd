extends Control

## Bare-bones launcher: the tiny main scene the browser reaches first. Heavy
## content (the material collection) is streamed on demand as a separate bundle
## pck, so the initial load is just the engine + this menu instead of stalling on
## the full asset payload.

const MATERIAL_SCENE := "res://addons/godot_blender_principled/samples/material_inspect_xr.tscn"
const BENCHMARK_SCENE := "res://addons/godot_blender_principled/samples/vr_stress_benchmark.tscn"
const TOOLKIT_SCENE := "res://scenes/Main.tscn"

## Material assets live in this streamed bundle, served next to index.html.
const MATERIAL_PCK := "material.pck"

var _streamer: SceneStreamer
var _status: Label

func _ready() -> void:
	_streamer = SceneStreamer.new()
	add_child(_streamer)
	_streamer.status.connect(_on_status)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "Godot WebXR Feasibility — choose a scene"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_status = Label.new()
	_status.text = "Base loaded. Heavy assets stream on demand."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)

	_add_button(vbox, "Material Inspector  (streams ~22 MB bundle)", func() -> void:
		_streamer.open(MATERIAL_SCENE, MATERIAL_PCK, MATERIAL_PCK))
	_add_button(vbox, "VR Stress Benchmark", func() -> void:
		_streamer.open(BENCHMARK_SCENE))
	_add_button(vbox, "XR Interaction Lab", func() -> void:
		_streamer.open(TOOLKIT_SCENE))

func _add_button(parent: Node, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 56)
	b.pressed.connect(on_press)
	parent.add_child(b)

func _on_status(text: String) -> void:
	_status.text = text
	print("[launcher] " + text)
