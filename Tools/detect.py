#!/usr/bin/env python3
"""
Auto-detect lifts and runs from a session file, and score the result against the hand tags.

This is Phase 1's core: the shipped app must work with START pressed and the phone pocketed, so
every tag button in the UI is scaffolding that exists only to produce the ground truth this script
grades against. When the scores here are good enough, the buttons come out.

Deliberately separate from analyze.py: that one answers "how accurate are the numbers", this one
answers "did we find the right runs at all". They share segment_runs and nothing else.

Stdlib only.

    ./detect.py Data/fixtures/2026-09-01_portillo_s1.jsonl
"""

import datetime as dtm
import importlib.util
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("analyze", os.path.join(_here, "analyze.py"))
analyze = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(analyze)

# --- detector tuning ------------------------------------------------------------------------
# Altitude is smoothed over this window before any rate is taken. A chairlift climbs steadily for
# minutes, so we can afford to be slow and stable; nothing here needs to react within a second.
SMOOTH_S = 20.0
# Sustained vertical rate that counts as climbing / descending, in m/s.
ASCENT_RATE = 0.25
DESCENT_RATE = 0.30
# A candidate segment must last this long and move this much to be believed.
#
# S7: these were 60 s / 30 m, and that threshold excluded an entire class of lift. Session 2
# contains a surface tow at 13:14:24 — 38 s, +36 m barometric — which the 60 s gate threw away,
# leaving two descents with no ride between them. It is a real lift and not a pressure artifact:
# GPS independently shows 130 m of travel at a rock-steady 3.0 m/s on a constant 70-78 degree
# course while climbing, with hAcc flat at 8-9 m throughout (R10 — the barometer and GPS agree
# here for *different* reasons, which is what makes it confirmation rather than one event hitting
# two sensors). A skier does not ascend at constant speed on a constant heading; only a tow does.
#
# The numbers below are not a compromise. Printing every raw ascent candidate on both days (R7)
# shows a wide empty gap: real rides are >=42.6 m over >=44.6 s, and the largest thing that is not
# a ride is 5.1 m over 17 s. 30 s / 20 m sits in the middle of that gap, recovers the tow, and
# leaves session 1's four rides bit-for-bit unchanged.
MIN_LIFT_S = 30.0
MIN_LIFT_GAIN_M = 20.0
# Tolerance when scoring against a hand tag. Martin taps the button while skiing, with gloves on,
# so the tag itself is worth about this much precision — scoring tighter would be measuring his
# thumb, not the detector.
TAG_TOLERANCE_S = 45.0


def smooth(times, values, window=SMOOTH_S):
    """Centred moving average over a time window. The baro series has small gaps, so this walks by
    timestamp rather than by sample count."""
    out = []
    lo = hi = 0
    total = 0.0
    for i, t in enumerate(times):
        while hi < len(times) and times[hi] <= t + window / 2:
            total += values[hi]
            hi += 1
        while times[lo] < t - window / 2:
            total -= values[lo]
            lo += 1
        out.append(total / (hi - lo))
    return out


def classify(times, alts):
    """Label every sample climbing / descending / flat from the smoothed vertical rate."""
    sm = smooth(times, alts)
    labels = []
    for i in range(len(times)):
        j = max(0, i - 1)
        k = min(len(times) - 1, i + 1)
        dt = times[k] - times[j]
        rate = (sm[k] - sm[j]) / dt if dt > 0 else 0.0
        if rate >= ASCENT_RATE:
            labels.append("up")
        elif rate <= -DESCENT_RATE:
            labels.append("down")
        else:
            labels.append("flat")
    return labels


def segments(times, labels, wanted):
    """Contiguous stretches carrying one label."""
    out, start = [], None
    for i, lab in enumerate(labels):
        if lab == wanted and start is None:
            start = i
        elif lab != wanted and start is not None:
            out.append((times[start], times[i - 1]))
            start = None
    if start is not None:
        out.append((times[start], times[-1]))
    return out


