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

**S15b — the labels arrived, and they overlap. The overlap is the result.** Martin labelled 17 runs
and did not write piste names: he wrote **routes** — "Las Lomas, a Canarios, hasta el hotel", three
pistes linked into one descent. At Portillo that is what a descent is, so "same run?" is not a
binary and a single mean-distance number cannot carry the answer. It shows up directly in his data:
a pair he gave **different** descriptions scores **43 m** while a pair he gave the **same** name
scores **59 m**, so no threshold on the mean can reproduce his labels.

**The divergence profile does separate them, and that is why this prints one.** Splitting the
point-to-point separation into eighths of the way down turns one number into a shape, and the four
cases stop looking alike:

    together the whole way   ████████    a genuine repeat (11 m)
    apart only in the middle █▓▓░░▓██    same route, different line down the same face (59 m)
    together then splitting  █████▓▓░    a shared start with a different ending (43 m)
    never together           ░▓█▓▓▓░▓    different descents (69 m)

The middle two are exactly the pairs the mean gets backwards. **Nothing is shipped on this** — it is
17 labels, 4 same-name pairs, 2 days (R5) — but it says the unit is wrong: the thing worth comparing
is a shared *segment*, not a whole descent, and a fourth graded day should be labelled with that in
mind.
"""

import csv
import datetime
import json
import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from grade import slopes_runs
from liftid import ROOT, attach_lift, cluster, load_all, overlapping
from analyze import haversine
from similar import deviation

LABELS = ROOT / "Data" / "labels"
LIFT_SHEET = LABELS / "lifts.csv"
RUN_SHEET = LABELS / "runs.csv"
# Martin's answers, as given. Kept as JSON beside the sheets because they are free text containing
# commas ("Las Lomas, a Canarios, hasta el hotel") and a CSV column is the wrong container for them.
PISTES = LABELS / "pistes.json"


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
            key = r["label"]
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
    # The CSV sheet first, then `pistes.json` on top. **The order is deliberate and load-bearing:**
    # the sheet is what Martin typed the first time, and `pistes.json` is where a *corrected* answer
    # lands — the two disagree on exactly one run today, `09-01 s2 r1`, because he confirmed in S15b
    # that "Plateau, que conecta con lomas hacia la silla de las lomas" and "Plateau a lomas" are the
    # same run and they were merged (`33a962d`). Reading the sheet last would silently revert that.
    #
    # 🔴 S18: this loop used to key the CSV as `f"{row['date']} {row['our_run']}"` — e.g.
    # "2026-09-01 09-01 s1 r1" — while every lookup uses the run label alone ("09-01 s1 r1"). **So
    # every label typed into the sheet was silently discarded**, and only `pistes.json` was ever
    # read. It went unnoticed because the two sources agree on 23 of 24 rows. That is R30's failure
    # a second time (an identifier a human types against has to be the one the code looks up), and
    # the same cost: work Martin did, thrown away without a word.
    if RUN_SHEET.exists():
        for row in csv.DictReader(open(RUN_SHEET)):
            piste = (row.get("piste  <-- FILL IN") or "").strip()
            if piste:
                runs[row["our_run"]] = piste
    if PISTES.exists():
        runs.update(json.loads(PISTES.read_text()))
    return lifts, runs


def same_piste(a, b):
    """Whether two labels name the same descent.

    Case- and punctuation-insensitive, because these are typed free text: the first run of this
    comparison counted "Plateau a lomas" and "Plateau a Lomas" as two different pistes, which
    dropped the one pair that overlaps and printed a confident SEPARATED verdict with a threshold
    on it. Exactly the invented number this tool exists to refuse (R20).
    """
    norm = lambda s: " ".join(s.lower().replace(",", " ").split()).rstrip(".")
    return norm(a) == norm(b)


def profile_bar(a, b, bins=8):
    """The separation between two tracks along the descent, as eighths, rendered as a bar.

    One number per pair throws away the only thing that distinguishes "we skied the same piste and
    then split up" from "we skied different pistes" — *when* the two tracks parted. Both are
    resampled by distance already, so the k-th eighth is the same fraction of the way down for both.
    """
    d = [haversine(*p, *q) for p, q in zip(a["track"], b["track"])]
    n = len(d) // bins
    means = [sum(d[i * n:(i + 1) * n]) / n for i in range(bins)]
    return "".join("█" if v < 40 else "▓" if v < 90 else "░" for v in means)


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
        r["piste"] = run_names.get(r["label"])

    labelled = [r for r in runs if r["piste"]]
    print(f"{len(labelled)} of {len(runs)} runs labelled, "
          f"{len({' '.join(r['piste'].lower().split()) for r in labelled})} distinct descriptions.")
    if lift_names:
        print("lifts: " + ", ".join(f"{k}={v}" for k, v in sorted(lift_names.items())))

    same, diff = [], []
    for a, b in itertools.combinations(labelled, 2):
        m, _ = deviation(a, b)
        (same if same_piste(a["piste"], b["piste"]) else diff).append((m, a, b))
    if not same or not diff:
        print("\nNeed at least one same-piste pair AND one different-piste pair to separate them.")
        return
    same.sort(key=lambda x: x[0])
    diff.sort(key=lambda x: x[0])

    print(f"\n  SAME piste      ({len(same):>3} pairs): "
          f"{same[0][0]:.0f}-{same[-1][0]:.0f} m   {[round(x[0]) for x in same[:10]]}")
    print(f"  DIFFERENT piste ({len(diff):>3} pairs): "
          f"{diff[0][0]:.0f}-{diff[-1][0]:.0f} m   {[round(x[0]) for x in diff[:10]]}")

    print("\n  where each pair diverges — point separation in eighths, top of the run to bottom:")
    shown = [("same", p) for p in same[:4]] + [("diff", p) for p in diff[:3]]
    for tag, (m, a, b) in shown:
        print(f"    {profile_bar(a, b)}  {m:5.0f} m  {tag:<4} {a['label']} ~ {b['label']}")
    print("    █ within 40 m   ▓ 40-90 m   ░ over 90 m")
    print("    A flat █ row is a repeat; █ turning ░ is a shared start with a different ending;")
    print("    ░ in the middle only is the same route skied on a different line. The mean cannot")
    print("    tell those apart, and on this data it ranks two of them backwards.")

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
