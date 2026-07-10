# Blender ↔ Godot Material 1:1 Parity Addon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a standalone Godot addon `godot_blender_principled` that imports the user's already-validated `MaterialCollection.glb`, renders it under a Blender-matched "strict parity" setup, documents the Blender→Godot material contract, and provides a thin Blender-Principled-named authoring material — proving Blender↔Godot 1:1 in the Compatibility/WebGL2 target.

**Architecture:** Pure GDScript + resources addon (no custom shader). Parity rides Godot's native glTF import → `StandardMaterial3D` (roughness native, same as Blender). Two small runtime scripts (`PrincipledMaterial`, `StrictParityEnvironment`), a copied GLB sample, a showcase scene, and a contract README. Tests live in the existing `demo/tests/run_tests.gd` harness.

**Tech Stack:** Godot 4.7 (`gl_compatibility`), GDScript with `class_name`, `.glb` glTF import, headless `SceneTree` test runner.

## Global Constraints

- Renderer: **`gl_compatibility` (WebGL2)** only. No Forward+/Mobile-only features, no WebGPU, no custom `.gdshader`.
- Pure GDScript + resources addon. No engine builds, no export-template changes, no GDExtension.
- Godot 4.7 console binary: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe`. Project root for `--path` runs is `demo`.
- Every runtime script keeps its `class_name` so the addon works with the plugin disabled.
- Standalone addon: `addons/godot_blender_principled/` depends on nothing (not the interaction toolkit, WebXR kit, or hands package). It must never reference `res://addons/godot_xr_*`.
- `.gd.uid` files are gitignored — move/copy them with plain `cp`/`mv`, not `git`.
- After moving/adding `class_name` scripts or importing new assets, run an editor rescan (`GODOT --headless --editor --path demo --quit`) before the headless test suite, or a stale `.godot` cache throws "hides a global script class" / missing-import errors.
- Baseline to preserve: `demo/tests/run_tests.gd` currently reports **171 checks, 0 failures**; every task keeps it green (growing the count). Headless load exits 0; web export exits 0.
- Source GLB (do not re-author): `C:/Users/davta/Repos/1-1_BlenderToUnityMaterial/Assets/_Imported/Blender/MaterialCollection/MaterialCollection.glb` (12 materials, lint-validated).
- Expect `LF will be replaced by CRLF` git warnings — harmless.

## File Structure

```text
addons/godot_blender_principled/
  plugin.cfg                         # Task 1
  plugin.gd                          # Task 1
  runtime/
    principled_material.gd           # Task 2: class_name PrincipledMaterial extends StandardMaterial3D
    strict_parity_environment.gd     # Task 3: class_name StrictParityEnvironment (static Environment builders)
  samples/
    assets/MaterialCollection.glb    # Task 4: copied from the Unity project
    material_parity_showcase.tscn    # Task 5
    material_parity_showcase.gd      # Task 5
  README.md                          # Task 6: Blender -> Godot contract
demo/tests/run_tests.gd              # Tasks 2,3,4: new checks appended
```

---

### Task 1: Addon skeleton

**Files:**
- Create: `demo/addons/godot_blender_principled/plugin.cfg`
- Create: `demo/addons/godot_blender_principled/plugin.gd`

**Interfaces:**
- Produces: an enabled-or-not addon at `res://addons/godot_blender_principled/`. Nothing consumes it yet.

- [ ] **Step 1: Write `plugin.cfg`**

```ini
[plugin]

name="Godot Blender Principled"
description="Blender Principled BSDF material parity for Godot (Compatibility/WebGL2): imports validated glTF material collections, a Blender-matched strict-parity render environment, a Blender->Godot material contract, and a thin Blender-named authoring material. Pure GDScript, depends on nothing."
author="OSE"
version="0.1.0"
script="plugin.gd"
```

- [ ] **Step 2: Write `plugin.gd`**

```gdscript
@tool
extends EditorPlugin

## Blender material parity addon. All runtime scripts are plain class_name
## scripts, so the addon works with this plugin disabled. Depends on nothing.
```

