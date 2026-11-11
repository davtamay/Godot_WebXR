extends Node3D
# Cross-engine benchmark, Godot leg. Mirrors xbench/common/xbench_scene.js
# EXACTLY (same mulberry32 stream, same draw order per object, same lights,
# camera, tonemap, MSAA, shadow size) so the three engines render the same
# scene. Per ramp step the first N objects are visible; after WARM_MS the
# page-level timer (xbench_timer.js, shared by every engine) records CPU ms
# per frame for MEASURE_MS, and this script adds the viewport's measured GPU
# time and the draw-call count. Results print as XBENCH lines and paint into
# the DOM overlay (phones have no console). ?n=2000 runs a single step.
const SEED := 1337
const MAX_N := 8000
const RAMP := [500, 1000, 2000, 4000, 8000]
const WARM_MS := 3000.0
const MEASURE_MS := 6000.0
const CAM_RADIUS := 24.0
const CAM_HEIGHT := 10.0
const CAM_SPEED := 0.12
const MATERIALS := [
	[Color(0.85, 0.25, 0.20), 0.0, 0.30], [Color(0.90, 0.60, 0.20), 1.0, 0.37],
	[Color(0.85, 0.85, 0.25), 0.0, 0.44], [Color(0.30, 0.80, 0.30), 1.0, 0.51],
	[Color(0.25, 0.70, 0.85), 0.0, 0.58], [Color(0.30, 0.40, 0.90), 1.0, 0.65],
	[Color(0.70, 0.35, 0.85), 0.0, 0.72], [Color(0.90, 0.90, 0.90), 1.0, 0.79],
]
const FLOOR_MATERIAL := [Color(0.45, 0.45, 0.47), 0.0, 0.9]
# One baked material; the eight variants only change uniforms (bake-safe on WebGPU).
const BASE_MATERIAL: StandardMaterial3D = preload("res://xbench_material.tres")

var _state: int = SEED
var _objects: Array[MeshInstance3D] = []
var _camera: Camera3D
var _angle := 0.0
var _ramp: Array = []
var _step := -1
var _phase := 0 # 0 waiting for the engine to settle, 1 warm, 2 measure, 3 done
var _phase_ms := 0.0
var _boot_ms := 0.0
var _gpu_accum := 0.0
var _gpu_samples := 0
var _draws_last := 0
var _web := false
var _unique := false # every object its own material: defeats mesh+material draw merging
var _timer_ready := false
var _label: Label

# Mirrors uniqueMaterial(i) in xbench_scene.js: golden-ratio hue, HSV(h, 0.6, 0.9).
func _unique_material(i: int) -> StandardMaterial3D:
	var mat: StandardMaterial3D = BASE_MATERIAL.duplicate()
	mat.albedo_color = Color.from_hsv(fmod(i * 0.6180339887, 1.0), 0.6, 0.9)
	mat.metallic = float(i % 2)
	mat.roughness = 0.3 + 0.5 * float((i * 7) % 13) / 13.0
	return mat

