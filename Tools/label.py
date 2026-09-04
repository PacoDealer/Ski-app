#!/usr/bin/env python3
"""Ask a human which runs are the same piste, in the fewest questions possible.

    Tools/label.py            # write the two sheets for a human to fill in
    Tools/label.py --score    # read them back and test the shape metric against them

**The problem this solves.** `similar.py` can rank descents by shape but cannot say which of them
are the same piste, because the scores are a continuum and **Slopes' export carries no trail name**
— its runs have no identifier at all. The only ground truth available is the person who skied them.
But Vertical has no map and no replay, so there is nothing in our own app to point at and name;
what Martin can see is the Slopes app's run list.

**So the sheets are keyed on Slopes, not on us.** Every row carries the clock time, vertical,
distance and duration exactly as Slopes itemises them, which is enough to find the row in that app.
Our own run is already attached to it by time overlap (R27) — the same pairing `grade.py` uses, and
it is safe here for the reason S12c established: the two apps record the identical CoreLocation
stream, so "the run that overlaps this one in time" is not an approximation, it is the same descent.
A label written against a Slopes row therefore lands on our run for free.

**Two sheets, because the lift question is 5 questions and the piste question is 24.**
`Data/labels/lifts.csv` has one row per lift cluster found by `liftid.py` — five of them across
three days, validated 1:1 against Slopes' own trackIDs. Naming those five is cheap and makes every
screen in the app readable ("Roca Jack x12") without touching the harder question.
`Data/labels/runs.csv` has one row per run, **grouped by lift**, so the question stops being "which
of these 24 are the same?" and becomes "of the 12 descents off this one lift, which are the same
piste?" — a question with a small answer set that a skier can answer from memory.

**What `--score` does, and what it deliberately does not.** With labels present it splits every run
pair into same-piste and different-piste, prints the two distributions, and reports whether a
threshold separates them and where. **It does not choose one and ship it.** If the populations
overlap, the honest output is that shape matching does not settle it at this resort, and that is a
result worth having rather than a number worth inventing (R20).
"""

import csv
import datetime
import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from grade import slopes_runs
from liftid import ROOT, attach_lift, cluster, load_all, overlapping
from similar import deviation

LABELS = ROOT / "Data" / "labels"
LIFT_SHEET = LABELS / "lifts.csv"
RUN_SHEET = LABELS / "runs.csv"


def slopes_reference():
    out = []
    for d in sorted((ROOT / "Data" / "comparisons").glob("slopes_2026-*")):
        meta = d / "Metadata.xml"
        if meta.exists():
            out += slopes_runs(meta)
    return out


def build():
    lifts, runs = load_all()
    names, _ = cluster(lifts)
    attach_lift(runs, lifts, names)
    ref = slopes_reference()
    LABELS.mkdir(parents=True, exist_ok=True)

    existing_lifts, existing_runs = read_labels()

    with open(LIFT_SHEET, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["lift", "rides", "days", "rise_m", "first_seen", "name  <-- FILL IN"])
        for name in sorted(set(names), key=lambda n: int(n.split("-")[1])):
            members = [l for l, g in zip(lifts, names) if g == name]
            rises = [m["drop"] for m in members]
            w.writerow([name, len(members), len({m["day"] for m in members}),
                        f"{min(rises):.0f}-{max(rises):.0f}",
                        min(m["clock"] for m in members).strftime("%d %b %H:%M"),
                        existing_lifts.get(name, "")])

    with open(RUN_SHEET, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["lift", "our_run", "date", "our_start", "our_end", "our_vertical_m",
                    "slopes_start", "slopes_vertical_m", "slopes_distance_m", "slopes_duration",
                    "note", "piste  <-- FILL IN"])
        ordered = sorted(runs, key=lambda r: (r["lift"], r["clock"]))
        matched = [overlapping(r, ref) for r in ordered]
        # We sometimes split one Slopes run in two across a mid-run gap (S14, 2026-09-03 run 2),
        # so two of our rows can point at one row of its list. Say so rather than let it read as
        # a duplicate — both halves get the same label, which is the correct answer for them.
        shared = {id(s) for s in matched if s and sum(1 for x in matched if x is s) > 1}
        for r, s in zip(ordered, matched):
            key = f"{r['day']} {r['label']}"
            w.writerow([
                r["lift"], r["label"], r["day"],
                r["clock"].strftime("%H:%M:%S"), r["clock_end"].strftime("%H:%M:%S"),
                f"{r['drop']:.0f}",
                s["start"].strftime("%H:%M:%S") if s else "—",
                f"{s['vert']:.0f}" if s else "—",
                f"{s['dist']:.0f}" if s else "—",
                f"{(s['end'] - s['start']).total_seconds() / 60:.1f} min" if s else "—",
                "we split this Slopes run in two" if s and id(s) in shared else "",
                existing_runs.get(key, ""),
            ])

    print(f"Wrote {LIFT_SHEET.relative_to(ROOT)} — {len(set(names))} lifts to name.")
    print(f"Wrote {RUN_SHEET.relative_to(ROOT)} — {len(runs)} runs, grouped by lift.\n")
    print("Fill in the last column of each. The `slopes_*` columns are there so each row can be")
    print("found in the Slopes app's run list; anything recognisable works as a piste name — two")
    print("rows sharing a name is the entire signal. Leave a row blank if you don't remember it.")
    print("\nThen: Tools/label.py --score")


