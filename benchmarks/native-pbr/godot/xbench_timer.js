// xbench_timer.js - the one frame timer every engine in the cross-engine bench
// shares. It wraps requestAnimationFrame at page level, so "cpu_ms" means the
// same thing for Godot's wasm main loop, three.js and Babylon.js: milliseconds
// the main thread spends inside the animation-frame callback (the engine's
// whole per-frame CPU work, JS and wasm alike). "fps" is derived from the
// callback-to-callback interval and is capped by the display's refresh rate,
// so cpu_ms is the primary number; fps only says whether the cap was reached.
// Results are printed as XBENCH lines (for the console tap / bench harness)
// and painted into a DOM overlay so a phone shows them without devtools.
(function () {
	const nativeRaf = window.requestAnimationFrame.bind(window);
	let recording = false;
	let frames = 0, cbMs = 0, cbMax = 0, longFrames = 0;
	let lastStart = 0, intervals = 0, intervalMs = 0;
	let totalFrames = 0;
	// Neutral GPU timing. Each engine's own gpu_ms comes from different
	// timestamp plumbing and is not always comparable: three.js read 0.23 ms for
	// 1,536 lights while its forward path read 2.0 ms for 384. This measures
	// the same thing for every engine at the same layer: from the frame's first
	// queue.submit to the last onSubmittedWorkDone. It carries the browser's
	// round trip, so read it as a comparison, not as pure GPU time.
	let queueFirst = 0, queueLast = 0, queueMs = 0, queueFrames = 0;
	if (window.GPUQueue) {
		const submit = GPUQueue.prototype.submit;
		GPUQueue.prototype.submit = function (buffers) {
			const result = submit.call(this, buffers);
			if (recording) {
				const now = performance.now();
				if (queueFirst === 0) queueFirst = now;
				this.onSubmittedWorkDone().then(() => { queueLast = performance.now(); });
			}
			return result;
		};
	}
	window.requestAnimationFrame = function (cb) {
		return nativeRaf(function (t) {
			const t0 = performance.now();
			if (recording && queueFirst > 0 && queueLast > queueFirst) {
				queueMs += queueLast - queueFirst;
				queueFrames++;
			}
			queueFirst = 0;
			queueLast = 0;
			if (recording && lastStart > 0) {
				intervalMs += t0 - lastStart;
				intervals++;
			}
			lastStart = t0;
			cb(t);
			const d = performance.now() - t0;
			totalFrames++;
			if (recording) {
				frames++;
				cbMs += d;
				if (d > cbMax) cbMax = d;
				if (d > 16.7) longFrames++;
			}
		});
	};
	let hud = null;
	function ensureHud() {
		if (hud || !document.body) return;
		hud = document.createElement("pre");
		hud.id = "xbench-hud";
		hud.style.cssText = "position:fixed;left:8px;top:8px;margin:0;padding:6px 8px;z-index:99999;" +
			"font:12px/1.35 monospace;color:#fff;background:rgba(0,0,0,0.55);pointer-events:none;white-space:pre;";
		document.body.appendChild(hud);
	}
	if (document.body) ensureHud(); else document.addEventListener("DOMContentLoaded", ensureHud);
	window.__xbench = {
		begin() {
			recording = true;
			frames = 0; cbMs = 0; cbMax = 0; longFrames = 0;
			lastStart = 0; intervals = 0; intervalMs = 0;
			queueMs = 0; queueFrames = 0;
		},
		end() {
			recording = false;
			const iv = intervals > 0 ? intervalMs / intervals : 0;
			return {
				frames,
				cpu_ms: frames > 0 ? cbMs / frames : 0,
				cpu_max: cbMax,
				long_frames: longFrames,
				interval_ms: iv,
				fps: iv > 0 ? 1000 / iv : 0,
				queue_ms: queueFrames > 0 ? queueMs / queueFrames : 0,
			};
		},
		// extra: free-form "key=value" text the engine appends (gpu_ms, draws...).
		report(engine, n, extra) {
			const s = this.end();
			const line = "XBENCH engine=" + engine + " n=" + n +
				" fps=" + s.fps.toFixed(1) + " cpu_ms=" + s.cpu_ms.toFixed(2) +
				" cpu_max=" + s.cpu_max.toFixed(1) + " long=" + s.long_frames +
				" frames=" + s.frames + " queue_ms=" + s.queue_ms.toFixed(2) + (extra ? " " + extra : "");
			console.log(line);
			this.note(line);
			return s;
		},
		note(text) {
			ensureHud();
			if (hud) hud.textContent += text + "\n";
		},
		frames() { return totalFrames; },
		ready: true,
	};
})();