- [ ] **Step 3: Verify the project loads (addon inert)**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo --quit`
Expected: exits 0; no parse error for the new addon.

- [ ] **Step 4: Commit**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git add demo/addons/godot_blender_principled/plugin.cfg demo/addons/godot_blender_principled/plugin.gd
git commit -m "Add godot_blender_principled addon skeleton"
```

---

### Task 2: `PrincipledMaterial` — thin Blender-named authoring material

**Files:**
- Create: `demo/addons/godot_blender_principled/runtime/principled_material.gd`
- Test: `demo/tests/run_tests.gd`

**Interfaces:**
- Produces: `class_name PrincipledMaterial extends StandardMaterial3D`. Blender-named alias properties whose setters write the differently-named native field. Native `metallic`/`roughness`/`normal_texture` are used as-is (names already match Blender — no alias). Aliases:
  - `base_color: Color` → `albedo_color`
  - `normal_strength: float` → `normal_scale` (and `normal_enabled = true`)
  - `emission_color: Color` → `emission` (and `emission_enabled = true`)
  - `emission_strength: float` → `emission_energy_multiplier`
  - `alpha_mode: AlphaMode {OPAQUE, BLEND, MASK}` → `transparency` (`TRANSPARENCY_DISABLED` / `TRANSPARENCY_ALPHA` / `TRANSPARENCY_ALPHA_SCISSOR`)
  - `ior: float` → `specular` via the dielectric approximation `specular = clampf(pow((ior-1.0)/(ior+1.0), 2.0) / 0.08, 0.0, 1.0)` (ior 1.5 → specular 0.5)

- [ ] **Step 1: Write the failing tests (append to `demo/tests/run_tests.gd`)**

Add the preload near the other consts (top of file):
```gdscript
const PrincipledMaterial := preload("res://addons/godot_blender_principled/runtime/principled_material.gd")
```
Register the test in `_run_all()` after `_test_layer_mask()`:
```gdscript
    _test_principled_material_aliases()
```
Add the function:
```gdscript
func _test_principled_material_aliases() -> void:
    var m := PrincipledMaterial.new()
    m.base_color = Color(0.2, 0.4, 0.6, 0.8)
    check(m.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.8)), "base_color aliases albedo_color")

    m.normal_strength = 0.8
    check(is_equal_approx(m.normal_scale, 0.8), "normal_strength aliases normal_scale")
    check(m.normal_enabled, "setting normal_strength enables normal mapping")

    m.emission_color = Color(1, 0.5, 0)
    check(m.emission_enabled, "setting emission_color enables emission")
    check(m.emission.is_equal_approx(Color(1, 0.5, 0)), "emission_color aliases emission")
    m.emission_strength = 3.0
    check(is_equal_approx(m.emission_energy_multiplier, 3.0), "emission_strength aliases emission_energy_multiplier")

    m.alpha_mode = PrincipledMaterial.AlphaMode.MASK
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "alpha_mode MASK -> alpha scissor")
    m.alpha_mode = PrincipledMaterial.AlphaMode.BLEND
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "alpha_mode BLEND -> alpha")
    m.alpha_mode = PrincipledMaterial.AlphaMode.OPAQUE
    check(m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "alpha_mode OPAQUE -> opaque")

    m.ior = 1.5
    check(is_equal_approx(m.specular, 0.5), "ior 1.5 maps to specular 0.5")

    # roughness/metallic are native StandardMaterial3D props (Blender names already match)
    m.roughness = 0.7
    m.metallic = 0.0
    check(is_equal_approx(m.roughness, 0.7) and is_equal_approx(m.metallic, 0.0), "native roughness/metallic pass through unchanged")
```

- [ ] **Step 2: Run to verify it fails**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --editor --path demo --quit >/dev/null 2>&1 ; c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "SCRIPT ERROR|Parse|checks,"`
Expected: parse error / failure — `PrincipledMaterial` does not exist yet.

- [ ] **Step 3: Write `runtime/principled_material.gd`**

```gdscript
class_name PrincipledMaterial
extends StandardMaterial3D

