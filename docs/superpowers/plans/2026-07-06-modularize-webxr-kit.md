# Modularize Into Three Drop-In Packages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the current single addon into three self-contained pure-GDScript editor addons so a new project can drop in exactly what it needs: the engine-agnostic interaction core alone, plus optionally a WebXR platform layer and/or a procedural hand visual.

**Architecture:** Three stacked addons.
1. `godot_xr_interaction_toolkit` — engine-agnostic core: interactors, interactables, manager, grab/socket/UI, the **abstract** `XRInputAdapter` seam, and the `XRHandTracker`-based gesture/resolver helpers. Depends on nothing.
2. `godot_webxr_kit` — WebXR platform layer: the concrete `WebXRInputAdapter`, the custom HTML shell that defines the browser hand/depth JS bridges, the session bootstrap, the browser-capability probe, and the depth-mesh visualizer (WebXR-shell-bound, Quest-only). **Depends on** the toolkit.
3. `godot_xr_hands` — presentation: the procedural hand visualizer. **Depends on** the toolkit only. It reads the WebXR hand bridge (`window.CompanyWebXRHandBridge`) as an *optional* runtime enhancement via a JS-global string eval — not a load-time dependency — and degrades to `XRHandTracker` when the shell is absent.

Dependency graph is a DAG with the toolkit at the base: `godot_webxr_kit → toolkit`, `godot_xr_hands → toolkit`. Neither the toolkit nor `godot_xr_hands` has any load-time reference to `godot_webxr_kit`.

**Tech Stack:** Godot 4.7 (GDScript only, `class_name` runtime scripts, editor `plugin.cfg`). No GDExtension, no engine modules, no custom export templates. Verification via Godot headless (`-s res://tests/run_tests.gd`, `--quit`, `--export-release`).

## Global Constraints

- Godot 4.4+/4.7+; machine's 4.7 console binary: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe`. Project root for `--path` runs is `demo`.
- Pure GDScript addons only. No engine/renderer/backend/export-template changes (CLAUDE.md hard boundary).
- Every runtime script keeps its `class_name` so each addon works with its plugin disabled.
- Dependency direction is fixed: toolkit depends on nothing; `godot_webxr_kit` and `godot_xr_hands` may depend on the toolkit; **nothing** may make the toolkit or `godot_xr_hands` load-time-depend on `godot_webxr_kit`.
- After the split, `godot_xr_interaction_toolkit` MUST contain zero references to `CompanyWebXR`, `res://scripts`, `res://scenes`, `res://web`, `godot_webxr_kit`, or `godot_xr_hands`.
- `godot_xr_hands` MUST contain zero `res://addons/godot_webxr_kit/...` paths (the WebXR bridge is used only as a feature-detected `window.CompanyWebXRHandBridge` JS-global string).
- The demo scene consumes addon APIs only; no toolkit/WebXR/hand logic moves *into* the demo.
- Baseline to preserve at every checkpoint: headless suite = **163 checks, 0 failures**; headless load exits 0; web export exits 0 with `index.{html,js,pck,wasm}` present and the shell embedded.
- Use `git mv` for every move (history follows the file). Move each `.gd.uid` sidecar with its `.gd`.
- Git Bash on Windows; forward-slash paths. `LF will be replaced by CRLF` git warnings are harmless.

---

### Task 1: Create both new package skeletons

**Files:**
- Create: `demo/addons/godot_webxr_kit/plugin.cfg`, `demo/addons/godot_webxr_kit/plugin.gd`
- Create: `demo/addons/godot_xr_hands/plugin.cfg`, `demo/addons/godot_xr_hands/plugin.gd`
- (Runtime/web subdirs are created by the first moved file in later tasks.)

**Interfaces:**
- Produces: two enabled-or-not addons rooted at `res://addons/godot_webxr_kit/` and `res://addons/godot_xr_hands/`. Nothing consumes them yet.

- [ ] **Step 1: Write `godot_webxr_kit/plugin.cfg`**

```ini
[plugin]

name="Godot WebXR Kit"
description="WebXR platform layer for godot_xr_interaction_toolkit: WebXRInputAdapter, custom HTML shell with hand/depth browser bridges, session bootstrap, browser-capability probe, and depth-mesh visualizer. Pure GDScript. Requires godot_xr_interaction_toolkit."
author="OSE"
version="0.1.0"
script="plugin.gd"
```

