# The Slopes export — 2026-09-02, Portillo

Martin exported his own day from Slopes on 2026-09-02 at 17:04 and handed over the file. It is the
best ground truth this project has ever had, and it settles A18.

**`2 September 2026 - Portillo.slopes` is a zip containing three files:**

| File | What it is |
|---|---|
| `Metadata.xml` | The activity, plus **one `<Action>` per lift and per run**, each with start, end, duration, vertical, distance, avg speed, top speed, and the lat/long/altitude *where the top speed occurred*. |
| `RawGPS.csv` | The unprocessed fix stream: `time, lat, long, altitude, course, speed, vAcc, hAcc`. |
| `GPS.csv` | The same fixes after Slopes' own processing. |

**This is the data Slopes paywalls.** Run-by-run stats are a Premium feature; the free tier shows a
daily summary. The export gives all of it, to more precision than the paid screen does, for free.
Worth knowing before we treat "run-by-run detail" as the thing we're giving away — Slopes already
does, through a door most users never open.

## Activity header

```
runCount 8   vertical 1359.9 m   distance 8278 m   topSpeed 69.17 km/h   duration 7456 s
start 10:30:24   end 12:34:41   recordStart 10:22:32   recordEnd 17:04:33
```

`recordStart` 10:22:32 against our session start of **10:22:27** — five seconds apart, which is
Martin's thumb moving between two apps. The windows really were the same; S11's warning that the
percentages were provisional is now discharged.

## Run by run, ours against theirs

| # | Slopes start | ours | Δ | Slopes end | ours | Δ | Slopes vert | our vert | Δ |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 10:51:05 | 10:52:08 | +63 s | 11:01:38 | 11:03:15 | +98 s | 304.3 | 303.1 | −0.4% |
| 2 | 11:09:16 | 11:09:27 | +12 s | 11:13:07 | 11:13:49 | +43 s | 125.1 | 131.0 | +4.8% |
| 3 | 11:20:30 | 11:20:35 | +6 s | 11:25:31 | 11:26:41 | +70 s | 128.2 | 128.3 | +0.1% |
| 4 | 11:34:00 | 11:34:06 | +6 s | 11:39:23 | 11:40:22 | +60 s | 126.6 | 127.8 | +0.9% |
| 5 | 11:46:35 | 11:46:45 | +10 s | 11:53:55 | **11:56:09** | **+134 s** | 119.6 | **141.6** | **+18.4%** |
| 6 | 12:05:07 | 12:04:58 | −9 s | 12:10:56 | 12:10:58 | +3 s | 310.4 | 300.1 | −3.3% |
| 7 | 12:21:41 | **12:18:50** | **−171 s** | 12:24:19 | 12:24:55 | +37 s | 121.7 | 126.2 | +3.7% |
| 8 | 12:33:25 | **12:30:36** | **−168 s** | 12:34:41 | 12:35:31 | +51 s | 123.9 | 127.7 | +3.1% |
| | | | | | | | **1359.9** | **1386.0** | **+1.9%** |

**Eight runs against eight, matched one-to-one, with no hand tags on either side.** Six of the eight
agree within 3.7%. This is the first time the detector has been graded run-by-run against anything
other than Martin's glove.

**Two real defects of ours are visible here, and neither is a threshold to nudge blindly:**

- **Run 5, +22 m and 134 s long at the bottom.** We keep descending where Slopes stops. Either we
  are absorbing a runout Slopes cuts, or we merged something Slopes split.
- **Runs 7 and 8 start ~170 s too early.** Slopes' lift 7 ends at 12:19:30 and its run 7 starts at
  12:21:41 — a 2 m 11 s wait at the top. Ours starts at 12:18:50, *before Slopes' lift has even
  ended*. The A19 plateau trim, which fixed exactly this in S7, is not catching these two. Note the
  trim was built and scored against the 2026-09-01 days; this is the first data that disagrees with
  it. **Do not retune against a single day (R5) — check what the barometer is doing across those
  170 s first.**

## A18 IS SETTLED — and the mechanism is now measured, not inferred

`Metadata.xml` stamps the day's top speed with the exact position it occurred at. Searching our own
raw file for that point:

```
Slopes' day top speed  69.17 km/h at (-32.8345707, -70.1269833) alt 2870.3 m
our nearest fix        0.0 m away, 12:10:44, 68.42 km/h, hAcc ±7.7 m, alt 2870 m
```

**It is the same GPS fix.** Zero metres apart, the same second, the same altitude — and our day's
maximum sits on that identical fix. Then, in Slopes' own two files at that timestamp:

```
RawGPS.csv   19.0060 m/s = 68.42 km/h   <-- our number, to the decimal
GPS.csv      19.2128 m/s = 69.17 km/h   <-- what Slopes publishes
```

So **Slopes publishes its processed track, not the fix the chip handed it**, and the entire +1.09%
gap between us is Slopes' own post-processing. Across the whole day its processed track is faster
than its own raw on **1,014 of 1,343 fixes**, mean **+0.33 km/h**, max **+3.72 km/h**.

**That closes A18.** The question was whether Slopes' 67.2 km/h on 2026-09-01 was the 11:28:59
multipath burst, or our clean 64.7 peak read +3.9% high. We now know what Slopes' processing costs
on a clean peak: **+1.09%**. It cannot produce +3.9%. The 2026-09-01 gap is not processing, so it is
the burst — the same conclusion we reached for Carve's 66.8, now for Slopes, and reached by
measurement instead of by leaning.

*(Confirming it outright would take one more thing: the `.slopes` export for **1 Sep 2026**, which
is still in Martin's logbook. Its `topSpeedLat`/`topSpeedLong` would say directly whether Slopes'
peak that day sits on the burst fix. Cheap, and it converts "settled by inference from a clean day"
into "read off the file".)*

## Slopes and Vertical are recording the same bytes

All 1,345 of Slopes' raw fixes match one of ours, after a constant clock offset of −0.154 s:

| | Result |
|---|---|
| Fixes matched within 50 ms | **1,345 / 1,345 (100%)** |
| Position agreement | mean **0.079 m**, max 0.144 m — the export writes 6-decimal lat/long, which *is* 0.11 m |
| hAcc agreement | median \|Δ\| **0.052 m**, max **0.100 m** — the export rounds to 1 dp, so this is exact |
| Speed, excluding clamped fixes | **1,117 / 1,117 identical to float precision (100%)** |
| Fixes Slopes wrote as `0.0000` where we kept a real Doppler value | **228** (ours: median 1.70 m/s, max 2.73 m/s) |

**Vertical and Slopes read the identical CoreLocation stream.** Every difference between the two
apps' published numbers is a processing choice, not a sensor or a capture difference. The four
independent ties (0.8 / 1.2 / 1.0 / 1.9%) now have a mechanism: we are looking at the same bytes.

Two things Slopes does to those bytes that we do not:

1. **It clamps slow fixes to zero** — 228 of them, up to 2.73 m/s. Defensible for display; it also
   means Slopes cannot go back and ask what happened at walking pace.
2. **It throws most of the day away.** Over the same window Slopes' export holds **1,345** fixes
   where we hold **7,900** — **Slopes keeps 17%.** R13 said never drop sensor data at capture time
   because a filter can be changed later and a discarded sample cannot. The market leader's own
   export is the argument: every accuracy finding in this project came from fixes at this density,
   and Slopes no longer has them.

## What this does NOT show

Vertical agreement is **not** explained by shared bytes — vertical comes from the barometer, which
Slopes does not export, and ours is `CMAltimeter`. The +1.9% is still an independent result. And
n=1: one day, one phone, one mountain (R5).
