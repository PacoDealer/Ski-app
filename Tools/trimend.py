#!/usr/bin/env python3
"""Grade candidate run-END rules against Slopes, instead of arguing about them.

    Tools/trimend.py               # every candidate, every graded day
    Tools/trimend.py --verbose     # per-run detail for each candidate

**The question.** S16 measured what S14b had only asserted: our runs end **mean +65 s** after
Slopes' (later on 21 of 23), the tails average **3.3 km/h**, and **12 of 21** are neither moving
nor descending. So there is dead time inside our runs. But S16 also showed that adopting Slopes'
boundary outright overshoots — the tails hold 129 m of vertical against a +69 m excess and 1,576 m
of distance against a +821 m excess. **That rules out copying Slopes' end. It does not tell us
what our own rule should be**, because any real rule cuts less than the whole tail.

**The tension this has to resolve.** `segment_runs` is barometric on purpose, and a run already
ends at the altitude minimum, so the tail is time spent within hysteresis of the floor. A purely
barometric trim therefore cuts *every* tail — including the two that were still genuinely moving.
Keeping those requires GPS speed, which crosses a line the project drew deliberately
(`attach_run_positions` is kept out of `segment_runs` for exactly this reason). Rather than settle
that in the abstract, every candidate below is graded, barometric and GPS-assisted alike, and the
cost of each is printed.

**Read the table this way.** `vert` and `dist` are what the app would publish against Slopes'
totals. `ski min` is graded against Slopes' own summed run durations, which is the number S7 used
when it rejected trimming both ends ("undershoots by 13%") — that verdict is re-run here across
three days and 23 runs instead of one day. A candidate that fixes distance by breaking vertical is
not an improvement; S16's whole finding was that these two move independently.
"""

import argparse
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import (BARO_HYSTERESIS_M, MAX_H_ACC, MAX_SPEED_ACC, MAX_SPEED_H_ACC,
                     MIN_DISTANCE_DT, haversine, load, resume_seams, segment_runs, split_at_seams)
from grade import DAYS, FIXTURES, ROOT, TZ, pair_by_time, slopes_runs


# --- the candidate rules -------------------------------------------------------------------
#
# Each takes the run and the day's series and returns the time the run should end. They all walk
# BACKWARDS from the altitude minimum, which is where `segment_runs` currently ends the run.

def keep_all(run, times, alts, speed_at):
    """Current behaviour: end at the altitude minimum, runout included (S7)."""
    return run["end"]


def baro_plateau(threshold):
    """Mirror of `descent_start`: walk back through the trailing plateau, purely barometric.

    This is the rule S7 tried and rejected on one day's ski time. It cannot distinguish a skier
    coasting a flat runout from a skier standing still, because at the bottom of a run both are
    within a few metres of the floor.
    """
    def rule(run, times, alts, speed_at):
        floor = None
        end = run["end"]
        for t, a in zip(reversed(times), reversed(alts)):
            if t > run["end"]:
                continue
            if t <= run["start"]:
                break
            if floor is None:
                floor = a
            if a > floor + threshold:
                return t
            floor = min(floor, a)
            end = t
        return end
    return rule


def stopped(threshold, kmh):
    """Trim the trailing plateau only while the skier is ALSO not moving.

    The conditional form S16 argued for: dead time is flat *and* slow, a runout is flat *and*
    fast. Costs the barometric-only purity of segmentation, which is the trade to be judged.
    """
    def rule(run, times, alts, speed_at):
        floor = None
        end = run["end"]
        for t, a in zip(reversed(times), reversed(alts)):
            if t > run["end"]:
                continue
            if t <= run["start"]:
                break
            if floor is None:
                floor = a
            v = speed_at(t)
            if a > floor + threshold or (v is not None and v * 3.6 >= kmh):
                return t
            floor = min(floor, a)
            end = t
        return end
    return rule


