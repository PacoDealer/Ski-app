#!/usr/bin/env python3
"""Draw the recorded days as a map, so a human can say which descents are the same piste.

    Tools/runmap.py [out.html]

**Why a map exists here after maps were cut.** S8 cut *in-app* maps: weeks of work to match a
feature Slopes gives away free. This is not that. It is a harness output, the same class of thing as
`analyze.py`'s tables, and it exists because the ground truth for run comparison is Martin's memory
and he cannot reach it without seeing the mountain: *"if we had a map or something like Slopes I
could tell you and figure it out."* Nothing here ships in the app.

**What it draws.** Every detected run as a polyline in local metres, with the OSM `aerialway`
geometry underneath for orientation and every lift labelled by `liftname.py`. Runs are grouped by
the lift that carried them up, because that is the partition `liftid.py` established and it is what
makes the question small: not "which of these 24 match?" but "of the descents off Las Lomas, which
are the same piste?"

**Projection.** Local equirectangular about the centre of the data — the whole resort spans ~3 km,
where the error against a proper projection is centimetres, and using one keeps this stdlib-only.
"""

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import MAX_H_ACC, load, resume_seams, segment_runs, split_at_seams
from liftid import ROOT, TZ, attach_lift, cluster, load_all
from liftname import CACHE, match, ways
from similar import FILES, FIXTURES, deviation, resample

import datetime


def full_tracks():
    """Every run's complete 1 Hz track, not the 32-point resample used for scoring."""
    out = {}
    for name in FILES:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        locs = [l for l in recs["loc"] if l["dt"] >= 0 and 0 <= l["hAcc"] <= MAX_H_ACC]
        baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
        seams = resume_seams(recs["note"])
        runs = [r for t, a in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams)
                for r in segment_runs(t, a)]
        for i, r in enumerate(runs, 1):
            out[f"{name[5:10]} r{i}"] = [(l["lat"], l["lon"])
                                         for l in locs if r["start"] <= l["dt"] <= r["end"]]
    return out


def build():
    lifts, runs = load_all()
    names, _ = cluster(lifts)
    attach_lift(runs, lifts, names)
    aerial = ways()

    named = {}
    for g in sorted(set(names)):
        members = [l for l, n in zip(lifts, names) if n == g]
        votes = {}
        for m in members:
            votes.setdefault(match(m["track"], aerial)[0][1]["name"], []).append(1)
        named[g] = max(votes, key=lambda k: len(votes[k]))

    tracks = full_tracks()
    pts = [p for t in tracks.values() for p in t] + [p for w in aerial for p in w["pts"]]
    lat0 = sum(p[0] for p in pts) / len(pts)
    my, mx = 111_320.0, 111_320.0 * math.cos(math.radians(lat0))
    lon0 = sum(p[1] for p in pts) / len(pts)

    def project(p):
        return [round((p[1] - lon0) * mx, 1), round(-(p[0] - lat0) * my, 1)]

    # Nearest neighbour within the same lift group, by the shape metric similar.py scores with.
    # This is the number that would decide a threshold, so it belongs next to the human's answer:
    # if he calls a 200 m pair the same piste, that is the finding, not a mislabel.
    shaped = {r["label"]: r for r in runs}
    near = {}
    for a in runs:
        peers = [b for b in runs if b is not a and b["lift"] == a["lift"]]
        scored = sorted((deviation(a, b)[0], b["label"]) for b in peers)
        near[a["label"]] = [{"id": lbl, "m": round(m)} for m, lbl in scored[:3]]
    pairs = {}
    for i, a in enumerate(runs):
        for b in runs[i + 1:]:
            if a["lift"] == b["lift"]:
                pairs[f"{a['label']}|{b['label']}"] = round(deviation(a, b)[0])

    return {
        "pairs": pairs,
        "lifts": [{"name": w["name"], "kind": w["kind"], "pts": [project(p) for p in w["pts"]]}
                  for w in aerial],
        "runs": [{"id": r["label"], "date": r["day"], "lift": named[r["lift"]] if r["lift"] in named else "—",
                  "drop": round(r["drop"]), "start": r["clock"].strftime("%H:%M"),
                  "mins": round((r["end"] - r["start"]) / 60, 1),
                  "pts": [project(p) for p in tracks.get(r["label"], [])],
                  "near": near.get(r["label"], [])}
                 for r in runs if tracks.get(r["label"])],
    }


if __name__ == "__main__":
    data = build()
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Data" / "labels" / "map_data.json"
    out.write_text(json.dumps(data))
    print(f"{len(data['runs'])} runs, {len(data['lifts'])} aerialways -> {out}")
