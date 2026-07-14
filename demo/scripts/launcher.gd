extends Control

## Bare-bones launcher: the tiny main scene the browser reaches first. Each
## button opens a WebXR sample scene on demand.

const BENCHMARK_SCENE := "res://addons/godot_blender_principled/samples/vr_stress_benchmark.tscn"
const TOOLKIT_SCENE := "res://scenes/Main.tscn"
const SCENE_UNDERSTANDING_SCENE := "res://addons/godot_webxr_scene_understanding/samples/scene_understanding_demo.tscn"
const LIGHT_ESTIMATION_SCENE := "res://addons/godot_webxr_scene_understanding/samples/light_estimation_demo.tscn"
const HIT_TEST_ANCHORS_SCENE := "res://addons/godot_webxr_scene_understanding/samples/hit_test_anchors_demo.tscn"
const GESTURE_DEMO := "res://addons/godot_xr_hands/samples/gesture_diagnostics_demo.tscn"
const MICROGESTURE_DEMO := "res://addons/godot_xr_hands/samples/microgesture_locomotion_demo.tscn"

var _streamer: SceneStreamer
var _status: Label

func _ready() -> void:
	_streamer = SceneStreamer.new()
	add_child(_streamer)
	_streamer.status.connect(_on_status)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	_add_button(vbox, "Light Estimation  (environment-matched PBR)", func() -> void:
		_streamer.open(LIGHT_ESTIMATION_SCENE))
	_add_button(vbox, "Hit Test + Anchors  (stable AR placement)", func() -> void:
		_streamer.open(HIT_TEST_ANCHORS_SCENE))
	_add_button(vbox, "Hand Gestures  (gesture diagnostics)", func() -> void:
		_streamer.open(GESTURE_DEMO))
	_add_button(vbox, "Micro-Gestures  (thumb-tap locomotion)", func() -> void:
		_streamer.open(MICROGESTURE_DEMO))

	_add_renderer_chip()

## Explicit renderer selector, top-right. Shown only where WebGPU is actually
## available for XR in this build (WebXRRenderer.webgpu_supported() -> false on
## stock/gl builds and on browsers without WebGPU-XR). Switching saves a
## preference and reloads: the graphics backend is a boot decision, since an
## HTML canvas is locked to its first getContext type.
func _add_renderer_chip() -> void:
	if not WebXRRenderer.webgpu_supported():
		return
	var active := WebXRRenderer.active()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -300.0
	box.offset_top = 12.0
	box.offset_right = -12.0
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var head := Label.new()
	head.text = "Renderer: " + active.to_upper()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(head)

	var note := Label.new()
	note.text = WebXRRenderer.coverage_note(active)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(288, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	for mode in ["webgl", "webgpu"]:
		var b := Button.new()
		b.text = mode.to_upper()
		b.disabled = (mode == active)
		b.custom_minimum_size = Vector2(96, 40)
		b.pressed.connect(_switch_renderer.bind(mode))
		row.add_child(b)

func _switch_renderer(mode: String) -> void:
	WebXRRenderer.switch_to(mode)

func _add_button(parent: Node, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 56)
	b.pressed.connect(on_press)
	parent.add_child(b)

func _on_status(text: String) -> void:
	_status.text = text
	print("[launcher] " + text)