- [ ] **Step 2: Write `godot_webxr_kit/plugin.gd`**

```gdscript
@tool
extends EditorPlugin

## WebXR platform layer. Plain class_name scripts, so it works with the plugin
## disabled. Requires godot_xr_interaction_toolkit (the abstract XRInputAdapter
## and XRHandTracker helpers it builds on).
```

- [ ] **Step 3: Write `godot_xr_hands/plugin.cfg`**

```ini
[plugin]

name="Godot XR Hands"
description="Procedural hand-joint visualizer for XR, driven by XRHandTracker. Requires godot_xr_interaction_toolkit. Optionally uses the WebXR hand bridge (window.CompanyWebXRHandBridge) for faster startup when godot_webxr_kit's shell is present."
author="OSE"
version="0.1.0"
script="plugin.gd"
```

- [ ] **Step 4: Write `godot_xr_hands/plugin.gd`**

```gdscript
@tool
extends EditorPlugin

## Procedural hand visual. Plain class_name script, works with the plugin
## disabled. Requires godot_xr_interaction_toolkit; the WebXR hand bridge is an
## optional runtime enhancement (feature-detected), not a load-time dependency.
```

- [ ] **Step 5: Verify the project still loads (both addons inert)**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo --quit`
Expected: exits 0; no parse errors for either new addon.

- [ ] **Step 6: Commit**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git add demo/addons/godot_webxr_kit/plugin.cfg demo/addons/godot_webxr_kit/plugin.gd \
        demo/addons/godot_xr_hands/plugin.cfg demo/addons/godot_xr_hands/plugin.gd
git commit -m "Add godot_webxr_kit and godot_xr_hands addon skeletons"
```

---

### Task 2: Move the concrete `WebXRInputAdapter` into the kit

This file is the hidden coupling — it reads `window.CompanyWebXRHandBridge`, which only the shell provides. Moving it out makes the toolkit purely engine-agnostic.

**Files:**
- Move: `demo/addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd` (+ `.uid`) → `demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd`
- Test: `demo/tests/run_tests.gd` (preload path for `WebXRInputAdapter`)

**Interfaces:**
- Consumes from the toolkit: the abstract `res://addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd` (class `XRInputAdapter`), and `xr_hand_gesture_provider.gd` / `xr_hand_tracker_resolver.gd` if referenced — all stay in the toolkit.
- Produces: `WebXRInputAdapter` at `res://addons/godot_webxr_kit/runtime/webxr_input_adapter.gd` — unchanged `class_name` and public API (`get_aim_pose`, `get_grip_pose`, `is_hand_active`, `select_started/ended`, `activate_started/ended`).

- [ ] **Step 1: Confirm nothing INSIDE the toolkit depends on the concrete adapter**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
grep -rn "webxr_input_adapter\|WebXRInputAdapter" demo/addons/godot_xr_interaction_toolkit/runtime/ | grep -v "input/webxr_input_adapter.gd"
```
Expected: no output. If any other toolkit file references it, STOP (the base layer must not depend on a WebXR class).

- [ ] **Step 2: Move the file + uid sidecar**

```bash
git mv demo/addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd \
       demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd
git mv demo/addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd.uid \
       demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd.uid
```

- [ ] **Step 3: Confirm the moved file's preloads still resolve**

Run: `grep -n "preload(" demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd`
Expected: every `preload(...)` targets an existing `res://addons/godot_xr_interaction_toolkit/...` path (those are unchanged by the move — no edit needed). Fix any relative/self path that broke.

- [ ] **Step 4: Update the test runner preload path**

In `demo/tests/run_tests.gd` change:
```gdscript
const WebXRInputAdapter := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd")
```
to:
```gdscript
const WebXRInputAdapter := preload("res://addons/godot_webxr_kit/runtime/webxr_input_adapter.gd")
```

- [ ] **Step 5: Run the headless suite**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd`
Expected: `163 checks, 0 failures`, exit 0. (The suite preloads scripts directly; it does not load `Main.tscn`, so it passes before the scene is rewired in Task 5.)

- [ ] **Step 6: Commit**

```bash
git add demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd \
        demo/addons/godot_webxr_kit/runtime/webxr_input_adapter.gd.uid \
        demo/addons/godot_xr_interaction_toolkit demo/tests/run_tests.gd
