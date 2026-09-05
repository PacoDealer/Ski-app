#!/usr/bin/env python3
"""Compare two descents over the part of the mountain they actually share.

    Tools/compare.py            # rank every pair, and grade against Martin's labels
    Tools/compare.py --grade    # just the grading summary

**The feature this prototypes.** Run comparison is the next item on Slopes' Premium list (D7).
Slopes answers "which two descents are comparable?" from a per-resort trail database it pays people
to maintain — a run is an atom, and two descents of it are trivially comparable. **We have no trail
database and are not going to build one**, so the question has to come off the track itself.

**Why that turns into an advantage rather than a compromise.** Because Slopes compares *named runs
from its database*, it can compare nothing at a resort it has not mapped, and nothing about two
descents that only partly overlap. We compare **the shared part of any two descents anywhere** —
which is strictly more general, works at an unmapped resort, and is the honest unit besides: S15b
established that at Portillo a descent is composed at ski time out of several pistes, so "the same
run" is often not a fact about the mountain at all.

**Why not names.** Martin labelled 24 descents and wrote *routes*, not piste names — "Las Lomas, a
Canarios, hasta el hotel" is three pistes linked. Geometry recovers the corridor two descents share;
it cannot recover his name for it, and S15b/S18 both confirmed the label populations overlap
irreducibly. So this asserts **no names and no identity**. It says: here is how much of the mountain
these two descents have in common, and here is how you skied it each time.

**The governing lesson, from the S18 audit (R31b twice over).** The S15b `band_deviation` fix —
sample at absolute altitudes both descents share — was validated on the single pair that motivated
it and never scored against the whole label set. Scored properly it tightens same-piste pairs
(11–142 m → 11–34 m) **and collapses different-piste ones**, 673 m → 13 m, because the shared band
can be a thin slice near a common lift station where every route looks alike. Seven of twelve false
matches shared only 10–50% of the longer descent.

**⇒ Separation without coverage is meaningless, so both are reported and neither is hidden inside a
single number.** Nothing here classifies. Pairs are *ranked*, the two quantities are printed, and no
threshold on the resort's geometry is fitted — which is what makes it shippable under the S18
standing limitation that everything is tested at exactly one resort (R5).
"""

import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (MAX_H_ACC, haversine, load, resume_seams, segment_runs,
                     speed_lookup, split_at_seams)
from similar import FILES, FIXTURES

ROOT = Path(__file__).parent.parent
SAMPLES = 32
#: Altitude band below which two descents are not worth comparing at all — the same 30 m that
#: `MIN_RUN_DROP_M` uses to decide a descent is a run. Reused rather than chosen, so no new
#: constant enters the code (S18, and Martin's "only resort-independent features").
MIN_BAND_M = 30.0
#: Two descents are offered as comparable when they share **at least half** of the longer one.
#:
#: This is a definition, not a fitted threshold, and the distinction is the whole reason it is
#: allowed to ship (R5/R20). Grading on Portillo says 70% would score better — it takes the
#: same/different overlap from 17 m to 12 m — and **adopting 70% for that reason would be fitting a
#: constant to one resort**, on four days, from eight same-piste pairs. "They share half the
#: descent" is a claim about the two runs; "they share 70%" would be a claim about Portillo.
#: Coverage is shown next to every comparison anyway, so the reader is never asked to trust it.
MIN_COVERAGE = 0.5


def descents():
    """Every detected run in every fixture, with the fixes that fall inside it.

    Keyed exactly as `label.py` keys them, so the labels join without translation.
    """
    out = {}
    for name in FILES:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        locs = [l for l in recs["loc"] if l["dt"] >= 0 and 0 <= l["hAcc"] <= MAX_H_ACC]
        baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
        seams = resume_seams(recs["note"])
        split = split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams)
        # **`speed_at` is not optional here, and leaving it out was a real defect (S18).**
        # `segment_runs` applies the S16 runout trim only when it can read speed; without it the
        # rule degrades to a no-op (R33, missing speed counts as MOVING) and every run keeps its
        # runout. `similar.py`, `liftid.py` and `label.py` all still call it that way, so every
        # geometry tool in this project has been comparing descents that include up to **91 s** of
        # standing around at the base — dead time S16 measured at 3.3 km/h, dragging the bottom of
        # each track around the base area exactly where two descents converge.
        runs = [r for t, a in split for r in segment_runs(t, a, speed_at=speed_lookup(locs))]
        for i, r in enumerate(runs, 1):
            fixes = [l for l in locs if r["start"] <= l["dt"] <= r["end"]]
            if len(fixes) >= 2:
                out[f"{name[5:10]} {name.split('_')[-1]} r{i}"] = {
                    "fixes": fixes, "drop": r["drop"],
                    "start": r["start"], "end": r["end"],
                }
    return out


def position_at(fixes, altitudes):
    """Where the skier was at each absolute altitude, walking the descent once.

    Altitude is the one coordinate a skier cannot pad: traverse as long as you like, you are still
    at 2,900 m when you are at 2,900 m. That is what makes this immune to the two bugs that broke
    resampling by track length (S15b) — a slow descent covering 30% more ground, and a descent we
    truncated at a mid-run stop.

    **🔴 And the altitude used here is GPS, not the barometer — measured, against instinct (S18).**
    Everywhere else in this project the barometer wins: it is the good sensor (0.85 m drift over
    3.2 min) and GPS altitude is the bad one (8.5 m of phantom movement in windows where nothing
    moved, S17). Here it loses, and the grading says so plainly — sampling on `CMAbsoluteAltitude`
    instead takes same-piste pairs from 11–34 m to 19–43 m and widens the overlap with different
    pistes from 12 m to 15 m.

    The reason is that this needs a coordinate that is **comparable between days**, which is a
    different question from being precise within a run. `absAlt` carries a weather-driven offset:
    paired fix by fix against GPS it sits at **−0.2, +5.4, +8.1, +7.4 m** on the four recordings —
    an 8 m swing between days and **5.6 m between two sessions of the same morning**. That bias is
    constant *inside* a descent, so it never hurts a top-to-bottom vertical, and it is exactly what
    ruins registration *across* descents. GPS altitude is noisy but roughly unbiased, and noise
    averages out over 32 samples where a bias does not.

    Same shape as S17's answer to the −3% vertical: the sensor and the question have to be chosen
    together, and the best sensor for one is not the best sensor for the other.
    """
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


