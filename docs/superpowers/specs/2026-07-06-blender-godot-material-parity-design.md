# Blender ↔ Godot Material 1:1 — Design

Status: approved for planning 2026-07-06. Governs a new addon
`addons/godot_blender_principled/`. Supersedes the URP Lit design
(`2026-07-06-urp-lit-material-design.md`).

## Goal

Prove — and make repeatable — that a Blender-authored material collection renders
**1:1 in Godot** (Compatibility / WebGL2), reusing the user's existing, validated
Blender→Unity pipeline as the source of truth. Deliver a drop-in Godot addon that
(1) imports the already-validated material collection, (2) renders it under a
Blender-matched "strict parity" setup for a measurable comparison, (3) documents
the Blender→Godot material contract, and (4) provides a thin Blender-Principled-
named authoring material for tweaking in Godot.

## Thesis (why Godot should reach 1:1, backed by the user's prior findings)

From the user's pipeline docs (`Unity_To_Blender_Material_Collection/`):

- The **glTFast-bound prefab "matches Blender almost exactly because glTFast
  implements the glTF 2.0 PBR spec."**
- The **stock URP Lit variant is "~5–15% off on non-metallic dielectrics due to
  BRDF differences"** and requires a metallic→smoothness repack.

Godot's **native glTF importer is the direct analog of glTFast** — it maps glTF
2.0 metallic-roughness PBR into `StandardMaterial3D`. Crucially, Godot uses
**roughness** (0 = glossy), identical to Blender, so there is **no smoothness
inversion / repack** and no URP-Lit BRDF penalty. Expected result: **Godot matches
Blender at least as well as glTFast did, and better than Unity's URP Lit variant.**
That claim is what this package measures.

## Reused prior art (inventory)

Source-of-truth assets already produced by the user (do not re-author):

| Artifact | Path | Use |
|---|---|---|
| Canonical validated GLB (12 materials) | `C:/Users/davta/Repos/1-1_BlenderToUnityMaterial/Assets/_Imported/Blender/MaterialCollection/MaterialCollection.glb` | Imported into Godot as the parity subject |
| Validated Blender fork (12/12 lint PASS) | `C:/Users/davta/Downloads/Unity_To_Blender_Material_Collection/Unity_To_Blender_Material_Collection.b2u_fixed.blend` | Source for a Blender Standard-view reference render |
| Blender reference renders | `.../Unity_To_Blender_Material_Collection/_validation_render_VALIDATED.png` (+ `_ORIGINAL`) | Comparison target |
| Pipeline docs (the contract) | `.../MATERIAL_FIXES_FOR_UNITY_EXPORT.md`, `HOW_TO_REPLICATE_MATERIALCOLLECTION_GLB.md`, `MATERIAL_PATTERNS_README.md`, `BLENDER_ARTIST_WORKFLOW.md` | Source for the Blender→Godot contract doc |

The user's validated **Strict-Parity verification method** (from
`BLENDER_ARTIST_WORKFLOW.md`), which this design mirrors in Godot:

- Blender: world flattened to `(0.05, 0.05, 0.05)` ambient, Sun energy `2.0`,
  **View Transform = Standard** (linear — no Filmic/AgX curve), EEVEE GI bounces /
  raytracing / fast-GI OFF.
- Unity: ambient `(0.05,0.05,0.05)`, sun intensity `1.0`, no skybox, no fog,
  **Linear** color space.
- "Both sides render with identical lighting math. Differences you see are real
  material differences."

## Constraints (inherited, non-negotiable)

- Renderer: **`gl_compatibility` (WebGL2)** only. No Forward+/Mobile-only features,
  no WebGPU.
- Pure GDScript + resources addon. **No custom `.gdshader`** — parity rides Godot's
  native `StandardMaterial3D` + glTF import (roughness matches Blender, so no shader
  is needed for the core). No engine builds, no export-template changes.
- **No Blender-side tooling** is built here — the user already has a Blender linter/
  exporter. Godot consumes its GLB output. The Godot contract doc references the
  Blender rules; it does not re-implement them.
- Author-in-Godot for the thin material layer; the primary flow is **import** the
  validated GLB.
- Standalone addon; depends on nothing (not the interaction toolkit / WebXR kit /
  hands).

## Package structure