git commit -m "Move WebXRInputAdapter into godot_webxr_kit (removes shell coupling from the core toolkit)"
```

---

### Task 3: Move the shell + WebXR scripts + depth visualizer into the kit

**Files:**
- Move: `demo/web/company_webxr_shell.html` → `demo/addons/godot_webxr_kit/web/company_webxr_shell.html`
- Move: `demo/scripts/webxr_bootstrap.gd` (+ `.uid`) → `demo/addons/godot_webxr_kit/runtime/webxr_bootstrap.gd`
- Move: `demo/scripts/browser_capabilities.gd` (+ `.uid`) → `demo/addons/godot_webxr_kit/runtime/browser_capabilities.gd`
- Move: `demo/scripts/webxr_depth_mesh_visualizer.gd` (+ `.uid`) → `demo/addons/godot_webxr_kit/runtime/webxr_depth_mesh_visualizer.gd`

**Interfaces:**
- Produces: `godot_webxr_kit` now owns the shell plus every `CompanyWebXRDepthBridge`/`CompanyWebXRFailure` reader and the WebXR session lifecycle. The depth visualizer (hard-bound to the shell's depth bridge) lives here, not in `godot_xr_hands`.

- [ ] **Step 1: Move the three scripts (+ uid sidecars) and the shell**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
for f in webxr_bootstrap browser_capabilities webxr_depth_mesh_visualizer; do
  git mv "demo/scripts/$f.gd" "demo/addons/godot_webxr_kit/runtime/$f.gd"
  git mv "demo/scripts/$f.gd.uid" "demo/addons/godot_webxr_kit/runtime/$f.gd.uid"
done
git mv demo/web/company_webxr_shell.html demo/addons/godot_webxr_kit/web/company_webxr_shell.html
```

- [ ] **Step 2: Confirm the moved scripts' preloads still resolve**

Run: `grep -rn "preload(" demo/addons/godot_webxr_kit/runtime/*.gd`
Expected: every `preload` targets an existing `res://addons/godot_xr_interaction_toolkit/...` path; none point at `res://scripts/` or `res://web/`. Fix any that do.

- [ ] **Step 3: Commit**

```bash
git add -A demo/addons/godot_webxr_kit demo/scripts demo/web
git commit -m "Move WebXR shell + bootstrap + capability probe + depth visualizer into godot_webxr_kit"
```

---

### Task 4: Move the hand visualizer into `godot_xr_hands`

**Files:**
- Move: `demo/scripts/webxr_hand_visualizer.gd` (+ `.uid`) → `demo/addons/godot_xr_hands/runtime/hand_visualizer.gd`
- Test: `demo/tests/run_tests.gd` (preload path for `WebXRHandVisualizer`)

**Interfaces:**
- Consumes from the toolkit: `xr_input_adapter.gd` (for `XRInputAdapter.Hand`) and `xr_hand_tracker_resolver.gd`, by absolute path — still valid.
- Reads (optional, runtime): `window.CompanyWebXRHandBridge` via `JavaScriptBridge.eval` — a JS-global string, NOT a Godot path, so it introduces no load-time dependency on `godot_webxr_kit`.
- Produces: the hand visual script at `res://addons/godot_xr_hands/runtime/hand_visualizer.gd`. Keep its existing `class_name` unchanged so the demo's `ext_resource` and the test preload resolve by path; the file name changes but the class name does not.

- [ ] **Step 1: Move the file + uid sidecar**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
git mv demo/scripts/webxr_hand_visualizer.gd demo/addons/godot_xr_hands/runtime/hand_visualizer.gd
git mv demo/scripts/webxr_hand_visualizer.gd.uid demo/addons/godot_xr_hands/runtime/hand_visualizer.gd.uid
```

- [ ] **Step 2: Confirm toolkit preloads resolve and there is NO godot_webxr_kit path**

```bash
grep -n "preload(" demo/addons/godot_xr_hands/runtime/hand_visualizer.gd
grep -n "godot_webxr_kit" demo/addons/godot_xr_hands/runtime/hand_visualizer.gd || echo "OK: hand visual has no godot_webxr_kit load-time dependency"
```
Expected: preloads target existing `res://addons/godot_xr_interaction_toolkit/...` paths; second grep prints the OK line. (`window.CompanyWebXRHandBridge` appearing in an `eval` string is fine — it is not a Godot path.)

