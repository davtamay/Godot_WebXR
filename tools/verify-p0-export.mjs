import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { createRequire } from 'node:module';

// Set GODOT_WEBGPU_TESTBED to a folder containing Playwright's package.json.
const require = createRequire(path.join(process.env.GODOT_WEBGPU_TESTBED || process.cwd(), 'package.json'));
const { chromium } = require('playwright');
const root = path.resolve(process.argv[2]);
const logs = path.resolve(process.argv[3]);
fs.mkdirSync(logs, { recursive: true });
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png' };
const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === '/favicon.ico') {response.writeHead(204).end();return;}
    const file = path.resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
    if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
        response.writeHead(404).end();
        return;
    }
    const headers = { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' };
    if (process.env.XR_TEST_THREADS === '1') {
        headers['Cross-Origin-Opener-Policy'] = 'same-origin';
        headers['Cross-Origin-Embedder-Policy'] = 'require-corp';
    }
    response.writeHead(200, headers);
    fs.createReadStream(file).pipe(response);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ channel: 'chrome' });
try {
    for (const mode of ['webgpu', 'webgl']) {
        const page = await browser.newPage();
        const messages = [];
        page.on('console', message => messages.push(`[${message.type()}] ${message.text()}`));
        page.on('pageerror', error => messages.push(`[pageerror] ${error.message}`));
        try {
            await page.goto(`http://127.0.0.1:${server.address().port}/index.html?renderer=${mode}`, { waitUntil: 'domcontentloaded' });
            await page.waitForFunction(() => typeof XRReport !== 'undefined' && XRReport.runtime !== null, null, { timeout: 90000 });
            await page.waitForTimeout(5000);
            const report = await page.evaluate(() => xrReportSnapshot());
            if (process.env.XR_TEST_THREADS !== undefined) {
                const hosting = await page.evaluate(() => ({ isolated: crossOriginIsolated, shared: typeof SharedArrayBuffer !== 'undefined' }));
                assert.equal(hosting.isolated, process.env.XR_TEST_THREADS === '1');
                assert.equal(hosting.shared, process.env.XR_TEST_THREADS === '1');
            }
            fs.writeFileSync(path.join(logs, `desktop-${mode}-report.json`), JSON.stringify(report, null, 2));
            assert.equal(report.runtime.driver, mode === 'webgpu' ? 'webgpu' : 'opengl3');
            assert.equal(report.requested_renderer, mode);
            assert.equal(report.runtime.build.template_sha256.length, 64);
            assert.equal(report.runtime.build.editor_sha256.length, 64);
            assert.equal(report.runtime.build.suite.revision.length, 40);
            assert.equal(report.runtime.build.demo.revision.length, 40);
            assert.equal(report.path_assessment, 'pending-immersive-frame');
            await page.getByText('XR test report', { exact: true }).click();
            const downloaded = page.waitForEvent('download');
            await page.getByRole('button', { name: 'Download JSON report' }).click();
            const download = await downloaded;
            await download.saveAs(path.join(logs, `downloaded-${mode}-report.json`));
            const saved = JSON.parse(fs.readFileSync(path.join(logs, `downloaded-${mode}-report.json`), 'utf8'));
            assert.equal(saved.runtime.build.build_id, report.runtime.build.build_id);
            assert.equal(messages.some(line => line.startsWith('[pageerror]') || line.startsWith('[error]')), false, 'Engine/browser console error');
            await page.screenshot({ path: path.join(logs, `desktop-${mode}.png`) });
            console.log(`${mode}: runtime, manifest, pending XR state and JSON download verified`);
        } finally {
            fs.writeFileSync(path.join(logs, `desktop-${mode}.log`), messages.join('\n'));
            await page.close();
        }
    }
} finally {
    await browser.close();
    server.close();
}
