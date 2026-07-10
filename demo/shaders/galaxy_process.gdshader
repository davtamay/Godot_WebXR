shader_type particles;
// Procedural spiral galaxy: every particle's position is computed each frame
// from its stable INDEX (no velocity integration), giving a deterministic
// three-arm disc with differential rotation - inner stars orbit faster, so
// the arms slowly wind and shear the way a real disc galaxy does.
render_mode disable_velocity;

uniform float radius = 2.2;
uniform float twist = 4.5;
uniform float rotation_speed = 0.03;
uniform float thickness = 0.22;
uniform float star_size = 0.016;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void start() {
	ACTIVE = true;
}

void process() {
	float idx = float(INDEX);
	// Radial density biased toward the core.
	float r01 = pow(hash(idx * 1.013 + 7.0), 0.65);
	float r = r01 * radius;
	// Three arms, wound by radius, with per-star scatter that widens outward.
	float arm = mod(idx, 3.0) / 3.0 * 6.2831853;
	float scatter = (hash(idx * 2.7 + 1.0) - 0.5) * (0.55 + 0.5 * r01);
	float angle = arm + r01 * twist + scatter + TIME * rotation_speed * (1.8 - r01);
	// A thin disc with a gently bulging core.
	float y = (hash(idx * 3.9 + 3.0) - 0.5) * thickness * (1.25 - r01);
	vec3 p = vec3(cos(angle) * r, y, sin(angle) * r);

	// Slowly cycling per-star rainbow softened toward warm white - the
	// palette of the original XRGPUBinding probe galaxy.
	float hue = fract(hash(idx * 4.2 + 2.0) + TIME * 0.015);
	vec3 rainbow = clamp(abs(fract(hue + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	vec3 color = mix(rainbow, vec3(1.0, 0.9, 0.75), 0.12);
	// Slow twinkle; brighter toward the core.
	float twinkle = 0.8 + 0.35 * sin(TIME * (0.6 + hash(idx * 6.1) * 2.2) + idx);
	float brightness = mix(1.2, 0.45, r01) * twinkle;
	COLOR = vec4(color * brightness, 1.0);

	float s = star_size * mix(1.5, 0.65, r01) * (0.7 + 0.6 * hash(idx * 8.1));
	TRANSFORM = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(p, 1.0));
}
