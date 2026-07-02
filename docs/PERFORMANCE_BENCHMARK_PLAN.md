# Performance and Build Size Benchmark Plan

## Goal

Compare Godot and Unity honestly for browser-delivered XR/product slices.

This benchmark does not try to prove that one engine is universally better. It answers:

```text
For our product class, target devices, target browser, and target visual quality,
which path gives the best combination of load size, startup time, XR frame stability,
workflow speed, and long-term ownership cost?
```

## Test matrix

| Dimension | Required values |
|---|---|
| Engines | Godot 4.7, current company Unity baseline |
| Graphics APIs | Godot WebGL2 Compatibility, Unity WebGL2, optional Unity WebGPU Experimental |
| Scenes | Empty baseline, product slice, stress ramp |
| Browsers | Chrome/Chromium, Firefox, target headset browser |
| Runs | 5 cold-cache runs, 5 warm-cache runs per scene/device |
| Hosting | Same local HTTPS/server/CDN config for all builds |
| Compression | raw, gzip; brotli if available |

## Measurement procedure

1. Export release/non-development builds.
2. Clear browser cache for cold-load test.
3. Start performance capture.
4. Open app URL.
5. Record capability panel timestamp.
6. Record engine app loaded timestamp.
7. Record first interactive frame timestamp.
8. Enter XR if device supports it.
9. Run fixed 60-second interaction loop.
10. Record frame timing and browser console output.
11. Repeat for warm-cache runs.
12. Produce summary table and raw logs.

## Required output files

```text
research/performance_results/godot_empty_build_size.json
research/performance_results/godot_product_slice_build_size.json
research/performance_results/unity_empty_build_size.json
research/performance_results/unity_product_slice_build_size.json
research/performance_results/runtime_metrics.csv
research/performance_results/summary.md
```

## Metrics to collect

```text
raw_total_bytes
gzip_estimated_total_bytes
brotli_estimated_total_bytes, if available
file_count
wasm_bytes
js_bytes
pck_or_data_bytes
texture_asset_bytes
largest_files
time_to_capability_panel_ms
time_to_engine_start_ms
time_to_first_interactive_ms
time_to_enter_xr_ms
avg_fps
p95_frame_ms
p99_frame_ms
long_frame_count_over_50ms
browser_console_errors
browser_console_warnings
```

## Success threshold placeholders

Fable should not invent thresholds. Fill these after product/team discussion:

```text
max_cold_load_seconds: TBD
max_compressed_initial_download_mb: TBD
min_headset_fps: TBD
max_p95_frame_ms: TBD
max_build_time_release_minutes: TBD
minimum_supported_headset_browser: TBD
```

## Important caveat

Unity WebGPU, if tested, must be labeled experimental. Godot WebGPU must be labeled detection-only unless actual Godot renderer source work exists.
