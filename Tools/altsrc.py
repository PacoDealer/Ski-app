#!/usr/bin/env python3
"""Why our vertical reads ~3% under Slopes' INSIDE SLOPES' OWN RUN WINDOWS.

    Tools/altsrc.py

**The question this closes.** S16 ran the control that separates measurement from segmentation
(R32): re-measured over Slopes' exact windows, our distance is +0.1% but our vertical is -3.0%.
S17 ruled out the other boundary too (`runup.py`: the heads hold 84 m of vertical, the tails 63 m
— neither end can produce a 3% day-scale deficit). So it was a measurement difference, and the
only hypothesis on the table was a bad one: Slopes' top speed sits +3.59% above ours and was
attributed to smoothing, so "maybe altitude is smoothed by the same 3%" — a coincidence of sign
and size, explicitly recorded as not-a-mechanism (A18) and not to be retuned on.

**It is not smoothing. It is a different sensor and a different convention, and both halves are
measurable.** Four steps, each of which can be re-run here:

1. **Slopes' published `vertical` is just the altitude column of its own export**, taken
   top-to-bottom over the run: it reproduces to **-0.3%/-0.5%** on every graded day.

2. **That column is our raw `CLLocation.altitude`** — i.e. GPS altitude, not barometry. Pairing
   its rows to ours on exact latitude/longitude (the field neither app processes; Slopes exports
   6 dp, so both sides round to 6) gives a rigid **-0.2203 s** clock offset across p5-p95 — the
   same-stream signature of S12c — and the altitudes are **identical to the millimetre on 96.4%**
   of paired fixes. Only ~24% of its rows pair, so on its own this is exposed to a selection
   effect (the rows that pair could be exactly the ones it left alone), which is why step 3 does
   not use pairing at all.

3. **The pairing-free version, and the real result.** Measure the same drop over Slopes' own
   windows twice from OUR file — barometer and raw GPS altitude — under both conventions:

   |            | baro 1st-last | baro max-min | gps 1st-last | **gps max-min** |
   |---|---|---|---|---|
   | 2026-09-01 | -3.2% | -2.3% | -1.4% | **+0.5%** |
   | 2026-09-02 | -3.5% | -2.6% | -2.1% | **+0.4%** |
   | 2026-09-03 | -2.3% | -1.3% | -1.0% | **+0.2%** |
   | 2026-09-04 | -2.8% | -1.8% | -1.3% | **+0.1%** |

   **GPS altitude, max minus min, lands on Slopes to +0.1/+0.5% on all four days.** The residual
   is two independent choices, not one: the SENSOR is worth ~1.3-1.8 points and the CONVENTION
   (max-min vs top-to-bottom) another ~1.0. Reading one without the other gets the size wrong.

4. **And max-min over GPS altitude is inflated by scatter, by about the amount observed.** The
   control: 5-minute windows in the real ski-day files where the *barometer* says nothing moved
   (<= 2 m) — standing at the top, in a lift queue, stopped for lunch — where the true vertical
   is therefore ~0.

   | over 11 flat outdoor 5-minute windows | mean | median | worst |
   |---|---|---|---|
   | barometer, max-min | 1.66 m | | 1.96 m |
   | **GPS altitude, max-min** | **8.46 m** | 5.05 m | 32.95 m |
   | GPS altitude, 1st-last | 3.78 m | | 13.07 m |

   On a 300 m Portillo run that is **+2.8% mean / +1.7% median of pure phantom vertical**, against
   a measured residual of 2.3-3.5%. The stationary fixture agrees independently: 81 locked indoor
   minutes give **7.65 m** per 5-minute window on GPS against **0.87 m** on the barometer — the
   same answer from a recording with no skiing in it at all.

**⇒ We are not reading 3% low. Slopes is reading ~2-3% high, by an amount its own choice of
sensor and convention predicts, and our barometric top-to-bottom number is the more conservative
measurement.** This is the same finding as Carve's +11% (S5), one order of magnitude down: Carve
sums smoothed GPS altitude across the day, Slopes takes max-min of it per run, we take the
barometer top-to-bottom. **Change nothing** — adopting max-min GPS to close the gap would be
fitting to the reference, and would import the phantom metres measured above.

Caveats kept in the open (R5/R20): one resort, four days, one device. The flat-window control has
n=11 and its mean is pulled by a 33 m worst case, so quote the median beside it. And this does not
retire the top-speed +3.59%, which remains smoothing (A18) and is a separate number.
"""

