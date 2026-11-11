shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D pattern:filter_nearest,repeat_enable;
uniform vec4 params=vec4(0.8,0.1,0.04,0.0);
uniform float material_rough=0.15;
varying vec3 shared_normal;
void vertex(){shared_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
vec3 direct(vec3 n, vec3 l, vec3 radiance, vec3 albedo, float metal, float rough) {
 vec3 v=vec3(0.0,0.0,1.0);vec3 h=normalize(v+l);
 float nv=max(dot(n,v),0.0001);float nl=max(dot(n,l),0.0);float nh=max(dot(n,h),0.0);float vh=max(dot(v,h),0.0);
 float a=rough*rough;float a2=a*a;float d0=nh*nh*(a2-1.0)+1.0;float d=a2/(3.14159265359*d0*d0);
 float k=(rough+1.0)*(rough+1.0)/8.0;float geom=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
 vec3 f0=mix(vec3(0.04),albedo,metal);vec3 f=f0+(vec3(1.0)-f0)*pow(1.0-vh,5.0);
 vec3 spec=d*geom*f/max(4.0*nv*nl,0.0001);vec3 diffuse=(vec3(1.0)-f)*(1.0-metal)*albedo/3.14159265359;
 return (diffuse+spec)*radiance*nl;
}
vec3 pbr(vec3 n0, vec3 albedo, float metal, float rough) {
 vec3 n=normalize(n0);vec3 color=0.02*albedo*(1.0-metal);
 color+=direct(n,normalize(vec3(-0.4,0.6,0.7)),vec3(3.0,2.7,2.4),albedo,metal,rough);
 color+=direct(n,normalize(vec3(0.6,0.2,0.4)),vec3(0.6,0.8,1.0),albedo,metal,rough);
 return color/(color+vec3(1.0));
}

void fragment(){ALBEDO=pbr(shared_normal,texture(pattern,UV).rgb*params.rgb,params.a,material_rough);}
