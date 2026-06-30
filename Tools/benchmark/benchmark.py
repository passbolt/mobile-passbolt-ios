#!/usr/bin/env python3
"""Parse XCTest performance output and compare against a saved baseline.

`xcodebuild test` prints one line per captured metric, e.g.:

    Test Case '-[PassboltSessionDataTests.SessionDataRefreshIntegrationBenchmarkTests test_benchmark_updateResources_withRealDecryption_small]' \
        measured [Clock Monotonic Time, s] average: 0.045, relative standard deviation: 12.345%, values: [...], ...

This tool extracts those measurements, records them in our own JSON format, and
either:
  * `compare`  — diffs the run against `baseline.json` and flags regressions, or
  * `baseline` — saves the run as the new `baseline.json`.

Lower is better for every metric we capture (clock/CPU/memory/storage), so a
positive delta is always a regression.

Format (`passbolt-benchmark/v1`):
    {
      "format": "passbolt-benchmark/v1",
      "generatedAt": "2026-06-18T11:00:00Z",
      "git": "<short sha>",
      "tolerancePercent": 10.0,
      "results": {
        "<Target.Class>/<method>": {
          "Clock Monotonic Time, s": { "average": 0.045, "relativeStandardDeviation": 12.3 },
          ...
        }
      }
    }
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

FORMAT_ID = "passbolt-benchmark/v1"
HERE = Path(__file__).resolve().parent
DEFAULT_BASELINE = HERE / "baseline.json"
DEFAULT_RESULTS_DIR = HERE / "results"
DEFAULT_HISTORY = HERE / "history.jsonl"

# Legacy stdout format (older Xcode):
# Test Case '-[Target.Class method]' measured [Metric, unit] average: N, relative standard deviation: N%
PERF_RE = re.compile(
    r"Test Case '-\[(?P<cls>[\w.]+)\s+(?P<method>\w+)\]'\s+measured\s+"
    r"\[(?P<metric>[^\]]+)\]\s+average:\s+(?P<avg>[\d.]+),\s+"
    r"relative standard deviation:\s+(?P<rsd>[\d.]+)%"
)

DIAGNOSTIC_HINT = (
    "Could not read performance metrics from the .xcresult.\n"
    "Recent Xcode only writes metrics to the result bundle (not stdout). Share the\n"
    "output of this so the parser can be adjusted:\n"
    "  xcrun xcresulttool get --legacy --format json --path <bundle> | "
    "python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin))[:2000])'"
)


def git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=HERE, text=True
        ).strip()
    except Exception:
        return "unknown"


def parse_log(text: str) -> dict:
    """Extract { "Class/method": { "metric": {average, relativeStandardDeviation} } }."""
    results: dict[str, dict[str, dict]] = {}
    for match in PERF_RE.finditer(text):
        test = f"{match.group('cls')}/{match.group('method')}"
        metric = match.group("metric").strip()
        results.setdefault(test, {})[metric] = {
            "average": float(match.group("avg")),
            "relativeStandardDeviation": float(match.group("rsd")),
        }
    return results


def _xcresulttool(bundle: Path, extra: list[str]) -> dict:
    """Run `xcrun xcresulttool get` returning parsed JSON, trying the Xcode 16+
    `--legacy` flag first and falling back to the older invocation."""
    base = ["xcrun", "xcresulttool", "get"]
    for prefix in (["--legacy"], []):
        try:
            out = subprocess.check_output(
                base + prefix + ["--format", "json", "--path", str(bundle)] + extra,
                text=True,
                stderr=subprocess.DEVNULL,
            )
            return json.loads(out)
        except subprocess.CalledProcessError:
            continue
    raise RuntimeError("xcresulttool get failed")


def _val(node: dict, *keys: str):
    """Pull a scalar `_value` from a legacy xcresult node by nested keys."""
    cur = node
    for key in keys:
        cur = cur.get(key, {}) if isinstance(cur, dict) else {}
    return cur.get("_value") if isinstance(cur, dict) else None


def _stats(values: list[float]) -> dict:
    avg = sum(values) / len(values)
    if len(values) > 1 and avg:
        variance = sum((v - avg) ** 2 for v in values) / len(values)
        rsd = round(variance ** 0.5 / avg * 100.0, 3)
    else:
        rsd = 0.0
    return {"average": avg, "relativeStandardDeviation": rsd}


def extract_from_xcresult(bundle: Path) -> dict:
    """Extract { "Target/Class/method": { "metric, unit": {average, rsd} } } from a
    result bundle via xcresulttool (legacy JSON object graph)."""
    root = _xcresulttool(bundle, [])
    test_refs = [
        ref
        for action in root.get("actions", {}).get("_values", [])
        if (ref := _val(action, "actionResult", "testsRef", "id"))
    ]

    results: dict[str, dict] = {}

    def walk(node: dict, target: str) -> None:
        subtests = node.get("subtests", {}).get("_values")
        if subtests:
            for child in subtests:
                walk(child, target)
            return
        summary_ref = _val(node, "summaryRef", "id")
        if summary_ref is None:
            return
        identifier = (_val(node, "identifier") or _val(node, "name") or "").rstrip("()")
        detail = _xcresulttool(bundle, ["--id", summary_ref])
        metrics: dict[str, dict] = {}
        for metric in detail.get("performanceMetrics", {}).get("_values", []):
            name = _val(metric, "displayName") or "metric"
            unit = _val(metric, "unitOfMeasurement") or ""
            values = [
                float(m["_value"])
                for m in metric.get("measurements", {}).get("_values", [])
                if m.get("_value") is not None
            ]
            if not values:
                continue
            metrics[f"{name}, {unit}" if unit else name] = _stats(values)
        if metrics:
            key = f"{target}/{identifier}" if target else identifier
            results[key] = metrics

    for ref in test_refs:
        summaries = _xcresulttool(bundle, ["--id", ref])
        for summary in summaries.get("summaries", {}).get("_values", []):
            for testable in summary.get("testableSummaries", {}).get("_values", []):
                target = _val(testable, "targetName") or _val(testable, "name") or ""
                for test in testable.get("tests", {}).get("_values", []):
                    walk(test, target)
    return results


def build_record(results: dict, tolerance: float, noise_sigma: float, gate_patterns: list[str]) -> dict:
    return {
        "format": FORMAT_ID,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "git": git_sha(),
        "tolerancePercent": tolerance,
        "noiseSigma": noise_sigma,
        "gateMetrics": gate_patterns,
        "results": results,
    }


def write_json(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + "\n")


def record_run(record: dict, results_dir: Path, history: Path) -> Path:
    results_dir.mkdir(parents=True, exist_ok=True)
    stamp = record["generatedAt"].replace(":", "").replace("-", "")
    run_path = results_dir / f"run-{stamp}.json"
    write_json(run_path, record)
    write_json(results_dir / "latest.json", record)
    # Append a compact one-line summary for long-term history.
    summary = {
        "generatedAt": record["generatedAt"],
        "git": record["git"],
        "results": {
            test: {metric: data["average"] for metric, data in metrics.items()}
            for test, metrics in record["results"].items()
        },
    }
    with history.open("a") as handle:
        handle.write(json.dumps(summary) + "\n")
    return run_path


def load_baseline(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as error:
        print(f"error: baseline {path} is not valid JSON ({error})", file=sys.stderr)
        return None


def fmt(value: float) -> str:
    return f"{value:.4g}"


def _stddev(entry: dict) -> float:
    """Recover absolute standard deviation from a stored {average, rsd%} entry."""
    return abs(entry.get("average", 0.0)) * entry.get("relativeStandardDeviation", 0.0) / 100.0


def _is_gated(metric: str, gate_patterns: list[str]) -> bool:
    """A metric gates the build if gating is 'all' or its name matches a pattern."""
    if any(p.strip().lower() == "all" for p in gate_patterns):
        return True
    return any(p.strip() and p.strip().lower() in metric.lower() for p in gate_patterns)


def compare(
    current: dict,
    baseline: dict,
    tolerance: float,
    noise_sigma: float,
    gate_patterns: list[str],
) -> bool:
    """Print a noise-aware comparison table. Returns True if a GATED metric regressed.

    A metric is over-threshold only when the change exceeds BOTH:
      * `tolerance`  — the relative threshold we care about, and
      * the measurement noise — `noise_sigma` × combined stddev of the two runs.

    Only metrics matching `gate_patterns` can fail the build. Others are shown for
    information (suffixed `·info`). This matters because metrics like
    `Memory Peak Physical` have a tiny *within-run* stddev (a high-water mark over
    correlated iterations) yet vary several percent *between* processes — they
    measure whole-process footprint, not the code under test, so they should not
    gate. The deterministic signal is `CPU Instructions Retired`.
    """
    base_results: dict = baseline.get("results", {})
    cur_results: dict = current["results"]

    header = f"{'TEST / metric':<58} {'baseline':>12} {'current':>12} {'delta%':>8} {'rsd%':>6}  status"
    print(header)
    print("-" * len(header))

    regressed = False
    for test in sorted(cur_results):
        print(test)
        for metric in sorted(cur_results[test]):
            cur_entry = cur_results[test][metric]
            cur = cur_entry["average"]
            cur_rsd = cur_entry.get("relativeStandardDeviation", 0.0)
            gated = _is_gated(metric, gate_patterns)
            base_entry = base_results.get(test, {}).get(metric)
            if base_entry is None:
                print(f"  {metric:<56} {'—':>12} {fmt(cur):>12} {'—':>8} {cur_rsd:>5.0f}%  new")
                continue

            base = base_entry["average"]
            diff = cur - base
            band = noise_sigma * ((_stddev(base_entry) ** 2 + _stddev(cur_entry) ** 2) ** 0.5)

            if base == 0:
                status = "ok" if cur == 0 else "changed"
                delta_str = "—"
            else:
                delta = diff / base * 100.0
                delta_str = f"{delta:+.1f}%"
                if abs(diff) <= band:
                    status = "noise"  # within measurement jitter — not actionable
                elif delta > tolerance:
                    if gated:
                        status = "REGRESSED"
                        regressed = True
                    else:
                        status = "regressed·info"
                elif delta < -tolerance:
                    status = "improved" if gated else "improved·info"
                else:
                    status = "ok"
            print(f"  {metric:<56} {fmt(base):>12} {fmt(cur):>12} {delta_str:>8} {cur_rsd:>5.0f}%  {status}")

    print(f"\nGating metrics (only these fail the build): {', '.join(gate_patterns)}")

    # Report metrics present in the baseline but missing this run (e.g. skipped test).
    missing = [
        f"{test} / {metric}"
        for test in base_results
        for metric in base_results[test]
        if metric not in cur_results.get(test, {})
    ]
    if missing:
        print("\nNot measured this run (present in baseline):")
        for item in missing:
            print(f"  - {item}")

    return regressed


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Parse + compare XCTest performance results.")
    parser.add_argument("mode", choices=["compare", "baseline"])
    parser.add_argument("--xcresult", type=Path, help="xcresult bundle to read metrics from (preferred)")
    parser.add_argument("--log", type=Path, help="xcodebuild stdout log (fallback for older Xcode)")
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--results-dir", type=Path, default=DEFAULT_RESULTS_DIR)
    parser.add_argument("--history", type=Path, default=DEFAULT_HISTORY)
    parser.add_argument("--tolerance", type=float, default=10.0, help="regression threshold (percent)")
    parser.add_argument(
        "--noise-sigma",
        type=float,
        default=2.0,
        help="ignore changes within this many combined std-deviations (0 disables)",
    )
    parser.add_argument(
        "--gate-metrics",
        default="CPU Instructions Retired",
        help="comma-separated metric name substrings that may fail the build, or 'all'",
    )
    args = parser.parse_args(argv)
    gate_patterns = [p for p in args.gate_metrics.split(",") if p.strip()]

    # Prefer the result bundle (recent Xcode only writes metrics there); fall back
    # to parsing the stdout log (older Xcode prints `measured […]` lines).
    results: dict = {}
    if args.xcresult and args.xcresult.exists():
        try:
            results = extract_from_xcresult(args.xcresult)
        except Exception as error:
            print(f"error: failed to read {args.xcresult}: {error}", file=sys.stderr)
            print(DIAGNOSTIC_HINT.replace("<bundle>", str(args.xcresult)), file=sys.stderr)
            return 2
    elif args.log and args.log.exists():
        results = parse_log(args.log.read_text(errors="replace"))
    else:
        print("error: provide --xcresult <bundle> (preferred) or --log <file>.", file=sys.stderr)
        return 2

    if not results:
        print("error: no performance measurements found.", file=sys.stderr)
        print("       (did the benchmark tests run as performance/measure tests?)", file=sys.stderr)
        if args.xcresult:
            print(DIAGNOSTIC_HINT.replace("<bundle>", str(args.xcresult)), file=sys.stderr)
        return 2

    record = build_record(results, args.tolerance, args.noise_sigma, gate_patterns)
    run_path = record_run(record, args.results_dir, args.history)

    measured = sum(len(metrics) for metrics in results.values())
    print(f"Parsed {measured} metric(s) across {len(results)} test(s). Saved {run_path.name}.\n")

    if args.mode == "baseline":
        write_json(args.baseline, record)
        print(f"Baseline updated: {args.baseline}")
        return 0

    baseline = load_baseline(args.baseline)
    if baseline is None:
        print(f"No baseline at {args.baseline}. Showing current results; run `make benchmark_baseline` to set one.\n")
        compare(record, {"results": {}}, args.tolerance, args.noise_sigma, gate_patterns)
        return 0

    regressed = compare(record, baseline, args.tolerance, args.noise_sigma, gate_patterns)
    print()
    gate = f"> {args.tolerance:g}% AND > {args.noise_sigma:g}σ noise"
    if regressed:
        print(f"❌ Regression ({gate}) vs baseline ({baseline.get('git', '?')}).")
        return 1
    print(f"✅ No regression ({gate}) vs baseline ({baseline.get('git', '?')}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
