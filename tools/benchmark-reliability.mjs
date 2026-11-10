// Desktop screening, not an XR compositor or GPU frame-time benchmark.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { createRequire } from 'node:module';
import { parseArgs } from 'node:util';
import { createHash } from 'node:crypto';

const { values: o } = parseArgs({ options: {
    root: { type: 'string' }, out: { type: 'string' },
    channel: { type: 'string', default: 'chrome' },
    renderer: { type: 'string', default: 'webgpu' },
    threads: { type: 'boolean', default: false },
    seconds: { type: 'string', default: '120' },
    soak: { type: 'string', default: '1800' },
    repeats: { type: 'string', default: '5' },
    warmup: { type: 'string', default: '10' },
} });
if (!o.root || !o.out || !['webgpu', 'webgl'].includes(o.renderer)) {
    throw new Error('Required: --root EXPORT --out RESULT.json [--threads] [--renderer webgpu|webgl]');
}
for (const k of ['seconds', 'soak', 'repeats', 'warmup']) {
    o[k] = Number(o[k]);
    if (!Number.isFinite(o[k]) || o[k] < 1 || (k === 'repeats' && !Number.isInteger(o[k]))) throw new Error(`Invalid ${k}`);
}
const require = createRequire(path.join(process.env.GODOT_WEBGPU_TESTBED || process.cwd(), 'package.json'));
const { chromium } = require('playwright');
const root = fs.realpathSync(o.root), out = path.resolve(o.out);
fs.mkdirSync(path.dirname(out), { recursive: true });
const result = { schema: 1, started: new Date().toISOString(), configuration: o,
    harnessSha256: createHash('sha256').update(fs.readFileSync(new URL(import.meta.url))).digest('hex'),
    scope: 'headless desktop launcher screen; browser RAF cadence, not engine/GPU/XR frame time',
    comparativeRankingEligible: false,
    rankingExclusions: ['launcher workload', 'no matched competitor scene', 'no engine/GPU frame timing'],
    runs: [], errors: [], deviceLoss: { status: 'not-run' },
    unsupportedMetrics: ['GPU duration', 'XR compositor dropped frames', 'GPU memory', 'total process memory'],
    artifactHashes: {} };
