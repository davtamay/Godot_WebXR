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

**Not yet verified:** that Quest over Link advertises
`XR_EXT_hand_interaction` — extensions are runtime-advertised and Link is a
different runtime path from standalone. This does not gate the plan (the
fallback covers it, and WebXR needs no extension at all), but it does decide
whether step 1 is testable in the current Link setup or only on-device.
