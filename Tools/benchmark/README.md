# Benchmark runner

Runs the iOS performance/benchmark tests in isolation, records their `XCTMetric`
results in a versioned JSON format, and compares each run against a saved baseline.

## Usage

```bash
# Run the benchmark tests and compare against baseline.json (fails on regression)
make benchmark

# Looser relative threshold / noise band
make benchmark BENCHMARK_TOLERANCE=15 BENCHMARK_NOISE_SIGMA=3

# Choose which metrics may fail the build
# (default: "CPU Instructions Retired,Clock Monotonic Time")
make benchmark BENCHMARK_GATE_METRICS="CPU Instructions Retired"   # CPU work only

# Run the benchmark tests and save the results as the new baseline
make benchmark_baseline
```

## What runs

A single **end-to-end** benchmark: `SessionDataRefreshIntegrationBenchmarkTests`
(`BENCHMARK_ONLY` in the Makefile). It stands up the real feature stack — real
`ResourceUpdater`, real Gopenpgp metadata decryption, real in-memory SQLCipher — and
measures `updateResources` (paginated fetch → decrypt → store) at three scales:
`small` (75 resources), `medium` (1550), `large` (25 000 across 5 pages). Large is
slow (real PGP × 25 000 per iteration), so it runs fewer iterations and skips when
the `Benchmark/large` fixtures are absent.

> Requires the ada key material (`Fixtures/keys/ada.private.asc` + `ada.passphrase`)
> — without it the benchmark **skips**, and `make benchmark` then reports no
> measurements (exit 2). See `…/Fixtures/keys/README.md`.

Earlier partial micro-benchmarks (a `refreshIfNeeded` variant that mocked
`ResourceUpdater`, and decode-only resource benchmarks) were removed — they didn't
measure the dominant cost (resource decryption). Request-behaviour correctness is now
a plain functional test (`SessionDataRefreshRequestsTests`, runs under `make test`).

## Why a metric can look like it "regressed" on identical code

Some metrics are inherently noisy on the simulator. In a typical baseline you'll
see `relativeStandardDeviation` (rsd) like **Clock ~90%** and **Memory Physical
~300%**, while **CPU Instructions Retired (~1%)** and **Memory Peak Physical
(~0.3%)** are very stable. A flat percentage threshold would flip the noisy ones
between "regressed" and "improved" run-to-run.

So a metric is reported as a **regression only when the change exceeds BOTH**:

1. `--tolerance` (`BENCHMARK_TOLERANCE`, default 10%) — the relative change we care about, and
2. `--noise-sigma` (`BENCHMARK_NOISE_SIGMA`, default 2) × the combined standard
   deviation of the two runs — i.e. the change must rise above measurement noise.

Changes within the noise band show as `noise` and never fail the build. Set
`BENCHMARK_NOISE_SIGMA=0` to disable noise-gating and compare on tolerance alone.

## Which metrics fail the build (gating)

Noise-gating is not enough for **Memory Peak Physical**: it's a process-wide
high-water mark sampled over correlated iterations, so its *within-run* rsd is
tiny (~0.3%) yet it drifts several percent *between* test processes (ASLR, loaded
dylibs, allocator, runtime overhead) — unrelated to your code. Its noise band is
therefore artificially small and it trips on identical code.

So only metrics matching `BENCHMARK_GATE_METRICS` can fail the build; every other
metric is still measured and shown, marked `·info` when over threshold, but never
fails. The default gates on two complementary metrics:

- **`CPU Instructions Retired`** — the deterministic "how much work did this code
  path do" signal. Catches CPU regressions; **immune to sleeps/waits** (a suspended
  thread retires no instructions — `CPU Time` is the same, which is why it isn't
  gated).
- **`Clock Monotonic Time`** — wall-clock time. Catches what instruction-count
  can't: `Task.sleep`, I/O waits, lock contention, async suspension.