def stopped_sustained(threshold, kmh, window_s):
    """As `stopped`, but movement must be SUSTAINED to halt the trim.

    `stopped` walks back and stops at the first sample above the speed gate, so one noisy fix in
    the middle of dead time ends the walk and the whole tail survives — which is most of why it
    barely moves ski time. Here the skier counts as moving only if the median gated speed over the
    surrounding `window_s` is above the gate, which is the same "don't let one fix own the number"
    discipline the hAcc gate exists for (S5).
    """
    def rule(run, times, alts, speed_at):
        floor = None
        end = run["end"]
        for t, a in zip(reversed(times), reversed(alts)):
            if t > run["end"]:
                continue
            if t <= run["start"]:
                break
            if floor is None:
                floor = a
            vs = [v for v in (speed_at(t + off) for off in range(-window_s, window_s + 1, 2))
                  if v is not None]
            moving = bool(vs) and sorted(vs)[len(vs) // 2] * 3.6 >= kmh
            if a > floor + threshold or moving:
                return t
            floor = min(floor, a)
            end = t
        return end
    return rule


CANDIDATES = [
    ("current (no trim)", keep_all),
    ("baro plateau 3 m", baro_plateau(BARO_HYSTERESIS_M)),
    ("baro plateau 5 m", baro_plateau(5.0)),
    ("baro plateau 8 m", baro_plateau(8.0)),
    ("stopped 3 m / 5 km/h", stopped(BARO_HYSTERESIS_M, 5.0)),
    ("stopped 3 m / 8 km/h", stopped(BARO_HYSTERESIS_M, 8.0)),
    ("stopped 5 m / 8 km/h", stopped(5.0, 8.0)),
    ("stopped 8 m / 8 km/h", stopped(8.0, 8.0)),
    ("sustained 3 m / 8 km/h", stopped_sustained(BARO_HYSTERESIS_M, 8.0, 10)),
    ("sustained 3 m / 6 km/h", stopped_sustained(BARO_HYSTERESIS_M, 6.0, 10)),
    ("sustained 5 m / 8 km/h", stopped_sustained(5.0, 8.0, 10)),
]


def speed_lookup(locs):
    """Nearest gated Doppler speed to a barometer sample time, or None where there isn't one."""
    pts = [(l["dt"], l["speed"]) for l in locs
           if l["speed"] >= 0 and 0 <= l["speedAcc"] <= MAX_SPEED_ACC
           and 0 <= l["hAcc"] <= MAX_SPEED_H_ACC]

    def at(t):
        if not pts:
            return None
        best = min(pts, key=lambda p: abs(p[0] - t))
        return best[1] if abs(best[0] - t) <= 3.0 else None
    return at


def measure(locs, alts_by_t, start, end, top_alt):
    """Vertical, distance and duration for one window, with `analyze.py`'s gates.

    **Vertical is `top_alt` minus the altitude at the (possibly trimmed) end — deliberately NOT
    max-minus-min over the window.** The first version of this tool used max-minus-min, which also
    silently discards the altitude lost during the *leading* plateau that `descent_start` trims,
    and that is a second, independent change worth 60 m across these 23 runs. Folding it in made
    "current (no trim)" grade +0.2% where `grade.py` reports +1.7%, i.e. it flattered every
    candidate equally by pre-applying a different fix. Measuring from `top_alt` makes the no-trim
    row reproduce `grade.py` exactly, which is the only way the rest of the column means anything.
    """
    fixes = [l for l in locs if start <= l["dt"] <= end and 0 <= l["hAcc"] <= MAX_H_ACC]
    dist, step_from = 0.0, None
    for l in fixes:
        if step_from is None:
            step_from = l
        elif l["dt"] - step_from["dt"] >= MIN_DISTANCE_DT:
            dist += haversine(step_from["lat"], step_from["lon"], l["lat"], l["lon"])
            step_from = l
    at_end = [a for t, a in alts_by_t if t <= end]
    return {
        "vert": (top_alt - at_end[-1]) if at_end else 0.0,
        "dist": dist,
        "dur": end - start,
    }


def evaluate(rule, verbose=False, name=""):
    tot = {"sv": 0.0, "sd": 0.0, "st": 0.0, "ov": 0.0, "od": 0.0, "ot": 0.0}
    end_deltas = []
    for d in sorted((ROOT / "Data" / "comparisons").glob("slopes_*")):
        meta = d / "Metadata.xml"
        if not meta.exists():
            continue
        ref = slopes_runs(meta)
        if not ref:
            continue
        day = ref[0]["start"].strftime("%Y-%m-%d")
        if day not in DAYS:
            continue

        ours = []
        for fx in DAYS[day]:
            recs, _ = load(str(FIXTURES / f"{fx}.jsonl"))
            started = datetime.datetime.fromisoformat(
                recs["meta"]["startedAt"].replace("Z", "+00:00"))
            locs = [l for l in recs["loc"] if l["dt"] >= 0]
            baro = [(b["dt"], b["relAlt"]) for b in recs["baro"]]
            seams = resume_seams(recs["note"])
            speed_at = speed_lookup(locs)
            for t_arr, a_arr in split_at_seams([x[0] for x in baro], [x[1] for x in baro], seams):
                for r in segment_runs(t_arr, a_arr):
                    # `segment_runs` reports `drop` = top_a - bot_a and ends the run at bot_t, so
                    # the summit altitude is recoverable without changing its return shape.
                    bot_a = next(a for t, a in zip(reversed(t_arr), reversed(a_arr))
                                 if t <= r["end"])
                    top_alt = r["drop"] + bot_a
                    new_end = rule(r, t_arr, a_arr, speed_at)
                    m = measure(locs, baro, r["start"], new_end, top_alt)
                    ours.append({
                        "start": (started + datetime.timedelta(seconds=r["start"])).astimezone(TZ),
                        "end": (started + datetime.timedelta(seconds=new_end)).astimezone(TZ),
                        **m,
                    })
        ours.sort(key=lambda r: r["start"])
        groups = pair_by_time(ref, ours)
        if verbose:
            print(f"\n  --- {name} · {day} ---")
        for i, (s, g) in enumerate(zip(ref, groups), 1):
            if not g:
                continue
            v = sum(r["vert"] for r in g)
            di = sum(r["dist"] for r in g)
            du = sum(r["dur"] for r in g)
            sdur = (s["end"] - s["start"]).total_seconds()
            tot["sv"] += s["vert"]; tot["sd"] += s["dist"]; tot["st"] += sdur
            tot["ov"] += v; tot["od"] += di; tot["ot"] += du
            end_deltas.append((g[-1]["end"] - s["end"]).total_seconds())
            if verbose:
                print(f"   {i:>2}  vert {s['vert']:6.0f} vs {v:6.1f}"
                      f" {100*(v-s['vert'])/s['vert']:+6.1f}%   dist {s['dist']:6.0f} vs {di:6.0f}"
                      f" {100*(di-s['dist'])/s['dist']:+6.1f}%   end {end_deltas[-1]:+5.0f}s")
    n = len(end_deltas)
    return {
        "vert": 100 * (tot["ov"] - tot["sv"]) / tot["sv"],
        "dist": 100 * (tot["od"] - tot["sd"]) / tot["sd"],
        "ski": 100 * (tot["ot"] - tot["st"]) / tot["st"],
        "ski_min": tot["ot"] / 60.0,
        "slopes_min": tot["st"] / 60.0,
        "end_mean": sum(end_deltas) / n,
        "end_abs": sum(abs(x) for x in end_deltas) / n,
        "late": sum(1 for x in end_deltas if x > 0),
        "n": n,
    }


def main(verbose=False):
    print(f"{'candidate':<22} {'vert':>8} {'dist':>8} {'ski time':>9} {'end Δ mean':>11}"
          f" {'|Δ|':>6} {'late':>7}")
    for name, rule in CANDIDATES:
        r = evaluate(rule, verbose=verbose, name=name)
        print(f"{name:<22} {r['vert']:>+7.1f}% {r['dist']:>+7.1f}% {r['ski']:>+8.1f}%"
              f" {r['end_mean']:>+10.0f}s {r['end_abs']:>5.0f}s {r['late']:>4}/{r['n']}")
    print(f"\n  Slopes' own summed run time: {evaluate(keep_all)['slopes_min']:.1f} min")
    print("  vert/dist/ski are OUR totals against SLOPES' totals; 0.0% is agreement.")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--verbose", action="store_true")
    main(p.parse_args().verbose)
