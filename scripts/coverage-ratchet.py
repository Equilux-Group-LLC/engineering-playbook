#!/usr/bin/env python3
"""Coverage ratchet (playbook Part 6): total line coverage must not fall below the committed baseline.

Usage: coverage-ratchet.py <report> [--baseline FILE] [--update]
  <report>     LCOV (lcov.info) or Cobertura XML (coverage.xml)
  --baseline   file holding the minimum percentage (default: .coverage-baseline)
  --update     write the current percentage to the baseline when it is higher

Exit codes: 0 ok, 1 coverage dropped, 2 bad input. A missing baseline file passes and prints the value.
"""
import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def lcov_percent(text):
    found = hit = 0
    for line in text.splitlines():
        if line.startswith("LF:"):
            found += int(line[3:])
        elif line.startswith("LH:"):
            hit += int(line[3:])
    if found == 0:
        raise ValueError("LCOV report has no LF records")
    return 100.0 * hit / found


def cobertura_percent(text):
    root = ET.fromstring(text)
    valid, covered = root.get("lines-valid"), root.get("lines-covered")
    if valid and covered and int(valid) > 0:
        return 100.0 * int(covered) / int(valid)
    rate = root.get("line-rate")
    if rate is None:
        raise ValueError("Cobertura report has no line-rate")
    return 100.0 * float(rate)


def total_percent(path):
    text = Path(path).read_text()
    return cobertura_percent(text) if text.lstrip().startswith("<") else lcov_percent(text)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("report")
    parser.add_argument("--baseline", default=".coverage-baseline")
    parser.add_argument("--update", action="store_true")
    args = parser.parse_args(argv)

    try:
        current = round(total_percent(args.report), 2)
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"coverage-ratchet: cannot read {args.report}: {error}", file=sys.stderr)
        return 2

    baseline_path = Path(args.baseline)
    if not baseline_path.exists():
        print(f"Total line coverage {current:.2f}%. No baseline at {args.baseline}; commit one to enable the ratchet.")
        if args.update:
            baseline_path.write_text(f"{current:.2f}\n")
        return 0

    baseline = float(baseline_path.read_text().strip())
    if current + 0.01 < baseline:
        print(f"FAIL: total line coverage {current:.2f}% is below the baseline {baseline:.2f}%.", file=sys.stderr)
        return 1
    print(f"PASS: total line coverage {current:.2f}% (baseline {baseline:.2f}%).")
    if args.update and current > baseline:
        baseline_path.write_text(f"{current:.2f}\n")
        print(f"Baseline raised to {current:.2f}%.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
