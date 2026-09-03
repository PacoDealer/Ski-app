#!/usr/bin/env python3
"""Diagnose false run tops, and score a candidate fix against Slopes' itemised runs.

    Tools/falsetop.py                      # report false tops in the fixtures
    Tools/falsetop.py --score <dir>...     # score now-vs-fixed against unzipped .slopes exports

THE BUG (found S12, 2026-09-02). `segment_runs` declares a descent's top at the first turning
point that survives 3 m of hysteresis. On a lift that crests a roll, the altitude can dip just
over 3 m and then climb higher again — so the top is declared *during the climb*, a minute or
more before the real summit. The descent-merge rule then stitches it back together and keeps the
*first* descent's top, so the run's vertical is barely affected but `descent_start` walks its
plateau trim forward from the wrong place, and the run's START TIME is minutes early.

On 2026-09-02 that put runs 7 and 8 at -171 s and -168 s against Slopes' itemised starts, and on
run 7 we declared a descent while Slopes still had him on a lift. Only ski time, vertical rate and
average speed are wrong; vertical is measured top-to-bottom and barely moves.

THE CANDIDATE FIX. When two descents merge, adopt the *higher* of the two tops instead of always
keeping the first. That is what "measured top-to-bottom" already claims to mean, and it leaves the
S5 case alone (there the blip is at the bottom, so the second descent's top is lower and nothing
changes).

WHY IT IS NOT SHIPPED. Scored against Slopes' exports it halves the mean start error on 2026-09-02
(56 s -> 29 s) and is a bit-for-bit no-op on 2026-09-01, but it makes run 6 worse (-9 s -> +54 s)
and moves the day's vertical 1386.0 -> 1390.1, which is a golden number in the test suite. Two
graded days is two graded days (R5). Re-run this with a third before deciding.
"""

import datetime
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (BARO_HYSTERESIS_M, MERGE_ASCENT_M, MERGE_GAP_S, MIN_RUN_DROP_M,
                     descent_start, load, resume_seams, split_at_seams)

TZ = datetime.timezone(datetime.timedelta(hours=-4))   # Portillo
FIXTURES = Path(__file__).parent.parent / "Data" / "fixtures"
DAYS = {
    "2026-09-01": ["2026-09-01_portillo_s1", "2026-09-01_portillo_s2"],
    "2026-09-02": ["2026-09-02_portillo_s3_partial"],
}


def turning_points(times, alts, threshold=BARO_HYSTERESIS_M):
    """The same walk `segment_runs` does, kept here so the experiment can vary one rule at a time."""
    turns = [(times[0], alts[0])]
    at, aa, direction = times[0], alts[0], 0
    for t, a in zip(times[1:], alts[1:]):
        if direction == 0:
            if abs(a - aa) >= threshold:
                direction = -1 if a < aa else 1
                at, aa = t, a
        elif direction == -1:
            if a < aa:
                at, aa = t, a
            elif a - aa >= threshold:
                turns.append((at, aa)); direction = 1; at, aa = t, a
        else:
            if a > aa:
                at, aa = t, a
            elif aa - a >= threshold:
                turns.append((at, aa)); direction = -1; at, aa = t, a
    turns.append((at, aa))
    return turns


def segment(times, alts, adopt_higher_top):
    """`segment_runs`, with the one rule under test switchable."""
    if len(alts) < 2:
        return []
    turns = turning_points(times, alts)
    descents = [{"top_t": t0, "top_a": a0, "bot_t": t1, "bot_a": a1}
                for (t0, a0), (t1, a1) in zip(turns, turns[1:]) if a0 - a1 > 0]

    merged = []
    for d in descents:
        if (merged and d["top_a"] - merged[-1]["bot_a"] < MERGE_ASCENT_M
                and d["top_t"] - merged[-1]["bot_t"] < MERGE_GAP_S):
            if adopt_higher_top and d["top_a"] > merged[-1]["top_a"]:
                merged[-1]["top_a"], merged[-1]["top_t"] = d["top_a"], d["top_t"]
            merged[-1]["bot_t"], merged[-1]["bot_a"] = d["bot_t"], d["bot_a"]
        else:
            merged.append(dict(d))

    runs = []
    for d in merged:
        drop = d["top_a"] - d["bot_a"]
        if drop >= MIN_RUN_DROP_M:
            start = descent_start(times, alts, d["top_t"], d["bot_t"], BARO_HYSTERESIS_M)
            runs.append({"start": start, "end": d["bot_t"], "drop": drop, "top_t": d["top_t"]})
    return runs


def day_runs(fixtures, adopt_higher_top):
    out = []
    for name in fixtures:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        started = datetime.datetime.fromisoformat(recs["meta"]["startedAt"].replace("Z", "+00:00"))
        baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
        seams = resume_seams(recs["note"])
        for times, alts in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams):
            for r in segment(times, alts, adopt_higher_top):
                out.append({"start": (started + datetime.timedelta(seconds=r["start"])).astimezone(TZ),
                            "drop": r["drop"],
                            "top": (started + datetime.timedelta(seconds=r["top_t"])).astimezone(TZ)})
    return sorted(out, key=lambda r: r["start"])


