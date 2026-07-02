# Claude/Fable Instructions: Godot WebXR / Web Export Feasibility

## Mission

Evaluate Godot 4.7 as an open-source alternative to Unity for browser-native WebGL2/WebXR delivery and future WebGPU readiness.

The goal is not to fork Godot immediately. The goal is to determine how much can be achieved through stock Godot, editor plugins, project code, a custom web shell, JavaScriptBridge, GDExtension, C++ modules, and custom export templates before considering core source modification.

## Hard boundary

Do not claim Godot renders through WebGPU unless source-level evidence proves it.

For Phase 1, assume:

- Godot web export uses WebAssembly + WebGL2.
- Godot web export uses the Compatibility renderer.
- WebGPU is a strategic requirement to investigate, not a Phase 1 rendering target.
- WebGPU capability detection is not renderer support.

## Architecture preference

Use the lowest-risk layer that solves the problem:

1. Project code
2. Editor plugin
3. Custom HTML shell
4. JavaScriptBridge
5. GDExtension
6. C++ module
7. Custom export template
8. Minimal core source patch

Do not modify Godot source unless you can explain why the higher layers cannot solve the problem.

## Required workflow

Before implementation:

1. Inventory existing repos, plugins, examples, forks, and proposals.
2. Check official Godot docs and source.
3. Identify reusable existing work.
4. Produce a customization matrix.
5. Produce a source-modification boundary list.

During implementation:

1. Keep diffs minimal.
2. Do not introduce renderer/backend work in Phase 1.
3. Use stock Godot first.
4. Use the Compatibility renderer.
5. Build a WebGL2/WebXR demo.
6. Add WebGPU feature detection only as a browser capability probe.

## Stop conditions

Stop and ask for review if:

- A task appears to require Godot source modification.
- A task appears to require renderer/backend changes.
- WebGPU rendering is requested.
- Existing ecosystem work already solves the problem.
- The implementation would create a long-lived fork.
- The evidence conflicts with this spec.

## Required output format

For research tasks, return:

- finding
- evidence/source
- file path or repo link
- implementation layer
- reuse potential
- risk level
- recommendation

For implementation tasks, return:

- summary
- files changed
- how to run
- how to test
- known limitations
- what was intentionally not done
- next smallest step

## Spec challenge / innovation mode

The spec is a baseline, not a prison. You are explicitly encouraged to find a better conclusion, better architecture, better implementation path, cheaper maintenance model, stronger benchmark, or existing ecosystem project that changes the recommendation.

Read `docs/SPEC_CHALLENGE_PROTOCOL.md` before beginning research or implementation.

When you find a better idea, do not silently change the implementation. Create a proposal using the Spec Challenge Proposal format and add it to the relevant docs or task response.

You may challenge:

- whether Godot is the best tradeoff
- whether WebGL2/WebXR is sufficient
- whether the demo scope is right
- whether a browser-native WebGPU engine should be paired with or replace Godot
- whether GDExtension, C++ modules, or custom export templates are worth the maintenance cost
- whether a different test or benchmark would produce better evidence

You may not silently override:

- no false WebGPU renderer claims
- no Phase 1 renderer/backend work
- no Phase 1 source modifications without approval
- no skipping evidence and ecosystem inventory
- no hiding maintenance, performance, build-size, hosting, or rebase costs

For every major recommendation, include:

1. Blue-team case: why it could work.
2. Red-team case: why it could fail.
3. Evidence required to decide.
4. Smallest prototype that would prove or disprove it.

Maintain:

- `docs/INNOVATION_BACKLOG.md`
- `docs/DECISION_LOG.md`