- [ ] **Step 3: Update the test runner preload path**

In `demo/tests/run_tests.gd` change:
```gdscript
const WebXRHandVisualizer := preload("res://scripts/webxr_hand_visualizer.gd")
```
to:
```gdscript
const WebXRHandVisualizer := preload("res://addons/godot_xr_hands/runtime/hand_visualizer.gd")
```

- [ ] **Step 4: Run the headless suite**

Run: `c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path demo -s res://tests/run_tests.gd`
Expected: `163 checks, 0 failures`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add demo/addons/godot_xr_hands/runtime/hand_visualizer.gd \
        demo/addons/godot_xr_hands/runtime/hand_visualizer.gd.uid demo/tests/run_tests.gd
git commit -m "Move procedural hand visualizer into godot_xr_hands (toolkit-only, optional WebXR bridge)"
```

---

### Task 5: Rewire the demo scene, export config, and remaining tests

**Files:**
- Modify: `demo/scenes/Main.tscn` (5 `ext_resource` script paths)
- Modify: `demo/export_presets.cfg` (`custom_html_shell` path)
- Modify: `demo/tests/run_tests.gd` (any remaining `res://scripts/webxr*` / `res://scripts/browser*` preloads)

**Interfaces:**
- Consumes: the new addon locations from Tasks 2–4.
- Produces: a demo that loads and runs identically, sourcing every WebXR/hand piece from the packages.

- [ ] **Step 1: Update `Main.tscn` ext_resource paths**

Change these five `path=` values (keep each `id=` unchanged):
```
res://scripts/webxr_bootstrap.gd             -> res://addons/godot_webxr_kit/runtime/webxr_bootstrap.gd
res://scripts/browser_capabilities.gd        -> res://addons/godot_webxr_kit/runtime/browser_capabilities.gd
res://scripts/webxr_depth_mesh_visualizer.gd -> res://addons/godot_webxr_kit/runtime/webxr_depth_mesh_visualizer.gd
res://addons/godot_xr_interaction_toolkit/runtime/input/webxr_input_adapter.gd -> res://addons/godot_webxr_kit/runtime/webxr_input_adapter.gd
res://scripts/webxr_hand_visualizer.gd       -> res://addons/godot_xr_hands/runtime/hand_visualizer.gd
```

- [ ] **Step 2: Update `export_presets.cfg` shell path**

Change:
```
html/custom_html_shell="res://web/company_webxr_shell.html"
```
to:
```
html/custom_html_shell="res://addons/godot_webxr_kit/web/company_webxr_shell.html"
```

- [ ] **Step 3: Repoint any remaining test preloads**

Run: `grep -n "res://scripts/webxr\|res://scripts/browser\|res://web/company" demo/tests/run_tests.gd`
Expected after fixes: no output. Repoint each remaining hit to its new `godot_webxr_kit`/`godot_xr_hands` location (bootstrap/capabilities → `godot_webxr_kit/runtime/`, depth → `godot_webxr_kit/runtime/`).

- [ ] **Step 4: Headless load + full suite**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path demo --quit ; echo "load exit: $?"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd 2>&1 | tail -1
```
Expected: load exits 0 with no missing-dependency errors for `Main.tscn`; suite prints `163 checks, 0 failures`.

- [ ] **Step 5: Web export + verify shell embedded**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path demo --export-release Web build/web47/index.html 2>&1 | tail -1
echo "export exit: $?"
ls demo/build/web47/index.wasm demo/build/web47/index.pck demo/build/web47/index.html
grep -c "CompanyWebXRDepthBridge" demo/build/web47/index.html   # shell embedded -> expect >=1
```
Expected: export exits 0; assets present; shell markers present.

- [ ] **Step 6: Commit**

```bash
git add demo/scenes/Main.tscn demo/export_presets.cfg demo/tests/run_tests.gd
git commit -m "Rewire demo scene, export shell path, and tests to the three packages"
```

