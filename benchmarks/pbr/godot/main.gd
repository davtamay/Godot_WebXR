extends Node3D
var frame := 0
var last_usec := 0
var count := 24
var viewport_rid: RID
var js: JavaScriptObject
func _ready() -> void:
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://workload.json"))
 count = int(JavaScriptBridge.eval("new URLSearchParams(location.search).get('count') || 24"))
 var positions: Array = config.workloads[str(count)]
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 var vertices := PackedVector3Array()
 for i in range(0, config.vertices.size(), 3):
  vertices.append(Vector3(config.vertices[i], config.vertices[i+1], config.vertices[i+2]))
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(config.indices)
 var normals := PackedVector3Array()
 for i in range(0,config.normals.size(),3):
  normals.append(Vector3(config.normals[i],config.normals[i+1],config.normals[i+2]))
 arrays[Mesh.ARRAY_NORMAL]=normals
 var uvs := PackedVector2Array()
 for i in range(0,config.uvs.size(),2):
  uvs.append(Vector2(config.uvs[i],config.uvs[i+1]))
 arrays[Mesh.ARRAY_TEX_UV]=uvs
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var image := Image.create_from_data(16,16,false,Image.FORMAT_RGBA8,PackedByteArray(config.texture))
 var texture := ImageTexture.create_from_image(image)
 var materials: Array[ShaderMaterial]=[]
 for spec in config.materials:
  var material: ShaderMaterial=preload("res://pbr.tres").duplicate()
  material.set_shader_parameter("params",Vector4(spec[0],spec[1],spec[2],spec[3]))
  material.set_shader_parameter("material_rough",spec[4])
  material.set_shader_parameter("pattern",texture)
  materials.append(material)
 for p in positions:
  var item := MeshInstance3D.new()
  item.mesh = mesh
  item.material_override=materials[int(p[4])]
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
 environment.environment.background_color = Color(1,0,1,1)
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 add_child(environment)
 viewport_rid = get_viewport().get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
 js = JavaScriptBridge.get_interface("window")
 var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://xr_build_provenance.json"))
 js.benchMetadata(JSON.stringify({"engine":"godot", "version":Engine.get_version_info(), "provenance":provenance, "count":count, "gpu_scope":"shared queue-submit wrapper", "cpu_scope":"renderer-process CPU including worker threads"}))
 RenderingServer.frame_post_draw.connect(_frame)
func _frame() -> void:
 frame+=1
 js.benchTick(frame,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
