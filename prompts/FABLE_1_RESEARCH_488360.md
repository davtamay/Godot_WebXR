# Fable Prompt — 488360 Research First

You are helping evaluate Godot as an open-source alternative to Unity for browser-native XR delivery.

Do not implement code yet.

## Goal

Identify what Godot can customize for web exports without modifying Godot core.

Focus on:

- WebGL2 web export
- WebXRInterface
- JavaScriptBridge
- custom HTML shell
- editor plugins
- GDExtension
- C++ modules
- custom export templates
- WebGPU feasibility
- graphics-quality improvements for web
- existing repos/plugins/examples/forks/proposals

## Required classification

For every capability, classify it as:

1. Project code
2. Editor plugin
3. Custom HTML shell
4. JavaScriptBridge
5. GDExtension
6. C++ module
7. Custom export template
8. Core source modification
9. Not currently practical

## Existing ecosystem inventory

For every repo/plugin/example, report:

- name
- link
- license
- latest activity
- supported Godot version
- implementation type
- what we can reuse
- what we should avoid
- risk level
- whether it helps WebGL, WebXR, WebGPU, graphics, export, tooling, or native XR

## Important boundary

Do not claim WebGPU rendering can be added to Godot through plugins or GDExtension unless the source evidence proves that Godot’s renderer can be routed through that extension point. Capability detection is not renderer support.

## Deliverables

1. Fill `docs/CUSTOMIZATION_MATRIX.md`.
2. Fill `docs/EVIDENCE_LOG.md`.
3. Fill `research/existing_repos_inventory.md`.
4. Fill `research/godot_source_map.md` at a high level.
5. Update `docs/WEBGPU_BOUNDARY_NOTE.md` with evidence.
6. Recommend the next smallest implementation task.

Additional comparison requirement:
Research the Unity Web baseline enough to define a fair comparison. Do not turn this into a Unity migration task, but document what Unity gives us that Godot may not:
- C# workflow
- WebGL build optimization settings
- package/build-size optimization options
- WebGPU experimental support if present in the installed/target Unity version
- XR/WebXR path and likely plugin/custom web shell needs
- performance/profiling advantages
- licensing/vendor-control disadvantages

Add findings to:
- docs/PERFORMANCE_BUILD_SIZE_PLAN.md
- docs/COST_TRADEOFFS.md if new evidence changes the tradeoff model


## Spec Challenge Protocol

Read `docs/SPEC_CHALLENGE_PROTOCOL.md`. You are encouraged to challenge the spec if you find a better, cheaper, more maintainable, more performant, or more honest path. Do not silently change scope. Produce a Spec Challenge Proposal with evidence, tradeoffs, maintenance impact, rebase impact, and smallest prototype. Maintain `docs/INNOVATION_BACKLOG.md` and `docs/DECISION_LOG.md` when relevant.

Hard boundaries remain: no false Godot WebGPU rendering claims, no Phase 1 renderer/backend work, no Phase 1 Godot source modifications without approval, and no skipping ecosystem inventory or benchmark evidence.
