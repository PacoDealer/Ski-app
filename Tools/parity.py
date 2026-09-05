#!/usr/bin/env python3
"""Prove the app's Swift and the offline Python report the same runs, run for run.

    Tools/parity.py                       # every fixture
    Tools/parity.py Data/fixtures/*.jsonl # specific ones

**Why this exists (S18).** R12a is "one rule, one implementation, and a harness that proves it",
and the harness was only ever half-built. `Tools/replay.sh` compiles the app's own
`LiveMetrics.swift` and prints its runs; `Tools/analyze.py` prints the same runs the Python way.
Both existed, and every session log from S12 on says some version of "`replay.sh` agrees Swift ==
Python on all N runs" — but **nothing compared the two outputs.** A human read two printouts side
by side. That is the single most load-bearing claim in the project checked by the least reliable
method in it, and it gets less reliable exactly as the fixtures get bigger: S17's day-4 table is
20 runs x 4 columns.

So this diffs them. It runs both harnesses and compares **vertical, distance, duration and top
speed for every run of every fixture**, which is what "the number on the phone is the number the
analyzer prints" actually means.

Exit status is 0 when they agree and 1 when they do not, so it can gate a commit.

**It is a comparison, not a third implementation** — it computes nothing itself and must not start
to. If a column here ever needs its own maths, that maths belongs in `LiveMetrics` with the Python
following it, not in the differ.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent

# analyze.py:  "   1.    411m   2202m   9.6m  47.6    13.8    0.7 m/s"
PY_RUN = re.compile(r"^\s*(\d+)\.\s+(\d+)m\s+(\d+)m\s+([\d.]+)m\s+([\d.]+)\s", re.M)
# replay.swift: "    1.    411 m   2202 m   9.6 min  top  47.6 km/h"
SW_RUN = re.compile(r"^\s*(\d+)\.\s+(\d+) m\s+(\d+) m\s+([\d.]+) min\s+top\s+([\d.]+) km/h", re.M)

COLUMNS = ("vertical m", "distance m", "duration min", "top speed km/h")


def runs(pattern, text):
    """Every run as (vertical, distance, duration, top speed), in file order."""
    return [(int(m[1]), int(m[2]), float(m[3]), float(m[4]))
            for m in (m.groups() for m in pattern.finditer(text))]


def main(paths):
    swift = subprocess.run(["sh", str(ROOT / "Tools" / "replay.sh"), *paths],
                           capture_output=True, text=True)
    if swift.returncode != 0:
        print(swift.stderr.strip() or "replay.sh failed", file=sys.stderr)
        return 1

    # replay.swift prints one "=== <filename>" block per file.
    blocks = {b.split("\n", 1)[0].strip(): b for b in swift.stdout.split("=== ")[1:]}

    failures = 0
    total_runs = 0
    for path in paths:
        name = Path(path).name
        py = subprocess.run([sys.executable, str(ROOT / "Tools" / "analyze.py"), path],
                            capture_output=True, text=True)
        p = runs(PY_RUN, py.stdout)
        s = runs(SW_RUN, blocks.get(name, ""))
        total_runs += len(p)

        if p == s:
            print(f"  OK        {name:<38} {len(p):3d} runs")
            continue

        failures += 1
        print(f"  MISMATCH  {name:<38} python {len(p)} runs, swift {len(s)} runs")
        for i, (a, b) in enumerate(zip(p, s), start=1):
            if a == b:
                continue
            for col, x, y in zip(COLUMNS, a, b):
                if x != y:
                    print(f"      run {i:2d}  {col:<14} python {x}  swift {y}")
        if len(p) != len(s):
            print(f"      run COUNT differs — segmentation itself has drifted, not just a number")

    print()
    if failures:
        print(f"FAIL — {failures} of {len(paths)} fixture(s) disagree.")
        print("The app and the analyzer are running different rules. Fix that before believing")
        print("any number either one prints (R12a).")
        return 1
    print(f"PASS — Swift == Python on all {total_runs} runs across {len(paths)} fixture(s),")
    print(f"       on {', '.join(COLUMNS)}.")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:] or sorted(str(p) for p in (ROOT / "Data" / "fixtures").glob("*.jsonl"))
    sys.exit(main(args))
