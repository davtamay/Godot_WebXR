# Web audio worker lifecycle fixture

This is a functional stream-playback check, not a performance benchmark. The generated 440 Hz PCM tone uses `PLAYBACK_TYPE_STREAM` so it exercises the engine's mixing worker rather than browser sample playback. Browser output is muted; an analyser checks the real worklet signal.

Export the project with the two builds under `Baseline/Web`, `Baseline/WebThreads`, `Candidate/Web`, and `Candidate/WebThreads`, then run:

```
node benchmarks/audio-worker/verify.mjs <build-root> <result-directory> <candidate-revision>
```

The fixture pins baseline engine `2f3fd8aa21` and requires the candidate revision as an argument. It waits for the audio clock to advance before sampling, with a five-second readiness timeout. It checks signal amplitude/frequency, suspension, resumed playback, and exit from both running and suspended states in both thread modes. Single-threaded pages have no cross-origin isolation headers.

The baseline emits a two-object ObjectDB cleanup warning. Only that exact baseline signature is retained as `knownBaselineWarnings`; the candidate must exit without console or page errors. The candidate receives no warning exemption. Verbose candidate output exposes leaked object identities. Passing this short test does not establish device-specific audio latency, absence of every underrun, or headset behavior.

Audio startup waits for 250 ms of context-clock progress after the engine signals playback readiness. An absolute context time is insufficient: the context may already have run before the stream starts. Signal bounds, finite readiness timeout, pause/resume and shutdown assertions remain strict.
