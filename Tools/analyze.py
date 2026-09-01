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
# Reject Doppler speed samples the receiver itself doesn't trust.
MAX_SPEED_ACC = 2.0     # m/s
# Reject position fixes worse than this before using them for anything.
MAX_H_ACC = 25.0        # m


def load(path):
    recs = {"meta": None, "loc": [], "baro": [], "abs": [], "mark": [], "note": [], "end": None}
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

    runs = []
    for (t0, a0), (t1, a1) in zip(turns, turns[1:]):
        drop = a0 - a1
        if drop >= min_drop:
            runs.append({"start": t0, "end": t1, "drop": drop, "dur": t1 - t0})
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

    # ---- SPEED: the headline comparison --------------------------------------------------
    print(f"\n  --- MAX SPEED: how you measure it changes the answer ---")

    doppler = [l["speed"] for l in locs
               if l["speed"] >= 0 and 0 <= l["speedAcc"] <= MAX_SPEED_ACC]
    doppler_ungated = [l["speed"] for l in locs if l["speed"] >= 0]

    # The naive method every other app uses: differentiate successive positions.
    derived = []
    for a, b in zip(locs, locs[1:]):
        dt = b["dt"] - a["dt"]
        if dt <= 0:
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

    runs = [r for t, a in segments for r in segment_runs(t, a)]
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
        for i, r in enumerate(runs, 1):
            print(f"  {i:2d}.  {r['drop']:5.0f} m   {r['dur']/60:5.1f} min"
                  f"   {r['drop']/max(r['dur'], 1):.1f} m/s vertical rate")
        drops = [r["drop"] for r in runs]
        print(f"\n  longest drop {max(drops):.0f} m   shortest {min(drops):.0f} m"
              f"   total {sum(drops):.0f} m")

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
        first, last = lvl(batt[0]), lvl(batt[-1])
        span = batt[-1]["dt"] - batt[0]["dt"]
        if first is not None and last is not None and span > 0 and first >= 0 and last >= 0:
            drain = (first - last) * 100
            print(f"\n  --- BATTERY ---")
            print(f"  {first*100:.0f}% -> {last*100:.0f}% over {span/3600:.2f} h"
                  f"   = {drain/(span/3600):.1f} %/h")
            if drain > 0:
                print(f"  projected full-day (7 h) cost: {drain/(span/3600)*7:.0f}%")

    print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        main(p)
