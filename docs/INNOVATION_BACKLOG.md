# Innovation Backlog

Fable should add ideas here when it finds a better architecture, cheaper implementation path, reusable ecosystem project, benchmark method, or strategic alternative.

| Priority | Idea | Hypothesis | Layer | Evidence Needed | Benefit | Cost/Risk | Prototype |
|---|---|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

---

## Hand-tracking fidelity: techniques worth porting from Meta's ISDK (2026-07-24)

Source: gap analysis of `godot-xr-suite` against Meta Interaction SDK v205, read
locally from `com.meta.xr.sdk.interaction@c7b9fd4a82b0` (678 C# files) in the
Hand-Tracking-Template Unity sample.

**Licensing constraint on everything below.** The ISDK ships under the Oculus
SDK License, which is not compatible with this suite. No ISDK code may be
copied, transcribed, or adapted. What transfers is *technique* plus the
knowledge that it works at production scale; implementations come from
published literature. Meta's constants are order-of-magnitude sanity checks,
not values to ship.

Ordered by quality-per-line, not by importance.

| # | Technique | Current state in suite | Why it matters | Layer | Est. size |
|---|---|---|---|---|---|
| 1 | **Tweened grab movement with perceived distance.** Travel time = `max(translation_m, rotation_deg × 0.5/360)`, so a 180° flip and a 25 cm move take equally long. | `MovementType.INSTANT` is the default; `xr_grab_interactable.gd:311` is a bare transform assignment. This *is* the quick-snap. | Highest felt improvement per line in the whole comparison. Fixes the single most-cited complaint. | Project code | S |
| 2 | **RANSAC throw velocity with a release dead-zone.** Ring buffer ~10 samples, discard the newest 2 outright, then consensus over sample pairs instead of averaging. | `xr_grab_interactable.gd:392` is an unweighted mean over the last 5 samples — which weights the release-corrupted frames most heavily. | Directly explains hand-thrown objects flying sideways. Independent of everything else. | Project code | S |
| 3 | **Adaptive signal conditioning (One Euro).** Filter at the data source so all consumers inherit it. Per-region and per-source parameter sets. | None. Three fixed-alpha lerps inside individual recognizers; everything else reads raw joints. | Foundation. Most of the "Meta feels more reliable" gap. Every other item improves once this lands. | Project code | M |
| 4 | **Synthetic/display hand.** A second rendered skeleton with per-joint freedom levels, wrist lock modes, and *separate* lock/unlock easing curves. | None. The visualizer renders tracked joints directly; no way to display a pose differing from the tracked one. | One system behind four observed behaviours: fingers wrapping objects, finger stopping on a button face, trigger squeeze, hand appearing at a grip while the real hand is elsewhere. | Project code | L |
| 5 | **Joint translation+rotation grab scoring over surfaces.** Score both, normalized so they're commensurate, with a tunable weight — against box/cylinder/sphere/bezier *surfaces*, not discrete points. | `xr_grab_interactable.gd:226` is a single `distance_squared_to`. | Enables grab-anywhere-along-the-body and gesture-dependent grips (pinch → nozzle, palm → body). | Project code | L |
| 6 | **Poke fidelity beyond hysteresis.** Separate normal *and tangent* hover enter/exit, cancel-select thresholds, minimum approach angle, drag-vs-press thresholds with easing, position pinning, recoil assist with velocity-dependent window expansion. | `xr_pokeable.gd` has press/release depth only. | Approach angle is what makes slapping buttons work without false fires; pinning is the "finger stops on the button" feel; recoil prevents double-fires. | Project code | M |
| 7 | **Analog pinch strength and a general "use" axis.** Separate *grab* from *use*: once held, finger curl drives a 0..1 value. | `pinch_distance` exists as a gesture feature only. `xr_sprayer` / `xr_blaster` are bespoke rather than riding a shared axis. | Turns one-off props into a reusable pattern; prerequisite for analog trigger behaviour. | Project code | S |
| 8 | **Locomotion mode gate.** An arc of angular gate sections scored against wrist angle with hysteresis, selecting locomotion mode. | None. | Pure math on joint poses — fully portable, no platform dependency. The mode selector observed in the Meta demo. | Project code | M |

### Explicitly NOT portable

**Wide motion mode / gaze-assisted modes** are `OVRManager` runtime flags backed
by Quest-only OpenXR extensions, not ISDK code. No ISDK source exists to learn
from. Reaching parity would need a vendor extension wrapper, which is a
different kind of work with a platform lock-in cost — it would not be portable
to WebXR, which is this project's primary target.

### Where the suite is already ahead

The microgesture recognizer works on any runtime exposing hand joints. Meta's
delegates to the Quest system recognizer. For an open, cross-runtime standard
this is the better design and should not be traded away for parity.

`XRHandTrackerResolver`'s scored, frame-cached tracker resolution is more robust
than a fixed-path lookup and has no ISDK equivalent — it exists because WebXR
runtimes expose canonical tracker paths before they carry useful joints.

### Status (updated 2026-07-25)

| # | Item | Size | Status |
|---|---|---|---|
| 1 | Tweened grab movement with perceived distance | S | **Done** — `transit_duration` / `transit_blend` |
| 2 | Consensus throw velocity with release dead-zone | S | **Done** — `throw_consensus`, `throw_peak_bias = 0.80`, earned in on device |
| 3 | Adaptive signal conditioning (One Euro) | M | **Done** — conditioning on; every consumer routed through the resolver |
| 7 | Analog pinch strength / general "use" axis | S | **Done** — `use_value` / `set_use_value`; sprayer and blaster NOT yet wired to it |
| 4 | Synthetic/display hand | L | Not started |
| 5 | Grab scoring over surfaces | L | Not started |
| 6 | Poke fidelity beyond hysteresis | M | Not started — **recommended next** (medium, no dependencies) |
| 8 | Locomotion mode gate | M | Not started |

Item 3's design note: `godot-xr-suite/docs/hand-signal-conditioning-design.md`.
Original sequencing was 3 then 4; 1, 2 and 7 were pulled forward because they
are S-sized and each fixed a directly reported feel complaint.

Open duplication from item 7: `trigger_progress` vs `use_value` — decide and
collapse one.

Full open-bug list and cross-device state: `docs/SESSION_HANDOFF_2026-07-25.md`.