import csv
import datetime
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analyze import load
from grade import DAYS, FIXTURES, ROOT, slopes_runs

COMPARISONS = ROOT / "Data" / "comparisons"
FLAT_WINDOW_S = 300.0
FLAT_BARO_M = 2.0


def day_altitudes(fixtures):
    """Every barometric and GPS altitude sample of a day, on one absolute clock."""
    baro, gps = [], []
    for name in fixtures:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        t0 = datetime.datetime.fromisoformat(
            recs["meta"]["startedAt"].replace("Z", "+00:00")).timestamp()
        baro += [(t0 + b["dt"], b["relAlt"]) for b in recs["baro"]]
        # The same hAcc gate `analyze.py` uses, so this is GPS altitude at its best, not at its
        # worst — the comparison must not be won by feeding the other sensor rejected fixes.
        gps += [(t0 + l["dt"], l["alt"]) for l in recs["loc"]
                if l["dt"] >= 0 and 0 <= l["hAcc"] <= 25]
    return sorted(baro), sorted(gps)


def graded_days():
    for d in sorted(COMPARISONS.glob("slopes_*")):
        meta = d / "Metadata.xml"
        if not meta.exists():
            continue
        ref = slopes_runs(meta)
        if not ref:
            continue
        day = ref[0]["start"].strftime("%Y-%m-%d")
        if day in DAYS:
            yield d, day, ref


def step1_published_vs_own_column():
    """Does Slopes' published `vertical` come from the altitude column of its own export?"""
    print("\n=== 1. Slopes' published vertical vs the altitude column in its own export ===")
    for d, day, ref in graded_days():
        pts = []
        with open(d / "RawGPS.csv") as f:
            for row in csv.reader(f):
                if len(row) >= 4:
                    pts.append((float(row[0]), float(row[3])))
        pts.sort()
        pub = own = 0.0
        for r in ref:
            a, b = r["start"].timestamp(), r["end"].timestamp()
            alts = [x[1] for x in pts if a <= x[0] <= b]
            if len(alts) < 2:
                continue
            pub += r["vert"]
            own += max(alts) - min(alts)
        print(f"  {day}   published {pub:7.0f} m   its own column {own:7.0f} m"
              f"   {100*(own-pub)/pub:+5.1f}%")


def step2_is_that_column_our_gps(day="2026-09-04"):
    """Is that column our raw CLLocation altitude? Pair on position, the field neither app touches."""
    print(f"\n=== 2. Is that column our raw GPS altitude? ({day}, paired on exact lat/lon) ===")
    if day not in DAYS:
        return
    by_pos = {}
    for name in DAYS[day]:
        recs, _ = load(str(FIXTURES / f"{name}.jsonl"))
        t0 = datetime.datetime.fromisoformat(
            recs["meta"]["startedAt"].replace("Z", "+00:00")).timestamp()
        for l in recs["loc"]:
            if l["dt"] >= 0:
                by_pos.setdefault((round(l["lat"], 6), round(l["lon"], 6)), []).append(
                    (t0 + l["dt"], l["alt"]))
    for name in ("RawGPS.csv", "GPS.csv"):
        path = COMPARISONS / f"slopes_{day}" / name
        if not path.exists():
            continue
        diffs, offsets, seen = [], [], 0
        for r in csv.reader(open(path)):
            if len(r) < 4:
                continue
            seen += 1
            ts, lat, lon, alt = float(r[0]), float(r[1]), float(r[2]), float(r[3])
            cands = by_pos.get((round(lat, 6), round(lon, 6)))
            if not cands:
                continue
            t, our_alt = min(cands, key=lambda c: abs(c[0] - ts))
            offsets.append(t - ts)
            diffs.append(alt - our_alt)
        if not diffs:
            continue
        diffs.sort(); offsets.sort(); n = len(diffs)
        same = sum(1 for x in diffs if abs(x) < 0.001)
        print(f"  {name}: paired {n} of {seen} rows"
              f"   clock offset median {offsets[n//2]:+.4f} s"
              f"  (p5 {offsets[n//20]:+.4f}, p95 {offsets[19*n//20]:+.4f})")
        print(f"     their altitude - our raw GPS altitude:"
              f" mean {sum(diffs)/n:+.3f} m, identical to 1 mm on {same}/{n}"
              f" ({100*same/n:.1f}%)")


