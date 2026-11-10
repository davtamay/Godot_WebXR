extends Node3D
var frame := 0
var last_usec := 0
var count := 100
var viewport_rid: RID
var js: JavaScriptObject
func _ready() -> void:
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://workload.json"))
 count = int(JavaScriptBridge.eval("new URLSearchParams(location.search).get('count') || 100"))
 var positions: Array = config.workloads[str(count)]
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 var vertices := PackedVector3Array()
 for i in range(0, config.vertices.size(), 3):
  vertices.append(Vector3(config.vertices[i], config.vertices[i+1], config.vertices[i+2]))
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(config.indices)
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var material := preload("res://white.tres")
 mesh.surface_set_material(0, material)
 for p in positions:
  var item := MeshInstance3D.new()
  item.mesh = mesh
  item.position = Vector3(p[0],p[1],p[2])
  item.scale = Vector3.ONE * p[3]
  item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(item)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = config.verticalSize
 camera.near = config.near
 camera.far = config.far
 camera.position = Vector3(0,0,30)
 add_child(camera)
 camera.current = true
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color.BLACK
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 add_child(environment)
 viewport_rid = get_viewport().get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
 js = JavaScriptBridge.get_interface("window")
 var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://xr_build_provenance.json"))
 js.benchMetadata(JSON.stringify({"engine":"godot", "version":Engine.get_version_info(), "provenance":provenance, "count":count, "gpu_scope":"Godot viewport timestamp interval; asynchronously returned latest sample", "cpu_scope":"viewport CPU plus frame setup; excludes script/update"}))
 RenderingServer.frame_post_draw.connect(_frame)
func _frame() -> void:
 var now := Time.get_ticks_usec()
 frame += 1
 var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
 js.benchFrame(JSON.stringify({"frame":frame,"frameMs":float(now-last_usec)/1000.0 if last_usec else 0.0,"cpuMs":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)+RenderingServer.get_frame_setup_time_cpu(),"gpuMs":gpu if gpu>=0 else null,"draws":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}))
 last_usec = now
