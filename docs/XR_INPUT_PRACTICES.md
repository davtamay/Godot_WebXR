# XR input practices

How the two mature XR interaction stacks solve the problems this suite keeps
re-solving by hand, what the evidence is, and which practice we adopt.

Sources read on disk, not recalled:

| Stack | Version | Path |
|---|---|---|
| Unity XR Interaction Toolkit | 3.0.5 | `Repos/KomodoSandbox/KomodoSandbox/Library/PackageCache/com.unity.xr.interaction.toolkit` |
| Unity XR Hands | 1.5.0 | `.../com.unity.xr.hands` |
| Meta Interaction SDK | (Hand-Tracking-Template) | `Documents/Unity Samples/.../com.meta.xr.sdk.interaction` |
| Godot OpenXR module | fork checkout | `Documents/Godot_WebGPU/modules/openxr` |

ISDK is Oculus-SDK-licensed. Technique only; no code, no constants.

---

## Practice 1 — Stabilize the ray. Do not gate it.

**Finding.** Unity does not detect bad hand data and suppress it. It accepts
every frame and stabilizes the *presentation*. The entire mechanism is one
component, `XRTransformStabilizer`.

**Evidence.**
`com.unity.xr.interaction.toolkit/Runtime/Inputs/XRTransformStabilizer.cs`.
The core is `CalculateStabilizedLerp(distance, timeSlice)`, where `distance` is
the error divided by a threshold (`positionStabilization = 0.25 m`,
`angleStabilization = 20°`):

- error at or above the threshold → lerp 1.0, the raw pose passes through at
  full speed and zero latency
- error near zero → lerp near zero, the previous pose is held
- in between → proportional

So it is a *deadband that scales*, not a low-pass filter. It needs no velocity
estimate, no cutoff tuning, and no filter state beyond the last pose. Their own
comment on the naive version: it "feels great in VR but is frame-dependent" —
the released version reconstructs the 90 fps behaviour analytically across up to
three frame slices, so the feel is identical at 72, 90, and 120 Hz.

The second half is subtler and is the part that matters for a *ray*. When an
aim target is supplied, `StabilizeOptimalRotation` computes two candidate
rotations — the previous rotation, and `antiRotation`, the rotation that keeps
the ray's **endpoint** parked where it was last frame — and takes whichever
requires less correction. Jitter at the wrist that would swing the far cursor
metres is cancelled at the endpoint rather than at the source.
`CalculateRotationParams` then scales the stabilization budget by
`1 + log(rayLength)`, clamped to 3×: **the further you point, the more
stabilization you get**, because the same angular jitter costs more at range.

**Contrast with what we built.** Our path is One Euro smoothing on a direction
derived from an ~8 cm wrist→knuckle baseline, plus an FOV cone that suppresses
the hand entirely. Both fight the symptom at the source. Neither knows how far
the ray is pointing, so both are mistuned at exactly the distances where jitter
is most visible.

**Practice.** Stabilize at the endpoint, budget by ray length, deadband rather
than filter, and compensate for frame rate explicitly. Reserve suppression for
data that is genuinely absent.

**Layer:** project code (addon runtime). **Risk:** low — additive, and it
replaces machinery rather than adding to it.

---

## Practice 2 — "No confidence signal" is not a Godot limitation.

**Finding.** Unity's per-joint tracking state carries no confidence value
either. `XRHandJointTrackingState` is exactly `Radius | Pose | LinearVelocity |
AngularVelocity | WillNeverBeValid | HighFidelityPose`
(`com.unity.xr.hands/Runtime/Enums.cs`). Frame-level success is
`UpdateSuccessFlags`: root pose and joints, per hand, and nothing else.

That is the same information Godot's `XRHandTracker` exposes. Unity is not
holding a signal back from us — **OpenXR core hand tracking does not define
one**, which is why Unity's answer is Practice 1 and not a gate.

**Correction to the record.** Earlier in this work I concluded from an API probe
that "Godot exposes no confidence signal, so a 1:1 port of Meta's
`LastKnownGoodHand` is impossible." The first clause is true *of
`XRHandTracker`* and false of the platform — see Practice 3. The gate built on
that conclusion is therefore solving a problem the runtime can answer directly.

