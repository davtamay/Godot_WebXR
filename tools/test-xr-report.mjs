import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync(new URL('../demo/web/adaptable_shell.html', import.meta.url), 'utf8');
const reportCode = html.slice(html.indexOf('// P0 report schema'), html.indexOf('// Renderer preference'));
const selectionCode = html.slice(html.indexOf('async function configureRenderer'), html.indexOf('(async function ()'));

function harness(query = '', saved = '', gpu = true, immersive = true) {
    const handlers = {};
    const element = () => ({ style: {}, appendChild() {}, click() {} });
    const context = vm.createContext({
        URL, URLSearchParams, Date, JSON, console,
        setTimeout: (callback, ms) => ms === 1500 ? 0 : callback(),
        location: { origin: 'https://example.test', pathname: '/', search: query },
        navigator: { userAgent: 'test', gpu: gpu ? {} : undefined, xr: { isSessionSupported: async () => immersive } },
        localStorage: { getItem: () => saved },
        document: { createElement: element, body: element(), getElementById: () => element() },
        GODOT_CONFIG: { experimentalWebGPU: true },
    });
    context.window = context;
    context.addEventListener = (name, callback) => { handlers[name] = callback; };
    vm.runInContext(reportCode + '\n' + selectionCode, context);
    return {
        context,
        evaluate: (code) => vm.runInContext(code, context),
        event: (detail) => handlers['godot-xr-diagnostic']({ detail }),
    };
}

const test = harness('?renderer=webgpu', 'webgl');
await test.context.configureRenderer();
assert.equal(test.context.GODOT_CONFIG.experimentalWebGPU, true);
assert.equal(test.context.GODOT_CONFIG.requiresWebXR, true);
assert.equal(test.context.xrReportAssessment(), 'pending-runtime');
test.context.godotXRRuntimeReport(JSON.stringify({ driver: 'webgpu', engine: { hash: 'abc' }, build: { identity_complete: true, editor: { hash: 'abc' } } }));
assert.equal(test.context.xrReportAssessment(), 'pending-immersive-frame');
test.event({ type: 'requested', mode: 'immersive-vr' });
test.event({ type: 'started', binding: 'webgpu' });
assert.equal(test.context.xrReportAssessment(), 'pending-immersive-frame');
test.event({ type: 'frame', binding: 'webgpu', views: 2 });
assert.equal(test.context.xrReportAssessment(), 'immersive-path-observed');
assert.equal(test.context.xrReportSnapshot().provenance_complete, true);
test.event({ type: 'depth', status: 'ok', view_count: 2, valid_mask: 3, units: 'meters' });
assert.equal(test.context.xrReportSnapshot().sessions.at(-1).depth.valid_mask, 3);

test.event({ type: 'ended' });
assert.equal(test.context.xrReportAssessment(), 'immersive-path-observed');
test.event({ type: 'requested', mode: 'immersive-vr' });
assert.equal(test.context.xrReportAssessment(), 'pending-immersive-frame');
test.event({ type: 'started', binding: 'webgl' });
test.event({ type: 'frame', binding: 'webgl', views: 2 });
assert.equal(test.context.xrReportAssessment(), 'failed-binding-mismatch');
test.context.godotXRRuntimeReport(JSON.stringify({ driver: 'opengl3', engine: { hash: 'old' }, build: { identity_complete: true, editor: { hash: 'abc' } } }));
assert.equal(test.context.xrReportAssessment(), 'failed-renderer-mismatch');
assert.equal(test.context.xrReportSnapshot().provenance_complete, false);
test.event({ type: 'failure', message: 'denied' });
assert.equal(test.context.xrReportAssessment(), 'failed');

const automatic = harness('?renderer=auto', 'webgpu');
await automatic.context.configureRenderer();
assert.equal(automatic.context.GODOT_CONFIG.experimentalWebGPU, false);
const webgl = harness('?renderer=webgl');
await webgl.context.configureRenderer();
assert.equal(webgl.context.GODOT_CONFIG.experimentalWebGPU, false);
const flat = harness('', '', true, false);
await flat.context.configureRenderer();
assert.equal(flat.context.GODOT_CONFIG.experimentalWebGPU, true);
assert.equal(flat.context.GODOT_CONFIG.requiresWebXR, false);
await assert.rejects(harness('?renderer=webgpu', '', false).context.configureRenderer(), /cannot initialize/);
console.log('XR report and renderer selection regression checks passed');

// The in-app renderer switch must override an explicit test URL as well.
const switchSource = fs.readFileSync(new URL('../demo/addons/godot_webxr_kit/runtime/webxr_renderer.gd', import.meta.url), 'utf8');
const switchBody = switchSource.match(/var script := """([\s\S]+?)""" % \[PREF_KEY, mode, mode\]/)[1];
for (const storageBlocked of [false, true]) {
    let destination;
    const switchContext = vm.createContext({
        URL,
        localStorage: { setItem() { if (storageBlocked) throw new Error('blocked'); } },
        location: { href: 'https://example.test/index.html?renderer=webgpu&scene=workshop', replace(url) { destination = new URL(url); } },
    });
    vm.runInContext(switchBody.replace('%s', 'godot_renderer').replace('%s', 'webgl').replace('%s', 'webgl'), switchContext);
    assert.equal(destination.searchParams.get('renderer'), 'webgl');
    assert.equal(destination.searchParams.get('scene'), 'workshop');
}
console.log('In-app renderer switching regression checks passed');
