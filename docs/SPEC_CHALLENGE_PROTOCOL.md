# Spec Challenge Protocol

## Purpose

This project should not trap Claude/Fable inside the initial spec if a better path exists. The spec defines the current best-known plan and hard safety boundaries, not the ceiling of the solution.

Fable is encouraged to challenge assumptions, propose better architectures, find existing ecosystem work, reduce maintenance cost, improve performance, or identify a different conclusion if evidence supports it.

## Hard constraints that cannot be silently overridden

Fable may challenge almost anything except these constraints without explicit human approval:

1. Do not claim Godot renders through WebGPU unless source-level evidence proves it.
2. Do not modify Godot source during Phase 1 unless the user explicitly approves a plan.
3. Do not introduce renderer/backend work in Phase 1.
4. Do not skip the existing ecosystem inventory before custom implementation.
5. Do not hide maintenance cost, build-size cost, performance cost, or rebase risk.
6. Do not present WebGPU capability detection as WebGPU renderer support.
7. Do not make a production recommendation without measured evidence or clearly labeled assumptions.

## Challengeable assumptions

Fable should actively challenge these assumptions when evidence suggests a better path:

- Godot is the best long-term open-source option.
- Godot WebGL2/WebXR is good enough for the target product.
- A custom HTML shell is the best browser integration boundary.
- GDExtension or C++ modules are worth using for this project.
- The company should prioritize Godot over Babylon.js, PlayCanvas, Three.js, Unity, or another stack.
- The demo scope is the smallest useful product slice.
- Existing Godot XR ecosystem work is sufficient.
- The packaging/performance tradeoff is acceptable.
- A fork-minimized Godot distribution is maintainable.

## Required output when challenging the spec

When Fable finds a better idea or a better conclusion, it must create a proposal using this format:

```md
# Spec Challenge Proposal: <title>

## Summary

What should change?

## Why the current spec may be suboptimal

What assumption, constraint, or design choice is being challenged?

## Evidence

Link to official docs, source files, repos, benchmarks, issues, or measured results.

## Proposed alternative

Describe the alternative architecture or workflow.

## Benefits

What improves? Examples: performance, build size, maintenance, capability, reuse, schedule, risk.

## Costs / sacrifices

What gets worse? Examples: editor workflow, skill requirements, custom code, hosting complexity, portability.

## Maintenance impact

What will the company own over time?

## Rebase/upstream impact

Will this make future Godot updates easier or harder?

## Prototype path

What is the smallest tangible test that proves or disproves this alternative?

## Recommendation

Adopt now, research later, reject, or escalate for human decision.
```

## Exploration lanes

Fable should run exploration in parallel lanes, then compare them:

### Lane A: Stock Godot WebGL2/WebXR

Prove the supported Godot web path with minimum custom code.

### Lane B: Godot-plus-tooling

Determine how much value comes from editor plugins, validators, custom shell, JavaScriptBridge, and reusable XR templates.

### Lane C: Browser-native WebGPU/WebXR benchmark

Investigate whether Babylon.js, PlayCanvas, Three.js, or raw WebGPU delivers substantially better browser graphics/performance with acceptable tooling tradeoffs.

### Lane D: Source/custom-template feasibility

Map what Godot source/custom export-template work would be required for deeper integration, without implementing renderer changes.

### Lane E: Unity baseline

Where practical, compare build size, startup time, runtime performance, workflow, and engineering risk against equivalent Unity WebGL/WebGPU/WebXR output.

## Red-team / blue-team review loop

For every major recommendation, Fable should produce two perspectives:

### Blue-team case

Why this path is attractive and how to make it work.

### Red-team case

Why this path might fail, where it is expensive, and what hidden costs leadership may miss.

### Decision gate

What evidence would change the recommendation?

## Efficiency mandate

Fable should look for ways to reduce work:

- reuse existing plugins/templates before building new ones
- generate small benchmark scenes instead of large demos
- automate build-size measurement early
- avoid custom source unless strictly needed
- prefer reversible experiments
- create scripts that can be rerun by humans
- keep implementation diffs small and easy to discard

## Innovation backlog

Fable should maintain `docs/INNOVATION_BACKLOG.md` with any promising idea that is outside the immediate sprint. Each idea should include:

- title
- hypothesis
- implementation layer
- evidence needed
- expected benefit
- expected cost
- risk
- suggested prototype
- priority

## Final decision standard

The final recommendation must be evidence-led. It is acceptable for Fable to conclude any of the following:

- Godot is the best strategic path.
- Godot is viable only for specific web/XR product types.
- Godot should be paired with a browser-native WebGPU engine.
- Unity remains better for production while Godot remains a strategic R&D path.
- A Godot source/fork investment is not currently justified.
- A narrow Godot source/custom-template investment is justified.

The goal is the best company decision, not defending the initial plan.
