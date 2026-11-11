fn direct(n:vec3f,l:vec3f,radiance:vec3f,albedo:vec3f,metal:f32,rough:f32)->vec3f {
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