---

### Task 6: Prove the three packages are cleanly separated

**Files:** verification only (fix + commit if a leak is found).

**Interfaces:**
- Produces: evidence that the DAG holds — toolkit depends on nothing, kit and hands depend only on the toolkit, and no dangling old paths remain.

- [ ] **Step 1: Toolkit is WebXR-free, hands-free, demo-free**

```bash
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
grep -rn "CompanyWebXR\|res://scripts\|res://scenes\|res://web\|godot_webxr_kit\|godot_xr_hands" \
  demo/addons/godot_xr_interaction_toolkit/ && echo "LEAK (fix first)" || echo "CLEAN: toolkit is self-contained"
```
Expected: `CLEAN: toolkit is self-contained`.

- [ ] **Step 2: `godot_xr_hands` has no load-time dependency on the WebXR kit**

```bash
grep -rn "godot_webxr_kit" demo/addons/godot_xr_hands/ || echo "OK: hands does not load-time-depend on the WebXR kit"
grep -rc "godot_xr_interaction_toolkit" demo/addons/godot_xr_hands/runtime/ | grep -v ":0"   # expected: depends on toolkit
```
Expected: first prints the OK line (a `window.CompanyWebXRHandBridge` string inside an `eval` is acceptable and is NOT flagged by this grep); second shows a nonzero toolkit reference count.

- [ ] **Step 3: `godot_webxr_kit` depends on the toolkit, and the toolkit never depends back**

```bash
grep -rc "godot_xr_interaction_toolkit" demo/addons/godot_webxr_kit/runtime/ | grep -v ":0" | head   # expected: nonzero
grep -rn "godot_webxr_kit" demo/addons/godot_xr_interaction_toolkit/ || echo "OK: toolkit does not reference the WebXR kit"
```
Expected: kit references the toolkit; toolkit prints the OK line.

- [ ] **Step 4: No dangling old paths anywhere in the project**

```bash
grep -rn "res://scripts/webxr\|res://scripts/browser_capabilities\|res://web/company_webxr_shell\|runtime/input/webxr_input_adapter" \
  demo --include=*.gd --include=*.tscn --include=*.cfg
```
Expected: no output.

- [ ] **Step 5:** If Steps 1–4 needed a fix, commit it (`Fix package-separation leak: <what>`); otherwise nothing to commit — record results in Task 7 docs.

---

### Task 7: Package docs + architecture/decision updates

**Files:**
- Create: `demo/addons/godot_webxr_kit/README.md`, `demo/addons/godot_xr_hands/README.md`
- Modify: `demo/addons/godot_xr_interaction_toolkit/README.md`
- Modify: `docs/xr_interaction_toolkit_architecture.md`, `docs/DECISION_LOG.md`

**Interfaces:**
- Produces: each addon's README states what it provides, its dependencies, and (for the kit) the one export line to wire the shell.

- [ ] **Step 1: Write `godot_webxr_kit/README.md`**

Cover: WebXR platform layer; **requires `godot_xr_interaction_toolkit`**; contents (`WebXRInputAdapter`, session bootstrap, capability probe, depth-mesh visualizer, HTML shell); required export wiring — `html/custom_html_shell="res://addons/godot_webxr_kit/web/company_webxr_shell.html"`; the shell's JS bridges (`CompanyWebXRHandBridge`, `CompanyWebXRDepthBridge`, `CompanyWebXRFailure`) and which script consumes each; platform notes (Quest works; Galaxy XR multiview gap; Quest depth is gpu-optimized-only, DECISION_LOG 2026-07-06). Note that `godot_xr_hands`, if also installed, consumes `CompanyWebXRHandBridge` from this kit's shell.

- [ ] **Step 2: Write `godot_xr_hands/README.md`**

Cover: procedural `XRHandTracker` hand visualizer; **requires `godot_xr_interaction_toolkit`**; works on any XR runtime that populates `XRHandTracker`; the WebXR hand bridge is an *optional* startup enhancement used only if `godot_webxr_kit`'s shell is present (feature-detected; degrades to `XRHandTracker` otherwise) — so `godot_xr_hands` is usable standalone on native OpenXR.

- [ ] **Step 3: Update the toolkit README**