**Practice.** Before hand-rolling a signal, check whether an OpenXR extension
already publishes it. Absence from one Godot class is not absence from OpenXR.

---

## Practice 3 — Take the aim ray from the platform. It is the portable path.

**Finding, and the root cause of this class of bug.** Every platform we target
already publishes a pointing ray for hands. We ignore all of them and derive our
own from raw joints. The derived ray is the device-specific bespoke path; the
platform ray is the uniform one.

### WebXR — already available, on every device, in stock Godot

`webxr_interface_js.cpp:1006-1008` takes the browser's `targetRaySpace` pose
(read at `native/library_godot_webxr.js:835`) and sets it as **both** `default`
and `aim` on the input source's tracker. In WebXR a tracked hand *is* an input
source with a target ray, so this happens for hands exactly as for controllers,
on any WebXR runtime, with no extension to negotiate and nothing to bind.

`targetRayMode` is surfaced to GDScript as
`WebXRInterface.get_input_source_target_ray_mode()`
(`TARGET_RAY_MODE_TRACKED_POINTER` for hands and controllers,
`TARGET_RAY_MODE_GAZE`, `TARGET_RAY_MODE_SCREEN`), so an author can also tell
*what kind* of pointer a source is and adapt.

Caution: on WebXR the **hand tracker's** `default` pose is the palm
(`webxr_interface_js.cpp:1120`), while the **controller tracker's** `default` is
the target ray. Two trackers, two conventions, same hand. Read `aim`
explicitly rather than `default`.

### OpenXR — the same pose, behind a cross-vendor extension we do not bind

`XR_EXT_hand_interaction` is an `EXT` (multi-vendor) extension, not a Meta one.
It exists precisely because `XR_FB_hand_tracking_aim` was vendor-specific.
Binding it is what makes hand aim work the *same* on Quest, Pico, Vive, Android
XR, and SteamVR — not what ties us to one of them.

**Evidence.**
`Godot_WebGPU/modules/openxr/extensions/openxr_hand_interaction_extension.cpp:73-96`
registers `/interaction_profiles/ext/hand_interaction_ext` with, per hand:

| Path | What it gives us |
|---|---|
| `/input/aim/pose` | runtime's own pointing ray — ergonomically placed, runtime-stabilized |
| `/input/pinch_ext/pose` | pinch anchor |
| `/input/poke_ext/pose` | poke anchor |
| `/input/grip/pose`, `/input/grip_surface/pose` | grip / palm |
| `/input/pinch_ext/value` + `/ready_ext` | pinch strength, plus the runtime's readiness flag |
| `/input/aim_activate_ext/value` + `/ready_ext` | far-select, plus readiness |
| `/input/grasp_ext/value` + `/ready_ext` | whole-hand grasp, plus readiness |
| `swipe_{left,right,forward,backward}_meta`, `tap_thumb_meta` | microgestures, gated on `XR_META_hand_tracking_microgestures` |

Our bound profiles, from
`demo/addons/godot_webxr_kit/openxr/default_action_map.tres`, are exactly two:
`khr/simple_controller` and `oculus/touch_controller`. No hand profile. So with
hands, `aim` resolves from nothing and we fall back to deriving direction from
`knuckle - wrist` — an 8 cm baseline, which amplifies joint noise into ray
angle. That derivation is the jitter source I have been filtering downstream of.

`ready_ext` is a **per-input** readiness flag, not a general tracking
confidence — the spec's guarantee is that the paired value is meaningful, which
in practice means the runtime considers the hand observable enough for that
interaction. That is narrower than Meta's `IsHighConfidence`, and it is exactly
the question our FOV cone was estimating geometrically.

### The practice

One resolution order, identical on every backend, decided per hand per frame:

1. the tracker's `aim` pose, if the platform published one this frame —
   WebXR always does; OpenXR does once `XR_EXT_hand_interaction` is bound and
   the runtime advertises it
2. otherwise the derived `wrist → knuckle` ray we use today

No device is named in that rule and no device is required to support anything.
A runtime that publishes an aim pose gets the good path automatically; one that
does not keeps exactly today's behaviour. Godot only activates the OpenXR
profile when the extension is present, so the fallback is load-bearing, not
decorative — and it is what keeps the suite honest on unknown hardware.

