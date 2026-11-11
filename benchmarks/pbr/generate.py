from pathlib import Path
import math,json
r=Path('benchmarks/pbr');g=r/'godot'
v=[];n=[];uv=[];idx=[]
for j in range(17):
 for i in range(33):
  a=math.pi*j/16;b=2*math.pi*i/32;p=[math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b)]
  v.extend(round(x,8) for x in p);n.extend(round(x,8) for x in p);uv.extend([i/32,j/16])
for j in range(16):
 for i in range(32):
  a=j*33+i;b=a+33;idx.extend([a,b,a+1,a+1,b,b+1])
texture=[]
for y in range(16):
 for x in range(16):
  c=190 if (int(abs(x-7.5)//4)+int(abs(y-7.5)//4))%2 else 80;texture.extend([c,c,c,255])
m={'schema':1,'name':'canonical-textured-ggx-v1','width':1280,'height':720,'verticalSize':22,'near':.1,'far':100,'vertices':v,'normals':n,'uvs':uv,'indices':idx,'texture':texture,'materials':[[.8,.1,.04,0,.15],[.05,.3,.7,0,.5],[.7,.55,.2,1,.15],[.6,.6,.6,1,.65],[.08,.5,.15,.5,.35],[.5,.08,.3,0,.85]],'workloads':{}}
for count,cols,rows in [(24,6,4),(96,12,8),(384,24,16)]:
 gap=min(34/cols,19/rows)
 m['workloads'][str(count)]=[[round((i%cols-(cols-1)/2)*gap,6),round((i//cols-(rows-1)/2)*gap,6),0,round(gap*.36,6),i%6] for i in range(count)]
(g/'workload.json').write_text(json.dumps(m,separators=(',',':'))+'\n')
wgsl='''fn direct(n:vec3f,l:vec3f,radiance:vec3f,albedo:vec3f,metal:f32,rough:f32)->vec3f {
 let v=vec3f(0.0,0.0,1.0);let h=normalize(v+l);
 let nv=max(dot(n,v),0.0001);let nl=max(dot(n,l),0.0);let nh=max(dot(n,h),0.0);let vh=max(dot(v,h),0.0);
 let a=rough*rough;let a2=a*a;let d0=nh*nh*(a2-1.0)+1.0;let d=a2/(3.14159265359*d0*d0);
 let k=(rough+1.0)*(rough+1.0)/8.0;let geom=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
 let f0=mix(vec3f(0.04),albedo,metal);let f=f0+(vec3f(1.0)-f0)*pow(1.0-vh,5.0);
 let spec=d*geom*f/max(4.0*nv*nl,0.0001);let diffuse=(vec3f(1.0)-f)*(1.0-metal)*albedo/3.14159265359;
 return (diffuse+spec)*radiance*nl;
}
fn pbr(n0:vec3f,albedo:vec3f,metal:f32,rough:f32)->vec3f {
 let n=normalize(n0);var color=0.02*albedo*(1.0-metal);
 color+=direct(n,normalize(vec3f(-0.4,0.6,0.7)),vec3f(3.0,2.7,2.4),albedo,metal,rough);
 color+=direct(n,normalize(vec3f(0.6,0.2,0.4)),vec3f(0.6,0.8,1.0),albedo,metal,rough);
 return color/(color+vec3f(1.0));
}
fn encodeSrgb(c:vec3f)->vec3f {return select(1.055*pow(c,vec3f(1.0/2.4))-vec3f(0.055),12.92*c,c<=vec3f(0.0031308));}
'''
(r/'pbr.wgsl').write_text(wgsl)
# Same scalar equations, with only language syntax and engine output transfer changed.
glsl=wgsl[:wgsl.index('fn encodeSrgb')]
import re
glsl=re.sub(r'fn (\w+)\((.*?)\)->vec3f',lambda m:'vec3 '+m[1]+'('+', '.join(re.sub(r'(\w+):(vec3f|f32)',lambda n:('vec3' if n[2]=='vec3f' else 'float')+' '+n[1],x) for x in m[2].split(','))+')',glsl)
glsl=glsl.replace('vec3f','vec3')
for name in ['v','h','f0','f','spec','diffuse','n','color']:
 glsl=re.sub(r'\b(let|var) '+name+'=', 'vec3 '+name+'=',glsl)
glsl=re.sub(r'\blet (\w+)=',r'float \1=',glsl)
(g/'pbr.gdshader').write_text('''shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D pattern:filter_nearest,repeat_enable;
uniform vec4 params=vec4(0.8,0.1,0.04,0.0);
uniform float material_rough=0.15;
varying vec3 shared_normal;
void vertex(){shared_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
'''+glsl+'\nvoid fragment(){ALBEDO=pbr(shared_normal,texture(pattern,UV).rgb*params.rgb,params.a,material_rough);}\n')
(g/'pbr.tres').write_text('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n[ext_resource type="Shader" path="res://pbr.gdshader" id="1"]\n[resource]\nshader=ExtResource("1")\n')
f=g/'main.tscn';f.write_text(Path('benchmarks/matched/godot/main.tscn').read_text().replace('res://white.tres','res://pbr.tres'))
f=g/'main.gd';s=Path('benchmarks/matched/godot/main.gd').read_text().replace('|| 100','|| 24').replace('var count := 100','var count := 24')
s=s.replace('arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(config.indices)','''arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(config.indices)
 var normals := PackedVector3Array()
 for i in range(0,config.normals.size(),3):
  normals.append(Vector3(config.normals[i],config.normals[i+1],config.normals[i+2]))
 arrays[Mesh.ARRAY_NORMAL]=normals
 var uvs := PackedVector2Array()
 for i in range(0,config.uvs.size(),2):
  uvs.append(Vector2(config.uvs[i],config.uvs[i+1]))
 arrays[Mesh.ARRAY_TEX_UV]=uvs''')
s=s.replace('var material := preload("res://white.tres")\n mesh.surface_set_material(0, material)','''var image := Image.create_from_data(16,16,false,Image.FORMAT_RGBA8,PackedByteArray(config.texture))
 var texture := ImageTexture.create_from_image(image)
 var materials: Array[ShaderMaterial]=[]
 for spec in config.materials:
  var material: ShaderMaterial=preload("res://pbr.tres").duplicate()
  material.set_shader_parameter("params",Vector4(spec[0],spec[1],spec[2],spec[3]))
  material.set_shader_parameter("material_rough",spec[4])
  material.set_shader_parameter("pattern",texture)
  materials.append(material)''')
s=s.replace('item.mesh = mesh','item.mesh = mesh\n  item.material_override=materials[int(p[4])]')
s=s.replace('RenderingServer.viewport_set_measure_render_time(viewport_rid, true)','RenderingServer.viewport_set_measure_render_time(viewport_rid, false)')
s=s[:s.index('func _frame()')]+'''func _frame() -> void:
 frame+=1
 js.benchTick(frame,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
'''
s=s.replace('"gpu_scope":"Godot viewport timestamp interval; asynchronously returned latest sample", "cpu_scope":"viewport CPU plus frame setup; excludes script/update"','"gpu_scope":"shared queue-submit wrapper", "cpu_scope":"renderer-process CPU including worker threads"')
f.write_text(s.replace("Color.BLACK","Color(1,0,1,1)"))
f=g/'shell.html';s=Path('benchmarks/matched/godot/shell.html').read_text();s=s.replace('window.benchFrame=s=>{bench.ready=true;if(bench.collecting)bench.frames.push(JSON.parse(s));};','window.benchTick=(frame,draws)=>{bench.ready=true;if(bench.collecting)bench.frames.push({frame,draws});};');f.write_text(s)
