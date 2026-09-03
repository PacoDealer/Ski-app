# Competitor screenshots — the evidence behind `RESEARCH.md` §5.1.1

Screenshots Martin took of the **other two apps recording the same morning as
`../fixtures/2026-09-01_portillo_s1.jsonl`**. They are the only record of those numbers: neither
app exports raw samples, and both screens are live views that are gone once the session is cleared.
Keep them.

| File | App | Taken | What it shows |
|---|---|---|---|
| `2026-09-01_slopes.png` | Slopes (free tier) | 11:46 local | Today's Stats: 1 h 11 m, 5 runs, 912 m vertical, 5.1 km. Run 1 (10:38) itemised — 415 m, 2.1 km, 53.8 km/h top, 31.0 km/h avg, 5 m 26 s. Runs 2+ blurred behind the paywall; only run 2's **10:57** start time is legible, and it matches ours to three seconds. |
| `2026-09-01_carve.png` | Carve | 11:47 local | Record screen, paused at 1:05:43: 4 runs, 996 m vertical, 5.69 km, **66.8 km/h top speed** — the number that turns out to be a multipath glitch in our own file at 11:28:59. Altitude 2868 m. Also confirms Carve renders on Apple Maps (the S4 MapKit finding). |

## Second batch — 13:39, cumulative for the whole day

Martin skied a second morning session and screenshotted both apps again before lunch. **These are
day totals, not session-2 totals** — they include the 10:35–11:30 session in the table above.

| File | App | Day total at 13:39 |
|---|---|---|
| `2026-09-01_carve_1339.png` | Carve | 3:01:43 elapsed (paused), **7 runs, 1,509 m vertical, 9.08 km**, top speed **66.8 km/h**, altitude 2,875 m |
| `2026-09-01_slopes_1339.png` | Slopes | **8 runs, 1,384 m vertical**, altitude 2,875 m, top speed **67.2 km/h** |

Three things worth noting before the second session's raw file is pulled and analysed:

1. **Carve's top speed is still exactly 66.8 km/h** — unchanged from the 11:28:59 multipath sample
   identified in `RESEARCH.md` §5.1.1. Nothing in a second session of skiing beat it. A glitch is
   still sitting at the top of that app's day.
2. **By subtraction, session 2 was ~3 runs**: Slopes 8−5, Carve 7−4. Carve's day total is **+9.0%**
   over Slopes' (1,509 vs 1,384), consistent with the +10.1% measured on session 1 against our own
   barometric number.
3. **Slopes and Carve now disagree on run count by one in the same direction as before** (8 vs 7),
   which is the base-area split described in §5.1.1 finding 4 — worth re-checking against the
   second file rather than assumed.

**Analysed S6 (2026-09-01).** The second session was pulled and is now
`../fixtures/2026-09-01_portillo_s2.jsonl`. Results in `RESEARCH.md` §5.1.2. All three predictions
above held: session 2 is **3 runs** exactly as the subtraction said, Carve is **+10.4%** on the day
total against our 1,367 m, and Slopes is **+1.2%**. The run-count disagreement (8 vs 7) is entirely
session 1's base-area split — both apps agree with us on 3 runs for session 2.

One thing the subtraction could **not** settle: Slopes' 67.2 km/h day top speed. Session 2's maximum
is 43.9 km/h, so it comes from session 1, where the only candidates are the clean 64.7 peak and the
11:28:59 multipath burst. See §5.1.2 and assumption **A18** — it is not yet known which, and the
Run 2 top-speed field in `2026-09-01_slopes.png` that would answer it is behind the Premium blur.

## Third batch — 16:18 / 16:20, the finished day records

`2026-09-01_slopes_1618.png` and `2026-09-01_carve_1620.png`. Martin skied no afternoon and
**confirmed he pressed stop straight after the 13:39 screenshot** — he did not ski again — so these
are the same recording as the 13:39 batch, saved rather than live.

