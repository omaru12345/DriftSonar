#!/usr/bin/env python3
"""Convert an .xcresult's code coverage into an LCOV report for Codecov (TASK-162 / #197).

Self-contained: uses only `xcrun xccov` (always present with Xcode) and the Python
standard library — no gem / third-party uploader dependency. Mirrors how the Core
workflow feeds Codecov an .lcov, so the App layer joins the same coverage report.

Usage:
    xccov_to_lcov.py <TestResults.xcresult> <workspace-root> [out.lcov]

Emits coverage for the App's own Swift sources only: test targets, SwiftPM
checkouts and anything outside the repo are dropped so the numbers reflect
production code.
"""
import json
import os
import subprocess
import sys

# Path fragments whose files are not production App source — excluded from coverage.
_EXCLUDE_FRAGMENTS = (
    "/DriftSonarAppTests/",
    "/DriftSonarAppUITests/",
    "/.build/",
    "/SourcePackages/",
    "/DerivedData/",
)


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: xccov_to_lcov.py <xcresult> <workspace-root> [out.lcov]\n")
        return 2
    xcresult, workspace = sys.argv[1], sys.argv[2]
    out_path = sys.argv[3] if len(sys.argv) > 3 else "coverage.lcov"

    raw = subprocess.check_output(
        ["xcrun", "xccov", "view", "--archive", xcresult, "--json"]
    )
    files = json.loads(raw)

    records = []
    for abs_path, lines in files.items():
        if any(frag in abs_path for frag in _EXCLUDE_FRAGMENTS):
            continue
        rel = os.path.relpath(abs_path, workspace)
        # Skip anything that resolves outside the repo (absolute or parent-relative).
        if rel.startswith("..") or os.path.isabs(rel):
            continue
        das = [
            (entry["line"], entry.get("executionCount", 0))
            for entry in lines
            if entry.get("isExecutable")
        ]
        if not das:
            continue
        body = ["SF:" + rel]
        body += [f"DA:{line},{count}" for line, count in das]
        body.append("end_of_record")
        records.append("\n".join(body))

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(records) + "\n")
    sys.stderr.write(f"Wrote {out_path}: {len(records)} source files\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