def shared(a, b, n=SAMPLES):
    """How much two descents have in common, and how far apart they are over it.

    Returns `(separation_m, shared_m, coverage)` or None when they share too little to compare.

    - `shared_m` is the altitude band both descents actually cover.
    - `coverage` is that band as a fraction of the **longer** descent. Against the longer one on
      purpose: comparing a 400 m run to the 43 m tail of another gave 13 m of separation and meant
      nothing, and dividing by the shorter one would have called that a perfect match (S18).
    - `separation_m` is the mean ground distance between the two, sampled at shared altitudes.
    """
    top = min(a["fixes"][0]["alt"], b["fixes"][0]["alt"])
    bottom = max(a["fixes"][-1]["alt"], b["fixes"][-1]["alt"])
    band = top - bottom
    if band < MIN_BAND_M:
        return None
    targets = [top - band * k / (n - 1) for k in range(n)]
    pa, pb = position_at(a["fixes"], targets), position_at(b["fixes"], targets)
    separation = sum(haversine(*p, *q) for p, q in zip(pa, pb)) / n
    longer = max(a["fixes"][0]["alt"] - a["fixes"][-1]["alt"],
                 b["fixes"][0]["alt"] - b["fixes"][-1]["alt"])
    return separation, band, (band / longer if longer > 0 else 0.0)


def stats(run):
    """The numbers a comparison actually shows, over the whole descent."""
    fixes = run["fixes"]
    duration = run["end"] - run["start"]
    speeds = [f["speed"] for f in fixes
              if f["speed"] >= 0 and 0 <= f["hAcc"] <= 15 and 0 <= f["speedAcc"] <= 3]
    dist, prev = 0.0, None
    for f in fixes:
        if prev is None or f["dt"] - prev["dt"] >= 2.5:
            if prev is not None:
                dist += haversine(prev["lat"], prev["lon"], f["lat"], f["lon"])
            prev = f
    return {"duration": duration, "distance": dist, "drop": run["drop"],
            "top": max(speeds) * 3.6 if speeds else -1,
            "avg": (dist / duration * 3.6) if duration > 0 else 0}


def main(grade_only=False):
    runs = descents()
    scored = []
    for ka, kb in itertools.combinations(sorted(runs), 2):
        s = shared(runs[ka], runs[kb])
        if s:
            scored.append((s[0], s[1], s[2], ka, kb))

    if not grade_only:
        print(f"{len(runs)} descents, {len(scored)} comparable pairs "
              f"(sharing at least {MIN_BAND_M:.0f} m of altitude).\n")
        print("  Ranked by separation over the shared band. Coverage is printed beside it and is")
        print("  half the answer: 13 m over 10% of a run means nothing at all.\n")
        print(f"  {'sep':>5} {'shared':>7} {'cover':>6}   pair")
        for sep, band, cover, ka, kb in sorted(scored)[:15]:
            flag = "" if cover >= MIN_COVERAGE else "   <- thin band, not offered"
            print(f"  {sep:5.0f} {band:7.0f} {cover:6.0%}   {ka} ~ {kb}{flag}")

    grade(scored)


def grade(scored):
    """Score the ranking against Martin's 24 labels — the only ground truth there is."""
    try:
        from label import read_labels, same_piste
    except Exception as e:                                    # pragma: no cover
        print(f"\n  (no labels available: {e})")
        return
    _, names = read_labels()
    if not names:
        return

    same, diff = [], []
    for sep, band, cover, ka, kb in scored:
        pa, pb = names.get(ka), names.get(kb)
        if not pa or not pb:
            continue
        (same if same_piste(pa, pb) else diff).append((sep, cover, ka, kb, pa, pb))

    labelled = {k for k in names if k in {ka for _, _, _, ka, _ in scored} | {kb for _, _, _, _, kb in scored}}
    print(f"\n=== GRADED against {len(labelled)} labelled descents ===")
    for cut in (0.0, 0.5, 0.7, 0.8, 0.9):
        s = [x for x in same if x[1] >= cut]
        d = [x for x in diff if x[1] >= cut]
        if not s or not d:
            continue
        worst_same, best_diff = max(x[0] for x in s), min(x[0] for x in d)
        gap = best_diff - worst_same
        verdict = f"SEPARATED by {gap:.0f} m" if gap > 0 else f"overlap {-gap:.0f} m"
        print(f"  coverage >= {cut:4.0%}   same {min(x[0] for x in s):3.0f}-{worst_same:3.0f} m"
              f"   diff from {best_diff:3.0f} m   {len(s):2d} same / {len(d):3d} diff   {verdict}")

    print("\n  No threshold is adopted from this table. It is here to show what coverage buys,")
    print("  and it buys most of the answer — which is the S18 finding, stated as a measurement.")


if __name__ == "__main__":
    main(grade_only="--grade" in sys.argv)