| App | Saved day record | Live at 13:39 | Moved |
|---|---|---|---|
| Slopes | 8 runs, **1,380 m**, 8.4 km, 2 h 50 m, top **67,2 km/h**, tallest run 415 m, peak alt 3.173 m, ski 41 min / lift 40 min / rest 1 h 28 m | 1,384 m | −4 m |
| Carve | 7 runs, **1,625 m**, 9.4 km, 3 h 2 m, top **67 km/h** | 1,509 m, 9.08 km, 3:01:43 paused | **+116 m** |

**The finding is the Carve row.** Same run count, same elapsed once rounded, and **Martin confirms
he pressed stop and skied nothing further** — and 116 m (+7.7%) more vertical in the saved entry
than on the live screen. Slopes moved 4 m the
other way. Against our 1,367 m the saved figures are **Slopes +1.0%, Carve +18.9%**. Written up in
`RESEARCH.md` §5.1.3, with the decomposition of Carve's error and the two questions it opened
(A19, A20).

Also worth keeping from the Slopes screen: it recorded the same 10:37–13:27 span we did, including
the 69-minute lunch break, and booked that break as **1 h 28 m of rest with no vertical**. And its
**40 min of lift time** is an independent check on our own lift detector, which finds 37.4 min.

## 2026-09-02, 12:45–12:46 — the four-app batch, taken at the START of the afternoon break

`2026-09-02_strava_1245.png`, `2026-09-02_carve_1245.png`, `2026-09-02_slopes_1246.png`,
`2026-09-02_vertical_1246.png`. App identification confirmed by Martin.

Martin skied the morning with all four running, then **paused Slopes, Carve and Strava and left
Vertical recording**, per the S7 ask. He does not ski again until ~14:30. These are **live screens,
not saved records** (R12b applies to the end-of-day batch, not to a mid-day bracket like this one).

| App | State | Elapsed | Runs | Vertical | Distance | Top speed | Altitude |
|---|---|---|---|---|---|---|---|
| **Vertical** | recording | 2:23:50 | **8** — *screen showed 7, see below* (+45 m sub) | **1,386 m** (naive 1,634) | — | **68** km/h, *gate clean* | 2,876 m (GPS) |
| Slopes | paused | — | 8 | **1,360 m** | — | **69,2** km/h | 2.876 m |
| Strava | paused | 02:13:28 | 9 | **1.412 m** | 9,62 km | — (avg 9,0) | — |
| Carve | paused | 2:12:15 | 9 | **1572 m** | 9.15 km | **68.4** km/h | 2903 m |

Against our 1,386 m: **Slopes −1.9%, Strava +1.9%, Carve +13.4%.**

⚠️ **The windows are not identical and the percentages above are provisional.** Ours ran 2:23:50
continuously; Carve's clock froze at 2:12:15 and Strava's at 02:13:28 when Martin paused them, and
none of the four start times is known from a screenshot. Resolve against the raw file before these
numbers go into `RESEARCH.md`.

Five things this batch establishes, pending the raw file:

1. **A21, first read: Strava sits in the tie cluster, not with Carve.** +1.9% over our barometric
   number, the same order as Slopes' −1.9%. This does **not** yet answer whether Strava measures
   with the barometer or DEM-corrects afterwards — that check is still owed before its number is
   treated as a sensor reading.
2. **Fourth independent Slopes agreement** (0.8%, 1.2%, 1.0%, now 1.9%) — and the **first time we
   read higher than Slopes rather than lower**.
3. **Carve is consistent with itself**: +13.4%, inside the +10.1 / +10.4 / +18.9% band from
   2026-09-01, and still unexplained at the top end (A20).
4. **Altitude cross-check, new and unprompted:** our GPS altitude reads **2,876 m** and Slopes reads
   **2.876 m** — identical to the metre — while **Carve reads 2,903 m, +27 m high**. Independent
   corroboration of the S5/S7 finding that Carve's altitude is GPS-only and smoothed.
