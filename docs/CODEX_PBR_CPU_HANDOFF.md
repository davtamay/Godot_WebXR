# PBR CPU follow-up — audio candidate in validation

The bind-group candidate 3130ee0622 on engine codex/pbr-cpu-opt passed 120 paired runs and pixel identity, but did NOT show a convincing CPU win. Do not promote it. Raw results remain C:/Users/davta/work/pbr-cpu/paired.

Codex is now testing engine b5cf19bc20 on codex/web-audio-cpu-opt, based directly on baseline 2f3fd8aa21 (without the bind-group change). The one shared runtime change extends the audio worker's fallback wait from 1 to 10 ms: AudioWorklet notifications still wake playback immediately. The timeout only bounds shutdown/polling while notifications stop. This general web-audio fix intentionally applies to standard web builds as well as WebGPU and is separately marked [shared]; the stack allowlist names that one upstream file.

Both full Closure templates and the matching editor built successfully. Muted real-engine audio signal, suspend/resume and shutdown tests are being prepared for both thread modes. Fresh PBR CPU comparisons will retain normal audio. Suspended-audio tests are attribution controls only, not a claimed engine optimization.

Original source edits, all Monday refs and published branches remain untouched. No push/merge and no headset testing. Demo tooling is C:/Users/davta/work/engine-demo-merge/demo, codex/pbr-cpu-opt; engine worktree is U:/. Do not overlap these active branches. Claude's recorded xbench wins were located and retained with their distinct scopes and shader-error caveats under C:/Users/davta/work/pbr-cpu/claude-evidence. Final handoff will replace this status.
