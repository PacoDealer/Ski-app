#!/usr/bin/env python3
"""
Replay a Vertical session file and compare vertical/speed methods head to head.

This is the accuracy harness. The whole project thesis is that the ski-tracking category has
soft numbers — 5-10% vertical overestimation, ~10 mph max-speed error — because everyone
computes them the lazy way. This script computes them BOTH ways on the same real data, so the
claim stops being a claim.

Stdlib only, no dependencies.

    ./analyze.py ~/Downloads/2026-08-31_101500_a1b2c3d4.jsonl
"""

import json
import math
import sys
from collections import Counter
from datetime import datetime

# --- tuning knobs for the "careful" methods -------------------------------------------------
# Ignore altitude wiggles smaller than this; below it we're measuring noise, not terrain.
BARO_HYSTERESIS_M = 3.0
# A descent must drop at least this much to count as a run.
MIN_RUN_DROP_M = 30.0
# Two descents separated by less re-ascent than this, and by less time than MERGE_GAP_S, are one
# run with a bump in it rather than two runs. Both conditions matter: the height rule alone also
# swallows the several minutes of shuffling around the base area between real runs, which would
# then be counted as descent time and descent distance.
MERGE_ASCENT_M = 15.0
MERGE_GAP_S = 60.0
# Reject Doppler speed samples the receiver itself doesn't trust.
#
# S5: this was 2.0 m/s and it was the wrong knob. On the Portillo day the MEDIAN speedAcc was
# 2.04, so the gate discarded 57% of a perfectly healthy 1 Hz track — and it still got the
# answer wrong, because speedAcc rises with speed: it clipped the real peak (a smooth, clean
# 15 s acceleration to 64.7 km/h that position-differentiation independently confirms at
# 70.6 km/h) at 58.7 km/h, purely because that one sample's speedAcc crossed 2.0.
# Meanwhile the day's actual bad data — a multipath burst with a 42 m one-second position
# jump — sailed through, because a receiver that has lost the sky reports a confident
# speed for a wrong position.
#
# hAcc is the field that separates them: the burst degrades to 22-31 m while the real run
# stays under 15 m. Gating on hAcc <= 15 m keeps 94% of the day and lands on 64.7 km/h.
# Keep a speedAcc ceiling only as a loose sanity bound, not as the primary filter.
MAX_SPEED_ACC = 3.0     # m/s
# Reject position fixes worse than this before using them for anything.
MAX_H_ACC = 25.0        # m
# Doppler speed is only trustworthy while the receiver still knows where it is.
MAX_SPEED_H_ACC = 15.0  # m
# Shortest interval that can carry a speed. CoreLocation redelivers fixes microseconds apart;
# differentiating positions across those pairs divides scatter by ~0, not by a sample period.
MIN_DERIV_DT = 0.5      # s
# Shortest interval between two fixes used as a distance step.
#
# Summing every 1 Hz step reads +9.8% against Slopes' itemised run distances — the distance twin
# of the vertical bug this whole project is about, in our own code. At 1 Hz a skier moves ~10 m
# between fixes against a median +/-7 m fix, so scatter is a large share of every step, and
# scatter only ever adds.
#
# Calibrated over SLOPES' OWN RUN WINDOWS, not ours, which is the part that matters: our runs end
# ~60 s later than Slopes' because we deliberately keep the runout, so fitting against our own
# windows tunes the estimator to absorb a segmentation difference. Doing that gave 3.0 s; taking
# segmentation out of the question gives 2.5 s, and drops the PER-RUN error from 8.8% to 1.6%.
#
# The knob is quantised by the fix rate — at 1 Hz every threshold in (2, 3] keeps roughly every
# third fix — so 2.5 is chosen to sit mid-plateau rather than on a boundary where sampling jitter
# flips the step between 2 and 3 fixes. Three days (R5); re-score with Tools/grade.py on a fourth.
MIN_DISTANCE_DT = 2.5   # s


def load(path):
    recs = {"meta": None, "loc": [], "baro": [], "abs": [], "mark": [], "note": [],
            "imu": [], "end": None}
    bad = 0
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                # A truncated final line is expected if the app was killed mid-write.
                bad += 1
                continue
            t = r.get("t")
            if t == "meta":
                recs["meta"] = r
            elif t == "end":
                recs["end"] = r
            elif t in recs:
                recs[t].append(r)
    return recs, bad


