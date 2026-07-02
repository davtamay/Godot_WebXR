# Fable Prompt — 488363 Source Modification Map

Do this only after 488360 research is reviewed.

## Goal

Map Godot source boundaries for web export, WebXR, JavaScriptBridge, GDExtension web support, custom export templates, and renderer/WebGPU limitations.

## Do not implement changes

Read source, document boundaries, and propose where changes would live. Do not patch Godot source yet.

## Deliverables

- `research/godot_source_map.md`
- source paths for web export
- source paths for WebXRInterface
- source paths for JavaScriptBridge
- source paths for export templates
- build commands for stock web templates
- build commands for dlink/GDExtension web templates
- likely renderer/backend boundary for WebGPU
- minimal-patch strategy
- rebase risk estimate

## Required conclusion

Classify every possible modification as:

- no patch needed
- plugin/project code
- web shell/JavaScriptBridge
- GDExtension
- C++ module
- custom export template
- core patch
- upstream contribution candidate
- not practical this cycle


## Spec Challenge Protocol

Read `docs/SPEC_CHALLENGE_PROTOCOL.md`. You are encouraged to challenge the spec if you find a better, cheaper, more maintainable, more performant, or more honest path. Do not silently change scope. Produce a Spec Challenge Proposal with evidence, tradeoffs, maintenance impact, rebase impact, and smallest prototype. Maintain `docs/INNOVATION_BACKLOG.md` and `docs/DECISION_LOG.md` when relevant.

Hard boundaries remain: no false Godot WebGPU rendering claims, no Phase 1 renderer/backend work, no Phase 1 Godot source modifications without approval, and no skipping ecosystem inventory or benchmark evidence.