def step3_which_sensor_and_convention():
    """The pairing-free version: measure our own file both ways, over Slopes' own windows."""
    print("\n=== 3. Over SLOPES' OWN WINDOWS, measured from OUR file — sensor x convention ===")
    print(f"  {'day':>11} {'Slopes':>8} | {'baro 1st-last':>14} {'baro max-min':>14}"
          f" | {'gps 1st-last':>14} {'gps max-min':>14}")
    for _, day, ref in graded_days():
        baro, gps = day_altitudes(DAYS[day])
        pub = bf = bm = gf = gm = 0.0
        for r in ref:
            a, b = r["start"].timestamp(), r["end"].timestamp()
            ba = [x[1] for x in baro if a <= x[0] <= b]
            ga = [x[1] for x in gps if a <= x[0] <= b]
            if len(ba) < 2 or len(ga) < 2:
                continue
            pub += r["vert"]
            bf += ba[0] - ba[-1]; bm += max(ba) - min(ba)
            gf += ga[0] - ga[-1]; gm += max(ga) - min(ga)
        fmt = lambda v: f"{v:6.0f} ({100*(v-pub)/pub:+5.1f}%)"
        print(f"  {day:>11} {pub:8.0f} | {fmt(bf):>14} {fmt(bm):>14}"
              f" | {fmt(gf):>14} {fmt(gm):>14}")
    print("  ^ GPS altitude max-min reproduces Slopes on every day. Two choices, not one:"
          "\n    the SENSOR is worth ~1.3-1.8 points, the CONVENTION another ~1.0.")


def step4_phantom_control():
    """What max-min invents from scatter alone, where the barometer says nothing moved."""
    print(f"\n=== 4. Control: {FLAT_WINDOW_S/60:.0f}-minute windows where the BAROMETER says"
          f" nothing moved (<= {FLAT_BARO_M:.0f} m) ===")
    for label, names in (("outdoors, real ski days", [f for v in DAYS.values() for f in v]),
                         ("indoors, the stationary fixture",
                          ["2026-09-01_portillo_stationary"])):
        b_mm, g_mm, g_fl = [], [], []
        for name in names:
            if not (FIXTURES / f"{name}.jsonl").exists():
                continue
            baro, gps = day_altitudes([name])
            if not baro:
                continue
            t = baro[0][0]
            while t + FLAT_WINDOW_S <= baro[-1][0]:
                ba = [x[1] for x in baro if t <= x[0] <= t + FLAT_WINDOW_S]
                if len(ba) > 1 and (max(ba) - min(ba)) <= FLAT_BARO_M:
                    ga = [x[1] for x in gps if t <= x[0] <= t + FLAT_WINDOW_S]
                    if len(ga) > 30:            # a real fix rate, not a coverage gap
                        b_mm.append(max(ba) - min(ba))
                        g_mm.append(max(ga) - min(ga))
                        g_fl.append(abs(ga[0] - ga[-1]))
                t += FLAT_WINDOW_S
        if not g_mm:
            continue
        print(f"\n  {label} — {len(g_mm)} windows, true vertical ~0 m")
        print(f"     barometer max-min    mean {statistics.mean(b_mm):5.2f} m"
              f"   worst {max(b_mm):5.2f} m")
        print(f"     GPS alt   max-min    mean {statistics.mean(g_mm):5.2f} m"
              f"   median {statistics.median(g_mm):5.2f} m   worst {max(g_mm):5.2f} m")
        print(f"     GPS alt   1st-last   mean {statistics.mean(g_fl):5.2f} m"
              f"   worst {max(g_fl):5.2f} m")
        print(f"     => on a 300 m run, GPS max-min invents"
              f" {100*statistics.mean(g_mm)/300:.1f}% mean /"
              f" {100*statistics.median(g_mm)/300:.1f}% median of phantom vertical")


if __name__ == "__main__":
    step1_published_vs_own_column()
    step2_is_that_column_our_gps()
    step3_which_sensor_and_convention()
    step4_phantom_control()
    print("\n  ⇒ We are not 3% low. Slopes is ~2-3% high, by an amount its own sensor and"
          "\n    convention predict. Do not adopt max-min GPS to close it (R20 / A18).")