for (const name of fs.readdirSync(root).filter(n => /\.(wasm|pck|js|html)$/.test(n))) {
    result.artifactHashes[name] = createHash('sha256').update(fs.readFileSync(path.join(root, name))).digest('hex');
}
const server = http.createServer((req, res) => {
    try {
        const name = decodeURIComponent(new URL(req.url, 'http://local').pathname);
        if (name === '/favicon.ico') { res.writeHead(204).end(); return; }
        const file = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
        if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404).end(); return; }
        const headers = { 'Cache-Control': 'no-store', 'Content-Type': { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm' }[path.extname(file)] || 'application/octet-stream' };
        if (o.threads) Object.assign(headers, { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
        res.writeHead(200, headers); fs.createReadStream(file).pipe(res);
    } catch { res.writeHead(400).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
const percentile = (a, p) => a.length ? [...a].sort((x, y) => x - y)[Math.ceil(a.length * p) - 1] : null;
const save = () => fs.writeFileSync(out, JSON.stringify(result, null, 2));
try {
    browser = await chromium.launch({ channel: o.channel });
    result.browserVersion = browser.version();
    const browserCdp = await browser.newBrowserCDPSession();
    const system = await browserCdp.send('SystemInfo.getInfo');
    result.gpu = { devices: system.gpu.devices, featureStatus: system.gpu.featureStatus };
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
    await context.addInitScript(() => {
        window.__screen = { devices: [], losses: [], intervals: [], longTasks: [], last: null, collecting: false };
        const s = window.__screen;
        if (typeof GPUAdapter !== 'undefined') {
            const original = GPUAdapter.prototype.requestDevice;
            GPUAdapter.prototype.requestDevice = async function (...args) {
                const device = await original.apply(this, args);
                s.devices.push(device);
                device.lost.then(info => s.losses.push({ reason: info.reason, message: info.message, at: performance.now() }));
                return device;
            };
        }
        function tick(t) {
            if (s.collecting && s.last !== null) s.intervals.push(t - s.last);
            s.last = s.collecting ? t : null;
            requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
        if (PerformanceObserver.supportedEntryTypes.includes('longtask')) new PerformanceObserver(list => {
            if (s.collecting) for (const e of list.getEntries()) s.longTasks.push({ start: e.startTime, duration: e.duration });
        }).observe({ type: 'longtask' });
    });
    const page = await context.newPage();
    let phase = 'startup';
    page.on('pageerror', e => result.errors.push({ phase, type: 'pageerror', message: String(e) }));
    page.on('crash', () => result.errors.push({ phase, type: 'crash', message: 'page crashed' }));
    page.on('console', m => {
        if (m.type() === 'error' || /GPUValidationError|Invalid CommandBuffer|SCRIPT ERROR/.test(m.text())) result.errors.push({ phase, type: m.type(), message: m.text() });
    });
    const url = `http://127.0.0.1:${server.address().port}/?renderer=${o.renderer}`;
    const boot = async () => {
        await page.goto(url, { waitUntil: 'domcontentloaded' });
        await page.waitForFunction(() => typeof xrReportSnapshot === 'function' && xrReportSnapshot().runtime, null, { timeout: 90000 });
        const info = await page.evaluate(() => ({ readyMs: performance.now(), report: xrReportSnapshot(), isolated: crossOriginIsolated, shared: typeof SharedArrayBuffer !== 'undefined' }));
        if (info.report.runtime.driver !== (o.renderer === 'webgpu' ? 'webgpu' : 'opengl3')) throw new Error('Renderer mismatch');
        if (info.isolated !== o.threads || info.shared !== o.threads) throw new Error('Thread hosting mismatch');
        if (info.report.runtime.build.options['variant/thread_support'] !== o.threads) throw new Error('Template thread mode mismatch');
        if (info.report.runtime.build.identity_complete !== true && !result.rankingExclusions.includes('incomplete build identity')) result.rankingExclusions.push('incomplete build identity');
        return info;
    };
    const cdp = await context.newCDPSession(page);
    await cdp.send('Performance.enable');
    const sample = async () => {
        const { metrics } = await cdp.send('Performance.getMetrics');
        const values = Object.fromEntries(metrics.map(m => [m.name, m.value]));
        return { at: Date.now(), jsHeapUsedBytes: values.JSHeapUsedSize, jsHeapTotalBytes: values.JSHeapTotalSize, nodes: values.Nodes, documents: values.Documents };
    };
    for (let i = 0; i <= o.repeats; i++) {
        phase = i < o.repeats ? `repeat-${i + 1}` : 'soak';
        const info = await boot();
        await page.waitForTimeout(o.warmup * 1000);
        await page.evaluate(() => { const s = window.__screen; s.intervals = []; s.longTasks = []; s.last = null; s.collecting = true; });
        const seconds = i < o.repeats ? o.seconds : o.soak, memory = [await sample()];
        const end = Date.now() + seconds * 1000;
        while (Date.now() < end) { await page.waitForTimeout(Math.min(5000, Math.max(1, end - Date.now()))); memory.push(await sample()); }
        const observed = await page.evaluate(() => { const s = window.__screen; s.collecting = false; return { intervals: s.intervals, longTasks: s.longTasks, losses: s.losses, visibility: document.visibilityState }; });
        const a = observed.intervals;
        result.runs.push({ phase, requestedSeconds: seconds, ...info, ...observed, memory,
            cadence: { samples: a.length, medianMs: percentile(a, .5), p95Ms: percentile(a, .95), p99Ms: percentile(a, .99), over50ms: a.filter(x => x > 50).length },
            heapChangeBytes: memory.at(-1).jsHeapUsedBytes - memory[0].jsHeapUsedBytes });
        if (!a.length || observed.losses.length) throw new Error('Missing animation samples or unexpected device loss');
        await page.screenshot({ path: out + `.${phase}.png` });
        save(); console.log(`${phase}: ${a.length} RAF samples; p95=${percentile(a, .95)?.toFixed(2)} ms`);
    }
    if (o.renderer === 'webgpu') {
        phase = 'injected-device-loss';
        const count = await page.evaluate(() => { const d = window.__screen.devices; d.forEach(x => x.destroy()); return d.length; });
        result.deviceLoss = { status: count ? 'injected' : 'unavailable', deviceCount: count };
        if (!count) throw new Error('Device destruction test unavailable: no captured GPU device');
        if (count) {
            await page.waitForTimeout(3000);
            result.deviceLoss.observed = await page.evaluate(() => ({ losses: window.__screen.losses, report: xrReportSnapshot() }));
            if (!result.deviceLoss.observed.losses.length) throw new Error('Device destruction produced no observed loss');
            // A responsive HTML shell is NOT evidence that the renderer recovered.
            result.deviceLoss.automaticRenderingRecovery = 'not-proven';
            phase = 'reload-after-loss';
            result.deviceLoss.reload = await boot();
            await page.waitForTimeout(3000);
            await page.screenshot({ path: out + '.after-loss-reload.png' });
            result.deviceLoss.status = 'reload-runtime-ready';
        }
    }
    const unexpected = result.errors.filter(e => e.phase !== 'injected-device-loss');
    result.status = unexpected.length ? 'failed' : 'screening-passed';
    if (unexpected.length) process.exitCode = 1;
} catch (e) {
    result.status = 'failed'; result.failure = String(e); process.exitCode = 1;
} finally {
    result.finished = new Date().toISOString(); save();
    await browser?.close(); await new Promise(resolve => server.close(resolve));
}
