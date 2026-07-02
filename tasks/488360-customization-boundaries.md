# 488360 — Identify Customization Potential for Custom Web Exports

## Goal

Identify what can be customized in Godot web exports without modifying Godot core.

## Scope

Investigate:

- WebGL2 web export
- WebXRInterface
- JavaScriptBridge
- custom HTML shell
- editor plugins
- GDExtension
- C++ modules
- custom export templates
- WebGPU capability detection
- graphics-quality improvements
- existing repos/plugins/examples/forks/proposals

## Non-goals

- Do not implement a WebGPU renderer.
- Do not modify Godot source.
- Do not create a long-lived fork.
- Do not begin migration from Unity.

## Deliverables

- `docs/CUSTOMIZATION_MATRIX.md`
- `docs/EVIDENCE_LOG.md`
- `research/existing_repos_inventory.md`
- `research/godot_source_map.md`
- `docs/WEBGPU_BOUNDARY_NOTE.md`
- next-step recommendation

## Acceptance criteria

- We know which features can be done without source modification.
- We know which features require custom export templates or modules.
- We know which features require true renderer/source work.
- We have identified existing work to reuse.
- No unsupported claims about WebGPU rendering are made.
