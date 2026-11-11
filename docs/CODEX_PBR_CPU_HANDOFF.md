# PBR CPU follow-up — completed desktop validation

## Branch ownership and integration

Engine candidate: `codex/web-audio-cpu-opt`, `b5cf19bc2049a9ab9bdef69bd7e592c26320f314`, worktree U:/ (C:/Users/davta/Documents/Codex/2026-11-09/explore-and-compare-architectural-approaches-x20-2/work/rendering-candidate). It is based directly on preserved published baseline 2f3fd8aa21. Do not mix in the rejected bind-group branch.

Demo tooling: `codex/pbr-cpu-opt`, C:/Users/davta/work/engine-demo-merge/demo. Exported PBR builds use demo source 60c19b8; later commits only finalize validation/tooling/docs. Suite source remains d261d8cc9efd68faed57881344b632d80bce359d in C:/Users/davta/work/matched-bench-suite; no suite implementation change in this batch.

No pushes or merges. All Monday refs, prior published remote-tracking refs, and original source WIP are preserved. Original repositories were changed only for these coordination documents/notices.

## Runtime change

One `[shared]` web-audio patch changes the threaded mixer fallback wait from 1 to 10 ms in platform/web/audio_driver_web.cpp. The AudioWorklet still notifies and wakes the worker every processing quantum. The finite timeout bounds shutdown during suspension; maximum fallback polling delay grows by nine milliseconds. The patch intentionally applies to standard web audio as well as WebGPU. Single-threaded code is unchanged. The only other file change adds this path to the stack checker's SHARED_OK allowlist.

The source hunk applies to the frozen Monday candidate. The entire commit does NOT apply directly to that older candidate because SHARED_OK has evolved: retain its existing entries and add only platform/web/audio_driver_web\.cpp. Current candidate stack boundaries pass. Do not claim conflict-free integration with future upstream revisions or alter the frozen Monday ref.

## Desktop evidence

Both complete Closure templates and matching Windows editor built successfully. Full rendering gates pass (strict GPU probes for both modes, Closure/loader checks, 13 XR glue cases, Mobile/Forward+ export/boot with zero excluded shader variants, MSAA cycles and frame hygiene). No-SAB XR emulation passes. The PBR matrix has 60 fresh normal-audio runs; all pass runtime/provenance checks and pixel identity against preserved references. Both thread variants have identical 142-resource content excluding build identity. Active scene, workload and shader bytes match baseline; generated cache paths/remaps differ.

Real audio stream fixture: all eight baseline/candidate, single/threaded, running/suspended shutdown cases pass playback signal, suspension/resume and exit checks. The same two-object ObjectDB cleanup warning occurs in both revisions and is retained as a known unresolved baseline warning; other errors fail. No headset testing. No claim of eliminating every underrun or proving mobile audio latency.

CPU medians (whole renderer-process CPU milliseconds per frame, profiling off; five paired windows each). Positive paired saving means lower CPU:

| Objects | Mode | Baseline | Candidate | Paired mean saving | 95% descriptive interval |
|---:|---|---:|---:|---:|---|
| 24 | godot-single | 2.831 | 2.865 | -0.079 | -0.174 to +0.009 |
| 24 | godot-threaded | 2.220 | 2.157 | +0.033 | -0.018 to +0.075 |
| 96 | godot-single | 2.970 | 2.995 | +0.015 | -0.073 to +0.120 |
| 96 | godot-threaded | 2.313 | 2.295 | +0.011 | -0.032 to +0.064 |
| 384 | godot-single | 2.941 | 2.948 | -0.040 | -0.136 to +0.059 |
| 384 | godot-threaded | 2.348 | 2.293 | +0.033 | -0.014 to +0.079 |

**Performance verdict:** Threaded medians fell about 0.8–2.8%, but every CPU paired interval includes zero. A repeatable speedup is not established; keep this as an isolated, functionally tested candidate, not a proven performance win.

Use the paired uncertainty and unchanged single-thread path when interpreting small differences. This is a targeted worker-overhead candidate, not proof of a WebGPU rendering speedup. Do not advertise a universal engine ranking from these desktop measurements.

## Rejected and historical evidence

Engine `codex/pbr-cpu-opt` at 3130ee0622 passed 120 paired runtime/pixel runs and binding-mask equivalence tests but did NOT demonstrate a CPU win. Do not promote it. Raw data: C:/Users/davta/work/pbr-cpu/paired. It is not an ancestor of the audio candidate.

Claude's November 7 xbench logs contain Godot wins over PlayCanvas (8,000 batch: 5.20 vs 6.96 ms callback; 8,000 unique: 18.12 vs 21.82 ms). Preserve these as workload-specific historical results, with the recorded shader-error caveat. They use native PBR, lights/shadows/MSAA and a callback timing scope, unlike whole-process CPU here. Our prior PBR report now explicitly notes active Godot audio overhead; the old raw numbers are unchanged.

## Reproduction and artifacts

Run benchmarks/pbr/run-paired.py against the preserved baseline and audio-build directories; verify with `--candidate-revision b5cf19bc20`. README documents all diagnostic switches. Primary runs must use normal audio with samplers/traces/command auditing off. Audio-suspended controls are attribution experiments only.

Working evidence: C:/Users/davta/work/pbr-cpu/audio-paired, audio-fixture-verified, audio-build, audio-gates-driver.log, audio-workload-audit.json, audio-isolation-check.json. Previous baseline exports remain C:/Users/davta/work/engine-demo-merge/demo/benchmarks/pbr/build. New templates/editor are U:/bin; preserved baseline binaries are C:/Users/davta/work/pbr-cpu/baseline-bin.

User deliverables: C:/Users/davta/Documents/Codex/2026-11-09/explore-and-compare-architectural-approaches-x20-2/outputs/CPU-optimization-results.md, accompanying CSV/manifest/builds/validation/source bundles and separate rejected-experiment data. Read the report before claiming a measured improvement. Do not rewrite baseline results, merge the rejected experiment, or overwrite original dirty source edits.
