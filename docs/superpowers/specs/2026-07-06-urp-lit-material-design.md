# URP-Lit-Compatible Material for Godot WebGL2 — Design

> **SUPERSEDED 2026-07-06** by
> `docs/superpowers/specs/2026-07-06-blender-godot-material-parity-design.md`.
> The target pivoted from Unity URP Lit to **Blender Principled BSDF parity**
> after the user confirmed their source models live in Blender and provided a
> prior Blender→Unity 1:1 pipeline to build on. Kept for the decision trail.

Status: superseded. Governed a new addon `addons/godot_urp_lit/` (not built).

## Goal

Give a Unity-trained team a Godot material that reads and behaves like Unity's
**URP Lit** material, authored directly in Godot (no Unity file import), rendering
through Godot's **Compatibility / WebGL2** path so it works in the WebXR target.
Ship it as a standalone drop-in addon with a self-demonstrating material showcase
scene. "Translation" means a faithful *semantic + visual* mapping — as close to
1:1 as the Compatibility renderer allows — proven by the showcase, not a `.mat`
file converter.

## Constraints (inherited, non-negotiable)

- Renderer: **`gl_compatibility` (WebGL2)** only. No Forward+/Mobile-only features,
  no compute, no WebGPU. Every shader feature must compile and run in Compatibility.
- Pure GDScript + `.gdshader` addon. No engine builds, no export-template changes,
  no GDExtension.
- Author-in-Godot only. **No Unity `.mat` YAML importer** in this version.
- Feature scope: **URP Lit "Core PBR" set** (enumerated below). Detail maps,
  parallax/height, Specular (vs Metallic) workflow, per-texture tiling, and the
  receive-shadows/highlights/reflections toggles are **out of scope for v1**.
- Standalone package: `godot_urp_lit` depends on nothing (not on the interaction
  toolkit, WebXR kit, or hands package).

## Naming

Package `godot_urp_lit`, primary class `URPLitMaterial`. Familiar URP terminology
is kept deliberately to ease Unity migration. The README will state plainly that
this is an **independent recreation of the URP Lit workflow, not affiliated with
or derived from Unity Technologies or Unity source**. (Open decision for review:
swap to a neutral `godot_pbr_lit` / `PBRLitMaterial` if the URP name is a concern.)

## Package structure

```text
addons/godot_urp_lit/
  plugin.cfg
  plugin.gd                        # @tool EditorPlugin (inert; class works with plugin disabled)
  runtime/
    urp_lit_material.gd            # class_name URPLitMaterial extends ShaderMaterial
    urp_lit.gdshader               # shared shader body (opaque, cull_back baseline)
    <surface-option variants>      # small set of .gdshader variants; exact list finalized in the plan
  samples/
    material_showcase.tscn
    material_showcase.gd
  README.md
```

Shader variants exist because Godot spatial-shader `render_mode` (cull, blend,
transparency) is **compile-time, not a uniform**. Rather than a combinatorial
explosion, v1 ships a small, explicit variant set covering the Surface-Options
matrix (Surface Type × Render Face cull) — see "Surface Options". To avoid
duplicating the fragment logic across variants, the shared surface code lives in a
common `.gdshader` `#include`d by each variant (or, if `#include` proves awkward
in Compatibility, a single generated body kept DRY by the material). The exact
variant file list and the include-vs-generate choice are settled in the plan;
this design fixes the *behavior* (which options exist and what they map to), not
the file count.

## The material and its authoring surface

`URPLitMaterial extends ShaderMaterial` (`class_name URPLitMaterial`). The
authoring surface is the shader's **own uniforms, named in URP terms with Godot
inspector hints**, so the material inspector reads like URP Lit with no extra
GDScript property plumbing. `URPLitMaterial` pre-wires the correct `.gdshader` and
sane defaults on `_init`, so "New Resource → URPLitMaterial" yields a ready-to-use
material, and it owns the Surface-Option enums that select the shader variant.

Uniforms (URP name → Godot hint → mapping):

| URP Lit param | Shader uniform | Inspector hint | Maps to |
|---|---|---|---|
| Base Map | `base_map : sampler2D` | `source_color` | `ALBEDO` (rgb) × `base_color`, `ALPHA` (a) |
| Base Color | `base_color : vec4` | `source_color` | tint |
| Metallic | `metallic : float` | `hint_range(0,1)` | `METALLIC` scalar (when no map) |
| Smoothness | `smoothness : float` | `hint_range(0,1)` | `ROUGHNESS = 1.0 - smoothness` |
| Metallic-Smoothness map | `metallic_smoothness_map : sampler2D` | `hint_default_white` | metallic = `.r`, smoothness = `.a` (see fidelity) |
| Normal Map | `normal_map : sampler2D` | `hint_normal` | `NORMAL_MAP` |
| Normal Scale | `normal_scale : float` | `hint_range(0,2)` | `NORMAL_MAP_DEPTH` |
| Occlusion Map | `occlusion_map : sampler2D` | `hint_default_white` | `AO` from `.g`/`.r` |
| Occlusion Strength | `occlusion_strength : float` | `hint_range(0,1)` | `AO_LIGHT_AFFECT` / lerp |
| Emission Map | `emission_map : sampler2D` | `source_color` | `EMISSION` (rgb) |
| Emission Color (HDR) | `emission_color : vec4` | `source_color` | `EMISSION` × color, HDR-capable |
| Alpha Clip Threshold | `alpha_cutoff : float` | `hint_range(0,1)` | `ALPHA_SCISSOR_THRESHOLD` |

