# Benchmark/reliability follow-up — completed

Codex added desktop measurement tooling on demo branch codex/benchmark-reliability in C:/Users/davta/work/engine-demo-merge/demo. Scope: tools/benchmark-reliability.mjs and docs/BENCHMARK_RELIABILITY.md only. Published engine/demo/suite heads and Monday candidates are untouched. This batch is complete; continue from this branch after reviewing the protocol.

The exported demo starts on its launcher; recorded RAF cadence is NOT a rendering benchmark or an XR frame rate. Current short screens cover reloads, main-target JS heap trends, errors, and intentional GPU destruction followed by explicit reload. Actual unexpected device loss and repeated XR-session cycles still need dedicated tests. Device.destroy() is intentionally ignored by the engine's automatic-loss handler and must not be described as proving automatic recovery.

Engine performance adapters and matched Babylon/PlayCanvas scenes are planned, not implemented. No comparative ranking is supported. Existing runtime provenance marks demo identity incomplete, so artifact hashes accompany results; resolve release-source identity before publishing external comparisons.

Validation: six short screens passed (Chrome WebGL/WebGPU in both thread modes; Edge WebGPU in both thread modes), zero captured errors; intentional destroy plus explicit reload passed in four WebGPU cases; negative thread-template control correctly failed. Existing report tests and syntax checks pass. No 30-minute soak, matched competitor scenes or headset tests were run. See outputs/Desktop-benchmark-reliability-assessment.md in the original Codex project output directory for exact durations and limits.
