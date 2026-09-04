#!/usr/bin/env python3
"""Characterise the seconds our runs keep recording after Slopes has closed the same run.

    Tools/runout.py                # every day with an unzipped export
    Tools/runout.py --fixes N      # also print the raw fixes of the N longest tails

**Why this exists.** S14b left one defect open and unexplained: our runs end later than Slopes'.
`grade.py` now measures it — **mean +65 s, median +57 s, later on 21 of 23 graded runs** — which
makes it one-directional and therefore structural, not scatter. It is also the single biggest
contributor to both remaining residuals (distance +5.75%, vertical +2.87%), because every extra
second is distance and altitude we add and Slopes does not.

**And it is a deliberate choice, which is why it must not be blind-tuned (S7: "coasting out is
skiing").** The symmetric change has already been tried and rejected once: trimming the trailing
plateau the way `descent_start` trims the leading one undershot ski time by 13%. So the question
is not "should we trim" but **what is actually in those seconds** — is the skier still descending
at speed, or has the detector simply not noticed he stopped?

This tool answers that with the raw fixes, per run, before anything is changed (R5). It reports,
for the window between Slopes' end and ours: how long, how much altitude, how far, and how fast —
using the identical gates `analyze.py` uses, so the numbers are the ones the app would report.

**What it found (S16), in three parts.**

1. **The tail is not skiing.** 21 tails, mean 72 s, and a **mean speed of 3.3 km/h** — walking
   pace. Only 2 of 21 are still moving at 8 km/h or better and *neither of those is descending*;
   **12 of 21 are neither moving nor dropping at all.** S7's "coasting out is skiing" does not
   describe these seconds. He is standing at the bottom, shuffling towards the lift.

2. **But cutting them would overshoot, by about 2x.** They hold 129 m of vertical against a +69 m
   excess and 1,576 m of distance against a +821 m excess, so a blanket trim lands at **-60 m and
   -756 m** — past Slopes, not on it. That is S7's rejected experiment reproduced with a number,
   and it says the residual was never one error.

3. **Holding the window fixed splits it into two.** Re-measured over **Slopes' exact windows**,
   our distance is **+0.1%** across 23 runs — the method is right, and the whole published +5.75%
   is a boundary artifact, not a measurement error. Our vertical over the same windows is
   **-3.0%**, low on 20 of 23 runs. So the published +2.87% vertical is **two errors cancelling**
   (R28) — a segmentation surplus sitting on top of a measurement deficit — and fixing only the
   visible one would have made vertical worse while making distance right.

**Not yet explained: why vertical reads 3% low inside Slopes' own window.** Note that its top
speed sits +3.59% above ours and S12c/S14b attributed that to Slopes smoothing; a smoothing uplift
of the same sign and size on altitude is a hypothesis with a suspicious coincidence behind it,
nothing more. Do not quote it as a mechanism (A18's lesson) and do not retune vertical on it.
"""

import argparse
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (MAX_H_ACC, MAX_SPEED_ACC, MAX_SPEED_H_ACC, MIN_DISTANCE_DT,
                     attach_run_positions, haversine, load, resume_seams, segment_runs,
                     split_at_seams)
from grade import DAYS, FIXTURES, ROOT, TZ, pair_by_time, slopes_runs


def day_tracks(fixtures):
    """Our runs for a day, each carrying the fixes and barometer samples it was measured from."""
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
                "vert": r["drop"], "dist": r["dist"], "top": r["top_speed"], "dur": r["dur"],
                "started": started, "locs": locs, "baro": baro,
            })
    return sorted(out, key=lambda r: r["start"])