def haversine(a_lat, a_lon, b_lat, b_lon):
    R = 6371000.0
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp = math.radians(b_lat - a_lat)
    dl = math.radians(b_lon - a_lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def naive_descent(series):
    """Sum every negative delta. This is the bug that inflates vertical by 5-10%: it integrates
    sensor noise as if it were terrain, and noise only ever adds."""
    total = 0.0
    for prev, cur in zip(series, series[1:]):
        if cur < prev:
            total += prev - cur
    return total


def hysteresis_descent(series, threshold=BARO_HYSTERESIS_M):
    """Only commit a direction change once the signal has moved past a noise threshold, so
    small oscillations can't accumulate."""
    if not series:
        return 0.0
    total = 0.0
    # Walk the series collecting turning points, only committing a reversal once the signal has
    # travelled `threshold` against the current direction.
    turns = [series[0]]
    anchor = series[0]
    direction = 0
    for v in series[1:]:
        if direction == 0:
            if abs(v - anchor) >= threshold:
                direction = -1 if v < anchor else 1
                anchor = v
        elif direction == -1:
            if v < anchor:
                anchor = v
            elif v - anchor >= threshold:
                turns.append(anchor)
                direction = 1
                anchor = v
        else:
            if v > anchor:
                anchor = v
            elif anchor - v >= threshold:
                turns.append(anchor)
                direction = -1
                anchor = v
    turns.append(anchor)
    for a, b in zip(turns, turns[1:]):
        if b < a:
            total += a - b
    return total


def descent_start(times, alts, top_t, bot_t, threshold=BARO_HYSTERESIS_M):
    """When the skiing actually starts, as opposed to when the altitude stopped going up.

    S7: a run is cut between altitude turning points, so a skier standing at the top of a run is
    still inside the run. Slopes books **41 min** of ski time for 2026-09-01; the same seven
    descents measured turning-point to turning-point come to **54.5 min**, +33%. Session 2's last
    run is the clearest case — 10.6 min of which the first 4.4 are spent stationary at 94 m before
    the first turn. Vertical is measured top-to-bottom and is untouched by this, but duration,
    vertical rate and average speed are all wrong by about a third, and those are numbers we print.

    The fix is the mirror of the lift-start trim in `detect.py`: walk forward from the top through
    the *leading* plateau — while the altitude is still within `threshold` of the ceiling — and
    stop at the first departure. Trimming only the leading plateau matters twice over. It is
    streamable, so `LiveMetrics` can compute the identical thing one sample at a time (R12a), and
    it deliberately leaves the flat runout at the *bottom* of a run inside the run: coasting out is
    skiing, standing at the top is not. Trimming both ends instead undershoots Slopes by 13%.

    Calibrated against the two external numbers we have, and they agree: the day goes 54.5 -> 43.7
    min against Slopes' 41 (+6.6%, was +33%), and session 1's run 1 goes 378 -> 341 s against the
    5 m 26 s Slopes itemises for it (+4.6%, was +16%). We stay slightly generous in both, which is
    the expected direction — we keep the whole runout.
    """
    ceiling = None
    started = top_t
    for t, a in zip(times, alts):
        if t < top_t:
            continue
        if t > bot_t:
            break
        if ceiling is None:
            ceiling = a
        elif a < ceiling - threshold:
            break
        ceiling = max(ceiling, a)
        started = t
    return started


def attach_run_positions(runs, locs):
    """Per-run distance, own top speed and endpoints, from the fixes inside each run's window.

    Kept out of `segment_runs` on purpose: segmentation is barometric and must stay that way, and
    the run windows are not final until the merge rule has had its say. This is the batch twin of
    `LiveMetrics.measure` — same gates, same walk — so `Tools/replay.sh` can prove they agree.
    """
    usable = [l for l in locs if 0 <= l["hAcc"] <= MAX_H_ACC]
    for r in runs:
        window = [l for l in usable if r["start"] <= l["dt"] <= r["end"]]
        # Distance walks a decimated copy (MIN_DISTANCE_DT); top speed reads every fix, because
        # dropping 2 of every 3 would also drop the peak. Same trail, two samplings.
        dist, step_from = 0.0, None
        top = -1.0
        for l in window:
            if step_from is None:
                step_from = l
            elif l["dt"] - step_from["dt"] >= MIN_DISTANCE_DT:
                dist += haversine(step_from["lat"], step_from["lon"], l["lat"], l["lon"])
                step_from = l
            if (l["speed"] >= 0 and 0 <= l["speedAcc"] <= MAX_SPEED_ACC
                    and 0 <= l["hAcc"] <= MAX_SPEED_H_ACC):
                top = max(top, l["speed"])
        r["dist"] = dist
        r["top_speed"] = top
        r["start_pos"] = (window[0]["lat"], window[0]["lon"]) if window else None
        r["end_pos"] = (window[-1]["lat"], window[-1]["lon"]) if window else None
    return runs


def segment_runs(times, alts, min_drop=MIN_RUN_DROP_M, threshold=BARO_HYSTERESIS_M):
    """Split into descents by finding turning points, then keep only the meaningful drops.
    Vertical is then measured top-to-bottom per run — never by summing deltas."""
    if len(alts) < 2:
        return []
    turns = [(times[0], alts[0])]
    anchor_t, anchor_a = times[0], alts[0]
    direction = 0
    for t, a in zip(times[1:], alts[1:]):
        if direction == 0:
            if abs(a - anchor_a) >= threshold:
                direction = -1 if a < anchor_a else 1
                anchor_t, anchor_a = t, a
        elif direction == -1:
            if a < anchor_a:
                anchor_t, anchor_a = t, a
            elif a - anchor_a >= threshold:
                turns.append((anchor_t, anchor_a))
                direction = 1
                anchor_t, anchor_a = t, a
        else:
            if a > anchor_a:
                anchor_t, anchor_a = t, a
            elif anchor_a - a >= threshold:
                turns.append((anchor_t, anchor_a))
                direction = -1
                anchor_t, anchor_a = t, a
    turns.append((anchor_t, anchor_a))

    # Every descent, before any filtering.
    descents = []
    for (t0, a0), (t1, a1) in zip(turns, turns[1:]):
        if a0 - a1 > 0:
            descents.append({"top_t": t0, "top_a": a0, "bot_t": t1, "bot_a": a1})

    # S5: merge descents separated by only a small re-ascent, BEFORE applying min_drop.
    #
    # Without this the analyzer loses vertical, which is the opposite of the category bug but
    # just as wrong. On the Portillo day a 4.1 m pressure blip at 11:28:57 — arriving at the
    # base building, which spiked the barometer and scattered GPS in the same second — split
    # run 4 into 284 m + a 16 m tail. The tail then fell under MIN_RUN_DROP_M and was silently
    # deleted, so the day was reported 16 m short. A blip that survives 3 m of hysteresis is
    # still nothing like a lift ride; only a real ascent separates two runs.
    # S14: on merge, adopt the HIGHER of the two tops instead of always keeping the first.
    #
    # A lift that crests a roll can dip just past the 3 m hysteresis and then climb higher again,
    # so the first turning point is declared *during the climb* — a false top (Tools/falsetop.py).
    # The merge then stitched the pieces back together but kept that first top, so `descent_start`
    # walked its plateau trim forward from the wrong place and the run started minutes early. On
    # 2026-09-02 run 7 we declared a descent while Slopes still had him on a lift.
    #
    # Scored against three days of Slopes' itemised exports: a bit-for-bit no-op on 2026-09-01 and
    # 2026-09-03 (neither has a false top), and on 2026-09-02 it takes the mean |start error| from
    # 56 s to 29 s — run 8 from -168 s to -7 s. It costs run 6 (-9 s -> +54 s), where the higher
    # peak lands after the real push-off, and moves that day's vertical 1386.0 -> 1390.1.
    # Measuring top-to-bottom is what "vertical" already claims to mean, so the higher top is the
    # honest one; three graded days is the evidence bar R5 asked for.
    merged = []
    for d in descents:
        if (merged
                and d["top_a"] - merged[-1]["bot_a"] < MERGE_ASCENT_M
                and d["top_t"] - merged[-1]["bot_t"] < MERGE_GAP_S):
            if d["top_a"] > merged[-1]["top_a"]:
                merged[-1]["top_a"], merged[-1]["top_t"] = d["top_a"], d["top_t"]
            merged[-1]["bot_t"], merged[-1]["bot_a"] = d["bot_t"], d["bot_a"]
        else:
            merged.append(dict(d))

    runs, dropped = [], []
    for d in merged:
        # Top-to-bottom, so a wiggle in the middle of a run can neither add nor remove vertical.
        drop = d["top_a"] - d["bot_a"]
        if drop >= min_drop:
            skiing_from = descent_start(times, alts, d["top_t"], d["bot_t"], threshold)
            runs.append({"start": skiing_from, "end": d["bot_t"], "drop": drop,
                         "dur": d["bot_t"] - skiing_from,
                         "top_t": d["top_t"]})
        elif drop > 0:
            dropped.append(drop)
    # Report what the threshold discarded rather than letting it vanish — a day that loses a lot
    # here is a day where min_drop or the merge rules are wrong for that mountain.
    if runs:
        runs[0]["sub_threshold"] = dropped
    return runs


def pct(part, whole):
    return f"{100.0 * part / whole:+.1f}%" if whole else "n/a"


RESUME_MARKER = "resumed after interruption"


def resume_seams(notes):
    """Times (dt) where the app was relaunched after a crash, jetsam, or dead battery.

    These matter more than they look. CMAltimeter's relativeAltitude is measured from the moment
    updates *start*, so every resume silently resets it to zero. Summing deltas straight across
    that seam invents a descent the size of the whole mountain. Absolute `pressure` is logged on
    every baro sample precisely so altitude can be carried across the gap later; for now we simply
    refuse to measure through it."""
    return sorted(n["dt"] for n in notes if RESUME_MARKER in n.get("text", ""))


def split_at_seams(times, alts, seams):
    """Break a baro series into stretches that share one altimeter baseline."""
    if not seams:
        return [(times, alts)]
    segments, start = [], 0
    for seam in seams:
        cut = next((i for i, t in enumerate(times) if t >= seam), len(times))
        if cut > start:
            segments.append((times[start:cut], alts[start:cut]))
        start = cut
    if start < len(times):
        segments.append((times[start:], alts[start:]))
    return [s for s in segments if len(s[1]) >= 2]


def main(path):
    recs, bad_lines = load(path)
    meta, locs, baros = recs["meta"], recs["loc"], recs["baro"]

    print("=" * 74)
    print(f"  {path.split('/')[-1]}")
    print("=" * 74)

    if meta:
        print(f"  device      {meta.get('device')}  iOS {meta.get('osVersion')}")
        print(f"  started     {meta.get('startedAt')}")
    print(f"  closed      {'cleanly' if recs['end'] else 'INTERRUPTED (data still valid)'}")
    seams_preview = resume_seams(recs["note"])
    if seams_preview:
        print(f"  resumed     {len(seams_preview)} auto-resume(s) after the app died — "
              f"at {', '.join(f'{s/60:.0f} min' for s in seams_preview)}")
        print(f"              baro metrics are summed per stretch; vertical skied while the app "
              f"was dead is unknown and excluded")
    if bad_lines:
        print(f"  unparseable {bad_lines} line(s) — expected if killed mid-write")

    if not locs:
        print("\n  No location samples. Nothing to analyse.")
        return

    # CoreLocation hands over a cached fix the instant updates start — often timestamped seconds
    # (sometimes much longer) BEFORE recording began. The recorder logs it deliberately: raw
    # fidelity means never discarding data at capture time, because a dropped sample is gone
    # forever while a filter can always be changed. Filtering belongs here instead.
    stale = [l for l in locs if l["dt"] < 0]
    if stale:
        print(f"  stale       {len(stale)} pre-start cached fix(es) excluded "
              f"(oldest {min(l['dt'] for l in stale):.1f}s before start)")
        locs = [l for l in locs if l["dt"] >= 0]
    if not locs:
        print("\n  Only cached fixes. Nothing to analyse.")
        return

    dur = locs[-1]["dt"] - locs[0]["dt"]
    print(f"\n  duration    {dur/3600:.2f} h ({dur/60:.0f} min)")
    print(f"  GPS fixes   {len(locs)}  ({len(locs)/dur:.2f} Hz)")
    print(f"  baro fixes  {len(baros)}  ({len(baros)/dur:.2f} Hz)" if dur else "")

    # ---- fix quality ------------------------------------------------------------------------
    haccs = sorted(l["hAcc"] for l in locs if l["hAcc"] >= 0)
    if haccs:
        print(f"\n  --- FIX QUALITY ---")
        print(f"  horizontal accuracy   median ±{haccs[len(haccs)//2]:.1f} m"
              f"   p90 ±{haccs[int(len(haccs)*0.9)]:.1f} m"
              f"   worst ±{haccs[-1]:.1f} m")
        good = sum(1 for h in haccs if h <= MAX_H_ACC)
        print(f"  usable fixes (<= {MAX_H_ACC:.0f} m)  {good}/{len(haccs)}  ({100*good/len(haccs):.1f}%)")
    dropped = sum(1 for l in locs if l["speed"] < 0 or l["speedAcc"] < 0)
    print(f"  fixes with no valid Doppler speed  {dropped}/{len(locs)}")

    # ---- motion capture health ---------------------------------------------------------------
    #
    # S8 added device motion at 25 Hz. It is the one sensor with no other symptom when it fails —
    # location and barometer keep working, the day looks normal, and the absence is only noticed
    # months later when the data is wanted. So it gets checked on every pull, and the check is
    # coverage rather than presence: a file with 40 minutes of motion out of a 3-hour day is a
    # worse outcome than one with none, because it looks fine.
    imu = recs["imu"]
    print(f"\n  --- MOTION (IMU) ---")
    if not imu:
        v = (recs["meta"] or {}).get("formatVersion", 1)
        print("  none in this file" + ("  (format v1 — recorded before motion capture existed)"
                                       if v < 2 else "  ⚠️  format v2 but no samples — check the sensor"))
    else:
        n = sum(len(b["ax"]) for b in imu)
        span = imu[-1]["dt"] + len(imu[-1]["ax"]) / imu[-1]["hz"] - imu[0]["dt"]
        print(f"  {n} samples in {len(imu)} batches   nominal {imu[0]['hz']:.0f} Hz"
              f"   effective {n/span:.1f} Hz over {span/60:.1f} min")
        # Every batch is one second, so consecutive dt should step by ~1 s. Anything much larger is
        # a stretch of the day with no motion recorded, and it is worth naming rather than averaging
        # away — that is exactly the failure this block exists to catch.
        gaps = [(b["dt"] - a["dt"] - len(a["ax"]) / a["hz"])
                for a, b in zip(imu, imu[1:])]
        big = [g for g in gaps if g > 2.0]
        cover = 100 * n / imu[0]["hz"] / span if span else 0
        print(f"  coverage {cover:.1f}% of the span"
              + (f"   ⚠️  {len(big)} gap(s) > 2 s, worst {max(big):.0f} s" if big else "   no gaps > 2 s"))
        if dur and span < 0.9 * dur:
            print(f"  ⚠️  motion covers {span/60:.1f} min of a {dur/60:.0f} min session")

    # ---- SPEED: the headline comparison --------------------------------------------------
    print(f"\n  --- MAX SPEED: how you measure it changes the answer ---")

    doppler = [l["speed"] for l in locs
               if l["speed"] >= 0 and 0 <= l["speedAcc"] <= MAX_SPEED_ACC
               and 0 <= l["hAcc"] <= MAX_SPEED_H_ACC]
    doppler_ungated = [l["speed"] for l in locs if l["speed"] >= 0]

    # The naive method every other app uses: differentiate successive positions.
    #
    # S13: CoreLocation delivers duplicate/batched fixes microseconds apart — 384 pairs closer
    # than 0.2 s on 2026-09-02, the tightest 95 µs. Dividing a metre of scatter by that interval
    # produced a "position-differentiated max" of 341,659 km/h and a +499,243% headline. The old
    # `dt <= 0` guard never fired because the intervals are positive, just meaningless. Requiring
    # a real sampling interval is the whole fix. We criticised Carve for publishing a glitch as
    # its top speed; this is the same mistake in our own harness (R20).
    derived = []
    for a, b in zip(locs, locs[1:]):
        dt = b["dt"] - a["dt"]
        if dt < MIN_DERIV_DT:
            continue
        d = haversine(a["lat"], a["lon"], b["lat"], b["lon"])
        derived.append(d / dt)

    def kmh(v):
        return v * 3.6

    if doppler:
        print(f"  Doppler, accuracy-gated   {kmh(max(doppler)):6.1f} km/h   <-- what we should report")
    if doppler_ungated:
        print(f"  Doppler, ungated          {kmh(max(doppler_ungated)):6.1f} km/h")
    if derived:
        derived_max = max(derived)
        print(f"  position-differentiated   {kmh(derived_max):6.1f} km/h   <-- what other apps report")
        if doppler:
            err = kmh(derived_max) - kmh(max(doppler))
            print(f"  >>> naive method overstates by {err:+.1f} km/h ({err/1.609:+.1f} mph), "
                  f"{pct(derived_max - max(doppler), max(doppler))}")

    # ---- SPEED PEAK CONTEXT -----------------------------------------------------------------
    # S5: never trust a headline max speed without looking at the seconds around it. A real peak
    # is a smooth ramp with steady hAcc; a multipath burst is a step change with hAcc falling
    # apart. Carve published a 66.8 km/h glitch as its top speed for exactly this day.
    if doppler:
        peak = max((l for l in locs if l["speed"] >= 0
                    and 0 <= l["speedAcc"] <= MAX_SPEED_ACC
                    and 0 <= l["hAcc"] <= MAX_SPEED_H_ACC), key=lambda l: l["speed"])
        print(f"\n  --- THE 10 s AROUND THE REPORTED MAX (sanity-check it by eye) ---")
        near = [l for l in locs if abs(l["dt"] - peak["dt"]) <= 5]
        prev = None
        for l in near:
            step = ""
            if prev:
                gap = l["dt"] - prev["dt"]
                if gap >= MIN_DERIV_DT:
                    d = haversine(prev["lat"], prev["lon"], l["lat"], l["lon"])
                    step = f"  pos-diff {kmh(d/gap):5.1f} km/h"
            flag = "  <-- MAX" if l is peak else ""
            print(f"  {l['dt']-peak['dt']:+5.1f}s  {kmh(max(l['speed'],0)):5.1f} km/h"
                  f"   hAcc ±{l['hAcc']:5.1f} m   alt {l['alt']:6.0f} m{step}{flag}")
            prev = l

    # ---- VERTICAL: four methods ------------------------------------------------------------
    print(f"\n  --- VERTICAL DESCENT: four ways of counting the same day ---")

    gps_alts = [l["alt"] for l in locs if l["hAcc"] >= 0]
    baro_alts = [b["relAlt"] for b in baros]
    baro_times = [b["dt"] for b in baros]

    # Every baro metric is computed per unbroken stretch and then summed, so an altimeter baseline
    # reset at a resume can never be mistaken for vertical. Vertical skied while the app was dead
    # is genuinely unknown, and an unknown is reported as missing, never as zero and never guessed.
    seams = resume_seams(recs["note"])
    segments = split_at_seams(baro_times, baro_alts, seams) if baro_alts else []

    results = {}
    if gps_alts:
        results["GPS altitude, summed deltas"] = naive_descent(gps_alts)
    if segments:
        results["barometric, summed deltas"] = sum(naive_descent(a) for _, a in segments)
        results[f"barometric, {BARO_HYSTERESIS_M:.0f} m hysteresis"] = \
            sum(hysteresis_descent(a) for _, a in segments)

    runs = attach_run_positions([r for t, a in segments for r in segment_runs(t, a)], locs)
    if runs:
        results["barometric, run-segmented"] = sum(r["drop"] for r in runs)

    baseline = results.get("barometric, run-segmented")
    for name, val in results.items():
        line = f"  {name:<36} {val:8.0f} m"
        if baseline and name != "barometric, run-segmented":
            line += f"   {pct(val - baseline, baseline)} vs. run-segmented"
        print(line)

    if baseline:
        print(f"\n  Run-segmented is the honest number: it measures each descent top-to-bottom")
        print(f"  instead of integrating noise. The gap above is the category-wide error.")

    # ---- runs ----------------------------------------------------------------------------
    if runs:
        print(f"\n  --- {len(runs)} RUNS DETECTED (barometric, >= {MIN_RUN_DROP_M:.0f} m drop) ---")
        print(f"  {'#':>3}  {'vert':>6} {'dist':>7} {'time':>6} {'top':>7} {'avg':>7} {'v.rate':>7}")
        for i, r in enumerate(runs, 1):
            top = f"{r['top_speed']*3.6:5.1f}  " if r["top_speed"] >= 0 else "    -  "
            avg = r["dist"] / max(r["dur"], 1) * 3.6
            print(f"  {i:2d}.  {r['drop']:5.0f}m {r['dist']:6.0f}m {r['dur']/60:5.1f}m"
                  f" {top} {avg:5.1f}  {r['drop']/max(r['dur'], 1):5.1f} m/s")
        drops = [r["drop"] for r in runs]
        print(f"\n  longest drop {max(drops):.0f} m   shortest {min(drops):.0f} m"
              f"   total {sum(drops):.0f} m"
              f"   descent distance {sum(r['dist'] for r in runs)/1000:.2f} km")
        # Never let a threshold discard vertical silently — that is how we lost 16 m in S5.
        sub = [d for r in runs for d in r.get("sub_threshold", [])]
        if sub:
            print(f"  not counted: {len(sub)} descent(s) under {MIN_RUN_DROP_M:.0f} m, "
                  f"{sum(sub):.0f} m in total")

    # ---- markers: the ground truth ---------------------------------------------------------
    if recs["mark"]:
        print(f"\n  --- {len(recs['mark'])} HAND-PLACED MARKERS (ground truth) ---")
        for m in recs["mark"]:
            print(f"  {m['dt']/60:7.1f} min   {m['label']}")
        counts = Counter(m["label"] for m in recs["mark"])
        print(f"  {dict(counts)}")
        if runs:
            print(f"  >>> compare: {len(runs)} runs detected vs. "
                  f"{counts.get('Top', 0)} 'Top' markers you placed")

    # ---- battery -------------------------------------------------------------------------
    batt = [n for n in recs["note"] if "battery level=" in n.get("text", "")]
    if len(batt) >= 2:
        def lvl(n):
            try:
                return float(n["text"].split("battery level=")[1].split()[0])
            except (IndexError, ValueError):
                return None
        def state(n):
            try:
                return int(n["text"].split("state=")[1].split()[0])
            except (IndexError, ValueError):
                return None

        # Only unplugged stretches measure drain. On 2026-09-02 the phone was on a charger from
        # 12:47 to ~12:57 in the middle of a 5.25 h recording; taking first-minus-last across that
        # read 4.8 %/h for a day that actually drained ~7 (S12). A charge in the middle of a session
        # is normal on a ski day, so the endpoints are not a measurement — the segments are.
        # UIDevice.batteryState: 1 = unplugged, 2 = charging, 3 = full.
        drain, hours, charged = 0.0, 0.0, False
        for a, b in zip(batt, batt[1:]):
            la, lb = lvl(a), lvl(b)
            if la is None or lb is None or la < 0 or lb < 0:
                continue
            if state(a) != 1 or state(b) != 1 or lb > la:
                charged = True
                continue
            drain += (la - lb) * 100
            hours += (b["dt"] - a["dt"]) / 3600

        first, last = lvl(batt[0]), lvl(batt[-1])
        if first is not None and last is not None and hours > 0:
            # UIDevice.batteryLevel is quantised to 5% — every reading in every file so far is a
            # multiple of 0.05. So the rate is only as good as the number of *steps* observed, and
            # over a one-hour session there is exactly one. S5 and S6 published 5.5 %/h and
            # 6.7 %/h as if they were different measurements; both are one 5-point step over a
            # slightly different span, and the true rate could be anywhere from ~0 to ~11 %/h.
            # Print the uncertainty rather than a decimal the instrument cannot support (R7).
            steps = round(drain / 5)
            print(f"\n  --- BATTERY ---")
            print(f"  {first*100:.0f}% -> {last*100:.0f}% over the session")
            if charged:
                print(f"  charging (or an unreadable state) seen mid-session — that time is excluded")
            print(f"  drained {drain:.0f}% over {hours:.2f} h unplugged"
                  f"   = {drain/hours:.1f} %/h nominal")
            if steps <= 2:
                lo = max(0.0, drain - 5) / hours
                hi = (drain + 5) / hours
                print(f"  ONLY {steps} x 5% STEP(S) OBSERVED — batteryLevel is quantised to 5%,")
                print(f"  so the honest range is {lo:.1f}-{hi:.1f} %/h. Do not quote the nominal")
                print(f"  figure. A usable battery number needs a session of 3 h or more.")
            elif drain > 0:
                print(f"  {steps} x 5% steps observed — the rate is meaningful at "
                      f"+/-{5/hours:.1f} %/h.")
            if drain > 0:
                print(f"  projected full-day (7 h): {drain/hours*7:.0f}% "
                      f"({max(0.0, drain-5)/hours*7:.0f}-{(drain+5)/hours*7:.0f}%)")

    print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        main(p)
