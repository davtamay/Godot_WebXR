# Claude/Fable Instructions: Godot WebXR / Web Export

## Mission

Make Godot the leading open-source SDK for browser-native and standalone XR —
matching or beating the fidelity, reliability, and ergonomics of Unity's XR
Interaction Toolkit and Meta's Interaction SDK, on open standards.

The original mission was a feasibility question: *can Godot do this?* That
question has been answered affirmatively and is closed. The work now is
quality, not viability.

## Repository map

Four locations, easy to confuse. Check which one a task belongs to before
touching anything.

| Location | What it is |
|---|---|
| `Repos/Godot_WebXR_gh` | This repo. Research, evidence, demos, web shell, export tooling. Default branch `feature/xr-interaction-toolkit-addon` (not `master`, which is stale). |
| `Repos/godot-xr-suite` | The addon suite — the actual product. Trunk is `master`. |
| `Documents/Godot_WebGPU` | A Godot **engine fork** carrying the WebGPU backend as a rebasable patch stack. Has its own `CLAUDE.md` with strict rules — read it before touching that repo. |
| `Documents/Unity Samples/Hand-Tracking-Template` | Reference only. Meta ISDK under the Oculus SDK License — read for technique, never copy code. |

**Coupling to know about:** `Godot_WebXR_gh/demo/addons/*` are **symlinks into
the `godot-xr-suite` working tree**, not pinned commits. Whatever branch the
suite has checked out is what the demo builds against. The two repos must be
kept on corresponding branches.

## Hard boundary — evidence before claims

**This section's bar was met, not waived.** The original rule was: *do not claim
Godot renders through WebGPU unless source-level evidence proves it.* That
evidence now exists — see below. The discipline it encoded still applies to
every new claim.

Current, evidenced state:

- **Stock Godot web export** uses WebAssembly + WebGL2 via the Compatibility
  renderer. Unchanged, and still the default and the safe path.
- **The `Godot_WebGPU` fork** implements a WebGPU backend and renders the
  Forward+ clustered renderer in-browser, validated on two independent
  implementations (Dawn/Chrome and wgpu/naga/Firefox). Its `CLAUDE.md` "Current
  state" section is the authoritative record.
- **WebGPU is not automatically the better target.** Chrome's `XRGPUBinding`
  performs a full-resolution copy per frame that defeats reprojection on some
  devices, which is why WebGL remains the default on Galaxy and WebGPU is
  opt-in. Renderer choice is a per-device measurement, not a preference.
- **WebGPU capability detection is still not renderer support.** Unchanged.

Still forbidden: asserting that any *particular* feature renders through
WebGPU without having verified it, in that fork's log or by running it.

## Architecture preference

Use the lowest-risk layer that solves the problem:

1. Project code
2. Editor plugin
3. Custom HTML shell
4. JavaScriptBridge
5. GDExtension
6. C++ module
7. Custom export template
8. Minimal core source patch

Do not modify Godot source unless you can explain why the higher layers cannot
solve the problem. Layer 8 is no longer hypothetical — it is an active,
disciplined practice confined to the `Godot_WebGPU` fork under that repo's own
rules. That does not lower the bar for reaching for it from here.

**Layer 5 carries a web-specific cost.** Default web export templates ship
`variant/extensions_support=false`; GDExtension on web requires the `dlink`
template variant, making it effectively a layer-7 commitment for web targets.
GDScript efficiency is the primary lever for WebXR, not a fallback. See
`docs/EVIDENCE_LOG.md`.

## Required workflow

Before implementation:

1. Inventory existing repos, plugins, examples, forks, and proposals.
2. Check official Godot docs and source.
3. Identify reusable existing work.
4. Read the relevant session history before designing — much of the *why*
   lives in `Godot_WebGPU/CLAUDE.md`'s log rather than in code comments.
5. Produce a customization matrix.
6. Produce a source-modification boundary list.

During implementation:

1. Keep diffs minimal.
2. Use stock Godot first; renderer/backend work belongs in the fork, not here.
3. Prefer the Compatibility/WebGL2 path as the default target; treat WebGPU as
   an opt-in measured against it.
4. Respect the addon dependency DAG declared in each addon's `xr_package.cfg`.
   `xr.interaction` is `layer="foundation"` with `requires=[]` and must stay
   installable standalone.

## On-device earn-in

A replacement must prove itself in-headset, not only in metrics or on paper.

Precedent: a more sophisticated microgesture engine was architecturally better
and measurably *less reliable on-device*, and was rolled back to the older
recognizer. The rule recorded from it — **working code is not discarded for
purity** — governs every change to tracking, gestures, and interaction feel.

Corollary: much of the suite's behaviour is tuned from repeated on-device
sessions and differs from the addon defaults. Find the tuned values before
"fixing" them, and treat them as the baseline to beat.

Second corollary: measure where the latency actually is. Light-estimation
smoothing was once raised nearly 4x and changed nothing — the delay was the
platform's own convergence time.

## Stop conditions

Stop and ask for review if:

- A task appears to require Godot source modification *from this repo*.
- A task would create a second long-lived fork, or move renderer work out of
  the existing one.
- A change would invert the addon dependency DAG or break standalone install.
- Existing ecosystem work already solves the problem.
- A change would alter on-device-tuned interaction values without an
  on-device verification plan.
- The evidence conflicts with this spec.

## Required output format

For research tasks, return:

- finding
- evidence/source
- file path or repo link
- implementation layer
- reuse potential
- risk level
- recommendation

For implementation tasks, return:

- summary
- files changed
- how to run
- how to test
- known limitations
- what was intentionally not done
- next smallest step

## Licensing

The suite is open source and intended as a standard others adopt. Reference
material is not.

Meta's Interaction SDK is under the Oculus SDK License, which is **not**
compatible. Techniques and the knowledge that they work at production scale may
transfer; code, transcription, and adaptation may not. Implement from published
literature and cite it. Treat any constants quoted from reference material as
order-of-magnitude sanity checks, never as values to ship.

## Spec challenge / innovation mode

The spec is a baseline, not a prison. You are explicitly encouraged to find a
better conclusion, better architecture, better implementation path, cheaper
maintenance model, stronger benchmark, or existing ecosystem project that
changes the recommendation.

Read `docs/SPEC_CHALLENGE_PROTOCOL.md` before beginning research or
implementation.

When you find a better idea, do not silently change the implementation. Create
a proposal using the Spec Challenge Proposal format and add it to the relevant
docs or task response.

You may challenge:

- whether Godot is the best tradeoff
- whether WebGL2 or WebGPU is the right default for a given device
- whether the demo scope is right
- whether a browser-native WebGPU engine should be paired with or replace Godot
- whether GDExtension, C++ modules, or custom export templates are worth the
  maintenance cost
- whether a different test or benchmark would produce better evidence

You may not silently override:

- no unevidenced WebGPU renderer claims
- no renderer/backend work outside the fork
- no source modifications from this repo without approval
- no skipping evidence and ecosystem inventory
- no copying license-incompatible reference code
- no discarding on-device-tuned behaviour without on-device verification
- no hiding maintenance, performance, build-size, hosting, or rebase costs

For every major recommendation, include:

1. Blue-team case: why it could work.
2. Red-team case: why it could fail.
3. Evidence required to decide.
4. Smallest prototype that would prove or disprove it.

Maintain:

- `docs/INNOVATION_BACKLOG.md`
- `docs/DECISION_LOG.md`
