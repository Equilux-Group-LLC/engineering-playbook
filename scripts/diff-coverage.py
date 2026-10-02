#!/usr/bin/env python3
"""Changed-line coverage gate (playbook Part 6).

Usage: diff-coverage.py <report> <base-ref> [--head HEAD] [--fail-under 80]
  <report>    LCOV (lcov.info) or Cobertura XML (coverage.xml)
  <base-ref>  commit or ref to diff against (the PR base)

Only lines that are both added/changed in the diff AND instrumented in the report count.
Exit codes: 0 ok (or nothing measurable changed), 1 below threshold, 2 bad input.
"""
import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


def changed_lines(base, head):
    diff = subprocess.run(
        ["git", "diff", "--unified=0", "--no-color", "--diff-filter=AM", f"{base}...{head}"],
        check=True, capture_output=True, text=True,
    ).stdout
    result, current = {}, None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[4:]
            current = path[2:] if path.startswith("b/") else None
            if current:
                result.setdefault(current, set())
        elif current and (match := HUNK.match(line)):
            start, count = int(match.group(1)), int(match.group(2) or 1)
            result[current].update(range(start, start + count))
    return result


def parse_lcov(text):
    hits, current = {}, None
    for line in text.splitlines():
        if line.startswith("SF:"):
            current = hits.setdefault(line[3:].strip(), {})
        elif line.startswith("DA:") and current is not None:
            number, count = line[3:].split(",")[:2]
            current[int(number)] = int(count)
        elif line == "end_of_record":
            current = None
    return hits


def parse_cobertura(text):
    hits = {}
    for cls in ET.fromstring(text).iter("class"):
        lines = hits.setdefault(cls.get("filename", ""), {})
        for line in cls.iter("line"):
            lines[int(line.get("number"))] = int(line.get("hits", "0"))
    return hits


def match_report_file(path, report):
    if path in report:
        return report[path]
    for name, lines in report.items():
        normalized = name.replace("\\", "/")
        if normalized.endswith("/" + path) or path.endswith("/" + normalized.lstrip("./")):
            return lines
    return None


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("report")
    parser.add_argument("base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--fail-under", type=float, default=80.0)
    args = parser.parse_args(argv)

    try:
        text = Path(args.report).read_text()
        report = parse_cobertura(text) if text.lstrip().startswith("<") else parse_lcov(text)
        diff = changed_lines(args.base, args.head)
    except (OSError, ValueError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f"diff-coverage: {error}", file=sys.stderr)
        return 2

    measured = covered = 0
    missing = []
    for path, lines in sorted(diff.items()):
        file_hits = match_report_file(path, report)
        if not file_hits:
            continue
        for number in sorted(lines):
            if number in file_hits:
                measured += 1
                if file_hits[number] > 0:
                    covered += 1
                else:
                    missing.append(f"{path}:{number}")

    if measured == 0:
        print("PASS: no instrumented lines changed.")
        return 0
    percent = 100.0 * covered / measured
    summary = f"changed-line coverage {percent:.1f}% ({covered}/{measured}); threshold {args.fail_under:.0f}%"
    if percent + 1e-9 < args.fail_under:
        print(f"FAIL: {summary}", file=sys.stderr)
        print("Uncovered changed lines:", file=sys.stderr)
        for item in missing[:50]:
            print(f"  {item}", file=sys.stderr)
        return 1
    print(f"PASS: {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
