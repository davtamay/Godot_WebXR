// Lightweight runtime timing helper for web export comparisons.
// Include this from a custom shell when benchmarking Godot, Unity, or a browser-native demo.
(function () {
  const metrics = {
    marks: {},
    frames: [],
    longFramesOver50ms: 0,
    startedAt: performance.now(),
  };

  let lastFrame = performance.now();
  let running = false;

  function mark(name) {
    metrics.marks[name] = performance.now();
    try { performance.mark(name); } catch (_) {}
  }

  function startFrameCapture() {
    if (running) return;
    running = true;
    lastFrame = performance.now();
    requestAnimationFrame(frame);
  }

  function stopFrameCapture() {
    running = false;
  }

  function frame(now) {
    const delta = now - lastFrame;
    lastFrame = now;
    metrics.frames.push(delta);
    if (delta > 50) metrics.longFramesOver50ms += 1;
    if (running) requestAnimationFrame(frame);
  }

  function percentile(values, p) {
    if (!values.length) return null;
    const sorted = values.slice().sort((a, b) => a - b);
    const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
    return sorted[index];
  }

  function report() {
    const frames = metrics.frames;
    const avgFrameMs = frames.length ? frames.reduce((a, b) => a + b, 0) / frames.length : null;
    return {
      marks: metrics.marks,
      frameCount: frames.length,
      avgFrameMs,
      avgFps: avgFrameMs ? 1000 / avgFrameMs : null,
      p95FrameMs: percentile(frames, 95),
      p99FrameMs: percentile(frames, 99),
      longFramesOver50ms: metrics.longFramesOver50ms,
      jsHeap: performance.memory ? {
        usedJSHeapSize: performance.memory.usedJSHeapSize,
        totalJSHeapSize: performance.memory.totalJSHeapSize,
        jsHeapSizeLimit: performance.memory.jsHeapSizeLimit,
      } : null,
      navigation: performance.getEntriesByType('navigation')[0] || null,
    };
  }

  window.CompanyRuntimeMetrics = {
    mark,
    startFrameCapture,
    stopFrameCapture,
    report,
  };

  mark('shell_script_loaded');
  window.addEventListener('load', () => mark('window_load'));
})();