def detect_lifts(times, alts):
    """Ascents long enough and high enough to be a lift ride.

    Nothing here looks at the piste map yet. A lift detector that needs `aerialway` geometry can't
    work at a resort OSM hasn't mapped, and it can't be validated against the one day of tagged
    data we actually have — so start from physics, and add the map later as a confirmation rather
    than a dependency.
    """
    labels = classify(times, alts)
    lifts = []
    for t0, t1 in segments(times, labels, "up"):
        idx = [i for i, t in enumerate(times) if t0 <= t <= t1]
        gain = alts[idx[-1]] - alts[idx[0]]
        if t1 - t0 >= MIN_LIFT_S and gain >= MIN_LIFT_GAIN_M:
            lifts.append({"start": t0, "end": t1, "gain": gain})
    # Extend each ascent forward to the altitude it actually reaches.
    #
    # A chairlift flattens out before its station, so the smoothed climb rate falls under the
    # threshold while the rider is still on the chair — the first version of this detector called
    # every lift over 55 s to 157 s early and scored 0/3 against the "Lift off" tags. The ride ends
    # where the altitude peaks, not where the climbing gets lazy, so walk forward to the highest
    # point before the next real descent starts.
    descents = [t0 for t0, _ in segments(times, labels, "down")]
    for l in lifts:
        limit = next((t for t in descents if t > l["end"]), times[-1])
        window = [i for i, t in enumerate(times) if l["end"] <= t <= limit]
        if window:
            peak = max(window, key=lambda i: alts[i])
            if alts[peak] >= alts[[i for i, t in enumerate(times) if t >= l["end"]][0]]:
                l["gain"] += alts[peak] - alts[min(window)]
                l["end"] = times[peak]

    # And trim the start back to where the rider actually leaves the ground.
    #
    # The mirror of the problem above: smoothing bleeds the end of a run and the minutes spent
    # standing in the lift line into the front of the ascent, so the first version started every
    # ride 25-44 s early. The ride begins at the bottom of the climb — the last moment the
    # altitude is still at its lowest — not when a smoothed rate first turns positive.
    for l in lifts:
        window = [i for i, t in enumerate(times) if l["start"] <= t <= l["end"]]
        if not window:
            continue
        floor = min(alts[i] for i in window) + analyze.BARO_HYSTERESIS_M
        at_bottom = [i for i in window if alts[i] <= floor]
        if at_bottom:
            l["start"] = times[max(at_bottom)]

    # Same reasoning as the run merge in analyze.py: a lift that pauses, or passes a mid-station,
    # is one ride with a gap in it, not two rides. After the extension above, the second half of a
    # split ride is usually swallowed whole — which is the point.
    merged = []
    for l in lifts:
        if merged and l["start"] - merged[-1]["end"] < analyze.MERGE_GAP_S:
            merged[-1]["end"] = max(merged[-1]["end"], l["end"])
            merged[-1]["gain"] += l["gain"]
        elif merged and l["end"] <= merged[-1]["end"]:
            continue  # fully contained in the previous ride's extension
        else:
            merged.append(dict(l))
    return merged


def structure(lifts, runs, clock):
    """Interleave the rides and the descents, and complain when the day doesn't make sense.

    A ski day alternates: you go up, you come down, you go up again. That is not a heuristic, it
    is gravity — so any descent with no ride in front of it means a lift was missed, and two rides
    in a row mean a descent was. This check needs no hand tags, which matters because Martin has
    stopped tagging: session 2 carried exactly one tag, and the missed surface tow at 13:14 was
    invisible to the tag scoring below while being obvious here. It is the self-diagnosis (R17)
    for a detector whose ground truth is drying up.

    It is a smell, not a verdict. Skiing to a different base, or walking to lunch, breaks the
    alternation legitimately — so it prints what it saw and names the suspicion.
    """
    timeline = ([("lift", l["start"], l["end"], l["gain"]) for l in lifts]
                + [("run", r["start"], r["end"], -r["drop"]) for r in runs])
    timeline.sort(key=lambda e: e[1])

    print("\n  --- THE DAY, IN ORDER ---")
    complaints = []
    for i, (kind, t0, t1, dv) in enumerate(timeline):
        flag = ""
        if kind == "run" and (i == 0 or timeline[i - 1][0] != "lift"):
            flag = "  ⚠ descent with no ride before it — a lift may have been missed"
        elif kind == "lift" and i and timeline[i - 1][0] == "lift":
            flag = "  ⚠ two rides in a row — a descent may have been missed"
        if flag:
            complaints.append(flag)
        print(f"  {kind:<4} {clock(t0)} → {clock(t1)}  {dv:+6.0f} m{flag}")

    up = sum(e[3] for e in timeline if e[0] == "lift")
    down = -sum(e[3] for e in timeline if e[0] == "run")
    # Ridden vertical and skied vertical should roughly agree over a whole day, because the only
    # other ways to change altitude are walking and driving. A large gap is the same signal as a
    # broken alternation, seen from a different angle.
    print(f"\n  ridden {up:.0f} m vs skied {down:.0f} m  ({up - down:+.0f} m unaccounted)")
    if not complaints:
        print("  Structure is clean: every descent is preceded by a ride.")


