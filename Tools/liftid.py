#!/usr/bin/env python3
"""Recognise which lift a ride was on, across days, from the track alone.

    Tools/liftid.py             # cluster every detected ride, print the groups
    Tools/liftid.py --validate  # score those clusters against Slopes' own trackIDs
    Tools/liftid.py --runs      # group runs by the lift that carried them up

**Why this exists.** `similar.py` tried to answer "which of these descents are the same piste?"
straight from the descents, and couldn't: the pairwise scores form a continuum (11, 21, 25, 30, 35,
43, 50 m …) with no gap to cut at. Skiers do not repeat a line. That looked like a dead end until
the obvious thing got tried on the other half of the day — **a lift is a rail.** The cable hangs
where it hangs, so two rides on the same lift produce nearly the same track no matter who is
riding, and two rides on different lifts do not come close.

**The separation is enormous, and it is the gap `similar.py` was missing.** Over 23 detected rides
on three Portillo days, same-lift pairs sit at **3-109 m** and everything else starts at **169 m**.
That is two populations with a 60 m no-man's-land between them, not a continuum, so
`CLUSTER_M = 140` sits in the middle of an empty band rather than being fitted to anything.

**Validated against an external database, not against our own tags.** Slopes' `Metadata.xml`
puts a `trackIDs` attribute on every `<Action type="Lift">` — a stable per-lift UUID out of the
resort database its paywall pays for — and puts **nothing** on the runs. So the lift half of this
question has free ground truth. Clustering our own rides recovers that partition exactly: five
clusters, five trackIDs, **21 of 21 identified rides correct**, no cluster spanning two IDs and no
ID split across clusters. Two further rides that Slopes left with no trackID at all get placed by
us, consistent with their cross-day cluster.

**What it buys the run question.** Conditioned on our own lift cluster — no Slopes data anywhere in
the path — every run pair below **114 m** is same-lift. The lift is the coarse key; shape within a
lift group is the fine one, and only that second step still needs a human to confirm (see
`label.py`). It is also a feature in its own right: "you rode this lift 12 times" is on Slopes'
Premium list, and this reaches it with no map, no OSM `aerialway`, and no new sensor.

**R5 caution, stated rather than buried:** 23 rides, one resort, three days. Portillo's va-et-vient
platters already broke the detector once. The 1:1 agreement with an external database is much
stronger evidence than hand tags, but it is still one mountain, and `CLUSTER_M` has been tested
nowhere else.
"""

import datetime
import glob
import itertools
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (MAX_H_ACC, load, resume_seams, segment_runs, speed_lookup,
                     split_at_seams)
from detect import detect_lifts
from similar import FILES, FIXTURES, deviation, resample

ROOT = Path(__file__).parent.parent
TZ = datetime.timezone(datetime.timedelta(hours=-4))

# Mid-band of the empty stretch between same-lift pairs (max 109 m) and the rest (min 169 m).
CLUSTER_M = 140.0


def _day(name):
    return name[:10]


def load_day(name):
    """Every lift ride and every run in one fixture, each with a distance-resampled track."""
    recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
    started = datetime.datetime.fromisoformat(recs["meta"]["startedAt"].replace("Z", "+00:00"))
    locs = [l for l in recs["loc"] if l["dt"] >= 0 and 0 <= l["hAcc"] <= MAX_H_ACC]
    baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
    seams = resume_seams(recs["note"])
    split = split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams)

    def track(a, b):
        return resample([(l["lat"], l["lon"]) for l in locs if a <= l["dt"] <= b])

    def clock(dt):
        return (started + datetime.timedelta(seconds=dt)).astimezone(TZ)

    lifts, runs = [], []
    # Runs get the speed lookup so their windows carry the S16 runout trim; lifts do not take one.
    # Without it `segment_runs` cannot read speed and the trim degrades to a no-op (R33), which
    # left every run here ending up to 91 s late, out on the flat by the base (S18).
    speed_at = speed_lookup(locs)
    for segs, kind, out in ((detect_lifts, "L", lifts), (segment_runs, "r", runs)):
        found = [s for t, a in split
                 for s in (segs(t, a) if kind == "L" else segs(t, a, speed_at=speed_at))]
        for i, s in enumerate(found, 1):
            tr = track(s["start"], s["end"])
            if tr:
                out.append({"file": name, "day": _day(name), "n": i,
                            "label": f"{_day(name)[5:]} {name.split('_')[-1]} {kind}{i}",
                            "start": s["start"], "end": s["end"],
                            "clock": clock(s["start"]), "clock_end": clock(s["end"]),
                            "drop": s.get("drop", s.get("gain", 0.0)), "track": tr})
    return lifts, runs


def load_all(files=FILES):
    lifts, runs = [], []
    for name in files:
        l, r = load_day(name)
        lifts += l
        runs += r
    return lifts, runs