The same shape applies to readiness: use `ready_ext` where it exists, fall back
to our own estimate where it does not, and never let the fallback be worse than
what we ship today.

**Layer:** 1 (project resource + addon code). No engine change.
**Risk:** medium — it changes where every hand pose comes from, so it must be
earned in on device against the current behaviour, not assumed better.
**Reuse:** high; this is stock Godot, already shipped, on both backends.

**Microgestures are additive only.** Our recognizer is the portable path and
stays the default. `*_meta/click` is a Quest-only accelerator layered on top,
never a replacement.

---

## Practice 4 — Separate "unobservable" from "gone". (Already adopted.)

**Finding.** Meta's `LastKnownGoodHand` substitutes the last good pose while the
hand is **connected** and only reports untracked when it is **disconnected** —
two distinct states, never conflated.

**Evidence.** `com.meta.xr.sdk.interaction/Runtime/Scripts/Input/Hands/DataModifiers/LastKnownGoodHand.cs`.
Note also that it marks substituted data `PoseOrigin.SyntheticPose` — downstream
consumers can tell a real pose from a held one. We have no equivalent
provenance field.

**Status.** Implemented in `XRHandConfidenceGate`, and it was the one change in
this line of work that survived device testing: a hand out of view freezes
rather than vanishing. Keep it.

**Gap.** No provenance. Worth adding when the gate is next touched, so a
consumer can choose to ignore held poses rather than trust them silently.

---

## What this changes

The drift I have failed to fix across eight attempts is being attacked at the
wrong layer. The ordered plan the evidence supports:

1. Prefer the platform `aim` pose, derived ray as fallback (Practice 3).
   Removes the jitter at its source. Free on WebXR; one action-map binding on
   OpenXR.
2. Replace the One Euro aim smoothing with endpoint-anchored,
   range-scaled stabilization (Practice 1). Backend-independent, so it also
   improves the fallback path and controllers.
3. Re-measure the FOV cone only after 1 and 2. It may become unnecessary; if
   `ready_ext` is available it is certainly a better signal than a hand-tuned
   cone angle.

Each step is separately testable on device, and step 1 alone may be sufficient.
Step 2 is the one that helps every device regardless of what its runtime
publishes, which is an argument for doing it even if step 1 succeeds.

---

## What actually happened

Three things were tried on device. The order they are listed in is not the
order of their value.

**Step 1 (platform aim) is bound but inert.** See above. No device has
confirmed it.

**Step 2 (`XRAimStabilizer`) shipped and helped slightly.** A range-scaled
deadband replacing the One Euro pass on the derived ray. The endpoint anchoring
was implemented and then removed: no test could be written that asserted a
guarantee it actually makes, because when the direction is steady, holding it
is already a zero-error candidate and always wins. Unity's behaves the same
way. One Euro is still selectable via `use_aim_stabilizer`.

**The actual bug was neither, and it was a sign error.**
`XRHandGestureProvider.get_hand_ray_pose` picks its pitch axis from
index-knuckle to pinky-knuckle. That axis mirrors between hands, so the code
flips the pitch sign for the right hand to cancel it. But when the pinky was
not reported it fell back to `fwd.cross(Vector3.UP)` -- fixed chirality, does
not mirror -- while still applying the handedness flip. The two hands therefore
pitched in **opposite** directions in the fallback, and the fallback is taken
exactly when a hand is leaving camera view.

Verified by reverting: the right hand keeps its correct slight downward pitch
(y ~ -0.15) while the left flips to a sharp upward deflection (y ~ +0.88).
`test_hand_ray_symmetry` builds mirrored fixtures, asserts mirrored rays, and
fails against the old code.

This is the "left hand ray drifts up and right when I look away" report that
survived eight attempted fixes. None of them could have worked: the FOV cone,
the tracked-joint thresholds, the reacquisition debounce, and the One Euro
tuning were all aimed at a symptom produced by a chirality bug two layers
below them.

**Lesson worth keeping.** Every one of those eight attempts was a plausible
mechanism reasoned from the observed behaviour. What finally found it was
reading the code path that PRODUCES the ray, rather than reasoning about what
could perturb it. Symmetry is cheap to test and was never tested; a
left-vs-right fixture would have caught this on day one.