def window_stats(run, t0, t1):
    """Measure one time window of a run exactly the way `analyze.py` measures a whole one."""
    started = run["started"]
    a = (t0 - started).total_seconds()
    b = (t1 - started).total_seconds()
    fixes = [l for l in run["locs"] if a <= l["dt"] <= b and 0 <= l["hAcc"] <= MAX_H_ACC]
    alts = [x[1] for x in run["baro"] if a <= x[0] <= b]

    dist, step_from, speeds = 0.0, None, []
    for l in fixes:
        if step_from is None:
            step_from = l
        elif l["dt"] - step_from["dt"] >= MIN_DISTANCE_DT:
            dist += haversine(step_from["lat"], step_from["lon"], l["lat"], l["lon"])
            step_from = l
        if (l["speed"] >= 0 and 0 <= l["speedAcc"] <= MAX_SPEED_ACC
                and 0 <= l["hAcc"] <= MAX_SPEED_H_ACC):
            speeds.append(l["speed"])
    return {
        "secs": b - a,
        # Top-to-bottom, the way `segment_runs` defines vertical — not a sum of deltas.
        "drop": (alts[0] - alts[-1]) if len(alts) >= 2 else 0.0,
        "dist": dist,
        "mean_kmh": 3.6 * sum(speeds) / len(speeds) if speeds else 0.0,
        "top_kmh": 3.6 * max(speeds) if speeds else 0.0,
        "fixes": fixes,
    }


