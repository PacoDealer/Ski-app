#!/usr/bin/env python3
"""Characterise the seconds Slopes records before our run starts — the other end of `runout.py`.

    Tools/runup.py                # every day with an unzipped export
    Tools/runup.py --fixes N      # also print the raw fixes of the N longest heads

**Why this exists (S17).** S16 measured and fixed the run END (+65 s -> +21 s) and, in doing so,
made the START the larger boundary error. Across four graded days our runs start **+21.3 s later
than Slopes' on average, later on 34 of 43** — one-directional, so structural, exactly the shape
that made the end defect worth chasing. On the fourth day alone it is +34 s, later on 17 of 20,
and that day's distance reads **-4.6%** over our windows against **+0.3%** over Slopes' own.
Something at the top of the run is being cut.

**And, like the tail, it is a deliberate choice that must not be blind-tuned.** S7/A19 moved the
run start to the end of the leading plateau, because standing at the top of a run was being
counted as ski time (54.5 min vs Slopes' 41). S14 then fixed a false-top defect on top of it.
Reverting either would put ski time back where S7 found it.

So the question is the same one `runout.py` asked at the other end: **what is actually in those
seconds?** If the skier is already descending at speed, we are cutting real run and the trim is
too aggressive. If he is standing still, then Slopes simply opens its window earlier than it
starts counting, we are right, and the deficit has to come from somewhere else.

The tool reports, for the window between Slopes' start and ours: how long, how much altitude, how
far and how fast — using the identical gates `analyze.py` uses, so the numbers are the ones the
app would report. Nothing is changed here (R5); this measures first.
"""

import argparse
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from grade import DAYS, ROOT, pair_by_time, slopes_runs
from runout import day_tracks, window_stats


def main(export_dirs, show_fixes=0):
    heads, early = [], 0
    deficit = {"vert": 0.0, "dist": 0.0}
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
        deficit["vert"] += sum(r["vert"] for r in ours) - sum(r["vert"] for r in ref)
        deficit["dist"] += sum(r["dist"] for r in ours) - sum(r["dist"] for r in ref)

        print(f"\n=== {day} — what Slopes records before our run opens ===")
        print(f"{'#':>2} {'head s':>7} {'drop m':>7} {'dist m':>7} {'mean':>7} {'top':>6}"
              f" | {'run drop':>8} {'run dist':>8} | head as % of run")
        for i, (s, g) in enumerate(zip(ref, groups), 1):
            if not g:
                continue
            our_start = g[0]["start"]
            if our_start <= s["start"]:
                early += 1
                print(f"{i:>2} {(our_start - s['start']).total_seconds():>+7.0f}"
                      f"   (we open first — no head)")
                continue
            w = window_stats(g[0], s["start"], our_start)
            v = sum(r["vert"] for r in g)
            di = sum(r["dist"] for r in g)
            w.update(day=day, run=i, run_drop=v, run_dist=di)
            heads.append(w)
            print(f"{i:>2} {w['secs']:>7.0f} {w['drop']:>7.1f} {w['dist']:>7.0f}"
                  f" {w['mean_kmh']:>6.1f}k {w['top_kmh']:>5.1f}k"
                  f" | {v:>8.0f} {di:>8.0f} |"
                  f" {100*w['drop']/v if v else 0:>5.1f}% vert"
                  f" {100*w['dist']/di if di else 0:>5.1f}% dist")

    if not heads:
        return
    n = len(heads)
    print(f"\n=== ALL {n} HEADS ({early} runs opened before Slopes' and have none) ===")
    print(f"  duration     mean {sum(h['secs'] for h in heads)/n:5.0f} s"
          f"   median {sorted(h['secs'] for h in heads)[n//2]:.0f} s"
          f"   worst {max(h['secs'] for h in heads):.0f} s")
    print(f"  vertical     mean {sum(h['drop'] for h in heads)/n:5.1f} m"
          f"   total {sum(h['drop'] for h in heads):.0f} m")
    print(f"  distance     mean {sum(h['dist'] for h in heads)/n:5.0f} m"
          f"   total {sum(h['dist'] for h in heads):.0f} m")
    print(f"  mean speed   mean {sum(h['mean_kmh'] for h in heads)/n:5.1f} km/h"
          f"   slowest {min(h['mean_kmh'] for h in heads):.1f}"
          f"   fastest {max(h['mean_kmh'] for h in heads):.1f}")

    # The discriminating question, mirrored from `runout.py`. A head already descending at speed
    # is run we are throwing away; a head that is flat and slow is the skier standing at the top,
    # which is precisely what S7/A19 decided not to count.
    moving = [h for h in heads if h["mean_kmh"] >= 8.0]
    dropping = [h for h in heads if h["drop"] >= 5.0]
    print(f"\n  already moving (mean >= 8 km/h): {len(moving)}/{n}")
    print(f"  already descending (>= 5 m):     {len(dropping)}/{n}")
    print(f"  both (this is real run):         "
          f"{len([h for h in heads if h in moving and h in dropping])}/{n}")
    print(f"  neither (standing at the top):   "
          f"{len([h for h in heads if h not in moving and h not in dropping])}/{n}")

    # And the arithmetic that stopped S16 from shipping a blanket trim at the other end (R28):
    # does restoring the heads land on Slopes, or shoot past it?
    hv, hd = sum(h["drop"] for h in heads), sum(h["dist"] for h in heads)
    print(f"\n  === would restoring the heads land on Slopes, or overshoot? ===")
    print(f"  vertical   we are {deficit['vert']:+.0f} m vs Slopes;  heads hold {hv:.0f} m"
          f"  -> adding all of them leaves {deficit['vert'] + hv:+.0f} m")
    print(f"  distance   we are {deficit['dist']:+.0f} m vs Slopes;  heads hold {hd:.0f} m"
          f"  -> adding all of them leaves {deficit['dist'] + hd:+.0f} m")

    for h in sorted(heads, key=lambda x: -x["secs"])[:show_fixes]:
        print(f"\n--- {h['day']} run {h['run']}: {h['secs']:.0f} s head, fix by fix ---")
        for l in h["fixes"]:
            print(f"   dt {l['dt']:8.1f}  hAcc {l['hAcc']:5.1f}  "
                  f"speed {3.6*l['speed'] if l['speed'] >= 0 else -1:6.1f} km/h  alt {l['alt']:7.1f}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("dirs", nargs="*")
    p.add_argument("--fixes", type=int, default=0, metavar="N",
                   help="print the raw fixes of the N longest heads")
    args = p.parse_args()
    main(args.dirs or sorted(str(x) for x in (ROOT / "Data" / "comparisons").glob("slopes_*")
                             if x.is_dir()),
         show_fixes=args.fixes)
