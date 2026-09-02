# The 1 Sep and 31 Aug Slopes exports — the ones that settle A18

Martin exported two more days on 2026-09-02: `1 September 2026 - Portillo.slopes` (the day the
multipath burst is in) and `31 August 2026 - Portillo.slopes` (a day we have no recording for).

| Export | Slopes runs | Slopes vertical | Slopes top speed | our coverage |
|---|---|---|---|---|
| 31 Aug 2026 | 11 | 2,072.0 m | 54.93 km/h | **none** — we were not recording |
| 1 Sep 2026 | 8 (one is 7.4 m) | 1,379.7 m | **67.21 km/h** | fixtures `_s1` + `_s2` |
| 2 Sep 2026 | 8 | 1,359.9 m | 69.17 km/h | fixture `_s3_partial` |

## A18 is answered, and neither of its two options was right

A18 asked whether Slopes' 67.2 km/h on 2026-09-01 was **the 11:28:59 multipath burst**, or **our
clean 64.7 peak read +3.9% high**. The export answers it by direct reading:

```
Slopes RawGPS.csv max   69.57 km/h @ 11:29:00  hAcc ±23.7   <- the burst
Slopes GPS.csv max      70.15 km/h @ 11:29:00  hAcc ±23.7   <- the burst, smoothed
Slopes PUBLISHED        67.21 km/h @ 11:01:11  hAcc ± 9.3   <- neither of the above
our gated peak          64.74 km/h @ 11:01:11  hAcc ± 9.3
our ungated peak        69.57 km/h @ 11:29:00  hAcc ±23.7
```

**Slopes has the burst in both of its own files and published neither.** Its published number comes
from 11:01:11 — the *identical fix* our hAcc gate lands on — and at that fix its raw value is
**64.74 km/h with hAcc ±9.3**, which is ours to the decimal. Its raw day maximum, 69.57, matches our
ungated maximum to **0.0000 km/h**.

So:

1. **Slopes rejects the multipath burst, exactly as we do.** It is not an ungated app. The S5-era
   framing where we were the careful ones and the category was naive does not describe Slopes at
   all — it describes Carve, which published its burst as its headline.
2. **Slopes and Vertical select the same clean fix as the day's peak**, independently, from the same
   raw stream.
3. **The remaining +3.81% is Slopes smoothing that fix**, and publishing the smoothed value rather
   than the reading.

### A withdrawn claim, and how it went wrong

Earlier in S12 — with only the 2 Sep export in hand — this was written up as *"Slopes published the
burst"*, on this reasoning: at the 2 Sep peak Slopes' processing added **+1.09%**, therefore
processing could not account for 2026-09-01's +3.9%, therefore the +3.9% had to be the burst.

**The premise was a single fix on a single day, promoted to a bound.** Slopes' uplift is
speed-dependent and variable:

| | 1 Sep |
|---|---|
| uplift on fixes above 18 km/h | mean +0.615 km/h, median +0.397, max +5.387 km/h |
| **relative** uplift on fixes above 54 km/h | **mean +2.72%, max +5.62%** |

+3.81% sits comfortably inside that. The conclusion is withdrawn in
`2026-09-02_slopes_export.md` and in `RESEARCH.md` §13.4 A18, where it was recorded.

This is exactly the failure R2 names — one inference on top of another without going back to a
primary source — committed on the same day the rule was quoted approvingly. The file that settles it
was one message away.

## Run by run, 1 Sep

Slopes reports 8 runs; **one of them is 7.4 m.** Excluding it, both apps report 7 runs and they pair
one-to-one:

| # | Slopes start | ours | Δ | Slopes end | ours | Δ | Slopes vert | our vert | Δ |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 10:39:27 | 10:39:52 | +26 s | 10:44:54 | 10:45:33 | +39 s | 415.1 | 407.4 | −1.9% |
| 2 | 10:57:03 | 10:57:37 | +34 s | 11:01:23 | 11:01:45 | +23 s | 61.8 | 58.2 | −5.9% |
| 3 | 11:12:30 | 11:12:39 | +9 s | 11:15:21 | 11:16:14 | +54 s | 139.5 | 144.0 | +3.2% |
| 4 | 11:22:24 | 11:23:26 | +62 s | 11:28:59 | 11:29:55 | +57 s | 288.5 | 295.8 | +2.5% |
| 5 | 12:48:08 | 12:48:48 | +40 s | 12:59:48 | 13:02:21 | +153 s | 307.7 | 297.3 | −3.4% |
| 6 | 13:09:03 | 13:09:43 | +40 s | 13:12:21 | 13:13:48 | +88 s | 70.6 | 71.6 | +1.4% |
| 7 | 13:20:12 | 13:19:33 | −39 s | 13:25:15 | 13:25:43 | +28 s | 89.1 | 92.6 | +4.0% |
| | | | | | | | **1372.3** | **1366.8** | **−0.4%** |

Against Slopes' full 8-run total including the fragment: **1,366.8 vs 1,379.7 = −0.9%**, which is
the S7 screenshot figure (−1.0%) confirmed from the file.

**The S5 "5 runs vs 4" story is now a number.** Slopes' extra run on this day is **7.4 m** of
descent at the base area. We merge it; Slopes counts it. That is the whole disagreement, and at 7.4 m
it is well under our 30 m minimum either way.

### What this says about the 2 Sep run-start defect

On 2 Sep our runs 7 and 8 started **~170 s early**. On 1 Sep nothing like that happens — our starts
are **+9 to +62 s late** on six of seven runs. The difference is the wait at the top:

| day | wait between Slopes' lift end and its run start | our start error |
|---|---|---|
| 1 Sep, runs 1–6 | 5–46 s | +9 to +62 s (late) |
| 1 Sep, run 7 | 306 s | −39 s (early) |
| 2 Sep, runs 7–8 | 131 s, 163 s | −171 s, −168 s (early) |

**Our run start goes early precisely when there is a long wait at the top** — and on 2 Sep run 7 we
started *before Slopes' lift had even ended*, so this is not only the A19 plateau trim missing a
plateau; the descent is being declared during what Slopes still calls a lift. Portillo's va-et-vient
platters are the obvious suspect. **Two days is still two days (R5)** — diagnose against the
barometer trace across those windows before touching a threshold.

## 31 Aug is reference only

11 runs, 2,072 m, top 54.93 km/h, 10:38:49 → 15:09:53. **We have no recording of that day** — the
31 Aug files in `Data/fixtures` are indoor tests. It is worth keeping as an example of the export
format across a longer day, and as evidence Slopes has been running on this phone since before we
started, but it supports no comparison.
