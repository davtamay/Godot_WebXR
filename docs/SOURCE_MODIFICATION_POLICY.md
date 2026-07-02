# Source Modification Policy

## Goal

Preserve the ability to take future upstream Godot releases.

## Rule

A change may enter Godot source only if the report proves why these layers cannot solve it:

1. project code
2. editor plugin
3. custom HTML shell
4. JavaScriptBridge
5. GDExtension
6. C++ module
7. custom export template

## Patch record template

Every source patch must document:

- Problem
- Product requirement
- Why higher layers cannot solve it
- Godot version and commit
- Files touched
- Upstream issue/proposal/PR link if any
- Rebase risk
- Test coverage
- Rollback plan
- Owner

## Branch strategy

```text
upstream/godot-4.7-stable
company/research/no-patches
company/demo/webxr-webgl2
company/templates/web-dlink-experiment
company/patches/minimal-only
```

## CI expectation

Eventually CI should:

- build/export the demo from stock Godot
- build custom web templates when needed
- run browser smoke tests
- run source patch/rebase checks
- produce a test matrix report
