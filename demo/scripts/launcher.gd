extends Control

## Bare-bones launcher: the tiny main scene the browser reaches first. Each
## button opens a WebXR sample scene on demand.

const BENCHMARK_SCENE := "res://addons/godot_blender_principled/samples/vr_stress_benchmark.tscn"
const TOOLKIT_SCENE := "res://scenes/Main.tscn"
const SCENE_UNDERSTANDING_SCENE := "res://addons/godot_webxr_scene_understanding/samples/scene_understanding_demo.tscn"
const GALAXY_SCENE := "res://scenes/galaxy.tscn"

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
	title.text = "Godot WebXR Samples — choose a scene"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)

	_add_button(vbox, "XR Interaction Toolkit", func() -> void:
		_streamer.open(TOOLKIT_SCENE))
	_add_button(vbox, "Performance  (VR stress benchmark)", func() -> void:
		_streamer.open(BENCHMARK_SCENE))
	_add_button(vbox, "Scene Understanding  (room mesh / labels / occlusion / depth)", func() -> void:
		_streamer.open(SCENE_UNDERSTANDING_SCENE))
	_add_button(vbox, "WebGPU Galaxy  (50k GPU stars)", func() -> void:
		_streamer.open(GALAXY_SCENE))

func _add_button(parent: Node, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 56)
	b.pressed.connect(on_press)
	parent.add_child(b)

func _on_status(text: String) -> void:
	_status.text = text
	print("[launcher] " + text)
