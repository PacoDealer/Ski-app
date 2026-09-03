#!/usr/bin/env python3
"""Grade our per-run numbers against Slopes' itemised runs, day by day and run by run.

    Tools/grade.py                              # every day with an unzipped export
    Tools/grade.py Data/comparisons/slopes_*    # specific ones

**What this is for.** `.slopes` exports carry one `<Action>` per lift and per run with vertical,
distance, duration and top speed — Slopes' Premium run-by-run data, exportable free. That makes
them the only external ground truth this project has, and the only honest way to add a number to
the app is to grade it against them first. Vertical has been graded since S12; distance and
per-run top speed are graded here from S14, and distance failed its first grading (see below).

**Pairing is by time overlap, never by index (R27).** The two lists are not the same length: on
2026-09-03 we report 9 runs to Slopes' 8, because we split one of its runs across a 4-minute
mid-run gap. Zipping them positionally manufactured a 14-minute "error" in `falsetop.py` before
this rule was learned. Each of our runs is attributed to the Slopes run it overlaps most, so a
split shows up as a group of two rather than as an error, and the group is summed before comparing.

**What it found on its first run (S14).** Summing every 1 Hz fix put our run distance **+9.8%**
over Slopes across three days — the distance twin of the 5–10% vertical overestimate this whole
project exists to criticise, in our own code. `MIN_DISTANCE_DT` fixed it to 1.0% mean. Grade a
number before printing it.
"""

import datetime
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (MIN_RUN_DROP_M, attach_run_positions, load, resume_seams, segment_runs,
                     split_at_seams)

TZ = datetime.timezone(datetime.timedelta(hours=-4))
ROOT = Path(__file__).parent.parent
FIXTURES = ROOT / "Data" / "fixtures"
DAYS = {
    "2026-09-01": ["2026-09-01_portillo_s1", "2026-09-01_portillo_s2"],
    "2026-09-02": ["2026-09-02_portillo_s3"],
    "2026-09-03": ["2026-09-03_portillo_s4"],
}


def slopes_runs(metadata, min_vertical=MIN_RUN_DROP_M):
    """Slopes' itemised runs. Fragments under our own minimum are skipped, not counted as misses."""
    root = ET.parse(metadata).getroot()
    out = []
    for a in (e.attrib for e in root.iter("Action")):
        if a["type"] != "Run" or float(a["vertical"]) < min_vertical:
            continue
        out.append({
            "start": datetime.datetime.strptime(a["start"], "%Y-%m-%d %H:%M:%S %z"),
            "end": datetime.datetime.strptime(a["end"], "%Y-%m-%d %H:%M:%S %z"),
            "vert": float(a["vertical"]),
            "dist": float(a["distance"]),
            "top": float(a["topSpeed"]),
        })
    return out


def our_runs(fixtures):
    out = []
    for name in fixtures:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        started = datetime.datetime.fromisoformat(recs["meta"]["startedAt"].replace("Z", "+00:00"))
        locs = [l for l in recs["loc"] if l["dt"] >= 0]
        baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
        seams = resume_seams(recs["note"])
        runs = [r for t, a in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams)
                for r in segment_runs(t, a)]
        for r in attach_run_positions(runs, locs):
            out.append({
                "start": (started + datetime.timedelta(seconds=r["start"])).astimezone(TZ),
                "end": (started + datetime.timedelta(seconds=r["end"])).astimezone(TZ),
                "vert": r["drop"], "dist": r["dist"], "top": r["top_speed"],
                "dur": r["dur"],
            })
    return sorted(out, key=lambda r: r["start"])


def pair_by_time(ref, ours):
    """Group our runs under the Slopes run they overlap most (R27). Many-to-one is expected."""
    groups = [[] for _ in ref]
    for r in ours:
        best, best_key = None, None
        for i, s in enumerate(ref):
            overlap = (min(r["end"], s["end"]) - max(r["start"], s["start"])).total_seconds()
            key = (overlap > 0, overlap, -abs((r["start"] - s["start"]).total_seconds()))
            if best_key is None or key > best_key:
                best, best_key = i, key
        groups[best].append(r)
    return groups


def pct(a, b):
    return f"{100 * (a - b) / b:+6.1f}%" if b else "     —"


def grade(export_dirs):
    totals = {"vert": [], "dist": [], "top": [], "start": []}
    for d in sorted(export_dirs):
        meta = Path(d) / "Metadata.xml"
        if not meta.exists():
            continue
        ref = slopes_runs(meta)
        if not ref:
            continue
        day = ref[0]["start"].strftime("%Y-%m-%d")
        if day not in DAYS:
            print(f"\n=== {day}: no recording of ours — reference only ===")
            continue
        ours = our_runs(DAYS[day])
        groups = pair_by_time(ref, ours)

        print(f"\n=== {day} ===")
        print(f"{'#':>2} {'start Δs':>8} | {'vert':>16} | {'distance':>18} | {'top speed':>17}")
        print(f"{'':>2} {'':>8} | {'Slopes':>6} {'ours':>9} | {'Slopes':>7} {'ours':>10} |"
              f" {'Slopes':>5} {'ours':>11}")
        for s, g in zip(ref, groups):
            if not g:
                print(f"{ref.index(s)+1:>2} {'MISSED':>8} |")
                continue
            v = sum(r["vert"] for r in g)
            di = sum(r["dist"] for r in g)
            tp = max(r["top"] for r in g)
            ds = (g[0]["start"] - s["start"]).total_seconds()
            totals["vert"].append(100 * (v - s["vert"]) / s["vert"])
            totals["dist"].append(100 * (di - s["dist"]) / s["dist"])
            totals["start"].append(abs(ds))
            if tp >= 0 and s["top"] > 0:
                totals["top"].append(100 * (tp - s["top"]) / s["top"])
            n = f"×{len(g)}" if len(g) > 1 else "  "
            print(f"{ref.index(s)+1:>2} {ds:>+8.0f} |"
                  f" {s['vert']:>6.0f} {v:>6.0f}{pct(v, s['vert'])[:0]}{n} {pct(v, s['vert'])} |"
                  f" {s['dist']:>7.0f} {di:>7.0f} {pct(di, s['dist'])} |"
                  f" {s['top']*3.6:>5.1f} {tp*3.6:>5.1f} {pct(tp, s['top'])}")

        sv = sum(r["vert"] for r in ref)
        sd = sum(r["dist"] for r in ref)
        ov = sum(r["vert"] for r in ours)
        od = sum(r["dist"] for r in ours)
        print(f"   day    vertical {sv:>7.1f} vs {ov:>7.1f} {pct(ov, sv)}"
              f"    distance {sd/1000:>5.2f} km vs {od/1000:>5.2f} km {pct(od, sd)}"
              f"    runs {len(ref)} vs {len(ours)}")

    if totals["vert"]:
        print(f"\n=== ALL {len(totals['vert'])} GRADED RUNS ===")
        for k, label in (("vert", "vertical"), ("dist", "distance"), ("top", "top speed")):
            v = totals[k]
            if not v:
                continue
            print(f"  {label:<10} mean {sum(v)/len(v):+6.2f}%   mean|err| {sum(abs(x) for x in v)/len(v):5.2f}%"
                  f"   worst {max(v, key=abs):+6.1f}%")
        st = totals["start"]
        print(f"  {'run start':<10} mean |error| {sum(st)/len(st):5.0f} s   worst {max(st):.0f} s")


if __name__ == "__main__":
    dirs = sys.argv[1:] or sorted(str(p) for p in (ROOT / "Data" / "comparisons").glob("slopes_*")
                                  if p.is_dir())
    grade(dirs)
