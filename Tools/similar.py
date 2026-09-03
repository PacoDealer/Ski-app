#!/usr/bin/env python3
"""Find runs that look like the same descent, with no map and no trail database.

    Tools/similar.py              # ranked candidate pairs across every fixture
    Tools/similar.py --clusters N # group at an N-metre mean-deviation threshold

**Why this exists.** Run comparison is the next feature on Slopes' Premium list, and it needs an
answer to "which of these descents are the same run?". Slopes answers it from a per-resort trail
database it pays people to maintain — the thing its paywall actually protects. We have no map and
are not going to build one, so the question has to be answered from the track itself.

**The method.** Resample each run's GPS trace to `SAMPLES` points evenly spaced *by distance along
the track*, then score a pair by the mean great-circle distance between corresponding points.
Resampling by distance rather than by time is what makes a fast descent and a slow one comparable.

**What was tried first and is not enough.** Matching on the start and end coordinates alone: at
Portillo every run off one lift starts and ends at the same two stations, so 2026-09-02 run 5 and
2026-09-03 run 9 match to 10 m at the start and 137 m at the end while covering 1,197 m and 1,608 m
— plainly different pistes. Shape matching separates them; endpoints do not.

**🔴 WHY THERE IS NO THRESHOLD IN HERE YET.** The pairwise scores form a continuum — 11, 21, 25,
30, 35, 43, 50, 59, 66, 69, … metres — with no gap to cut at, which is exactly what a resort of
overlapping corridors should look like. Choosing a number here and shipping "you have skied this
run 5 times" would be a claim we have not validated (R20), and **Slopes' export carries no trail
name**, so it cannot settle it either. The ground truth is Martin, who skied them. Until those
labels exist this prints candidates for a human to confirm and deliberately asserts nothing.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (MAX_H_ACC, haversine, load, resume_seams, segment_runs, split_at_seams)

ROOT = Path(__file__).parent.parent
FIXTURES = ROOT / "Data" / "fixtures"
FILES = ["2026-09-01_portillo_s1", "2026-09-01_portillo_s2",
         "2026-09-02_portillo_s3", "2026-09-03_portillo_s4"]
SAMPLES = 32


def resample(points, n=SAMPLES):
    """`n` points evenly spaced by distance along the track — not by time.

    By distance is the point: the same piste skied hard and skied slowly produces very different
    time sampling and near-identical spatial sampling, and it is the shape we are comparing.
    """
    if len(points) < 2:
        return None
    cumulative = [0.0]
    for a, b in zip(points, points[1:]):
        cumulative.append(cumulative[-1] + haversine(*a, *b))
    total = cumulative[-1]
    if total <= 0:
        return None
    out, j = [], 0
    for k in range(n):
        target = total * k / (n - 1)
        while j < len(cumulative) - 2 and cumulative[j + 1] < target:
            j += 1
        span = cumulative[j + 1] - cumulative[j]
        f = 0.0 if span <= 0 else (target - cumulative[j]) / span
        out.append((points[j][0] + (points[j + 1][0] - points[j][0]) * f,
                    points[j][1] + (points[j + 1][1] - points[j][1]) * f))
    return out


def load_runs():
    runs = []
    for name in FILES:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        locs = [l for l in recs["loc"] if l["dt"] >= 0 and 0 <= l["hAcc"] <= MAX_H_ACC]
        baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
        seams = resume_seams(recs["note"])
        segmented = [r for t, a in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams)
                     for r in segment_runs(t, a)]
        for i, r in enumerate(segmented, 1):
            track = resample([(l["lat"], l["lon"]) for l in locs
                              if r["start"] <= l["dt"] <= r["end"]])
            if track:
                runs.append({"label": f"{name[5:10]} r{i}", "drop": r["drop"], "track": track})
    return runs


def deviation(a, b):
    """Mean and worst point-to-point separation between two resampled tracks, in metres."""
    d = [haversine(*p, *q) for p, q in zip(a["track"], b["track"])]
    return sum(d) / len(d), max(d)


def main(threshold=None):
    runs = load_runs()
    pairs = []
    for i in range(len(runs)):
        for j in range(i + 1, len(runs)):
            mean, worst = deviation(runs[i], runs[j])
            pairs.append((mean, worst, runs[i], runs[j]))
    pairs.sort(key=lambda p: p[0])

    print(f"{len(runs)} runs with usable tracks, {len(pairs)} pairs.\n")
    print("Most similar pairs — CANDIDATES ONLY, nothing here is asserted to be the same piste:\n")
    print(f"  {'run A':<12} {'run B':<12} {'mean':>7} {'worst':>7}   {'vertical':>13}")
    for mean, worst, a, b in pairs[:20]:
        print(f"  {a['label']:<12} {b['label']:<12} {mean:>6.0f}m {worst:>6.0f}m"
              f"   {a['drop']:>5.0f} / {b['drop']:<5.0f} m")

    print(f"\n  the ranking is a continuum, not two populations: "
          f"{', '.join('%.0f' % p[0] for p in pairs[:12])} …")
    print("  → no gap to cut at, so no threshold is chosen here. See the module docstring.")

    if threshold is not None:
        print(f"\nClusters at mean deviation < {threshold} m (single-link):")
        parent = list(range(len(runs)))

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        for mean, _, a, b in pairs:
            if mean < threshold:
                ra, rb = find(runs.index(a)), find(runs.index(b))
                if ra != rb:
                    parent[ra] = rb
        groups = {}
        for i, r in enumerate(runs):
            groups.setdefault(find(i), []).append(r)
        for n, (_, members) in enumerate(sorted(groups.items(), key=lambda g: -len(g[1])), 1):
            if len(members) < 2:
                continue
            drops = [m["drop"] for m in members]
            print(f"  group {n}: {len(members)}×  {', '.join(m['label'] for m in members)}"
                  f"   vertical {min(drops):.0f}–{max(drops):.0f} m")


if __name__ == "__main__":
    t = None
    if "--clusters" in sys.argv:
        t = float(sys.argv[sys.argv.index("--clusters") + 1])
    main(t)