## Thin Blender-Principled-BSDF-named layer over StandardMaterial3D. Only aliases
## the inputs whose Godot name differs from Blender's; metallic/roughness/normal
## are native (names already match Blender, roughness is NOT inverted).

enum AlphaMode { OPAQUE, BLEND, MASK }

@export_group("Blender Principled")
@export var base_color := Color(0.8, 0.8, 0.8, 1.0): set = _set_base_color
@export_range(0.0, 4.0, 0.01, "or_greater") var normal_strength := 1.0: set = _set_normal_strength
@export var emission_color := Color(0, 0, 0, 1.0): set = _set_emission_color
@export_range(0.0, 100.0, 0.01, "or_greater") var emission_strength := 1.0: set = _set_emission_strength
@export var alpha_mode := AlphaMode.OPAQUE: set = _set_alpha_mode
@export_range(1.0, 3.0, 0.01) var ior := 1.5: set = _set_ior

func _init() -> void:
    # Blender-matching defaults: dielectric, mid roughness, no emission.
    metallic = 0.0
    roughness = 0.5
    specular = 0.5

func _set_base_color(value: Color) -> void:
    base_color = value
    albedo_color = value

func _set_normal_strength(value: float) -> void:
    normal_strength = value
    normal_enabled = true
    normal_scale = value

func _set_emission_color(value: Color) -> void:
    emission_color = value
    emission_enabled = true
    emission = value

func _set_emission_strength(value: float) -> void:
    emission_strength = value
    emission_energy_multiplier = value

func _set_alpha_mode(value: AlphaMode) -> void:
    alpha_mode = value
    match value:
        AlphaMode.OPAQUE:
            transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
        AlphaMode.BLEND:
            transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        AlphaMode.MASK:
            transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR

func _set_ior(value: float) -> void:
    ior = value
    specular = clampf(pow((value - 1.0) / (value + 1.0), 2.0) / 0.08, 0.0, 1.0)
```

- [ ] **Step 4: Run to verify it passes**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --editor --path demo --quit >/dev/null 2>&1 ; c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "aliases|maps to|pass through|FAIL|checks,"`
Expected: all new PASS lines; total checks increased; 0 failures.

- [ ] **Step 5: Commit**

```bash
git add demo/addons/godot_blender_principled/runtime/principled_material.gd demo/tests/run_tests.gd
git commit -m "Add PrincipledMaterial: Blender-named thin layer over StandardMaterial3D"
```

---

### Task 3: `StrictParityEnvironment` — Blender-matched render setup

**Files:**
- Create: `demo/addons/godot_blender_principled/runtime/strict_parity_environment.gd`
- Test: `demo/tests/run_tests.gd`

**Interfaces:**
- Produces: `class_name StrictParityEnvironment` with two static builders:
  - `static func parity_environment() -> Environment` — `tonemap_mode = TONE_MAPPER_LINEAR`, ambient source COLOR at `Color(0.05,0.05,0.05)` energy 1.0, `background_mode = BG_COLOR` background `Color(0.05,0.05,0.05)`, `ssao_enabled/ssil_enabled/sdfgi_enabled/glow_enabled = false`. (Mirrors Blender "Standard view transform, 0.05 ambient, GI off".)
  - `static func nice_environment() -> Environment` — `tonemap_mode = TONE_MAPPER_AGX` (matches Blender default AgX), ambient source COLOR at `Color(0.2,0.2,0.2)`, glow enabled. No sky resource (kept null so the sample stays self-contained; caller may assign one).

- [ ] **Step 1: Write the failing tests (append to `demo/tests/run_tests.gd`)**

