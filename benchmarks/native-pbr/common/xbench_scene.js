// xbench_scene.js - the ONE scene description all engines build. Seeded, so
// Godot (which mirrors this in GDScript with the same mulberry32 stream) and
// the JS engines place the same objects with the same materials.
//
// Scene: a 40x40 floor; up to MAX_N objects (box / sphere / torus, one draw
// each, no instancing) scattered over 36x36 with random yaw and size; eight
// opaque PBR materials (uniform differences only); one white directional
// light with a 2048 shadow map; sixteen unshadowed coloured point lights on a
// 4x4 grid; ACES tonemapping; MSAA 4x; an orbiting camera.
export const SEED = 1337;
export const MAX_N = 8000;
export const RAMP = [500, 1000, 2000, 4000, 8000];
export const WARM_MS = 3000;
export const MEASURE_MS = 6000;
export const FLOOR_SIZE = 40;
export const CAMERA = { radius: 24, height: 10, target: [0, 1, 0], speed: 0.12, fov: 60, near: 0.1, far: 200 };
export const SUN = { dir: [-0.5, -1.0, -0.3], shadow_size: 2048 };
export const AMBIENT = 0.3;

export const MATERIALS = [
	{ color: [0.85, 0.25, 0.20], metallic: 0, roughness: 0.30 },
	{ color: [0.90, 0.60, 0.20], metallic: 1, roughness: 0.37 },
	{ color: [0.85, 0.85, 0.25], metallic: 0, roughness: 0.44 },
	{ color: [0.30, 0.80, 0.30], metallic: 1, roughness: 0.51 },
	{ color: [0.25, 0.70, 0.85], metallic: 0, roughness: 0.58 },
	{ color: [0.30, 0.40, 0.90], metallic: 1, roughness: 0.65 },
	{ color: [0.70, 0.35, 0.85], metallic: 0, roughness: 0.72 },
	{ color: [0.90, 0.90, 0.90], metallic: 1, roughness: 0.79 },
];
export const FLOOR_MATERIAL = { color: [0.45, 0.45, 0.47], metallic: 0, roughness: 0.9 };

export function mulberry32(a) {
	return function () {
		a |= 0;
		a = (a + 0x6D2B79F5) | 0;
		let t = Math.imul(a ^ (a >>> 15), 1 | a);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

// Six draws per object, in this order, so GDScript can mirror it exactly.
export function makeObjects(n = MAX_N, seed = SEED) {
	const r = mulberry32(seed);
	const out = [];
	for (let i = 0; i < n; i++) {
		const kind = Math.floor(r() * 3); // 0 box, 1 sphere, 2 torus
		const x = (r() - 0.5) * 36;
		const z = (r() - 0.5) * 36;
		const s = 0.4 + r() * 0.8;
		const ry = r() * 6.283185307;
		const mat = Math.floor(r() * 8);
		out.push({ kind, x, y: s * 0.5, z, s, ry, mat });
	}
	return out;
}

export function makeLights() {
	const out = [];
	for (let j = 0; j < 4; j++) {
		for (let i = 0; i < 4; i++) {
			const m = MATERIALS[(i + j * 4) % 8];
			out.push({ x: -13.5 + 9 * i, y: 3, z: -13.5 + 9 * j, color: m.color, range: 9 });
		}
	}
	return out;
}

export function urlParams() {
	const q = new URLSearchParams(window.location.search);
	const n = q.get("n");
	return { ramp: n ? [parseInt(n, 10)] : RAMP.slice(), unique: q.get("unique") === "1" };
}

// "unique" mode: every object gets its own material (a distinct colour), so
// no engine can merge identical mesh+material pairs into instanced draws and
// the per-draw CPU cost is measured directly. Golden-ratio hue, HSV(h, 0.6, 0.9).
export function uniqueMaterial(i) {
	const h = (i * 0.6180339887) % 1, s = 0.6, v = 0.9;
	const k = Math.floor(h * 6), f = h * 6 - k;
	const p = v * (1 - s), qq = v * (1 - s * f), t = v * (1 - s * (1 - f));
	const rgb = [[v, t, p], [qq, v, p], [p, v, t], [p, qq, v], [t, p, v], [v, p, qq]][k % 6];
	return { color: rgb, metallic: i % 2, roughness: 0.3 + 0.5 * ((i * 7) % 13) / 13 };
}

// First values of the stream, for the cross-engine PRNG identity check.
export function prngProbe(seed = SEED) {
	const r = mulberry32(seed);
	return [r(), r(), r(), r(), r()].map((v) => v.toFixed(6)).join(" ");
}
