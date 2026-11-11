# PBR benchmark follow-up — in progress

Codex is working only in C:/Users/davta/work/engine-demo-merge/demo on codex/pbr-benchmarks. Do not overlap benchmarks/pbr or reset this worktree. No engine or suite source changes are needed. Monday refs and published heads remain frozen; preserve the original dirty checkouts.

Implemented: canonical textured GGX sphere workload, shared GPUQueue.submit timestamp boundaries, renderer-process CPU deltas including workers, paired profiling-off CPU controls, exact draw-count and provenance gates, and image silhouette/color validation. This is execution of a shared PBR shader, not a comparison of native material features, IBL, shadows or XR.

Both Godot exports were produced from demo a852fdb using engine 2f3fd8aa21 and the existing validated Closure templates. 142 resources match between threaded/single packs, excluding their identity manifest. Initial image checks pass (IoU 1.0; RGB RMSE 0.00350). Seven common-timing controls pass. The 120-case paired matrix is running; do not cite preliminary timings as final results. GPU timestamps retain browser quantization and omit queue.write uploads/presentation. CPU process totals include harness/browser renderer work, not just engine rendering.

Results: C:/Users/davta/work/engine-demo-merge/pbr-results. Matrix log: pbr-matrix.log alongside it. Final report/handoff will replace this in-progress status. Headset testing is deferred by the user. No push/merge authorized for this batch.
