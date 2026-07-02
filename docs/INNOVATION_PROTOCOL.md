# Innovation Protocol: Bounded Autonomy for Fable 5

## Purpose

Fable is allowed and encouraged to improve the spec when evidence shows a better path. The spec is the baseline, not a cage. However, Fable must not silently change the objective, architecture, or technical claims. Better ideas must be captured as proposals, compared against the baseline, and approved before implementation when they increase risk or scope.

## Core principle

**Challenge assumptions aggressively. Change implementation conservatively.**

The project wants Fable to find better conclusions, better architectures, existing reusable work, cheaper maintenance paths, stronger demos, and more efficient workflows. The project does not want speculative renderer work, hidden fork debt, or unverified claims.

## Innovation budget

Fable should spend effort in this order:

1. Reuse existing projects, plugins, demos, and patterns.
2. Reduce maintenance cost.
3. Improve evidence quality.
4. Improve demo clarity and leadership value.
5. Improve performance/build-size measurement.
6. Improve architecture boundaries.
7. Only then propose deeper engine work.

## Fable may propose changes when it finds

- an existing plugin/repo/demo that solves part of the task;
- a lower-maintenance layer than the current spec selected;
- a better prototype slice that proves more value for less work;
- a more accurate WebXR/WebGPU/Godot limitation;
- a measurable performance/build-size improvement;
- a better way to preserve upstream Godot compatibility;
- a better cross-platform test strategy;
- evidence that a current spec assumption is wrong;
- an opportunity to contribute upstream instead of maintaining a private patch.

## Proposal format

Every suggested improvement must be written as an Architecture Improvement Proposal:

```md
# AIP-NNN: <short title>

## Summary
<one paragraph>

## Baseline spec says
<what the current spec expected>

## New evidence or insight
<docs/source/repo/test evidence>

## Proposed change
<what should change>

## Why this is better
<benefit: less risk, smaller size, better performance, less maintenance, faster demo, more accurate claim>

## Cost
<engineering time, tooling, build ownership, test burden>

## Risks
<new risks introduced>

## Rebase/upstream impact
<none, low, medium, high, very high>

## Decision needed
<implement now / research more / ask human / defer>
```

## Decision thresholds

Fable may directly implement improvements that are:

- project code only;
- documentation only;
- measurement/reporting only;
- custom HTML shell only;
- JavaScriptBridge only;
- editor-plugin prototype only;
- reversible within one commit;
- no Godot source modification;
- no renderer/backend changes;
- no long-lived fork.

Fable must stop and ask for review before implementing improvements that involve:

- Godot source modifications;
- renderer/backend work;
- custom export template ownership;
- GDExtension on web;
- C++ modules;
- new external runtime dependencies;
- a second engine stack becoming part of the product instead of only a benchmark;
- claims that Godot renders through WebGPU;
- changes that increase future rebase burden.

## Opportunity register

Fable must keep `research/opportunity_register.md` updated. Each entry should include:

- opportunity;
- evidence;
- benefit;
- implementation layer;
- maintenance cost;
- risk;
- recommended action.

## Red-team requirement

For each major recommendation, Fable should also write the strongest opposing argument:

- Why this might fail.
- Why Unity might still be better.
- Why a browser-native WebGPU engine might be better.
- Why Godot might cost more than expected.
- What evidence would reverse the recommendation.

## Anti-drift rules

Fable must not:

- expand scope silently;
- rewrite the project around a new engine without approval;
- replace the Godot demo with a Babylon/PlayCanvas/Three.js demo;
- start renderer/backend work in Phase 1;
- treat WebGPU detection as rendering support;
- make leadership claims not backed by docs, source, or measurements;
- over-optimize before the first tangible demo runs.

## Preferred output after each long work session

```md
## What I learned

## What changed in my recommendation

## Better ideas discovered

## Opportunities added

## Risks added

## Evidence collected

## Work completed

## What I intentionally did not do

## Next smallest step
```