5. **A18's precondition is met for the first time: today has no multipath burst.** Our TOP SPEED
   tile reads *gate clean*, which by `ContentView.swift:130` means `maxSpeedUngated ≤ maxSpeed` —
   the hAcc gate rejected nothing faster than the clean peak. With no glitch available to anybody,
   all three published top speeds land within 1.8% of each other (68 / 68.4 / 69,2). Contrast
   2026-09-01, where Slopes read **+3.9%** over our clean peak with a known 4-second burst sitting
   in the track. That leans A18 toward *Slopes captured the burst*, but it is one clean day against
   one dirty one — **not settled, and the afternoon can still produce a burst.**

**~~Open on our side:~~ RESOLVED IN S12 — and it was not the S5 bug.** The suspicion was that our
**7 runs against Slopes' 8** were the S5 signature: a split run whose orphaned tail falls under
`MIN_RUN_DROP_M`. It wasn't. Replaying the raw file truncated to this screenshot's exact elapsed
(2:23:50) gives **8 runs / 1,386 m / +45 m sub-threshold** — the vertical and the discarded
sub-threshold match the table above *to the metre*, and only the count differs. The segmenter had it
right; **Slopes agreed with us on run count as well as vertical**, and the row above is a display
bug.

The cause was that the two tiles counted different things: `provisionalDescentM` included the
descent that is closed-but-still-mergeable *plus* the leg in progress, while `runCount` counted only
completed runs. All eight runs had finished by 12:35:31, ten minutes before the screenshot, but two
of them were still held in provisional state with nothing to close them — so the tile read 7, and
would have kept reading 7 until STOP. Fixed via `LiveMetrics.provisionalRunCount` (**R23**); no
recorded data was affected and no golden number moved. **Read the Vertical row above as 8 runs.**

Carve and Strava's 9 remain unexplained, and are consistent with their known GPS-summing behaviour
splitting descents ours merges.

### The A20 bracket — Martin did not ski the afternoon, and that IMPROVED the test

**Update, end of 2026-09-02:** Martin never resumed. Slopes, Carve and Strava are still **paused**
and Vertical is still **recording**. So this batch is not the "before" half of a 1 h 45 m bracket —
it is the **final morning number**, and the paused window is now **open-ended and many hours long**
instead of the 69-minute lunch that raised A20.

That is a better experiment, for a plain reason: if Carve's pause freezes the elapsed clock but not
the track, the accrual is roughly linear in wall-clock time, so a multi-hour pause makes the effect
**large and unmistakable** rather than a 116 m residual that has to be argued for. If Carve's
vertical is unchanged after all those hours, the hypothesis is dead and A20 needs a different
mechanism. Either way it stops being a guess.

**⚠️ This measurement is live and unsaved. It is destroyed by pressing Finish/Stop on any of the
three paused apps.** The "after" capture is the identical four screenshots taken **while still
paused, before finishing anything** — then the saved day records afterwards (R12b).

What makes it decisive rather than residual: **Vertical recorded through the whole window**,
outdoors, at the best GPS quality yet seen (hAcc ±4 m, Doppler 8,222/8,303 = 99.0%, 0.96 Hz). The
break is simultaneously a **matched stationary control on snow** — replay the Carve GPS-hysteresis
model over exactly the minutes Carve was paused and compare it against Carve's own accrual, instead
of arguing from the indoor 674 m upper bound (R20).

### ✅ THE A20 BRACKET WAS RUN — 2026-09-02, 16:57–17:07, after 4 h 12 m paused

Screenshots: `2026-09-02_strava_1657_paused.png`, `2026-09-02_slopes_1657_paused.png`,
`2026-09-02_carve_1658_paused_zeroed.png`, `2026-09-02_carve_1707_logbook_empty.png`.

| App | at 12:45 | at 16:57, still paused | change over 4 h 12 m |
|---|---|---|---|
| Strava | 02:13:28, 9 runs, 1.412 m, 9,62 km | identical, to the second | **nothing** |
| Slopes | 8 runs, 1.360 m, top 69,2, alt 2.876 m | 8 runs, **1.360 m**, top 69,2, alt 2.891 m | **nothing** (altitude is a live readout) |
| Carve | 2:12:15, 9 runs, 1572 m, 9.15 km | **00:00 · 0 runs · 0 m · 0.00 km** | **the session is gone** |

