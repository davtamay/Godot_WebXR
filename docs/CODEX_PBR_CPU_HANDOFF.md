# PBR CPU optimization — in progress

Codex is profiling and optimizing on isolated codex/pbr-cpu-opt branches: engine U:/ (physical rendering-candidate worktree) and demo C:/Users/davta/work/engine-demo-merge/demo. Baseline engine is 2f3fd8aa21; baseline demo/PBR is bc75a051c1. Do not overlap these worktrees or replace the baseline measured exports. No changes to Monday refs or public branches; preserve original dirty source.

The initial command audit proves both per-frame submissions contain real rendering. No empty-submit shortcut is justified. Profiling and symbol mapping are underway before choosing a patch. Evidence lives in C:/Users/davta/work/pbr-cpu. Both Closure thread variants and matched output/timing checks must pass before calling an optimization complete. No push/merge; headset testing deferred by the user. Final handoff will supersede this status.
