# ChatGPT Review Prompt

Review Fable's Godot WebXR feasibility work against the spec.

Check:

1. Did it avoid unnecessary source modification?
2. Did it correctly separate WebGPU detection from WebGPU rendering?
3. Did it use Godot’s supported WebGL2/WebXR path?
4. Did it use the right customization layer?
5. Are there maintainability risks?
6. Are there hidden browser/XR lifecycle issues?
7. Are there performance or graphics-quality risks?
8. Are there claims that need to be softened for leadership?
9. What should be the next smallest implementation step?

Return:

- pass/fail by requirement
- architecture concerns
- technical corrections
- recommended next task
- leadership-safe summary


## Spec Challenge Protocol

Read `docs/SPEC_CHALLENGE_PROTOCOL.md`. You are encouraged to challenge the spec if you find a better, cheaper, more maintainable, more performant, or more honest path. Do not silently change scope. Produce a Spec Challenge Proposal with evidence, tradeoffs, maintenance impact, rebase impact, and smallest prototype. Maintain `docs/INNOVATION_BACKLOG.md` and `docs/DECISION_LOG.md` when relevant.

Hard boundaries remain: no false Godot WebGPU rendering claims, no Phase 1 renderer/backend work, no Phase 1 Godot source modifications without approval, and no skipping ecosystem inventory or benchmark evidence.
