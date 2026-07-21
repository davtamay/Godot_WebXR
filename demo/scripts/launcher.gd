extends Node3D

## The main menu as a 3D scene. The WebXR rig lives here, so the XR session (or
## the flat mouse / desktop simulator) is ALREADY running when you pick a scene -
## selecting a showcase is an XR->XR (or flat->flat) hand-off instead of a flat
## menu jumping cold into an XR scene (which left the session stuck). The menu is
## a 3D panel you click with the controller ray, a bare-hand ray, or the mouse.

# Curated "wow" showcase scenes - each consolidates a family of XR blocks. The
# individual demos still exist in the addons for focused reference.
const WORKSHOP := "res://addons/godot_xr_interaction_toolkit/samples/workshop_demo.tscn"
const CONTROLS := "res://addons/godot_xr_interaction_toolkit/samples/control_panel_demo.tscn"
const LOCOMOTION_ARENA := "res://addons/godot_xr_interaction_toolkit/samples/locomotion_playground_demo.tscn"
const PERCEPTION := "res://addons/godot_webxr_scene_understanding/samples/perception_managers_demo.tscn"
const GESTURE_STUDIO := "res://addons/godot_xr_hands/samples/gesture_playground_demo.tscn"
const BENCHMARK_SCENE := "res://addons/godot_blender_principled/samples/vr_stress_benchmark.tscn"

var _streamer: SceneStreamer
var _status: Label


func _ready() -> void:
	_streamer = SceneStreamer.new()
	add_child(_streamer)
	_streamer.status.connect(_on_status)

	var root: Control = $MenuPanel/Viewport/Root
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 44)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Godot WebXR Samples"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	vbox.add_child(title)

	_status = Label.new()
	_status.text = "choose a showcase"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_status)

	_add_button(vbox, "Workshop", "grab · throw · draw · shoot · spray", func() -> void:
		_streamer.open(WORKSHOP))
	_add_button(vbox, "Controls", "buttons · sliders · dial · lever · drawer", func() -> void:
		_streamer.open(CONTROLS))
	_add_button(vbox, "Locomotion Arena", "teleport · anchors · climbing · smooth-move", func() -> void:
		_streamer.open(LOCOMOTION_ARENA))
	_add_button(vbox, "Perception", "room mesh · depth occlusion · light · anchors", func() -> void:
		_streamer.open(PERCEPTION))
	_add_button(vbox, "Gesture Studio", "record, name, and practice hand poses", func() -> void:
		_streamer.open(GESTURE_STUDIO))
	_add_button(vbox, "Performance", "VR stress benchmark", func() -> void:
		_streamer.open(BENCHMARK_SCENE))

	_add_renderer_chip(vbox)


func _add_button(parent: Node, name_text: String, desc_text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = name_text
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.tooltip_text = desc_text
	b.pressed.connect(on_press)
	parent.add_child(b)


## Renderer selector (web only): shown where WebGPU is actually available for XR
## (WebXRRenderer.webgpu_supported() -> false on stock/gl builds). Switching saves
## a preference and reloads - the graphics backend is a boot decision, since an
## HTML canvas is locked to its first getContext type.
func _add_renderer_chip(parent: Node) -> void:
	if not WebXRRenderer.webgpu_supported():
		return
	var active := WebXRRenderer.active()
	var head := Label.new()
	head.text = "Renderer: " + active.to_upper() + " — " + WebXRRenderer.coverage_note(active)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate = Color(1, 1, 1, 0.7)
	head.add_theme_font_size_override("font_size", 18)
	parent.add_child(head)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	for mode in ["webgl", "webgpu"]:
		var b := Button.new()
		b.text = mode.to_upper()
		b.disabled = (mode == active)
		b.custom_minimum_size = Vector2(120, 44)
		b.pressed.connect(_switch_renderer.bind(mode))
		row.add_child(b)


func _switch_renderer(mode: String) -> void:
	WebXRRenderer.switch_to(mode)


func _on_status(text: String) -> void:
	if _status:
		_status.text = text
	print("[launcher] " + text)
