# 488363 — Identify Source Modification Potential While Preserving Future Godot Releases

## Goal

Map where source modification would be required and how to avoid fork debt.

## Scope

- Clone/read Godot source.
- Identify web export platform code.
- Identify WebXRInterface source paths.
- Identify JavaScriptBridge source paths.
- Identify Compatibility renderer/web backend boundaries.
- Identify export template build path.
- Identify GDExtension web-template requirements.
- Propose minimal-patch strategy.

## Non-goals

- Do not implement WebGPU.
- Do not change renderer code.
- Do not make speculative patches.

## Deliverables

- `research/godot_source_map.md`
- source modification boundary list
- custom export template build notes
- rebase strategy
- risk estimate

## Acceptance criteria

- We know where the relevant Godot source code lives.
- We know the likely renderer/backend boundary.
- We know what can be changed as module/export template versus core patch.
- We have a minimal-patch policy.
- We have a rebase/testing plan.
