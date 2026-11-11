# Web audio worker lifecycle fixture

This is a functional stream-playback check, not a performance benchmark. The generated 440 Hz PCM tone uses `PLAYBACK_TYPE_STREAM` so it exercises the engine's mixing worker rather than browser sample playback. Browser output is muted; an analyser checks the real worklet signal.

Export the project with the two builds under `Baseline/Web`, `Baseline/WebThreads`, `Candidate/Web`, and `Candidate/WebThreads`, then run:

```
node benchmarks/audio-worker/verify.mjs <build-root> <result-directory>
```

The current fixture pins baseline engine `2f3fd8aa21` and audio candidate `b5cf19bc20`; update those expectations deliberately for a later comparison. It checks signal amplitude/frequency, suspension, resumed playback, and exit from both running and suspended states in both thread modes. Single-threaded pages have no cross-origin isolation headers.

Both builds currently emit the same two-object ObjectDB cleanup warning on exit. The exact known warning and its source location are retained in `knownBaselineWarnings`; other console/page errors fail the test. This warning remains unresolved. Passing this test does not establish device-specific audio latency, absence of every underrun, or headset behavior.