def score(detected, truth, tolerance=TAG_TOLERANCE_S):
    """Match detected boundaries to hand tags, nearest-first, one to one."""
    matches, unmatched_truth = [], []
    pool = list(detected)
    for tag_t in truth:
        best, best_d = None, None
        for d in pool:
            gap = abs(d - tag_t)
            if best_d is None or gap < best_d:
                best, best_d = d, gap
        if best is not None and best_d <= tolerance:
            matches.append((tag_t, best, best - tag_t))
            pool.remove(best)
        else:
            unmatched_truth.append(tag_t)
    return matches, unmatched_truth, pool


def main(path):
    recs, _ = analyze.load(path)
    baros, marks = recs["baro"], recs["mark"]
    if not baros:
        print("No barometer samples — nothing to detect.")
        return
    start = dtm.datetime.fromisoformat(recs["meta"]["startedAt"].replace("Z", "+00:00"))
    tz = dtm.timezone(dtm.timedelta(hours=-4))  # Portillo. TODO: derive from the track's location.

    def clock(dt):
        return (start + dtm.timedelta(seconds=dt)).astimezone(tz).strftime("%H:%M:%S")

    times = [b["dt"] for b in baros]
    alts = [b["relAlt"] for b in baros]

    lifts = detect_lifts(times, alts)
    runs = analyze.segment_runs(times, alts)

    print("=" * 74)
    print(f"  {os.path.basename(path)} — auto-detection")
    print("=" * 74)

    print(f"\n  --- {len(lifts)} LIFT RIDES DETECTED ---")
    for i, l in enumerate(lifts, 1):
        print(f"  {i:2d}. {clock(l['start'])} → {clock(l['end'])}   "
              f"+{l['gain']:5.0f} m over {(l['end']-l['start'])/60:4.1f} min")

    print(f"\n  --- {len(runs)} RUNS DETECTED ---")
    for i, r in enumerate(runs, 1):
        print(f"  {i:2d}. {clock(r['start'])} → {clock(r['end'])}   "
              f"-{r['drop']:5.0f} m over {r['dur']/60:4.1f} min")

    structure(lifts, runs, clock)

    if not marks:
        print("\n  No hand tags in this file — detection is unscored.")
        return

    def tags(label):
        return [m["dt"] for m in marks if m.get("label") == label or m.get("text") == label]

    print(f"\n  --- SCORED AGAINST HAND TAGS (±{TAG_TOLERANCE_S:.0f} s) ---")
    checks = [
        ("lift start", [l["start"] for l in lifts], tags("Lift on")),
        ("lift end", [l["end"] for l in lifts], tags("Lift off")),
        ("run start", [r["start"] for r in runs], tags("Top")),
        ("run end", [r["end"] for r in runs], tags("Bottom")),
    ]
    for name, detected, truth in checks:
        if not truth:
            print(f"  {name:<11} no tags of this kind")
            continue
        matched, missed, spurious = score(detected, truth)
        errs = [abs(d) for _, _, d in matched]
        line = (f"  {name:<11} {len(matched)}/{len(truth)} matched")
        if errs:
            line += f"   median error {sorted(errs)[len(errs)//2]:5.1f} s   worst {max(errs):5.1f} s"
        print(line)
        for t in missed:
            print(f"                MISSED  tag at {clock(t)} — nothing detected within tolerance")
        for d in spurious:
            print(f"                EXTRA   detected {clock(d)} — no tag near it")

    print("\n  Note: 'extra' is not automatically wrong. Martin tags optionally and stopped tagging\n"
          "  partway through 2026-09-01, so an unmatched detection may be a real run he didn't\n"
          "  label. Only a MISSED tag is unambiguously the detector's fault.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        main(p)