Preload near the others:
```gdscript
const StrictParityEnvironment := preload("res://addons/godot_blender_principled/runtime/strict_parity_environment.gd")
```
Register after `_test_principled_material_aliases()`:
```gdscript
    _test_strict_parity_environment()
```
Add:
```gdscript
func _test_strict_parity_environment() -> void:
    var env: Environment = StrictParityEnvironment.parity_environment()
    check(env.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "parity uses Linear tonemap (= Blender Standard view)")
    check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "parity ambient is a flat color")
    check(env.ambient_light_color.is_equal_approx(Color(0.05, 0.05, 0.05)), "parity ambient is 0.05 gray")
    check(not env.ssao_enabled and not env.sdfgi_enabled and not env.glow_enabled, "parity kills GI/SSAO/glow")

    var nice: Environment = StrictParityEnvironment.nice_environment()
    check(nice.tonemap_mode == Environment.TONE_MAPPER_AGX, "nice look uses AgX tonemap (= Blender default AgX)")
```

- [ ] **Step 2: Run to verify it fails**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --editor --path demo --quit >/dev/null 2>&1 ; c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "SCRIPT ERROR|Parse|checks,"`
Expected: failure — `StrictParityEnvironment` does not exist.

- [ ] **Step 3: Write `runtime/strict_parity_environment.gd`**

```gdscript
class_name StrictParityEnvironment
extends RefCounted

## Builds render environments for Blender<->Godot material comparison.
## parity_environment() mirrors the user's validated "Strict Parity" method
## (Blender Standard view transform, 0.05 flat ambient, GI off) so material
## differences are real, not lighting differences.

static func parity_environment() -> Environment:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.05, 0.05)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.05, 0.05, 0.05)
    env.ambient_light_energy = 1.0
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.ssao_enabled = false
    env.ssil_enabled = false
    env.sdfgi_enabled = false
    env.glow_enabled = false
    return env

static func nice_environment() -> Environment:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.35, 0.37, 0.4)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.2, 0.2, 0.2)
    env.ambient_light_energy = 1.0
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.glow_enabled = true
    return env
```

- [ ] **Step 4: Run to verify it passes**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --editor --path demo --quit >/dev/null 2>&1 ; c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "parity|nice look|FAIL|checks,"`
Expected: new PASS lines; 0 failures.

- [ ] **Step 5: Commit**

```bash
git add demo/addons/godot_blender_principled/runtime/strict_parity_environment.gd demo/tests/run_tests.gd
git commit -m "Add StrictParityEnvironment: Blender-matched parity + AgX nice-look environments"
```

---

### Task 4: Import the validated GLB + import-smoke test

**Files:**
- Create (copy): `demo/addons/godot_blender_principled/samples/assets/MaterialCollection.glb`
- Test: `demo/tests/run_tests.gd`

**Interfaces:**
- Produces: the imported collection loadable at `res://addons/godot_blender_principled/samples/assets/MaterialCollection.glb` (a `PackedScene`). Its meshes carry `StandardMaterial3D`s built by Godot's native glTF importer.

- [ ] **Step 1: Copy the GLB and import it**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
mkdir -p demo/addons/godot_blender_principled/samples/assets
cp "C:/Users/davta/Repos/1-1_BlenderToUnityMaterial/Assets/_Imported/Blender/MaterialCollection/MaterialCollection.glb" \
   demo/addons/godot_blender_principled/samples/assets/MaterialCollection.glb
# import pass generates the .import sidecar
c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --editor --path demo --quit 2>&1 | tail -2
ls demo/addons/godot_blender_principled/samples/assets/MaterialCollection.glb.import 2>&1
```
Expected: the `.glb.import` file exists (import succeeded).

- [ ] **Step 2: Discovery probe — dump the imported material table (throwaway)**

Create `demo/tests/_probe_materials.gd`:
```gdscript
extends SceneTree
func _initialize() -> void:
    var packed: PackedScene = load("res://addons/godot_blender_principled/samples/assets/MaterialCollection.glb")
    var root := packed.instantiate()
    var mats := {}
    var stack := [root]
    while not stack.is_empty():
        var n = stack.pop_back()
        if n is MeshInstance3D and n.mesh:
            for i in n.mesh.get_surface_count():
                var mat := n.mesh.surface_get_material(i)
                if mat and not mats.has(mat.resource_name):
                    mats[mat.resource_name] = mat
    for name in mats:
        var m: StandardMaterial3D = mats[name]
        print("%s | class=%s metallic=%.2f roughness=%.2f transparency=%d emission_e=%.2f" % [
            name, m.get_class(), m.metallic, m.roughness, m.transparency, m.emission_energy_multiplier])
    print("MATERIAL COUNT: %d" % mats.size())
    quit(0)