```text
addons/godot_blender_principled/
  plugin.cfg
  plugin.gd                          # @tool EditorPlugin (inert; classes work with plugin disabled)
  runtime/
    principled_material.gd           # class_name PrincipledMaterial extends StandardMaterial3D
    strict_parity_environment.gd     # helper: applies/reverts the Blender-matched parity lighting+tonemap
  samples/
    material_parity_showcase.tscn    # imports the GLB, renders it, parity/nice toggle, comparison overlay
    material_parity_showcase.gd
    assets/
      MaterialCollection.glb         # copied from the Unity project (self-contained, embedded textures)
      blender_reference_standardview.png  # Blender Standard-view render for side-by-side (user-provided)
  README.md                          # the Blender -> Godot contract + how to reproduce the parity test
```

Size note: the GLB (~tens of MB) lives under `samples/`; a consumer who only wants
`PrincipledMaterial` can delete `samples/`. The showcase is the parity proof, so it
ships the asset by design.

## Pillar 1 — Import the validated collection

Copy `MaterialCollection.glb` into `samples/assets/` and let Godot's glTF importer
build `StandardMaterial3D`s (the glTFast-equivalent accurate path). No re-authoring;
GLB carries embedded textures. This yields the Godot-side subject for comparison.

## Pillar 2 — Strict-Parity proof scene

`material_parity_showcase.tscn` renders the imported collection with two modes,
toggled at runtime by `strict_parity_environment.gd`:

- **Strict Parity** (the measurable 1:1 test): `WorldEnvironment` with **`tonemap_mode = LINEAR`** (= Blender "Standard" view transform), flat ambient `Color(0.05,0.05,0.05)` (ambient source = COLOR), **no sky, GI/SSAO/glow off**, a single `DirectionalLight3D` "sun". Camera framed to match the Blender/Unity reference shot. This is the state used to judge parity.
- **Nice Look** (authoring/turntable): `tonemap_mode = AGX` (Godot 4's AgX matches Blender's default AgX view transform) + a studio HDRI/sky, gentle glow. For pleasant evaluation, not for the parity claim.

A **comparison overlay** shows the Blender Standard-view reference PNG beside the
live Godot render (a split `TextureRect` / toggle), making drift visible per
material. A slow auto-orbit camera and per-object labels aid inspection.

Dependency: a **Blender Standard-view reference render** is needed for the overlay.
If the existing `_validation_render_*.png` were shot in authoring look rather than
Standard view, the user regenerates one via their existing Blender **Pipeline →
Match Unity Preview** operator + render (a one-click step on their side).

## Pillar 3 — Blender → Godot contract (README)

Adapt the user's existing contract; it is ~90% glTF-2.0 rules that apply to Godot
unchanged. Documented as a Godot-facing checklist, annotating Godot deltas:

Shared (glTF-driven) rules, unchanged from their Unity contract:
- Colorspace: sRGB for Base Color / Emission; **Non-Color** for Metallic /
  Roughness / Normal / Alpha / Occlusion.
- Alpha cutout: `Image.Alpha → Math:Round → Principled.Alpha` ⇒ `alphaMode=MASK`
  (Godot imports as `TRANSPARENCY_ALPHA_SCISSOR`). Without it ⇒ `BLEND` (soft).
- No shader math between Image Texture and Principled (glTF cannot carry it) — bake
  or channel-split, per their recipe.
- Preserve Normal Strength (`normalTexture.scale`), Mapping.Scale
  (`KHR_texture_transform`), IOR, Transmission Weight, per-material backface flag.
- Metallic/Roughness sanity (dielectrics = metallic 0; raise roughness when flipping
  a material off metal), and set `metallicFactor` explicitly to 0 (glTF omits it at
  the 1.0 default → chrome surprise).

Godot deltas (call out explicitly):
- Godot's native glTF import is the **accurate path** (glTFast-equivalent). There is
  no separate "URP Lit variant" and no metallic-smoothness repack — Godot reads
  glTF metallic-roughness directly (**roughness native, no inversion**).
- Emission: Godot imports **`KHR_materials_emissive_strength`** into
  `emission_energy_multiplier` (verify per material; HDR emission survives).
- Alpha: glTF `MASK` → alpha scissor; `BLEND` → alpha transparency in
  `StandardMaterial3D`.