**A20's hypothesis is dead for Slopes and Strava.** Neither accrued a single metre across four
hours paused. Whatever explains Carve's +116 m on 2026-09-01, it is not something a paused tracker
normally does.

**Slopes' altitude moved +15 m — and that is a fourth agreement, not a discrepancy.** Our own
barometer drifted **+9.9 m over 2.86 h** parked on the same afternoon (≈3.5 m/h, weather pressure
falling), which extrapolates to ≈14.5 m over Slopes' 4.2 h window. Two phones, the same drift.
More usefully: **neither app turned that drift into vertical.** Ours stayed at 1,386 m with the
drift landing in sub-threshold; Slopes stayed at 1,360. Another negative control, and precisely the
failure mode a GPS-summing pipeline cannot reject.

### 🔴 CARVE LOST THE DAY

Nobody pressed Finish. After ~4 hours paused, Carve's Record screen shows `Paused 00:00` with every
statistic at zero — speed, altitude, runs, top speed, vertical, distance — while the day's track is
still drawn on the map behind it. The Logbook then shows a **`2 Sep 2026` row carrying no stats at
all**, and the season header reads **2 days · 1.6k vert · 9.4 km · 7 runs**, which is the 1 Sep day
by itself. The 2 Sep day contributes nothing.

**A 2 h 12 m day — 9 runs, 1,572 m, 9.15 km, live on Carve's own screen at 12:45 — is unrecoverable.**

This is the strongest evidence the project has for its own core design decision, and it is worth
more than the A20 measurement it destroyed:

- Carve is a **local-first tracker with no paywall and iCloud sync** (`RESEARCH.md` §2.2). It is the
  app whose feature list we keep measuring ourselves against. It lost a full ski day to a pause.
- Vertical cannot do this. Every sample is appended to a JSONL file and fsync'd as it arrives, so
  the day exists on disk before any summary is computed. There is no save step to fail.
- We had already proved this from the other side in S12: our own session file was **pulled off the
  phone mid-recording** and analysed in full, hours before anyone pressed STOP.

It also retires the A20 mechanism hunt as a priority. The leading hypothesis was "Carve's pause
freezes the elapsed clock but not the track." What 2026-09-02 actually shows is that **Carve's
pause/save path is unreliable outright** — the 2026-09-01 +116 m recomputation and this total loss
are more plausibly one broken path than two separate behaviours. Do not spend more sessions
reverse-engineering it; record the observation and move on.

**Caveat (R5):** n=1, one pause, one device, and we do not know what a longer or shorter pause does.
Say "Carve lost a day when paused for four hours on 2026-09-02", not "Carve loses days".

---

Vertical's own numbers for the first session come from the fixture, via `Tools/analyze.py` and
`Tools/detect.py`, not from a screenshot.

---

## 2026-09-03 — the third graded day

`3 September 2026 - Portillo.slopes` (unzipped to `slopes_2026-09-03/`), analysed in
**`2026-09-03_slopes_export.md`**. Ours: `Data/fixtures/2026-09-03_portillo_s4.jsonl`.

Slopes 1,335.2 m / 8 runs vs. our 1,379.7 m / 9 runs (**+3.3%**); **mean run-start error 16 s**,
the best of the three graded days. Zero false tops, which is what let the higher-top merge fix ship
(R5). Top speed: our gate rejects a 78.4 km/h burst and lands on **66.999 km/h — bit-for-bit
Slopes' own raw maximum**; Slopes published 69.1, its smoothing of that same fix (A18, replicated).
Slopes marks 13:15–16:10 `ignore`; our segmenter reports zero runs there unaided.

**Note on the run counts:** 9 vs 8 is a labelling difference, not a defect — we split Slopes' run 2
across a 4-minute mid-run gap and the halves sum to +0.7% of its figure. The scorer used to pair
the two lists by index and reported a −11,964 s error for this; see **R27**.

All three exports are unzipped in-tree as `slopes_2026-09-01/`, `slopes_2026-09-02/`,
`slopes_2026-09-03/`, which is what `Tools/falsetop.py --score <dirs>` reads.
