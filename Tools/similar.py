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

**➡️ S15 read that continuum correctly, and it was a fact about skiers, not about the resort
(R29).** People do not repeat a line down a piste — but a lift is a rail, and the identical metric
run over the *ascents* in these same files gives two clean populations with a 60 m empty band
between them. See `liftid.py`, which clusters the rides, is validated 1:1 against Slopes' own
per-lift `trackIDs`, and partitions the runs: conditioned on the lift, **every run pair below 114 m
is same-lift**. This module is now the *fine* half of a two-step answer, not the whole one, and
`label.py` collects the human labels that would let a threshold be chosen inside a lift group.
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
                runs.append({"label": f"{name[5:10]} {name.split('_')[-1]} r{i}",
                              "drop": r["drop"], "track": track})
    return runs


def positions_at(fixes, altitudes):
    """Where the skier was at each of these absolute altitudes. Assumes a monotonic descent."""
    pts = [(f["lat"], f["lon"], f["alt"]) for f in fixes]
    out, j = [], 0
    for target in altitudes:
        while j < len(pts) - 2 and pts[j + 1][2] > target:
            j += 1
        a, b = pts[j], pts[j + 1]
        span = a[2] - b[2]
        f = 0.0 if abs(span) < 1e-9 else max(0.0, min(1.0, (a[2] - target) / span))
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out


def band_deviation(fa, fb, n=SAMPLES, min_band=30.0):
    """Mean separation sampled over the altitude band BOTH descents actually cover.

    **This replaces resampling by track length, which had two bugs that a single screenshot from
    Martin exposed at once (S15b).** He skied the same piste on 1 and 3 September — alone the first
    time, with a beginner the second — and the two tracks lie on top of each other on the map, yet
    length-resampling scored them **142 m apart**:

    1. **Traversing defeats it.** Nursing a beginner down meant 2,661 m of track over a piste he had
       covered in 2,063 m alone. "40% of the way along the track" is then not the same place on the
       mountain for the two of them, and the error grows monotonically down the run — which is
       exactly the 32/37/96/151/167/187/205/262 m profile it produced.
    2. **A truncated run is stretched to fit.** We split his 3 September descent in two at a
       four-minute stop, so its "bottom" was 45 m higher than the other's, and normalising each run
       onto its own top and bottom mapped those two different places onto each other.

    Altitude fixes both, because it is the one coordinate a skier cannot pad: you can traverse as
    long as you like, but you are still at 2,900 m when you are at 2,900 m. Sampling at *absolute*
    altitudes shared by both, rather than at fractions of each one's own range, also makes the
    comparison immune to one of them being cut short. The pair goes to **19 m**, and stays at 19 m
    even when scored against the truncated half. It is also the project's best sensor (barometer,
    0.85 m drift over 3.2 min) rather than its worst.
    """
    top = min(fa[0]["alt"], fb[0]["alt"])
    bottom = max(fa[-1]["alt"], fb[-1]["alt"])
    if top - bottom < min_band:
        return None
    targets = [top - (top - bottom) * k / (n - 1) for k in range(n)]
    d = [haversine(*p, *q) for p, q in zip(positions_at(fa, targets), positions_at(fb, targets))]
    return sum(d) / len(d)


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
