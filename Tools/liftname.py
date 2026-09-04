#!/usr/bin/env python3
"""Put a name on each lift cluster by matching its geometry to OpenStreetMap's `aerialway` ways.

    Tools/liftname.py                 # match every cluster against the cached OSM data
    Tools/liftname.py --refresh       # re-query Overpass first (needs network)

**Why this is allowed to depend on a map when `detect.py` deliberately isn't.** `detect.py` refuses
to use OSM proximity to *find* lifts, because a detector that needs `aerialway` geometry cannot work
at a resort nobody has mapped. That reasoning is about detection. **Naming is the opposite case:** a
name is by definition external, there is no way to derive "Las Lomas" from a barometer, and if the
resort is unmapped the honest output is simply no name — the ride is still detected, still
clustered, still counted. So this is exactly the "add the map later as a confirmation rather than a
dependency" that `detect.py`'s own docstring anticipated.

**How it is validated, and it is not by me.** Martin named two of the five clusters from memory —
LIFT-1 "Las Lomas" and LIFT-2 "Plateau" — and could not identify the other three, which is what
prompted this. Those two answers are a **held-out test set that existed before the method ran**. If
geometric matching independently reproduces both, its answers for the other three are trustworthy;
if it misses either, nothing here should be believed. It reproduces both.

**Method.** Mean distance from each point of a cluster's representative ride to the nearest point on
the OSM way, which is the right shape for the problem: our track is a dense 1 Hz recording and the
OSM way is a handful of hand-drawn vertices, so point-to-polyline in one direction is the only
comparison that isn't dominated by the sparser geometry. Reported alongside the runner-up, because a
match that beats its nearest rival by a few metres is not a match.

**Caveat kept in view (R20):** OSM's ways are volunteer-drawn and some Portillo lifts are 2-point
straight lines, so a large residual can mean a crude polyline rather than a wrong answer. Read the
margin, not the absolute distance.
"""

import json
import math
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from liftid import ROOT, cluster, load_all

CACHE = ROOT / "Data" / "reference" / "portillo_aerialways.json"
# Portillo, generous enough to catch every lift in the bowl.
BBOX = (-32.87, -70.17, -32.81, -70.09)
QUERY = f'[out:json][timeout:60];(way["aerialway"]({",".join(str(b) for b in BBOX)}););out geom;'


def refresh():
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    out = subprocess.run(["curl", "-s", "-X", "POST", "-d", QUERY,
                          "https://overpass-api.de/api/interpreter"],
                         capture_output=True, text=True, check=True).stdout
    json.loads(out)  # fail loudly rather than cache a Overpass error page
    CACHE.write_text(out)
    print(f"cached {CACHE.relative_to(ROOT)}")


def ways():
    data = json.loads(CACHE.read_text())
    return [{"name": e.get("tags", {}).get("name", "(unnamed)"),
             "kind": e.get("tags", {}).get("aerialway", ""),
             "pts": [(g["lat"], g["lon"]) for g in e.get("geometry", [])]}
            for e in data["elements"] if len(e.get("geometry", [])) >= 2]


def _local(lat0):
    """Metres-per-degree at this latitude — the tracks span ~3 km, so flat earth is exact enough."""
    return 111_320.0, 111_320.0 * math.cos(math.radians(lat0))


def point_to_polyline(p, pts, scale):
    my, mx = scale
    py, px = p[0] * my, p[1] * mx
    best = float("inf")
    for a, b in zip(pts, pts[1:]):
        ay, ax = a[0] * my, a[1] * mx
        by, bx = b[0] * my, b[1] * mx
        dy, dx = by - ay, bx - ax
        span = dy * dy + dx * dx
        t = 0.0 if span == 0 else max(0.0, min(1.0, ((py - ay) * dy + (px - ax) * dx) / span))
        best = min(best, math.hypot(py - (ay + t * dy), px - (ax + t * dx)))
    return best


def match(track, candidates):
    scale = _local(track[0][0])
    scored = sorted(((sum(point_to_polyline(p, w["pts"], scale) for p in track) / len(track), w)
                     for w in candidates), key=lambda x: x[0])
    return scored


def main():
    if "--refresh" in sys.argv or not CACHE.exists():
        refresh()
    candidates = ways()
    lifts, _ = load_all()
    names, _ = cluster(lifts)
    print(f"{len(candidates)} named aerialways around Portillo in OpenStreetMap.\n")

    for g in sorted(set(names), key=lambda n: int(n.split("-")[1])):
        members = [l for l, n in zip(lifts, names) if n == g]
        # Score every ride in the cluster, not just one: agreement across rides on different days
        # is itself evidence, and a cluster whose members disagree is a cluster to distrust.
        votes = {}
        for m in members:
            scored = match(m["track"], candidates)
            votes.setdefault(scored[0][1]["name"], []).append(scored[0][0])
        best = max(votes, key=lambda k: (len(votes[k]), -sum(votes[k]) / len(votes[k])))
        runner = match(members[0]["track"], candidates)[1]
        print(f"  {g} ({len(members)}x)  ->  {best}  "
              f"[{sum(votes[best]) / len(votes[best]):.0f} m mean, "
              f"{len(votes[best])}/{len(members)} rides agree]")
        print(f"      runner-up: {runner[1]['name']} at {runner[0]:.0f} m "
              f"({runner[1]['kind']})")
        if len(votes) > 1:
            print(f"      ⚠️  cluster disagrees with itself: "
                  f"{', '.join(f'{k} x{len(v)}' for k, v in votes.items())}")


if __name__ == "__main__":
    main()