def read_labels():
    lifts, runs = {}, {}
    if LIFT_SHEET.exists():
        for row in csv.DictReader(open(LIFT_SHEET)):
            name = (row.get("name  <-- FILL IN") or "").strip()
            if name:
                lifts[row["lift"]] = name
    if RUN_SHEET.exists():
        for row in csv.DictReader(open(RUN_SHEET)):
            piste = (row.get("piste  <-- FILL IN") or "").strip()
            if piste:
                runs[f"{row['date']} {row['our_run']}"] = piste
    return lifts, runs


def score():
    lift_names, run_names = read_labels()
    if not run_names:
        print(f"No piste labels in {RUN_SHEET.relative_to(ROOT)} yet — nothing to score.")
        print("Fill the last column for at least a few runs off the same lift, then re-run.")
        return

    lifts, runs = load_all()
    names, _ = cluster(lifts)
    attach_lift(runs, lifts, names)
    for r in runs:
        r["piste"] = run_names.get(f"{r['day']} {r['label']}")

    labelled = [r for r in runs if r["piste"]]
    print(f"{len(labelled)} of {len(runs)} runs labelled, "
          f"{len({r['piste'] for r in labelled})} distinct pistes.")
    if lift_names:
        print("lifts: " + ", ".join(f"{k}={v}" for k, v in sorted(lift_names.items())))

    same, diff = [], []
    for a, b in itertools.combinations(labelled, 2):
        m, _ = deviation(a, b)
        (same if a["piste"] == b["piste"] else diff).append((m, a, b))
    if not same or not diff:
        print("\nNeed at least one same-piste pair AND one different-piste pair to separate them.")
        return
    same.sort(key=lambda x: x[0])
    diff.sort(key=lambda x: x[0])

    print(f"\n  SAME piste      ({len(same):>3} pairs): "
          f"{same[0][0]:.0f}-{same[-1][0]:.0f} m   {[round(x[0]) for x in same[:10]]}")
    print(f"  DIFFERENT piste ({len(diff):>3} pairs): "
          f"{diff[0][0]:.0f}-{diff[-1][0]:.0f} m   {[round(x[0]) for x in diff[:10]]}")

    if same[-1][0] < diff[0][0]:
        print(f"\n  ✅ SEPARATED — every same-piste pair is under {same[-1][0]:.0f} m and every "
              f"different-piste pair is over {diff[0][0]:.0f} m.")
        print(f"     An empty band of {diff[0][0] - same[-1][0]:.0f} m sits between them; a "
              f"threshold at {(same[-1][0] + diff[0][0]) / 2:.0f} m is not fitted to either edge.")
    else:
        overlap = [x for x in same if x[0] >= diff[0][0]]
        print(f"\n  ⚠️  OVERLAP — {len(overlap)} same-piste pair(s) score worse than the closest "
              f"different-piste pair ({diff[0][0]:.0f} m). Shape alone does not separate these:")
        for m, a, b in overlap[:5]:
            print(f"       {m:6.0f} m  {a['label']} ~ {b['label']}  both '{a['piste']}'")
        print(f"       closest different pair: {diff[0][1]['label']} ~ {diff[0][2]['label']} "
              f"('{diff[0][1]['piste']}' vs '{diff[0][2]['piste']}')")
        print("     No threshold is chosen. That is the finding, not a step on the way to one.")

    wrong_lift = [(m, a, b) for m, a, b in same if a["lift"] != b["lift"]]
    print(f"\n  lift check: {len(same) - len(wrong_lift)}/{len(same)} same-piste pairs were also "
          f"off the same lift cluster" + ("." if not wrong_lift else
          f" — {len(wrong_lift)} were not, which breaks the coarse key:"))
    for m, a, b in wrong_lift[:5]:
        print(f"       {a['label']} ({a['lift']}) ~ {b['label']} ({b['lift']})  '{a['piste']}'")


if __name__ == "__main__":
    score() if "--score" in sys.argv else build()
