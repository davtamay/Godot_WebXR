# Decision Log

Record decisions and pivots here. Do not silently change direction without documenting why.

| Date | Decision | Reason | Evidence | Alternatives Considered | Owner | Follow-up |
|---|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## 2026-07-02 - XR Interaction As A Pure-GDScript Addon

Decision: implement XRITK-style interaction as
`addons/godot_xr_interaction_toolkit/` using pure GDScript, `class_name`
runtime classes, and an optional editor plugin. No engine modules, custom
export templates, or renderer/backend changes are part of this phase.

Reason: an engine module would force custom editor and export-template builds
for every consumer, which breaks drop-in reuse. The first deliverable only needs
scene-level interaction logic, ray selection, WebXR input adaptation, visuals,
and grab movement. Input adapters isolate WebXR from future OpenXR support, so
interaction logic ports by swapping one node.

Evidence: the demo scene now consumes addon APIs only, the old prototype ray
script was removed, the headless suite reports 65 checks and 0 failures, and the
Godot 4.7 Web export to `demo/build/web47/index.html` exits 0.