- Coat Tint / transmission / subsurface: same limits as URP (not represented in the
  Compatibility target); document as out of scope.

## Pillar 4 — Thin authoring material

`PrincipledMaterial extends StandardMaterial3D` (`class_name`), with **Blender-
matching defaults** set in `_init`.

Key correctness constraint: a subclass **cannot re-declare** a property the base
class already defines (`metallic`, `roughness`, `emission`, `normal_scale`,
`albedo_color` … already exist on `StandardMaterial3D`). So the layer adds
Blender-named `@export` conveniences **only where Godot's name differs from
Blender's**, and relies on Godot's native property everywhere the names already
match:

| Blender Principled | How PrincipledMaterial exposes it |
|---|---|
| Metallic | **native `metallic`** — Godot's name already matches Blender (no alias) |
| Roughness | **native `roughness`** — already matches Blender, no inversion (no alias) |
| Normal map | **native `normal_texture` / `normal_enabled`** |
| Base Color | alias `base_color` → sets `albedo_color` (different Godot name) |
| Normal Strength | alias `normal_strength` → sets `normal_scale` |
| Emission Color | alias `emission_color` → sets `emission` |
| Emission Strength | alias `emission_strength` → sets `emission_energy_multiplier` |
| Alpha mode | alias `alpha_mode` (enum) → sets `transparency` |
| IOR | alias `ior` → specular/refraction approximation |

Honest scoping: `StandardMaterial3D` ≈ Principled already (metallic/roughness names
and semantics are literally identical), so this is a **very thin familiarity layer**
— a handful of aliases for the differently-named inputs, plus Blender-matching
defaults. It is optional to the parity proof (which uses imported materials); it
exists for artists tweaking in Godot after import. Aliases are grouped under an
`@export_group("Blender Principled")` at the top of the inspector; the underlying
native fields remain visible below.

## Pillar 5 — Testing

- **glTF import smoke** (headless, in `demo/tests/run_tests.gd`): load the imported
  collection scene/resource, assert per-material expectations survive — e.g. a
  known emissive material has `emission_energy_multiplier > 1`; a cutout material
  has `transparency == TRANSPARENCY_ALPHA_SCISSOR`; a dielectric has `metallic == 0`;
  roughness values land in expected ranges.
- **`PrincipledMaterial` alias round-trip**: setting each Blender-named *alias*
  updates the differently-named native field — e.g. `base_color = C` ⇒
  `albedo_color == C`; `emission_strength = 3` ⇒ `emission_energy_multiplier == 3`;
  `normal_strength = 0.8` ⇒ `normal_scale == 0.8`; `alpha_mode = MASK` ⇒
  `transparency == TRANSPARENCY_ALPHA_SCISSOR`. (Native passthroughs like
  `metallic`/`roughness` need no test — they are Godot's own properties.)
- **`strict_parity_environment` correctness**: applying parity sets `LINEAR` tonemap
  + `(0.05,0.05,0.05)` ambient + sky/GI off; reverting restores prior values.
- **Web export builds** with the addon included.
- **Visual parity checklist** (documented, eyeball-judged against the Blender
  reference): per-material expected appearance; parity is ultimately visual.

## Non-goals (v1 descopes)

- No Blender-side linter/exporter (the user already has one; Godot consumes its GLB).
- No subsurface / transmission / coat / sheen / anisotropy fidelity (don't survive
  glTF / not in Compatibility).
- No custom shader; no attempt to out-do Godot's native glTF import.
- No Unity/URP path (superseded).
- No automated pixel-diff parity metric in v1 (visual checklist only; an automated
  SSIM/pixel-diff harness is a possible later addition).

## Known parity gaps (documented, not fixed)

- Godot GI / reflection / ambient model differs from Blender EEVEE; strict-parity
  mode minimizes this by killing GI on both sides, but indirect light is never
  bit-exact.
- Compatibility renderer lacks some Forward+ material features by design (out of
  scope).
- IOR → specular mapping is approximate in `StandardMaterial3D`.

## Naming

Package `godot_blender_principled`, class `PrincipledMaterial`. Open for review:
shorter `godot_principled` or `godot_b2g`. README states it is an independent tool
for moving Blender materials into Godot, not affiliated with the Blender Foundation.