## Correction: what the FOV cone is actually for

The cone was built to suppress the drift above. With the real cause fixed, it
looked like dead weight, so it was defaulted off -- and on device the left hand
then **disappeared** on look-away.

The reason is that the cone is doing a job its name does not describe. It
CLASSIFIES the loss. A hand leaving view is unobservable but still on the user,
and must freeze; a hand whose data stops arriving may genuinely be gone, and
must expire after `hold_duration_sec`. The geometric test is the only available
signal that separates those two states. Remove it and out-of-view loss becomes
indistinguishable from data loss, so the hand expires and vanishes.

It is back on, and `_test_fov_gate_ships_enabled` pins it with that reasoning,
because the class doc alone would lead a future reader to exactly the wrong
conclusion.

Its cost is accepted rather than solved: freezing parks the hand MESH in space
while the real hand moves on, seen on device as the hand sitting offset in
front of the real one for a beat before snapping back. A hand that vanishes is
worse, and has been rejected on device before.

**Next smallest step for that artifact:** drive the mesh from the raw tracker
while the RAY uses the frozen pose. The ray is what needs stability; the mesh
only needs to be where the hand is. Untested, and it would need the mesh's
consumers checked for anything that assumes both read the same source.

**Measured, and the answer was no.** Quest over Link (Oculus runtime 1.205.0)
does **not** advertise `XR_EXT_hand_interaction`. The profile is now bound in
`default_action_map.tres`, and `_probe_platform_aim` in
`xr_controller_hand_adapter.gd` reported `platform=false` on every sample
including while hand tracking was live; the boot log never mentions the profile
at all, because Godot registers it only when the runtime advertises the
extension.

Consequences, stated plainly:

- The binding is **inert over Link**. It changes nothing there, and nothing
  observed in that session can be credited to it.
- Step 1 is therefore **unverified anywhere**. It remains the right design —
  WebXR delivers the aim pose unconditionally, and the extension is
  multi-vendor — but no device has yet confirmed it end to end.
- The next measurement is the same probe run **standalone on Quest** (a
  different runtime path from Link), or on Android XR / Pico / SteamVR. Switch
  `debug_platform_aim` on and read the `[aim-probe]` lines.
- **Step 2 is now the higher-value work**, because it is backend-independent:
  it improves the derived ray that every device is still using, including Link
  and including any runtime that never advertises the extension.

## Standalone answered it: yes, and the binding alone was never enough

Measured 2026-07-26 on standalone Quest 3, Horizon OS v205, runtime
"Oculus 205.206.0", OpenXR 1.1.60, via the same `[aim-probe]` over adb logcat.

**The runtime advertises the extension.** The `--verbose` boot log enumerates
both `XR_EXT_hand_interaction` and `XR_MSFT_hand_interaction` in the
runtime's extension list. Link's absence of the extension is a Link
limitation, not a Quest one.