def main(export_dirs, show_fixes=0):
    tails, windows = [], []
    excess = {"vert": 0.0, "dist": 0.0}
    for d in sorted(export_dirs):
        meta = Path(d) / "Metadata.xml"
        if not meta.exists():
            continue
        ref = slopes_runs(meta)
        if not ref:
            continue
        day = ref[0]["start"].strftime("%Y-%m-%d")
        if day not in DAYS:
            continue
        ours = day_tracks(DAYS[day])
        groups = pair_by_time(ref, ours)
        excess["vert"] += sum(r["vert"] for r in ours) - sum(r["vert"] for r in ref)
        excess["dist"] += sum(r["dist"] for r in ours) - sum(r["dist"] for r in ref)

        print(f"\n=== {day} — what we record after Slopes closes the run ===")
        print(f"{'#':>2} {'tail s':>7} {'drop m':>7} {'dist m':>7} {'mean':>7} {'top':>6}"
              f" | {'run drop':>8} {'run dist':>8} | tail as % of run")
        for i, (s, g) in enumerate(zip(ref, groups), 1):
            if not g:
                continue
            wnd = window_stats(g[-1], s["start"], s["end"])
            wnd.update(day=day, run=i)
            windows.append((s, wnd))
            our_end = g[-1]["end"]
            if our_end <= s["end"]:
                print(f"{i:>2} {(our_end - s['end']).total_seconds():>+7.0f}"
                      f"   (we end first — no tail)")
                continue
            w = window_stats(g[-1], s["end"], our_end)
            v = sum(r["vert"] for r in g)
            di = sum(r["dist"] for r in g)
            w.update(day=day, run=i, run_drop=v, run_dist=di)
            tails.append(w)
            print(f"{i:>2} {w['secs']:>7.0f} {w['drop']:>7.1f} {w['dist']:>7.0f}"
                  f" {w['mean_kmh']:>6.1f}k {w['top_kmh']:>5.1f}k"
                  f" | {v:>8.0f} {di:>8.0f} |"
                  f" {100*w['drop']/v if v else 0:>5.1f}% vert {100*w['dist']/di if di else 0:>5.1f}% dist")

    if not tails:
        return
    n = len(tails)
    print(f"\n=== ALL {n} TAILS ===")
    print(f"  duration     mean {sum(t['secs'] for t in tails)/n:5.0f} s"
          f"   median {sorted(t['secs'] for t in tails)[n//2]:.0f} s"
          f"   worst {max(t['secs'] for t in tails):.0f} s")
    print(f"  vertical     mean {sum(t['drop'] for t in tails)/n:5.1f} m"
          f"   total {sum(t['drop'] for t in tails):.0f} m")
    print(f"  distance     mean {sum(t['dist'] for t in tails)/n:5.0f} m"
          f"   total {sum(t['dist'] for t in tails):.0f} m")
    print(f"  mean speed   mean {sum(t['mean_kmh'] for t in tails)/n:5.1f} km/h"
          f"   slowest {min(t['mean_kmh'] for t in tails):.1f}"
          f"   fastest {max(t['mean_kmh'] for t in tails):.1f}")
    # The discriminating question. A tail that is still descending at speed is skiing and belongs
    # in the run; a tail that is flat and slow is the detector failing to notice he stopped.
    moving = [t for t in tails if t["mean_kmh"] >= 8.0]
    dropping = [t for t in tails if t["drop"] >= 5.0]
    print(f"\n  still moving (mean >= 8 km/h): {len(moving)}/{n}")
    print(f"  still descending (>= 5 m):     {len(dropping)}/{n}")
    print(f"  both:                          {len([t for t in tails if t in moving and t in dropping])}/{n}")
    print(f"  neither (dead time):           "
          f"{len([t for t in tails if t not in moving and t not in dropping])}/{n}")

    # THE CONTROL THAT SPLITS MEASUREMENT FROM SEGMENTATION.
    #
    # Everything above compares our runs to Slopes' runs, so a difference could be either — our
    # numbers, or our window. Re-measuring OUR pipeline over SLOPES' EXACT windows holds the
    # window fixed and leaves only the measurement, and the two answers come apart completely:
    # distance is exact and vertical is not.
    print(f"\n=== the same measurement over SLOPES' EXACT windows (segmentation held fixed) ===")
    print(f"{'#':>2} {'day':>10} | {'vert Slopes':>11} {'ours':>7} {'':>7}"
          f" | {'dist Slopes':>11} {'ours':>7}")
    wv, wd, sv_all, sd_all = 0.0, 0.0, 0.0, 0.0
    for s, w in windows:
        wv += w["drop"]; wd += w["dist"]; sv_all += s["vert"]; sd_all += s["dist"]
        print(f"{w['run']:>2} {w['day']:>10} | {s['vert']:>11.0f} {w['drop']:>7.1f}"
              f" {100*(w['drop']-s['vert'])/s['vert']:>+6.1f}%"
              f" | {s['dist']:>11.0f} {w['dist']:>7.0f}"
              f" {100*(w['dist']-s['dist'])/s['dist']:>+6.1f}%")
    print(f"   TOTAL vertical {sv_all:.0f} vs {wv:.0f} ({100*(wv-sv_all)/sv_all:+.1f}%)"
          f"    distance {sd_all:.0f} vs {wd:.0f} ({100*(wd-sd_all)/sd_all:+.1f}%)")

    # Does the tail ACCOUNT for the residual, or over-explain it? (R28: two errors can cancel,
    # and the day totals are exactly where that hides.) If cutting the tails would move us past
    # Slopes rather than onto it, a blanket trim is the wrong fix however dead the tail looks —
    # which is what S7 already found the one time it was tried.
    tv, td = sum(t["drop"] for t in tails), sum(t["dist"] for t in tails)
    print(f"\n  === would cutting the tails land on Slopes, or overshoot? ===")
    print(f"  vertical   we are {excess['vert']:+.0f} m over Slopes;  tails hold {tv:.0f} m"
          f"  -> cutting all of them leaves {excess['vert'] - tv:+.0f} m")
    print(f"  distance   we are {excess['dist']:+.0f} m over Slopes;  tails hold {td:.0f} m"
          f"  -> cutting all of them leaves {excess['dist'] - td:+.0f} m")

    for t in sorted(tails, key=lambda x: -x["secs"])[:show_fixes]:
        print(f"\n--- {t['day']} run {t['run']}: {t['secs']:.0f} s tail, fix by fix ---")
        for l in t["fixes"]:
            print(f"   dt {l['dt']:8.1f}  hAcc {l['hAcc']:5.1f}  "
                  f"speed {3.6*l['speed'] if l['speed'] >= 0 else -1:6.1f} km/h  alt {l['alt']:7.1f}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("dirs", nargs="*")
    p.add_argument("--fixes", type=int, default=0, metavar="N",
                   help="print the raw fixes of the N longest tails")
    args = p.parse_args()
    main(args.dirs or sorted(str(x) for x in (ROOT / "Data" / "comparisons").glob("slopes_*")
                             if x.is_dir()),
         show_fixes=args.fixes)