`URPLitMaterial` GDScript-side enum properties (drive variant/render_mode, not uniforms):

- `surface_type : {OPAQUE, TRANSPARENT}` — selects `urp_lit.gdshader` vs `urp_lit_transparent.gdshader`.
- `render_face : {FRONT, BACK, BOTH}` — FRONT/BACK pick a cull mode; BOTH uses a `cull_disabled` variant (or the transparent shader already sets it). v1 may implement Render Face via a per-surface-type variant pair; the exact variant matrix is a plan-level detail.
- `alpha_clip : bool` — enables the in-shader scissor path.

## Fidelity mechanics (the core parity work, all in-shader)

1. **Smoothness → roughness**: `ROUGHNESS = 1.0 - smoothness` for the scalar, and
   `ROUGHNESS = 1.0 - texture(metallic_smoothness_map, uv).a` when the packed map
   is present. This inversion is the whole reason for a custom shader — Godot's
   `StandardMaterial3D` cannot invert a texture channel.
2. **Packed Metallic-Smoothness map**: metallic from red, smoothness from alpha —
   URP's convention. Scalar `metallic`/`smoothness` act as multipliers when a map
   is bound, matching URP's slider-scales-map behavior.
3. **Occlusion**: `AO` sampled, lerped by `occlusion_strength` toward 1.0.
4. **Emission**: `emission_map.rgb * emission_color.rgb`, HDR-capable so values > 1
   drive bloom if the environment has glow.
5. **Normal**: `NORMAL_MAP` + `NORMAL_MAP_DEPTH = normal_scale`.

Output is written to Godot's standard PBR surface outputs, so **Godot's lighting
does the shading** — this is what keeps it Compatibility-safe. Documented
approximation points: Godot's GI/reflection-probe/ambient model is not identical
to URP's, so indirect lighting and reflections are "close," not bit-exact. The
README states this explicitly.

## Showcase scene

`samples/material_showcase.tscn` — a lit material gallery that consumes only
`URPLitMaterial`:

- A grid of identical meshes (UV sphere and a rounded "material ball"), each a
  different setup: metallic sweep (0→1), smoothness sweep (0→1), normal-mapped,
  occlusion, emissive (HDR + glow), transparent, alpha-clipped, double-sided.
- A neutral lit environment (one key `DirectionalLight3D`, ambient/sky) and a slow
  auto-orbit camera; a small `Label3D`/UI caption per tile.
- **Comparison tile** (approved): one tile shows the *same* inputs rendered by a
  Godot `StandardMaterial3D` beside a `URPLitMaterial`, to make the smoothness/
  packed-map fidelity difference visible at a glance. (Open decision for review:
  keep or drop this tile.)
- Textures: tiny procedural/checker textures generated in `material_showcase.gd`
  (or minimal committed PNGs) so the sample is self-contained and adds negligible
  export size.

The scene is Compatibility-renderer and runs flat on desktop; it is **not** an XR
scene (materials are independent of the XR work) but nothing prevents using
`URPLitMaterial` on objects in the XR demo later.

## Testing

- **Headless parse/compile**: a load pass instantiates `URPLitMaterial` and assigns
  each `.gdshader`, so a shader that fails to compile in Compatibility fails the run.
- **Property round-trip** (in the existing `demo/tests/run_tests.gd` harness):
  setting URP properties updates the expected shader uniforms and selects the
  expected variant — e.g., `smoothness = 0.75` ⇒ shader param `smoothness == 0.75`;
  `surface_type = TRANSPARENT` ⇒ the transparent `.gdshader` is active;
  `alpha_clip = true` ⇒ scissor path enabled.
- **Web export builds** with the addon included.
- **Visual parity checklist** (documented, eyeball-judged): a short README/list of
  what each showcase tile should look like, since pixel parity cannot be asserted
  headlessly.

## Non-goals (v1 descopes, recorded)

- No Unity `.mat` importer (may come later; the material is designed so an importer
  could populate the same uniforms).
- No Detail maps, no Height/Parallax, no Specular workflow, no per-texture tiling,
  no receive-shadows/specular-highlights/environment-reflections toggles.
- No attempt at bit-exact URP GI/reflections — Godot lighting is used as-is.
- Not an XR feature; no dependency on the other three packages.

## Known parity gaps (documented, not fixed)

- Indirect lighting / reflections differ from URP (different GI systems).
- Surface Options are variant-based, not a single über-shader; the v1 variant
  matrix is intentionally small (Opaque/Transparent × cull), so exotic
  blend+cull+clip combinations may be approximated.
- Compatibility renderer lacks some Forward+ material features by design; those are
  out of scope, not regressions.