```
Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/_probe_materials.gd`
Record: the material count and which materials are `TRANSPARENCY_ALPHA_SCISSOR` (transparency==2), which have `metallic==0` vs `metallic==1`. Use these to confirm the assertions below. Then delete the probe: `rm demo/tests/_probe_materials.gd`.

- [ ] **Step 3: Write the import-smoke test (append to `demo/tests/run_tests.gd`)**

Register after `_test_strict_parity_environment()`:
```gdscript
    _test_material_collection_import()
```
Add (uses invariants that hold for this lint-validated collection — a helper walks the scene):
```gdscript
func _collect_collection_materials() -> Array:
    var packed: PackedScene = load("res://addons/godot_blender_principled/samples/assets/MaterialCollection.glb")
    var root := packed.instantiate()
    var out := []
    var stack := [root]
    while not stack.is_empty():
        var n = stack.pop_back()
        if n is MeshInstance3D and n.mesh:
            for i in n.mesh.get_surface_count():
                var mat := n.mesh.surface_get_material(i)
                if mat and not out.has(mat):
                    out.append(mat)
        for c in n.get_children():
            stack.append(c)
    root.free()
    return out

func _test_material_collection_import() -> void:
    var mats := _collect_collection_materials()
    check(mats.size() >= 8, "material collection imported multiple materials, got %d" % mats.size())

    var all_standard := true
    var has_scissor := false
    var has_dielectric := false
    var has_metal := false
    for m in mats:
        if not (m is StandardMaterial3D):
            all_standard = false
        if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
            has_scissor = true
        if is_equal_approx(m.metallic, 0.0):
            has_dielectric = true
        if m.metallic >= 0.99:
            has_metal = true
    check(all_standard, "all imported materials are StandardMaterial3D (glTFast-equivalent path)")
    check(has_scissor, "a cutout material imported as alpha scissor (MASK survived glTF)")
    check(has_dielectric, "a dielectric material imported with metallic 0")
    check(has_metal, "a metal material imported with metallic 1")
```
(If Step 2 revealed the collection has no fully-metallic material after import, relax `has_metal` to `m.metallic >= 0.5` and note it; do not assert something the probe disproved.)

- [ ] **Step 4: Run to verify it passes**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "material collection|imported|survived|dielectric|metal|FAIL|checks,"`
Expected: new PASS lines; 0 failures.

- [ ] **Step 5: Commit**

```bash
git add demo/addons/godot_blender_principled/samples/assets/MaterialCollection.glb \
        demo/addons/godot_blender_principled/samples/assets/MaterialCollection.glb.import demo/tests/run_tests.gd
git commit -m "Import validated MaterialCollection.glb + import-smoke test (parity subject)"
```

---

### Task 5: Material parity showcase scene

**Files:**
- Create: `demo/addons/godot_blender_principled/samples/material_parity_showcase.gd`
- Create: `demo/addons/godot_blender_principled/samples/material_parity_showcase.tscn`

**Interfaces:**
- Consumes: `MaterialCollection.glb` (Task 4), `StrictParityEnvironment` (Task 3), `PrincipledMaterial` (Task 2).
- Produces: a runnable flat scene showing the imported collection under strict-parity lighting, with a key light, a `parity`/`nice` toggle (default parity), a slow camera orbit, and a row of `PrincipledMaterial` demo spheres. Built entirely in `_ready()` from code so the `.tscn` stays minimal and robust.

- [ ] **Step 1: Write `material_parity_showcase.gd`**

```gdscript
extends Node3D