def cluster(items, threshold=CLUSTER_M):
    """Single-link clustering on mean track deviation. Returns a name per item, in size order.

    Single-link is the right shape here and not a shortcut: two rides on one lift are close because
    they trace the same cable, and that relation chains honestly along a mid-station. The 60 m empty
    band is what makes it safe — there is nothing at the threshold for a chain to leak through.
    """
    parent = list(range(len(items)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    pairs = sorted((deviation(a, b)[0], i, j)
                   for (i, a), (j, b) in itertools.combinations(enumerate(items), 2))
    for mean, i, j in pairs:
        if mean >= threshold:
            break
        a, b = find(i), find(j)
        if a != b:
            parent[a] = b

    groups = {}
    for i in range(len(items)):
        groups.setdefault(find(i), []).append(i)
    names = {}
    for n, (_, members) in enumerate(sorted(groups.items(), key=lambda g: -len(g[1])), 1):
        for i in members:
            names[i] = f"LIFT-{n}"
    return [names[i] for i in range(len(items))], pairs


def attach_lift(runs, lifts, names):
    """Each run inherits the cluster of the last ride that ended before it, in the same file."""
    for r in runs:
        prior = [i for i, l in enumerate(lifts) if l["file"] == r["file"] and l["end"] <= r["start"]]
        r["lift"] = names[max(prior, key=lambda i: lifts[i]["end"])] if prior else "—"
    return runs


def slopes_lifts():
    """Slopes' own itemised lift rides, with the resort-database UUID it puts on each one."""
    out = []
    for d in sorted(glob.glob(str(ROOT / "Data" / "comparisons" / "slopes_2026-*"))):
        meta = Path(d) / "Metadata.xml"
        if not meta.exists():
            continue
        for a in (e.attrib for e in ET.parse(meta).getroot().iter("Action")):
            if a["type"] == "Lift":
                out.append({
                    "start": datetime.datetime.strptime(a["start"], "%Y-%m-%d %H:%M:%S %z"),
                    "end": datetime.datetime.strptime(a["end"], "%Y-%m-%d %H:%M:%S %z"),
                    "track_id": a.get("trackIDs", ""),
                })
    return out


def overlapping(item, reference):
    """The reference entry sharing the most wall-clock time with this one (R27), or None."""
    best, best_overlap = None, 0.0
    for s in reference:
        overlap = (min(item["clock_end"], s["end"]) - max(item["clock"], s["start"])).total_seconds()
        if overlap > best_overlap:
            best, best_overlap = s, overlap
    return best


def report(validate=False, show_runs=False):
    lifts, runs = load_all()
    names, pairs = cluster(lifts)

    same = [m for m, i, j in pairs if names[i] == names[j]]
    other = [m for m, i, j in pairs if names[i] != names[j]]
    print(f"{len(lifts)} lift rides over {len({l['day'] for l in lifts})} days, "
          f"clustered at {CLUSTER_M:.0f} m mean track deviation.\n")
    print(f"  within a cluster : {min(same):.0f}-{max(same):.0f} m ({len(same)} pairs)")
    print(f"  across clusters  : {min(other):.0f}-{max(other):.0f} m ({len(other)} pairs)")
    print(f"  empty band       : {max(same):.0f} m -> {min(other):.0f} m — "
          f"the gap similar.py could not find in the descents\n")

    for name in sorted(set(names), key=lambda n: int(n.split("-")[1])):
        members = [l for l, g in zip(lifts, names) if g == name]
        rises = [m["drop"] for m in members]
        print(f"  {name}: {len(members)}x  rise {min(rises):.0f}-{max(rises):.0f} m   "
              f"{', '.join(m['label'] for m in members)}")

    if validate:
        ref = slopes_lifts()
        print(f"\n=== validated against Slopes' trackIDs ({len(ref)} of its rides) ===")
        seen, unlabelled = {}, []
        for l, g in zip(lifts, names):
            match = overlapping(l, ref)
            tid = match["track_id"] if match else ""
            if tid:
                seen.setdefault(g, set()).add(tid)
            else:
                unlabelled.append((l["label"], g))
        clean = all(len(v) == 1 for v in seen.values())
        ids = [next(iter(v)) for v in seen.values()]
        for g in sorted(seen, key=lambda n: int(n.split("-")[1])):
            print(f"  {g:<8} -> {', '.join(sorted(t[:8] for t in seen[g]))}")
        print(f"\n  {sum(len(v) for v in seen.values())} clusters carry "
              f"{len(set(ids))} distinct trackIDs; "
              f"{'no cluster spans two IDs and no ID is split' if clean and len(set(ids)) == len(ids) else 'MISMATCH'}")
        for label, g in unlabelled:
            print(f"  {label} has no trackID in Slopes' own export — we place it in {g}")

    if show_runs:
        attach_lift(runs, lifts, names)
        print("\n=== runs, grouped by the lift that carried them up ===")
        for r in runs:
            print(f"  {r['label']:<9} {r['clock']:%H:%M}  {r['lift']:<8} {r['drop']:>5.0f} m")
        pairs_same = sorted(deviation(a, b)[0] for a, b in itertools.combinations(runs, 2)
                            if a["lift"] == b["lift"] != "—")
        pairs_diff = sorted(deviation(a, b)[0] for a, b in itertools.combinations(runs, 2)
                            if "—" not in (a["lift"], b["lift"]) and a["lift"] != b["lift"])
        print(f"\n  run pairs off the SAME lift : {min(pairs_same):.0f}-{max(pairs_same):.0f} m")
        print(f"  run pairs off a DIFFERENT one: {min(pairs_diff):.0f}-{max(pairs_diff):.0f} m")
        print(f"  every pair below {min(pairs_diff):.0f} m is same-lift — the lift is the coarse key.")
        print("  Which of those are the SAME PISTE is not asserted here; see Tools/label.py.")


if __name__ == "__main__":
    report(validate="--validate" in sys.argv, show_runs="--runs" in sys.argv)