Clock is noisy (rsd ~27% on the integration test, ~92% on the tiny ones), but the
noise band absorbs that: identical code stays inside the band (no false positives),
at the cost that Clock only trips on **large** time regressions — and the more so
the tinier/faster the test. That's the right trade-off for catching real slowdowns
(e.g. a stray `sleep` or blocking call) without flapping.

`Memory Peak Physical` stays informational: it's a process-wide high-water mark
sampled over correlated iterations, so its *within-run* rsd is tiny (~0.3%) yet it
drifts several percent *between* test processes (ASLR, loaded dylibs, allocator,
runtime overhead) — unrelated to your code. Its noise band is therefore artificially
small and it would trip on identical code, so it must not gate.

Tune gating:

```bash
make benchmark BENCHMARK_GATE_METRICS="CPU Instructions Retired"   # CPU work only
make benchmark BENCHMARK_GATE_METRICS=all                          # gate on everything
```

If the tiniest/fastest tests ever false-positive on Clock, drop Clock from the gate
(above) or adopt per-test gating later.

**More samples** (raise `options.iterationCount` in `measureAsync`) tightens the
bands a little, but the Clock/Memory-Physical noise is systemic to the simulator,
not sample-count — the noise-aware gate above is the real fix.

Both targets run only the classes listed in `BENCHMARK_ONLY` (Makefile) via
`xcodebuild -only-testing`, on the `iPhone 15` simulator. Add new benchmark
classes there.

## What it measures

Each benchmark uses `measureAsync(metrics:)` (see
`Sources/CoreTest/Benchmark/XCTestCase+AsyncBenchmark.swift`), capturing
`XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, `XCTStorageMetric`.
`benchmark.py` reads each metric's `average` from the `.xcresult` bundle via
`xcrun xcresulttool` (recent Xcode writes metrics only to the bundle, not stdout);
it falls back to parsing `measured […]` stdout lines on older Xcode.
Lower is better for every metric, so a **positive delta is a regression**.

## Files

| Path | Tracked | Purpose |
| --- | --- | --- |
| `benchmark.py` | yes | parser + comparator (`compare` / `baseline`) |
| `README.md` | yes | this doc |
| `baseline.json` | no (git-ignored) | the reference results — **per machine** (`make benchmark_baseline`) |
| `history.jsonl` | no (git-ignored) | one compact line per run, local trend log |
| `results/` | no (git-ignored) | per-run JSON, `latest.json`, `last-run.log`, `last.xcresult` |

Results are **machine-specific** — absolute clock/CPU/memory (and even instruction
counts across arm64 vs x86_64 simulators) differ across hardware. So the baseline and
history are **not committed**: each machine establishes its own with
`make benchmark_baseline`, then `make benchmark` detects regressions in that same
environment. (If you later gate in CI, capture/store the baseline on the fixed CI
runner instead of committing one.)

## Format — `passbolt-benchmark/v1`

```json
{
  "format": "passbolt-benchmark/v1",
  "generatedAt": "2026-06-18T11:00:00Z",
  "git": "1a2b3c4",
  "tolerancePercent": 10.0,
  "noiseSigma": 2.0,
  "results": {
    "PassboltSessionDataTests.SessionDataRefreshBenchmarkTests/test_benchmark_refreshIfNeeded_small": {
      "Clock Monotonic Time, s": { "average": 0.045, "relativeStandardDeviation": 12.3 },
      "Memory Physical, kB": { "average": 1234.0, "relativeStandardDeviation": 3.1 }
    }
  }
}
```

`history.jsonl` lines are flattened to `{generatedAt, git, results: {test: {metric: average}}}`.

## Notes

- Builds incrementally (no forced clean). For the most stable numbers run a
  clean build first (`make clean_build`) — perf tests run in the Debug test
  configuration, so treat the numbers as relative regression signals, not
  absolute production figures.
- The integration benchmark `XCTSkip`s without `Fixtures/keys/` material; skipped
  tests simply don't appear in results (reported as "Not measured this run").
- `benchmark.py` can be run directly against any saved log:
  `python3 Tools/benchmark/benchmark.py compare --log path/to.log --tolerance 10`.