**The runtime publishes an aim pose for tracked hands.** With hands live,
`platform=true` on 154/177 left-hand and 276/279 right-hand samples. The
absences cluster at session-start acquisition and in look-around windows —
24 of 26 were the left hand, matching both the on-device report ("left hand
disappears, its ray shifts more than the right") and the spec's design that a
runtime withholds the pose when it does not consider the hand ready.

**The derived ray is not slightly off the platform ray. It is a different
ray.** Angular separation between the two, measured raw before any filtering:
right hand mean 29.5°, left hand mean 48.1°, maxima 59.5°/69.4°. The
left/right asymmetry is itself evidence: the derivation lands differently per
hand, which no amount of downstream filtering can reconcile. This is also why
the same build's cursor sits at a different height on standalone than over
Link — two runtimes feed the same wrist→knuckle formula different joint
estimates, so the derived ray is runtime-dependent by construction. The
platform pose is the only cross-runtime standard available.

**The trap that cost a session: binding the profile is not enabling it.**
Godot requests `XR_EXT_hand_interaction` from the runtime only when the
project setting `xr/openxr/extensions/hand_interaction_profile` is true
(`modules/openxr/extensions/openxr_hand_interaction_extension.cpp:59`). The
demo never set it, so on the first standalone run the boot log showed the
extension *Found* but not *Enabled*, and the bound profile was skipped with
"Interaction profile /interaction_profiles/ext/hand_interaction_ext requires
extension XR_EXT_hand_interaction". The action-map binding recorded above was
therefore inert **everywhere**, not just over Link — Link merely had a second,
independent reason. Both switches must be on: the action-map profile AND the
project setting.

Curiosity that forced a follow-up measurement: on that first run the aim pose
had tracking data *anyway*, with the ext profile provably skipped and the
MSFT profile unbound in our action map. The probe now logs the tracker's
active interaction profile to attribute the pose to whatever is actually
serving it.

**Adopted.** `_hand_aim_pose` now prefers the platform aim pose whenever the
hand tracker is live and the runtime published one, with the derived
wrist→knuckle ray as the unchanged fallback (Practice 3's resolution order,
verbatim). `prefer_platform_aim` switches it for A/B. The hand-liveness gate
is load-bearing: the same controller node carries a physically held
controller's aim pose, and without the gate a held controller would
masquerade as a hand ray. `tests/test_platform_aim.gd` pins selection,
fallback, toggle, and gate; all four survived three deliberate mutations
(gate removed, platform path dead, fallback dead).

**Withheld is not absent — hold, don't improvise.** First in-headset run of
the adopted change reproduced the withhold windows as a visible artifact: the
left ray sat on the UI menu, the hand left view, the runtime withheld its aim
pose, the code fell back to the derived ray — and the line swept to the far
right by the full 40–52° separation, then swept back on republish. The rule
that fixes it: once a runtime has published an aim pose for a hand, a
withheld frame while the hand is still live means "not observable enough to
aim", and the last platform ray is HELD — the same
unobservable-versus-gone classification the FOV gate applies to joints. A
runtime that has never published (Link) keeps the derived path untouched.
`_test_withheld_platform_holds_last_ray` pins the hold and fails with the
hold branch dead.

**Full loss is usually also "unobservable", and the cone cannot see that.**
Second in-headset run: the sweep was gone, but the left ray now *vanished* on
look-away. The probes caught the whole death (17:40:51): as the hand leaves
view the runtime's terminal frames are extrapolated garbage — the wrist
wanders while reading 46–50° off head-forward, well inside any plausible view
cone, the tracked-joint count collapses 26→17→7→2 — and then ALL data stops.
The FOV gate therefore sees an in-cone loss, classifies the hand as gone
rather than unobservable, and expires it ~260 ms later; empty pose, no ray.
The geometric classifier is being lied to by the very frames it needs for the
classification, so no cone angle fixes this. What does hold: on inside-out
tracking a VISIBLE hand never loses data, so a full loss while hands are the
modality almost always means out-of-view. The platform-aim hold now survives
full tracker loss for `platform_aim_hold_sec` (default 10 s, both hands, 0
restores expire-on-loss), then the ray hides. The mesh/gate machinery is
untouched — this is ray-only, the smallest change that restores left/right
parity. Pinned by `_test_full_loss_within_grace_holds_ray` and
`_test_full_loss_beyond_grace_expires`; both fail with their branch broken.

**Park from before the wander, and don't trust the first republish.** Third
in-headset run: no sweep, no vanish, but the left ray "shifts a little" at
the moment it leaves view. Cause, from the same 17:40:50 capture: for ~0.4 s
BEFORE the first withhold the runtime is still *publishing* — and those poses
wander with the dying extrapolation (the left aim swung from level to nearly
straight up while the wrist hallucinated 36 cm of travel). Parking on the
last published pose therefore parks displaced. The adapter now keeps a short
history of settled platform poses and, when the stream goes genuinely bad,
parks on the newest sample older than `platform_aim_park_backtime_sec`
(default 1.0 s — wide enough to clear the wander plus the withhold/republish
dance that follows). It stays parked through the measured 150–300 ms garbage
republish bursts until the stream has been continuously healthy for
`platform_aim_resume_sec` (default 0.75 s), and a loss that outlives the
grace window clears all of it so reacquisition starts clean. All transitions
live in `_process` (single writer); `_hand_aim_pose` is a pure reader.

**Two rejections later: the right hand IS the algorithm. No hysteresis.**
Both refinements of that park machinery were rejected in the headset within
minutes of each other:

1. *Park on any withheld frame* → short withholds are routine on a
   well-tracked hand (the probe's change-gated logging had hidden their
   true frequency), so the ray parked constantly — "the ray and hands get
   stuck".
2. *Resume only after a continuous healthy streak* → dirty-but-usable
   streams never satisfy the streak, so the ray floated detached from a
   perfectly tracked, visible hand — "the left ray was independent of the
   hand with an offset", "takes time to be placed correctly on the hand".

The user's framing was the correct design the whole time: *"right hand
behavior is the role model."* The right hand's entire algorithm is: a
published pose drives the ray the instant it exists. The shipped shape is
exactly that, with memory only FILLING gaps, never overriding data:

- pose published → it drives, immediately, unconditionally;
- gap < `platform_aim_fill_sec` (0.25 s) → coast on the last pose;
- longer gap → show the park pose (newest buffered sample older than
  `platform_aim_park_backtime_sec`, from before the terminal wander;
  buffer pushes require a 0.3 s settled stream so post-hiccup garbage
  never becomes a future park);
- hand lost > `platform_aim_hold_sec` (10 s) → ray hides, state clears.

The cost accepted with eyes open: during the loss dance's garbage republish
bursts the ray briefly follows garbage (~150–300 ms) before re-parking.
That transient was never reported as a problem on device; the machineries
that tried to suppress it were. Pinned by
`_test_micro_withhold_resumes_instantly` and
`_test_republish_after_park_resumes_instantly` (each fails against one of
the rejected machineries) plus `_test_park_predates_the_terminal_wander`.

**A gap pose on a tracked hand translates with the hand.** With the
simplified shape earned in ("behaves way better"), one residual artifact
remained: a long gap on a hand the runtime still TRACKS (joints live, mesh
moving — aim withheld) parked the ray in space while the visible hand
walked away from it. The gap pose now translates with the palm-anchored
delta since the gap began — the exact mechanism the pinch-select stabilizer
already earned in on device — so the ray stays on the visible hand while
only its direction is held. A fully lost hand has no anchor and parks in
space, which is right for a hand nobody can see. Pinned by
`_test_gap_ray_follows_the_live_hand`.

**The last "slight movement" was seams, not data.** Asked to verify the
left behaves exactly like the right on look-away, the capture showed the
code is hand-symmetric and the difference is entirely the streams: in 40 s
of use the left aim stream gapped five times (0.25–0.75 s), the right not
once — and across a measured left gap the aim direction itself drifted only
~2°. What the user saw was machinery seams at the gap boundaries: (a) at
the fill boundary the display hopped from the last pose to the up-to-1 s
old history even when nothing had wandered, and (b) mid-gap one-frame
liveness blips (present in the capture) toggled the palm translation off
and popped the origin. Fixes: the aged history is used only when the tail
actually disagrees with it (`platform_aim_wander_threshold_deg`, 5° — a
stable tail parks on itself, zero seam), and the gap display is computed
once per frame in `_process`, sticky across liveness blips. The remaining
seam is the republish correction, which is the data itself returning (~2°)
and is further damped by the downstream stabilizer. Pinned by
`_test_stable_gap_parks_on_the_last_pose` and
`_test_live_blip_does_not_pop_the_gap_pose`.

**The left stream doesn't gap — it churns. A tracked hand's gap ray must
move, not freeze.** The next session's log revealed the actual scale of the
left/right difference: eleven withhold/republish cycles in 27 s of ordinary
use on the left, zero on the right. With a gap every ~2 s, ANY
frozen-direction display is a visible stutter — no amount of seam polish
fixes freezing itself. So a gap on a still-tracked hand no longer freezes:
the palm frame drives the direction through the offset calibrated at gap
start (`palm⁻¹ × last published direction` — continuity at gap entry is
exact by construction), the origin rides the palm as before, and the ray
simply keeps moving with the hand until real data returns. The
wander-threshold recalibration happens once at the fill boundary if the
calibration tail disagrees with the aged history. Parking in space now
happens only for a hand that is actually lost. This is Meta's
hold-while-connected made concrete: substitute a pose driven by the
connected hand, never a frozen one. Pinned by
`_test_gap_ray_rotates_with_the_live_hand` — fourteen checks, fifteen
mutations caught in the suite across its lifetime.
