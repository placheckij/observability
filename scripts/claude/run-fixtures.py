#!/usr/bin/env python3
"""Send OTLP fixture events to the Collector and check what Loki stored.

Each fixture is a JSON file with:
  otlp    - an OTLP/JSON logs payload; "${RUN_ID}" and "${TIME_UNIX_NANO}" are filled in per run
  expect  - events:   number of events stored for this run's session.id
            metadata: attributes every stored event set must carry (proves metadata is kept)
            absent:   strings that must not appear anywhere in Loki (proves content is stripped)

Standard library only. Exit code 0 when every fixture passes.
"""

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


def fill(value, run_id, now_ns):
    if isinstance(value, str):
        return value.replace("${RUN_ID}", run_id).replace("${TIME_UNIX_NANO}", str(now_ns))
    if isinstance(value, list):
        return [fill(v, run_id, now_ns) for v in value]
    if isinstance(value, dict):
        return {k: fill(v, run_id, now_ns) for k, v in value.items()}
    return value


def http(url, data=None, headers=None, retries=30):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return resp.read()
        except urllib.error.HTTPError as err:
            raise RuntimeError(f"{url}: HTTP {err.code} {err.read()[:500]!r}") from err
        except (urllib.error.URLError, ConnectionError) as err:  # service still starting
            if attempt == retries - 1:
                raise RuntimeError(f"{url}: {err}") from err
            time.sleep(2)
    raise AssertionError("unreachable")


def loki_query(loki, query, start_ns, end_ns):
    params = urllib.parse.urlencode(
        {"query": query, "start": start_ns, "end": end_ns, "limit": 5000, "direction": "forward"}
    )
    return json.loads(http(f"{loki}/loki/api/v1/query_range?{params}"))


def run_fixture(path, otlp, loki, timeout):
    fixture = json.loads(path.read_text())
    run_id = f"fixture-{uuid.uuid4()}"
    now_ns = time.time_ns()
    payload = fill(fixture["otlp"], run_id, now_ns)
    expect = fill(fixture["expect"], run_id, now_ns)

    http(
        f"{otlp}/v1/logs",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )

    start_ns, deadline = now_ns - 60 * 10**9, time.time() + timeout
    session_query = f'{{service_name=~".+"}} | session_id="{run_id}"'
    entries, streams = 0, []
    while time.time() < deadline:
        streams = loki_query(loki, session_query, start_ns, time.time_ns() + 60 * 10**9)["data"]["result"]
        entries = sum(len(s["values"]) for s in streams)
        if entries >= expect["events"]:
            break
        time.sleep(2)

    failures = []
    if entries != expect["events"]:
        failures.append(f"stored {entries} events for session {run_id}, expected {expect['events']}")

    # Loki returns structured metadata merged into each stream's labels.
    labels = [s["stream"] for s in streams]
    for key, want in expect.get("metadata", {}).items():
        if not any(lbl.get(key) == want for lbl in labels):
            failures.append(f"no stored event has metadata {key}={want!r}")

    # Search everything stored around this run, not only this session's streams.
    everything = json.dumps(loki_query(loki, '{service_name=~".+"}', start_ns, time.time_ns() + 60 * 10**9))
    for text in expect.get("absent", []):
        if text in everything:
            failures.append(f"content text {text!r} is stored in Loki")

    status = "FAIL" if failures else "PASS"
    print(f"{status} {path.name}: {fixture['description']}")
    for failure in failures:
        print(f"  - {failure}")
    return not failures


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("fixtures", nargs="?", default="observability-solution/claude/fixtures")
    parser.add_argument("--otlp", default="http://localhost:4318", help="Collector OTLP/HTTP base URL")
    parser.add_argument("--loki", default="http://localhost:3100", help="Loki base URL")
    parser.add_argument("--timeout", type=int, default=60, help="seconds to wait for events in Loki")
    args = parser.parse_args()

    paths = sorted(pathlib.Path(args.fixtures).glob("*.json"))
    if not paths:
        sys.exit(f"no fixtures in {args.fixtures}")
    results = [run_fixture(p, args.otlp, args.loki, args.timeout) for p in paths]
    print(f"{sum(results)}/{len(results)} fixtures passed")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