func _rand() -> float:
	_state = (_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _imul(_state ^ (_state >> 15), _state | 1)
	t = ((t + _imul(t ^ (t >> 7), t | 61)) ^ t) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

func _imul(a: int, b: int) -> int: # Math.imul on unsigned 32-bit values
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	var al := a & 0xFFFF
	var bl := b & 0xFFFF
	return ((al * bl) + ((((a >> 16) * bl + al * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

func _ready() -> void:
	_web = OS.has_feature("web")
	var probe := PackedStringArray()
	for i in 5:
		probe.append("%.6f" % _rand())
	print("XBENCH prng ", " ".join(probe))
	_state = SEED
	get_viewport().msaa_3d = Viewport.MSAA_4X
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_ramp = RAMP.duplicate()
	var n_arg := ""
	if _web:
		var search: String = str(JavaScriptBridge.eval("window.location.search", true))
		var i := search.find("n=")
		if i >= 0 and (i == 1 or search[i - 1] == "&"):
			n_arg = search.substr(i + 2)
			var e := n_arg.find("&")
			if e >= 0:
				n_arg = n_arg.substr(0, e)
		_unique = search.find("unique=1") >= 0
		JavaScriptBridge.eval("var s=document.createElement('script');s.src='xbench_timer.js';document.head.appendChild(s);", true)
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("n="):
				n_arg = a.substr(2)
			elif a == "unique=1":
				_unique = true
	if n_arg.is_valid_int():
		_ramp = [int(n_arg)]
	_build()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_label)
	_note("godot %s %s" % [Engine.get_version_info().string, RenderingServer.get_video_adapter_api_version()])
	_note("prng " + " ".join(probe))

func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.near = 0.1
	_camera.far = 200.0
	add_child(_camera)
	_camera.current = true
	_orbit(0.0)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	sun.look_at_from_position(Vector3(15, 30, 9), Vector3(0, 0, 0), Vector3.UP) # dir (-0.5, -1, -0.3)
	var mats: Array[StandardMaterial3D] = []
	for m in MATERIALS:
		mats.append(_material(m))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = _material(FLOOR_MATERIAL)
	add_child(floor_inst)
	for j in 4:
		for i in 4:
			var l := OmniLight3D.new()
			l.position = Vector3(-13.5 + 9.0 * i, 3.0, -13.5 + 9.0 * j)
			l.light_color = MATERIALS[(i + j * 4) % 8][0]
			l.omni_range = 9.0
			l.light_energy = 2.0
			add_child(l)
	var box := BoxMesh.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 12
	var meshes := [box, sphere, torus]
	for k in MAX_N:
		var kind := int(floor(_rand() * 3.0))
		var x := (_rand() - 0.5) * 36.0
		var z := (_rand() - 0.5) * 36.0
		var s := 0.4 + _rand() * 0.8
		var ry := _rand() * 6.283185307
		var mat := int(floor(_rand() * 8.0))
		var inst := MeshInstance3D.new()
		inst.mesh = meshes[kind]
		inst.material_override = _unique_material(k) if _unique else mats[mat]
		inst.position = Vector3(x, s * 0.5, z)
		inst.rotation = Vector3(0, ry, 0)
		inst.scale = Vector3(s, s, s)
		inst.visible = false
		add_child(inst)
		_objects.append(inst)

func _material(m: Array) -> StandardMaterial3D:
	var mat: StandardMaterial3D = BASE_MATERIAL.duplicate()
	mat.albedo_color = m[0]
	mat.metallic = m[1]
	mat.roughness = m[2]
	return mat

func _orbit(delta: float) -> void:
	_angle += CAM_SPEED * delta
	_camera.look_at_from_position(Vector3(sin(_angle) * CAM_RADIUS, CAM_HEIGHT, cos(_angle) * CAM_RADIUS), Vector3(0, 1, 0), Vector3.UP)

func _note(text: String) -> void:
	if _web:
		JavaScriptBridge.eval("window.__xbench && window.__xbench.note(%s)" % JSON.stringify(text), true)
	_label.text += text + "\n"

func _process(delta: float) -> void:
	_orbit(delta)
	var ms := delta * 1000.0
	if _phase == 0:
		_boot_ms += ms
		if _web:
			if not _timer_ready:
				_timer_ready = bool(JavaScriptBridge.eval("!!(window.__xbench && window.__xbench.ready)", true))
			var pending = JavaScriptBridge.eval("typeof window.__godotWebGPUWarmPending === 'number' ? window.__godotWebGPUWarmPending : -1", true)
			var warm_done: bool = (pending is float or pending is int) and int(pending) == 0
			if _timer_ready and (warm_done or _boot_ms > 20000.0):
				_next_step()
		elif _boot_ms > 2000.0:
			_next_step()
		return
	if _phase == 3:
		return
	_phase_ms += ms
	if _phase == 1 and _phase_ms >= WARM_MS:
		_phase = 2
		_phase_ms = 0.0
		_gpu_accum = 0.0
		_gpu_samples = 0
		if _web:
			JavaScriptBridge.eval("window.__xbench.begin()", true)
		return
	if _phase == 2:
		_gpu_accum += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		_gpu_samples += 1
		_draws_last = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		if _phase_ms >= MEASURE_MS:
			var gpu_ms := _gpu_accum / maxf(_gpu_samples, 1.0)
			var n: int = _ramp[_step]
			var extra := "gpu_ms=%.2f draws=%d res=%dx%d mode=%s" % [gpu_ms, _draws_last, get_viewport().size.x, get_viewport().size.y, "unique" if _unique else "batch"]
			if _web:
				JavaScriptBridge.eval("window.__xbench.report('godot', %d, %s)" % [n, JSON.stringify(extra)], true)
			else:
				var line := "XBENCH engine=godot-native n=%d fps=%.1f %s" % [n, Engine.get_frames_per_second(), extra]
				print(line)
				_label.text += line + "\n"
			_next_step()

func _next_step() -> void:
	_step += 1
	if _step >= _ramp.size():
		_phase = 3
		print("XBENCH DONE")
		_note("XBENCH DONE")
		return
	var n: int = _ramp[_step]
	for i in _objects.size():
		_objects[i].visible = i < n
	_phase = 1
	_phase_ms = 0.0