Add a "Companion packages" section: the toolkit is engine-agnostic and ships only the abstract `XRInputAdapter`; add `godot_webxr_kit` for WebXR (provides `WebXRInputAdapter` + shell), add `godot_xr_hands` for a procedural hand visual. Repoint/remove any line implying `WebXRInputAdapter` or the hand visualizer lives in the toolkit.

- [ ] **Step 4: Update the architecture doc**

In `docs/xr_interaction_toolkit_architecture.md`, replace the single "Addon layout" with the three-addon layout and the dependency DAG (kit → toolkit, hands → toolkit; hands uses the WebXR bridge only as an optional runtime global). Note `webxr_input_adapter.gd` moved to `godot_webxr_kit/runtime/`, and the hand visualizer moved to `godot_xr_hands/runtime/hand_visualizer.gd`.

- [ ] **Step 5: Append a DECISION_LOG entry**

`## 2026-07-06 - Split Into Three Drop-In Packages (toolkit / webxr_kit / xr_hands)` covering: the goal (independent reuse), what moved where, the coupling it fixed (`CompanyWebXRHandBridge` reader now ships with the shell in the kit; the hand visual keeps only an optional feature-detected use of that global), the dependency DAG, and the deferred follow-up: 5 toolkit files use absolute-path `preload(...)` so the toolkit folder can't be renamed yet.

- [ ] **Step 6: Final full verification + commit**

```bash
GODOT="c:/tmp/Godot47/Godot_v4.7-stable_win64_console.exe"
cd "c:/Users/davta/Downloads/godot_webxr_fable5_handoff_v3/godot_webxr_fable5_handoff"
"$GODOT" --headless --path demo -s res://tests/run_tests.gd 2>&1 | tail -1   # 163 checks, 0 failures
"$GODOT" --headless --path demo --export-release Web build/web47/index.html 2>&1 | tail -1  # DONE, exit 0
git add demo/addons/godot_webxr_kit/README.md demo/addons/godot_xr_hands/README.md \
        demo/addons/godot_xr_interaction_toolkit/README.md \
        docs/xr_interaction_toolkit_architecture.md docs/DECISION_LOG.md
git commit -m "Document the three-package split (toolkit + webxr_kit + xr_hands)"
```

---

## Self-Review

**Spec coverage:**
- Three packages → Task 1 creates both new skeletons; Tasks 2–4 populate them; toolkit remains the base. ✓
- WebXR into its own kit + move shell → Tasks 2–3 (adapter, shell, bootstrap, capability probe, depth viz). ✓
- Hand + depth split apart per the decision → depth stays in `godot_webxr_kit` (Task 3), hand visual to `godot_xr_hands` (Task 4). ✓
- `godot_xr_hands` independent of the WebXR kit → Task 4 Step 2 + Task 6 Step 2 assert no `godot_webxr_kit` path; the bridge is only a feature-detected JS global. ✓
- Hidden `CompanyWebXRHandBridge` coupling in the core → removed by moving `WebXRInputAdapter` out (Task 2); Task 6 Step 1 asserts the toolkit is `CompanyWebXR`-free. ✓
- "Plan it first" → this document; no code changed yet. ✓

**Placeholder scan:** every code/edit step has the exact string or command. No TBD/TODO. The single conditional (Task 6 Step 5) states when to skip.

**Path/type consistency:** moved-file targets are identical across the move task, the rewire task, and the Task 6 greps (`godot_webxr_kit/runtime/webxr_input_adapter.gd`, `.../web/company_webxr_shell.html`, `godot_xr_hands/runtime/hand_visualizer.gd`). `class_name` identifiers are unchanged by the moves, so `class_name`-based references keep resolving; only explicit `preload`/`ext_resource`/`custom_html_shell` paths needed rewiring, and each is enumerated. The hand visualizer's file name changes (`webxr_hand_visualizer.gd` → `hand_visualizer.gd`) but its `class_name` does not — every path reference to it (Main.tscn id `4_hands`, the test preload) is repointed in Tasks 4–5.

**Deferred (called out, not dropped):** the 5 absolute-path `preload(...)` files that lock the toolkit folder name — Task 7 Step 5 records it as a follow-up, out of scope here.
