// Drives the real scene interaction chain through the installed XR Operator.
// This is desktop behavior evidence, not WebXR/WebGPU hardware certification.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const operator = process.env.GODOT_XR_OPERATOR;
if (!operator || !process.argv[2]) {
    throw Error('Set GODOT_XR_OPERATOR to the operator directory and pass an output JSON path.');
}
const { CASES, makeValidateTool } = await import(pathToFileURL(path.join(operator, 'validate.mjs')));
const { driveSession } = await import(pathToFileURL(path.join(operator, 'drive.mjs')));
const selected = CASES.filter(c => !process.argv[3] || c.name.includes(process.argv[3]));
if (!selected.length) throw Error('No matching interaction cases');
const plans = [];
for (const c of selected) {
    const plan = await driveSession({ scene: c.scene, actions: c.actions, dry_run: true });
    plans.push({ case: c.name, plan });
    if (!plan.ok) throw Error(`Invalid drive ${c.name}: ${JSON.stringify(plan)}`);
}
let index = 0;
if (process.argv.includes('--negative-controls')) {
    const controls = [];
    for (const c of selected.filter(candidate => candidate.control)) {
        const actions = c.control(c.actions);
        const plan = await driveSession({ scene: c.scene, actions, dry_run: true });
        if (!plan.ok) throw Error(`Invalid control ${c.name}`);
        const result = await driveSession({ scene: c.scene, actions, fixed_fps: 60, timeout_seconds: 120 });
        const events = result.events || [];
        const rejected = c.expect.some(signal => !events.join(' ').includes(signal)) || Boolean(c.assert?.(events));
        controls.push({ case: c.name, passed: result.connected === true && result.applied != null && rejected, events });
        console.log(`${controls.at(-1).passed ? 'PASS' : 'FAIL'} negative control: ${c.name}`);
    }
    fs.writeFileSync(path.resolve(process.argv[2]), JSON.stringify({ evidence: 'desktop-operator-negative-controls', controls }, null, 2));
    process.exit(controls.length && controls.every(control => control.passed) ? 0 : 1);
}
const result = await makeValidateTool(async args => {
    console.error(`Driving ${++index}/${selected.length}: ${selected[index - 1].name}`);
    return driveSession(args);
}).run({ only: process.argv[3], fixed_fps: 60 });
const report = { evidence: 'desktop-operator-interaction-chain', captured_at: new Date().toISOString(), plans, ...result };
const output = path.resolve(process.argv[2]);
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(report, null, 2));
console.log(result.verdict);
process.exit(result.failed || result.tracked_gaps || result.total !== selected.length ? 1 : 0);