def report_false_tops():
    """Every run whose altitude climbs back above its own declared top."""
    print(f"FALSE TOPS  (hysteresis {BARO_HYSTERESIS_M} m, merge {MERGE_ASCENT_M} m / {MERGE_GAP_S} s)\n")
    print(f"{'day':>10} {'declared':>9} {'real peak':>9} {'late by':>8} {'dip that':>9} {'peak is':>8}")
    print(f"{'':>10} {'top':>9} {'':>9} {'(s)':>8} {'fired (m)':>9} {'higher':>8}")
    total = []
    for day, fixtures in DAYS.items():
        for name in fixtures:
            recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
            started = datetime.datetime.fromisoformat(recs["meta"]["startedAt"].replace("Z", "+00:00"))
            baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
            seams = resume_seams(recs["note"])
            def clk(dt):
                return (started + datetime.timedelta(seconds=dt)).astimezone(TZ).strftime("%H:%M:%S")
            for times, alts in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams):
                for r in segment(times, alts, adopt_higher_top=False):
                    window = [(t, a) for t, a in baro if r["top_t"] - 1 <= t <= r["end"]]
                    if not window:
                        continue
                    top_a = next(a for t, a in window if abs(t - r["top_t"]) < 2)
                    later = [(t, a) for t, a in window if t > r["top_t"] + 5]
                    if not later:
                        continue
                    peak_t, peak_a = max(later, key=lambda x: x[1])
                    if peak_a <= top_a + 0.5:
                        continue
                    dip = top_a - min(a for t, a in window if r["top_t"] <= t <= peak_t)
                    total.append(dip)
                    print(f"{day:>10} {clk(r['top_t']):>9} {clk(peak_t):>9} {peak_t - r['top_t']:>8.0f}"
                          f" {dip:>9.2f} {peak_a - top_a:>+8.2f}")
    print(f"\n{len(total)} false tops. Dips that fired them: "
          f"{', '.join('%.2f' % d for d in sorted(total))} m — all within "
          f"{min(total) - BARO_HYSTERESIS_M:.2f}–{max(total) - BARO_HYSTERESIS_M:.2f} m of the threshold."
          if total else "\nNo false tops.")


def slopes_runs(metadata, min_vertical=MIN_RUN_DROP_M):
    """Slopes' itemised runs, skipping fragments below our own minimum so the lists pair up."""
    root = ET.parse(metadata).getroot()
    return [(datetime.datetime.strptime(a["start"], "%Y-%m-%d %H:%M:%S %z"), float(a["vertical"]))
            for a in (e.attrib for e in root.iter("Action"))
            if a["type"] == "Run" and float(a["vertical"]) >= min_vertical]


def score(export_dirs):
    """Score current behaviour and the candidate fix against each day's Slopes export."""
    for d in export_dirs:
        meta = Path(d) / "Metadata.xml"
        ref = slopes_runs(meta)
        day = ref[0][0].strftime("%Y-%m-%d")
        if day not in DAYS:
            print(f"\n=== {day}: no recording of ours — reference only ===")
            continue
        now, fixed = day_runs(DAYS[day], False), day_runs(DAYS[day], True)
        print(f"\n=== {day} ===")
        print(f"{'#':>2} {'Slopes':>9} | {'now':>9} {'Δs':>6} {'vert':>7} | {'fixed':>9} {'Δs':>6} {'vert':>7}")
        errs_now, errs_fixed = [], []
        for i, (start, vert) in enumerate(ref):
            a = now[i] if i < len(now) else None
            b = fixed[i] if i < len(fixed) else None
            da = (a["start"] - start).total_seconds() if a else None
            db = (b["start"] - start).total_seconds() if b else None
            if da is not None: errs_now.append(abs(da))
            if db is not None: errs_fixed.append(abs(db))
            print(f"{i+1:>2} {start.strftime('%H:%M:%S'):>9} |"
                  f" {a['start'].strftime('%H:%M:%S') if a else '—':>9} {da:>+6.0f} {a['drop']:>7.1f} |"
                  f" {b['start'].strftime('%H:%M:%S') if b else '—':>9} {db:>+6.0f} {b['drop']:>7.1f}")
        print(f"   mean |start error|   now {sum(errs_now)/len(errs_now):.0f} s"
              f"   fixed {sum(errs_fixed)/len(errs_fixed):.0f} s")
        print(f"   day vertical   Slopes {sum(v for _, v in ref):.1f}"
              f"   now {sum(r['drop'] for r in now):.1f}   fixed {sum(r['drop'] for r in fixed):.1f}")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--score":
        score(sys.argv[2:])
    else:
        report_false_tops()