## Renders the imported Blender material collection under the strict-parity
## environment for a 1:1 comparison, plus a row of PrincipledMaterial spheres.
## Press SPACE to toggle strict-parity vs nice-look lighting.

const COLLECTION := "res://addons/godot_blender_principled/samples/assets/MaterialCollection.glb"

var _world_env: WorldEnvironment
var _orbit: Node3D
var _nice := false

func _ready() -> void:
    _world_env = WorldEnvironment.new()
    _world_env.environment = StrictParityEnvironment.parity_environment()
    add_child(_world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -40, 0)
    sun.light_energy = 1.5
    add_child(sun)

    _orbit = Node3D.new()
    add_child(_orbit)
    var cam := Camera3D.new()
    cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 4.0))
    cam.current = true
    _orbit.add_child(cam)

    var collection := (load(COLLECTION) as PackedScene).instantiate()
    add_child(collection)

    _build_principled_row()

func _build_principled_row() -> void:
    var sphere := SphereMesh.new()
    for i in range(5):
        var mi := MeshInstance3D.new()
        mi.mesh = sphere
        mi.position = Vector3(-2.0 + i * 1.0, 0.0, 1.5)
        var mat := PrincipledMaterial.new()
        mat.base_color = Color(0.8, 0.3, 0.2)
        mat.metallic = float(i) / 4.0
        mat.roughness = 1.0 - float(i) / 4.0
        mi.material_override = mat
        add_child(mi)

func _process(delta: float) -> void:
    _orbit.rotate_y(delta * 0.2)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _nice = not _nice
        _world_env.environment = StrictParityEnvironment.nice_environment() if _nice else StrictParityEnvironment.parity_environment()
```

- [ ] **Step 2: Create `material_parity_showcase.tscn`**

Create the file with exactly this content (a single scripted root node):
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/godot_blender_principled/samples/material_parity_showcase.gd" id="1_show"]

[node name="MaterialParityShowcase" type="Node3D"]
script = ExtResource("1_show")
```

- [ ] **Step 3: Rescan + headless load of the showcase scene**

Run:
```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --editor --path demo --quit >/dev/null 2>&1
"$GODOT" --headless --path demo res://addons/godot_blender_principled/samples/material_parity_showcase.tscn --quit 2>&1 | grep -iE "error|script|shader" | grep -vi "Not a web export" || echo "loaded clean"
```
Expected: `loaded clean` (no errors instancing the scene, the collection, the environments, or the materials).

- [ ] **Step 4: Full suite still green**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "FAIL|checks,"`
Expected: 0 failures.

- [ ] **Step 5: Commit**

```bash
git add demo/addons/godot_blender_principled/samples/material_parity_showcase.gd \
        demo/addons/godot_blender_principled/samples/material_parity_showcase.tscn
git commit -m "Add material parity showcase scene (imported collection + PrincipledMaterial row, parity toggle)"
```

---

### Task 6: Contract README + final verification

**Files:**
- Create: `demo/addons/godot_blender_principled/README.md`

**Interfaces:**
- Produces: the Blender→Godot material contract and reproduction steps for the parity test.

- [ ] **Step 1: Write `README.md`**

Content must cover (prose + tables), drawn from the spec's Pillar 3:
- What the addon is; standalone, depends on nothing; Compatibility/WebGL2; no custom shader.
- **Blender→Godot contract** table: colorspace (sRGB color / Non-Color data); `Image.Alpha → Math:Round → Principled.Alpha` ⇒ glTF `alphaMode=MASK` ⇒ Godot alpha scissor; no shader-math between Image and Principled (bake/channel-split); preserve Normal Strength / Mapping.Scale / IOR / Transmission; set `metallicFactor` explicitly to 0 on dielectrics (glTF omits it at 1.0).
- **Godot deltas vs Unity**: native glTF import is the accurate (glTFast-equivalent) path; roughness is native (no smoothness repack); Godot imports `KHR_materials_emissive_strength` into `emission_energy_multiplier`; no URP-Lit BRDF penalty.
- **Reproduce the parity test**: open `samples/material_parity_showcase.tscn`; it renders under strict parity (Linear tonemap = Blender Standard view, 0.05 ambient, GI off); to compare, render the same collection in Blender via *Pipeline → Match Unity Preview* (Standard view) and put the two side by side; SPACE toggles the AgX nice-look.
- **`PrincipledMaterial`** usage: assign it to a mesh; edit the "Blender Principled" group; `metallic`/`roughness` use Godot's native fields (already Blender-named).
- **Non-goals / known gaps**: subsurface/transmission/coat/sheen out of scope; GI not bit-exact; IOR→specular approximate. Independent tool, not affiliated with the Blender Foundation.

- [ ] **Step 2: Final full verification**

Run:
```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd 2>&1 | grep -iE "FAIL|checks,"     # 0 failures
"$GODOT" --headless --path demo --quit 2>&1 | grep -iE "error" | grep -vi "Not a web export" || echo "load clean"
"$GODOT" --headless --path demo --export-release Web build/web47/index.html 2>&1 | tail -1     # DONE, exit 0
```
Expected: suite 0 failures; load clean; export exits 0.

- [ ] **Step 3: Verify addon self-containment**

Run: `grep -rn "godot_xr_interaction_toolkit\|godot_webxr_kit\|godot_xr_hands\|res://scripts\|res://scenes" demo/addons/godot_blender_principled/ || echo "CLEAN: standalone, no cross-addon/demo references"`
Expected: `CLEAN: standalone, ...`.

- [ ] **Step 4: Commit**

```bash
git add demo/addons/godot_blender_principled/README.md
git commit -m "Add Blender->Godot material contract README + parity reproduction steps"
```

---

## Self-Review

**Spec coverage:**
- Pillar 1 (import validated GLB) → Task 4. ✓
- Pillar 2 (strict-parity scene, Linear tonemap; AgX nice look) → Task 3 (environments) + Task 5 (scene/toggle). ✓
- Pillar 3 (Blender→Godot contract doc) → Task 6. ✓
- Pillar 4 (thin PrincipledMaterial, only differing-name aliases, no metallic/roughness collision) → Task 2. ✓
- Pillar 5 (tests: import smoke, alias round-trip, parity env correctness, web export, self-containment) → Tasks 2/3/4 + Task 6 Steps 2-3. ✓
- Constraints (Compatibility, no custom shader, standalone, class_name, uid handling, rescan) → Global Constraints + per-task rescan steps. ✓
- Naming `godot_blender_principled` / `PrincipledMaterial` → Task 1/2. ✓

**Placeholder scan:** No TBD/TODO. The one adaptive step (Task 4 Step 3 `has_metal` relaxation) is conditioned on the Step 2 probe's actual output and states the exact fallback — not a placeholder. The README task lists concrete required content rather than prose to copy, which is appropriate for a doc task.

**Type consistency:** `PrincipledMaterial` aliases (`base_color`, `normal_strength`, `emission_color`, `emission_strength`, `alpha_mode`, `ior`) and enum `AlphaMode {OPAQUE,BLEND,MASK}` are identical between Task 2's interface, code, and test. `StrictParityEnvironment.parity_environment()/nice_environment()` names match between Task 3 and Task 5's consumer. `Environment.TONE_MAPPER_LINEAR/AGX`, `AMBIENT_SOURCE_COLOR`, `BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR` are Godot 4 built-ins used consistently.

**Dependency note:** the side-by-side Blender reference render (spec Pillar 2) is an external artifact the user generates in Blender; the plan's showcase provides the Godot half and the reproduction steps (Task 6 Step 1), which is the correct boundary — the plan cannot run Blender.
