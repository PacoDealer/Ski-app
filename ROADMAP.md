# ROADMAP.md — Vertical

Current state, planned work, and the decisions that gate it.
Companion docs: `RESEARCH.md` (market + feasibility), `CLAUDE.md` (project context + tooling).

---

## ⚡ START HERE — handoff for the next session (updated 2026-09-03, S13)

### 🟢 S13 — the whole file is off the phone, and the prefix claim is now a test

Martin AirDropped the complete 2026-09-02 recording:
**`Data/fixtures/2026-09-02_portillo_s3.jsonl`, 49,716,710 bytes, 6 h 37 m (10:22–16:59)**,
17,446 fixes, 22,008 baro, 597,193 motion samples. It replaces the 40 MB partial, which is gone
from `Data/fixtures/` (`portilloS3Partial` → `portilloS3`).

**Three things it settles.**

1. **The append-only prefix claim is proven, not asserted.** The 40 MB pull is a *byte-exact*
   prefix of the whole file (same md5 over the first 39,998,540 bytes), and it reports the
   **identical 8 runs / 1,386 m / 68.4 km/h**. That is what licenses R18b (copy first, ask
   second) and it is now the test `fortyMegabytePrefixReadsTheSameDay`, which truncates the
   fixture in-process rather than keeping a second 40 MB blob in git. **24 tests green.**
   `replay.sh` agrees with `analyze.py` to the metre on the new fixture.
2. **The session was properly closed** — a real `end` record at 16:59:28, `imuCount` 597,193.
   S11/S12's "the phone is holding an unclosed session" is resolved; nothing is stranded.
   **IMU coverage 100.3% over 6.6 h, no gap > 0.2 s.** The dinner control proved background
   device motion for one hour; this proves it for six and a half.
3. **The tail is a second negative control, and it is cleaner than the first.** The last 82
   minutes are a stationary phone *outdoors at 2,890 m* (baro flat within 8.6 m, GPS under
   1 km/h). It added **zero runs and zero vertical** — the day total did not move by a metre.
   It accrued 59 m of sub-threshold descent across 10 candidates (~43 m/h), all far under the
   30 m `MIN_RUN_DROP_M`, which is exactly the margin doing its job. The dinner control was
   indoors; this one is the outdoor case, and both invent nothing.

**🔴 A real defect of ours, found here, in `analyze.py` (fixed, `MIN_DERIV_DT = 0.5`).** The
"position-differentiated" max speed — *our own headline about the category's error* — divided by
whatever interval separated two fixes, guarded only by `dt <= 0`. **CoreLocation redelivers fixes
microseconds apart**: 384 pairs closer than 0.2 s on this day, the tightest **95 µs**. A metre of
scatter over 95 µs printed **341,659 km/h** and a **+499,243%** headline. Every fixture has such
pairs (9 / 4 / 237 / 384). **We criticised Carve for publishing a glitch as its top speed and had
the same bug in our own harness** (R20).

- **The 1 Sep +136.5% headline survives untouched** — 153.1 km/h there was always a real 42.5 m
  jump across a full second. Nothing published has to be withdrawn.
- **2 Sep's naive max is now 311.7 km/h** and it is a genuine finding: an **86.4 m one-second
  position jump at 13:42:51 while the phone sat still**, Doppler reading 2.5 → 0.0 km/h across it.
- **No number the app displays was affected.** The app's "naive" tiles are summed baro deltas and
  ungated Doppler; it never position-differentiates. Harness-only.

**🔋 Battery, best measurement yet: 6.7 %/h over 6.00 h unplugged, 8 discrete 5% steps (±0.8).**
Projects to **47% for a 7 h day (41–52%)**. Split: **7.0 %/h over the 5 h skiing window** (identical
to S12's figure, same window) and 5.5 %/h over the stationary tail — but that tail is *one* step,
so it is a hint, not a rate. The mid-session charge (12:47–12:57) is still correctly excluded (R24).

**Also in the file:** two `kCLErrorDomain error 0` location dropouts at 15:49 and 15:54 while
parked, both self-healing; one fix at ±1,414 m hAcc at 12:36 which the 25 m gate discarded.

### 🔴 Still open, unchanged by S13
1. **Reinstall before the fuse dies ~2026-09-08** — also ships the RUNS-tile fix from S12. Martin's
   last ski day is ~2026-09-07, so this is the deadline that actually bites.
2. **The false-top fix stays unshipped** — S13 added a *longer* day, not a *third graded* one, so
   R5 is unchanged. A third `.slopes` export still decides it.
3. **Ask for the 1 Sep `.slopes` export** if it is still in the logbook (see S12 below).

### 🟢 S12 — the day is off the phone, and it carried two bugs out with it.

**The recording is saved.** `Data/fixtures/2026-09-02_portillo_s3_partial.jsonl` — 5 h 15 m,
10:22–15:37 local, 14,489 fixes, 473,854 motion samples, **8 runs / 1,386 m**, top speed 68.4 km/h
*gate clean*. It was pulled **while the session was still recording**, without waiting for Martin to
press STOP: the format is append-only and fsync'd, so a mid-recording copy is a valid prefix (new
rule **R18b** — copy first, ask second; S11 left a full ski day on a phone for a day because the
handoff had that order backwards).

**It is a partial, and that is a finding, not an accident.** `devicectl copy from` stops at
**exactly 40,000,000 bytes** and reports it as `CoreDeviceError 7000` / socket-closed, which reads
like flakiness. Four retries and a whole-directory copy all produced byte-identical 40,000,000-byte
files with the same md5, while a 10 MB file came across whole in the same run. At ~7.6 MB/h with
motion capture on, **the cable hits this cap about 5¼ hours into any ski day** (**R18a**). The rest
of that file is still on the phone. Getting it needs another route — the `ShareLink` already in
`SessionsView` (AirDrop) is the obvious one, and is now worth testing for real.

### 🟢 S12 later — the A20 bracket ran, Carve lost the day, and Slopes handed us its raw file

**A20's bracket, after 4 h 12 m paused:** Strava identical to the second; **Slopes unmoved at
1,360 m**; **Carve zeroed itself** — `00:00`, every stat at zero, and a Logbook row for 2 Sep 2026
with no stats at all while the season total equals the 1 Sep day alone. **A 2 h 12 m day, 9 runs,
1,572 m, is unrecoverable, and nobody pressed Finish.** That is the strongest evidence this project
has for append-only capture, and it retires the A20 mechanism hunt: Carve's pause/save path is
simply unreliable. n=1 — say "lost a day when paused for four hours", not "loses days".

**Slopes' altitude moved +15 m over that window and that is an agreement, not a discrepancy** — our
own barometer drifted +9.9 m in 2.86 h parked (≈3.5 m/h), which extrapolates to ≈14.5 m. Neither app
turned the drift into vertical.

**Martin then exported `2 September 2026 - Portillo.slopes`, and it is the best ground truth the
project has ever had.** It is a zip of `Metadata.xml` (one `<Action>` per lift and per run, with
vertical, duration, top speed and *where* the top speed occurred), `RawGPS.csv` and `GPS.csv` —
i.e. Slopes' Premium run-by-run data, exportable free. Full write-up:
`Data/comparisons/2026-09-02_slopes_export.md`. Three results:

1. **A18 IS ANSWERED — and the answer is neither option the question offered.** Martin then exported
   1 Sep and 31 Aug too, and the 1 Sep file reads directly: Slopes' `RawGPS.csv` max is **69.57 km/h
   @ 11:29:00 hAcc ±23.7** — the burst, matching our *ungated* max to 0.0000 km/h — its processed max
   is 70.15, and **it published neither**. It published **67.21 @ 11:01:11**, the identical fix our
   hAcc gate lands on, where its raw value is **64.74 km/h, bit-for-bit ours**. **Slopes rejects the
   burst exactly as we do**, and the residual +3.81% is its smoothing of the clean fix.
   ⚠️ **An earlier S12 write-up said "Slopes published the burst" and is withdrawn** — it generalised
   a single fix's +1.09% uplift on 2 Sep into a bound, when the uplift is speed-dependent (1 Sep:
   mean +2.72% above 54 km/h, max +5.62%). R2, on the day it was quoted approvingly. Both write-ups
   carry the correction: `Data/comparisons/2026-09-01_slopes_export.md`.
2. **Slopes and Vertical record the identical CoreLocation stream.** All 1,345 of its raw fixes
   match ours after a constant −0.154 s offset, with **1,117/1,117 non-clamped speeds identical to
   float precision**. Every published difference between the two apps is a processing choice. Slopes
   also clamps 228 slow fixes to zero and keeps only **17%** of the fixes we do (1,345 vs 7,900) —
   R13, argued by the market leader's own export.
3. **Run-by-run, 8 against 8, no hand tags on either side, +1.9% on the day** — and it exposed two
   real defects of ours: **run 5 runs 134 s and +22 m long**, and **runs 7 and 8 start ~170 s early**
   (the A19 plateau trim is not catching a 2-minute wait at the top). The 1 Sep export gives a second
   graded day — **7 runs against 7 once Slopes' 7.4 m fragment is set aside, −0.4%**, and it
   **localises the defect**: our starts are +9 to +62 s *late* on the six runs with a 5–46 s wait at
   the top, and go *early* only where the wait is long (306 s → −39 s; 2 Sep's 131/163 s → −171/−168
   s). On 2 Sep run 7 we started **before Slopes' lift had even ended**, so this is not only a missed
   plateau — the descent is being declared during what Slopes still calls a lift. Portillo's
   va-et-vient platters are the suspect. **Two days is still two days (R5)** — read the barometer
   across those windows before touching a threshold.
4. **The S5 "5 runs vs 4" disagreement is now a number: Slopes' extra run on 1 Sep is 7.4 m.**

### 🔬 The run-start defect is diagnosed — `Tools/falsetop.py` — and deliberately NOT fixed yet

**It is a false *top*, not a missed plateau.** `segment_runs` declares a descent's top at the first
turning point that survives 3 m of hysteresis. On a lift cresting a roll the altitude dips just past
3 m and then climbs higher again, so the top is declared **during the climb**. The merge rule then
stitches the two descents back together and keeps the **first** one's top, so vertical is barely
affected — but `descent_start` walks its plateau trim forward from the wrong place and the run
**starts minutes early**. On 2026-09-02 run 7 we declared a descent while Slopes still had him on a
lift.

Run 7's raw trace: peak **123.11 m at 12:18:43**, dip to **119.99 at 12:18:53** — **3.12 m**, i.e.
**12 cm past the threshold** — then back up to **123.84 at 12:19:41**, and the real push-off at
**12:21:50** (GPS jumps 1.5 → 17.1 km/h). Between them, two minutes of milling at 0–6 km/h with the
course swinging 177° → 278° → 236°.

**Exactly three false tops exist across all three recorded days, all on 2026-09-02, and they are
runs 6, 7 and 8** — precisely the runs the Slopes comparison flagged. The dips that fired them are
**3.12, 3.25 and 4.48 m**, all within 1.5 m of the threshold. 2026-09-01 has none, which is why that
day's starts are all correct.

**Candidate fix, scored:** when two descents merge, adopt the **higher** of the two tops instead of
always keeping the first — which is what "measured top-to-bottom" already claims to mean, and it
leaves the S5 case untouched (there the blip is at the bottom, so the second top is lower).

| | 2026-09-01 | 2026-09-02 |
|---|---|---|
| mean \|start error\|, now | 36 s | 56 s |
| mean \|start error\|, fixed | **36 s** (bit-for-bit no-op) | **29 s** |
| run 8 | — | −168 s → **−7 s** |
| run 7 | — | −171 s → −72 s |
| run 6 | — | −9 s → **+54 s (worse)** |
| day vertical | 1366.8 (unchanged) | 1386.0 → **1390.1** |

**Not shipped, on purpose.** It halves the error on the affected day and does nothing on the
unaffected one, but it makes one run worse and moves **1386 m**, which is a golden number in the
suite. Two graded days is two graded days (R5). **A third `.slopes` export decides it** — re-run
`Tools/falsetop.py --score <unzipped export dirs>`.

**🔴 STILL OPEN, and the reason to be quick: the fuse dies ~2026-09-08.** Vertical's session was
still recording at 15:37 and nothing has closed it; the file's tail past 40 MB is still on the phone.
**Worth asking for: the `.slopes` export of 1 Sep 2026**, still in the logbook — its
`topSpeedLat`/`topSpeedLong` would turn A18's answer from inferred-from-a-clean-day into read-off-
the-file, and it gives a second day of run-by-run ground truth for the run 5 / runs 7–8 defects.

### What the file settled

**Battery, finally measured — and the harness was lying about it.** `analyze.py` read 75% → 50%
over 5.25 h and printed **4.8 %/h**. The phone was on a charger from 12:47 to ~12:57 (`state=2`,
60 → 70%), which the endpoint arithmetic silently absorbed. Excluding charged time: **7.0 %/h over
5.00 h unplugged, 7 discrete 5% steps, ±1.0 %/h** — the first battery number this project is
entitled to quote, and ~46% higher than the naive one. A 7 h day costs **~49% (42–56%)**, with GPS
at 1 Hz and motion capture at 25 Hz running the whole time. Every earlier figure (5.5, 6.7, 0–3.7)
was one step or none; they bracket 7.0 without contradicting it. Fixed in `analyze.py`, which now
splits at charging and says so (**R24**).

**The 7-runs-vs-8 gap was ours, and it was a UI bug, not a segmentation bug.** S11 read the phone at
12:46 as **7 runs / 1,386 m / +45 m sub** against Slopes' 8. Replaying the identical bytes truncated
to that exact instant gives **8 runs / 1,386 m / +45 m sub** — vertical and sub-threshold match to
the metre, only the count differs, so the segmenter was right all along and **Slopes agreed with us
on run count** too. Cause: `provisionalDescentM` counted the closed-but-still-mergeable descent
*and* the leg in progress, while `runCount` counted completed runs only. Standing at the bottom
after the last run of the day the tile was **two** descents low, and stayed there until STOP.
Fixed with `provisionalRunCount` in `LiveMetrics`; **the recorded data was never affected** and no
golden number moved. New rule **R23**, and a test that deliberately never calls `finish()`.

**A18 gets its cleanest evidence yet.** Ungated and gated top speed are identical at 68.4 km/h over
the whole 5¼ hours — no multipath burst anywhere in the day, including three hours of a parked
phone. Still leaning, not settled: one clean day against one dirty one.

**The IMU held for five hours.** 473,854 samples, 25.1 Hz, 100% coverage, **no gap over 0.2 s**,
most of it screen-off and parked. S10 proved this for 81 minutes; this proves it across a ski day.

Both fixes ship with tests — **22 now, all green** (`Tools/test.sh`), including a golden test on
this day. Everything committed.

---

### 🔴 S11's original handoff — item 1 is DONE (see above), item 2 is NOT.

Martin skied the morning of 2026-09-02 with all four apps, paused Slopes/Carve/Strava over the
break, **did not ski the afternoon, and left Vertical recording.** As of end of S11 that is still
the state: **three apps paused, Vertical's session still open, nothing pulled off the phone.**

**1. Pull the raw file.** It is the longest recording the project has (≥2:23:50, 8,303 fixes,
217k IMU samples, ~19.3 MB, and still growing while the session is open). It has never been
`devicectl copy from`'d. Until it is, a full ski day plus a multi-hour stationary control exists
only on a phone whose **provisioning fuse dies ~2026-09-08**. Ask Martin to press STOP first — the
file is append-only and safe, but a closed session is what `SessionRecovery` and `analyze.py` expect.

**2. Ask for the A20 "after" screenshots BEFORE anything is finished.** Slopes, Carve and Strava
have now been *paused* for many hours. If Carve's pause freezes the elapsed clock but not the track
(the leading A20 hypothesis), the accrual is linear in wall-clock time and a multi-hour pause makes
it **unmissable** instead of a 116 m residual. Screenshot all four **while still paused**, then the
saved day records (R12b). **Pressing Finish/Stop on any of the three destroys the measurement.**

Everything else from the morning is committed: `Data/comparisons/2026-09-02_*.png` plus the analysis
in that directory's README (`681b043`).

**What the morning batch already established** — Strava joins the tie cluster (**A21**, +1.9% over
our 1,386 m; Slopes −1.9%, Carve +13.4%); a fourth independent Slopes agreement, and the first time
we read *higher*; our GPS altitude and Slopes' agree **to the metre** at 2,876 m while Carve reads
+27 m, a third independent confirmation that Carve's altitude is GPS-only and smoothed; and **today
has no multipath burst** (TOP SPEED tile reads *gate clean*), which is the precondition **A18** has
been waiting for — all three top speeds land within 1.8%.

**Two things NOT to carry forward as settled.** The percentages are provisional: our clock ran
continuously while the other three froze at pause, and no start time is legible in any screenshot,
so the windows are not identical until the raw file says so. And **A18 is leaning, not answered** —
one clean day against one dirty one.

**Open on our side, to check against the raw file, not assume:** we reported **7 runs against
Slopes' 8 and Carve/Strava's 9**, with **45 m of descent discarded under the minimum-drop
threshold**. That is the signature of the S5 bug (a split run whose orphaned tail falls under
`MIN_RUN_DROP_M`), but it is a signature, not a diagnosis.

**Battery stays unmeasured.** The phone was on charge at 60% by 12:46, so the continuous-drain
number this day was supposed to deliver did not happen. Bound remains 0–3.7 %/h.

---

## Handoff as of S9 (2026-09-01) — still valid underneath the above

### 🟢 S9 built the session detail screen, and it is ON THE PHONE.

`SessionDetailView` + `SessionReplay` (`c8960fd`) turn a saved recording into runs, vertical, top
speed and a recording-quality block, on the phone, with no cable. Matches `analyze.py` exactly on
both fixtures. **Installed 2026-09-01 20:03**, so the provisioning fuse is reset again (~2026-09-08)
and this is the build Martin skis with. Martin left the install decision to me; the reasoning was
that the change cannot reach a recording — `SessionReplay` only ever reads files that are already
closed, and the only edit outside new files is marking `LiveMetrics` `nonisolated`.

**Confirmed by Martin, 2026-09-01: the app opens and the detail screen opens.** (`devicectl process
launch` had failed with `FBSOpenApplicationErrorDomain error 7 — Locked`, so this needed his hands;
a locked phone cannot be launched into remotely.) **Still unseen: the screen itself.** Nobody has
looked at a screenshot of it, and the numbers on it have only ever been checked as text from
`replay.sh` — worth one screenshot when he next opens a real day (R13, screenshot beyond the math).

### ✅ Both S8 blockers are closed (S10, 2026-09-02)

**1. The walk test is done and it is green.** 81 minutes locked and pocketed over dinner:
**25.1 Hz, 100% coverage, no gap over 2 s, 122,358 motion samples.** Background device-motion
delivery is now *observed*, not inferred from `CMAltimeter`. **The IMU is cleared to ski with.**

**2. Martin is skiing with it today (2026-09-02)** — Vertical, Slopes, Carve and Strava together.

The same file became the **negative control the project had never run**: over 81 stationary
minutes our method reports **0 m**, while our reproduction of Carve's GPS-hysteresis pipeline
reports **674 m** and naive GPS summing reports 1,162 m. Indoors, so it is an upper bound on the
failure mode rather than a prediction of Carve's error on snow — but it is also independent
mechanism-evidence for **A20** (Carve's +116 m across a *paused* lunch). See S10 in the log.

**Battery bound tightened to 0–3.7 %/h** (was 0–11): 90% → 90% over 1.33 h, zero 5% steps. Today's
single long session is what finally answers it.

### ✅ D7 IS ANSWERED (S9). Read the decisions table's §13.6 before planning anything.

Martin, in his own words: **"the objective of the app was basically have Slopes and all its paid
functions for free"**, accuracy was **"maybe better if possible"** added while planning, and
**"eventually I would like for my friends and family to have it too."** Three consequences, and
they are not small:

1. **S8's audit was written as if accuracy were the premise. It never was.** Tying Slopes costs
   the marketing line and costs nothing on the goal. Stop treating it as a strategic problem —
   while still obeying R20 and not claiming accuracy we don't have.
2. **The target list is literally Slopes' Premium feature list:** run-by-run stats ✅ (S9), run
   comparison, speed heatmaps, offline maps, 3D. **S8 cut maps on the wrong test** — that Slopes
   gives *trail maps* away free is irrelevant when the goal is what Slopes *charges* for.
3. **"Friends and family" makes D3 (where we test next) load-bearing.** Everything we know comes
   from one resort over two sessions, and Portillo's platters already broke the detector once.

**D5 is answered too: yes to the $99 program, after Yomi ships.** So the 7-day fuse is a temporary
cost with an end date, and TestFlight is blocked on Yomi rather than on a decision.

### 🧊 Still true from the S8 audit (`RESEARCH.md` §13.5)

**"Slopes paywalls maps" was false** — the free tier has trail maps. And the real paid line in this
category is **analysis**: Slopes' free tier gives a daily summary only. That is still the sharpest
description of what we're building, and per-run detail — the first item on it — shipped in S9.

**The one thing with a deadline:** Martin leaves Portillo ~2026-09-07 and there is no snow within
reach for ~3 months after. Desk work has unlimited runway; **capture does not**. And the recorder
captures **no accelerometer and no gyroscope** — `TrackRecorder` never touches `CMMotionManager` —
which permanently forecloses every "how you ski" question (turns, carving, airtime) for any day we
record without it. See §13.5 for the sequencing that doesn't risk tomorrow's build.

**Open decision D7 — what is this project for?** Personal tool, narrow data-ownership product, the
IMU axis, or stop. The plan below quietly assumes "product". Nobody has actually decided.

### 🛠 Work that needs no snow, no sensors, and no answer to D7

Martin asked what else there is besides location, speed and measurement. This is the list, ranked.
All of it is desk work; none of it depends on the weather or on what the project turns out to be.

**1. ~~Get a session off the phone without a Mac.~~ ✅ It was already built — S9 read the file and
found it.** `SessionsView` has shipped a per-row `ShareLink` **and** a "Share all" toolbar item
since the S1–S2 commit (`5b1aacc`), so AirDrop / WhatsApp / Files have never actually required a
cable. S8 ranked this urgent from memory of the screen rather than from the source, and lost an
item to it. **R21:** before ranking work, open the file — this list is written about code, not
about recollection of code. Still true and worth knowing: **IMU files are ~5.7 MB/hour, so a 3 h
day is ~20 MB** — fine for AirDrop, painful for email.

**2. ~~A session detail screen.~~ ✅ Done in S9 — `SessionDetailView` + `SessionReplay`.**
Tapping a row replays the file through the same `LiveMetrics` that ran live and shows the three
headline numbers, a per-run list (drop, elapsed window, vertical rate), and a **RECORDING QUALITY**
block — Doppler ratio, median hAcc, fixes the speed gate rejected, pre-start cached fixes, IMU
coverage and longest motion gap. The quality block is the part that matters most: it is what makes
a bad day read as a bad day rather than as a plausible number. Parsing runs on a detached task; a
3 h file is ~35,000 lines. `Tools/replay.swift` now calls `SessionReplay` instead of keeping its
own parse loop, so the harness checks the phone's actual path (R12a). Verified identical to
`analyze.py` on both fixtures — 3342/2773 fixes, ±8.0/±7.9 m, 905/462 m, 4/3 runs, 12/24 m
sub-threshold. **Not yet seen on a phone.**

**3. ~~There is not a single automated test in the project.~~ ✅ Done in S9 — 19 tests, `VerticalTests`.**
Run them with **`Tools/test.sh`** (simulator; ~30 s cold, 5 s warm). Three suites: the segmentation
and gating rules each named after the session that earned them, the two Portillo days as golden
numbers, and the crash path — `SessionRecovery`'s 6-hour window and `SampleWriter` reopening a file
with a truncated final line. Synthetic session files are written **through the real `SampleWriter`
and the real sample structs**, because a fixture that isn't byte-identical to production output
only tests the fixture (S4). **The suite was mutation-checked, not just run**: setting
`mergeAscentM` to 1.0 re-introduces the exact S5 bug and fails three tests, including the day total.

**4. Run comparison — a Slopes Premium feature, and the cheapest one left. ⬅ do this next.**
Re-ranked in S9 by D7's answer: the goal is Slopes' paid features, and this one needs no map, no
new sensor and no new parsing — `SessionReplay` already returns every run of every day. Compare
runs within a day, and the same run across days. It is the natural second screen after
`SessionDetailView` and it is worth more than anything else on this list per hour spent.

**5. Port the detector into the app** (`Tools/detect.py` → Swift). `LiveMetrics` already segments
*runs*; what `detect.py` adds is **lifts**, and the alternating lift/run timeline that complains
when a descent has no ride before it. It is also the precondition for **R19**: the four tag buttons
come out of the UI once detection works, and Martin flagged them as scaffolding back in S4 — they
must be gone before anyone but him uses the app.

**6. GPX export.** Named in `RESEARCH.md` §2.2 as the switching-cost lever, but it is worth more
than that here: it makes a recording usable in Strava, Slopes, or anything else, which is the whole
"your data is a file you own" claim made real rather than asserted.

**7. Speed heatmap** — Slopes Premium, and back on the list after D7 (§13.6). Needs a map view and
a track coloured by the gated Doppler speed, which is already logged per fix. The map is the work;
the data is done.

**8. A design pass.** `ContentView` says "deliberately ugly" at the top and it is right to have
waited. But sunlight readability and glove-sized targets are *functional* requirements on a
mountain, not polish — and once friends and family have it, "deliberately ugly" stops being a
defensible answer. The `design` skill is installed.

**Off the list, with reasons:** naming (D6, don't spend cycles); 3D (D4 — a *deferred target* now,
not out of scope, and still blocked on the real MapKit finding from S5); offline maps (a Slopes
Premium feature and therefore a target, but the expensive one, with an ODbL licensing story to
settle first — §7.1). **The $99 program is no longer a "why bother": D5 is yes, after Yomi.**

### S7 in four lines

1. **The build is on the phone.** Rebuilt and installed 2026-09-01 16:17, launched, process
   confirmed running. **The provisioning fuse now dies ~2026-09-08**, past the end of the trip.
   **Be precise about what is and isn't proven here:** Martin skied two full sessions with the app
   today, so the recording path — START, background capture, STOP, file on disk — is proven on
   device by a real ski day, twice. But he skied them on the **2026-08-31 build**. The S6/S7 screen
   (VERTICAL / TOP SPEED / RUNS, and now trimmed run durations) only reached the phone at 16:17,
   *after* the skiing. So what is untested is the new **screen**, not the recorder, and the failure
   it can produce is a wrong number displayed, never a lost recording — `LiveMetrics` only reads
   samples already written. Two minutes with the app would still retire it.
2. **Carve's real day number is 1,625 m, not the 1,509 we had — +18.9% over us, not +10.4%.** Its
   saved logbook entry and its live screen disagree by 116 m on the identical recording. Slopes'
   saved day is 1,380 m, **+1.0%** over our 1,367 — a third independent tie. `RESEARCH.md` §5.1.3.
3. **The detector was missing short surface tows.** A 38 s, +36 m platter in session 2 fell under a
   60 s minimum and left a descent with no ride before it. Fixed, session 1 unchanged, and
   `detect.py` now prints the day as an alternating lift/run timeline that complains when gravity
   is violated — a check that works with no hand tags, which is what we now have.
4. **Slopes handed us a free grade on our own detector:** lift time 40 min vs our 37.4 (good), ski
   time 41 min vs our 54.5 (bad — our runs counted standing at the top as run time). **Fixed, and
   the build on the phone has the fix**: runs now start when the skier does, the day is 43.7 min,
   and `replay.sh` proves the app's `LiveMetrics` and `analyze.py` agree to the decimal. Vertical
   never moved (905 and 462 unchanged) — it is measured top-to-bottom.

### ⬅ Asks for Martin — batched, all small

**Tomorrow morning (2026-09-02) Martin skis again, and will add Strava** — a third app, and the
first with a large user base and a published elevation methodology (see A21 before comparing: check
whether it barometer-measures or DEM-corrects an iOS ski activity, and do not assume).

**How he actually uses the competitors, learned S7:** Slopes and Carve both have **pause**, and
pause is what you press for a break — **stop** means done for the day. On 2026-09-01 he paused
through the 11:30–12:39 break and stopped after lunch. Vertical has no pause and does not need one:
it writes raw samples and segments offline, so a recorded break costs nothing and is worth having.

**⭐ The one high-value new test — it costs two screenshots.** When pausing Carve for a break,
screenshot its vertical **immediately before pausing** and **immediately after, before resuming**.
If the number grew while the app was paused, that is the mechanism behind A20 measured directly,
and "its pause accumulates vertical" is a far stronger finding than any total-vs-total delta.
Same pair for Slopes if it is no trouble — we expect Slopes not to move, which is the control.

1. **On Vertical: press START once, at the very beginning, and do not press STOP until you are done
   for the day** — through every break. This single habit answers three open questions at once and
   costs nothing:
   - **Battery (open since S5).** `batteryLevel` moves in 5% steps and no session has been long
     enough to see more than one, so every %/h figure in these docs has been retracted. A 3 h+
     continuous recording is the only thing that fixes it.
   - **A20 / what a break costs.** Slopes booked 2026-09-01's break as rest with no vertical; what
     Carve did with it is the open question above. We have never recorded a break at all, so the
     ~37 m we attribute to it is a residual, not a measurement. One recorded break — on our side,
     raw — makes it a measurement and gives the pause test something to be compared against.
   - **The auto-detector's hardest case.** A long stationary break is exactly what a lift/run
     detector must *not* mistake for anything, and we have no example of one.
2. **Screenshot Slopes, Carve and Strava at the end of the day, from the saved day record** — the
   Logbook entry, not the live Record screen. R12b exists because the two disagreed by 7.7%. Press
   **stop** before screenshotting so what is captured is the finished record.
3. **A18 still needs a burst-free day.** Nothing special to do; if the day happens to contain no
   multipath burst, the top-speed question settles itself from the screenshot in #2.
4. **Optional, two minutes:** open the app before skiing and check the new VERTICAL / TOP SPEED /
   RUNS tiles look sane. Today's two sessions were recorded on the older build, so the recorder is
   proven but this screen has never been looked at on the device.

---

## The S6 handoff, still current below this line

**The GPS question is answered green and the three-app head-to-head is done.** Read
`RESEARCH.md` §5.1.1 first — it is now the most important page in the repo, because it is the only
place where the thesis meets measured numbers instead of forum posts. The short version:

- **Slopes is accurate.** 912 m to our 905 m over the whole morning — **0.8%**. Run 1: 415 vs 407 m
  (2.0%), 53.8 vs 52.6 km/h (2.3%). The "everyone overestimates 5–10%" folklore does not describe
  Slopes. **Accuracy is a tie against Slopes, not a wedge.**
- **Carve overstates vertical by +10.1%** (996 m vs 905 m over the same four descents), and its
  headline top speed of **66.8 km/h is, to the decimal, a corrupted sample in our own file** — a
  four-second multipath burst at 11:28:59 with hAcc at 22 m and a 42.5 m one-second position jump.
  **Against Carve the accuracy gap is real and demonstrable.**
- **Two bugs of our own** came out of the comparison, both now fixed: the speed gate used the wrong
  field, and run segmentation was silently deleting vertical (see S5 below).

**S5 also opened `RESEARCH.md` §13, the assumption register, and `WORKFLOW.md`, the rules of
process.** Between them they replaced three false claims that had survived five sessions. Read §13
before repeating any number about a competitor, and R1–R4 before writing a new one down.

### The plan, in order

**✅ Done in S6: session 2 is pulled, analysed, and committed** as
`Data/fixtures/2026-09-01_portillo_s2.jsonl` (the session-1 fixture was renamed `_s1` to match).
Written up in **`RESEARCH.md` §5.1.2**. Both S5 conclusions replicated on an independent day-half —
**Slopes +1.2%, ~~Carve +10.4%~~** on the 1,367 m day total (**S7: against the apps' *saved* day
records it is Slopes +1.0% and Carve +18.9%** — the S6 pair came from live screens, see §5.1.3) —
and fix quality replicated too (0.97 Hz,
hAcc ±7.9 m, Doppler on 2,768/2,773). The detector found exactly the 3 runs the screenshot
subtraction had predicted, with one hand tag in the whole session.

**⬅ THE ONE THING TO GET FROM THE NEXT RECORDING — assumption A18.** Slopes' day top speed is
**67.2 km/h** and it is *either* the 11:28:59 multipath burst (which Carve demonstrably published)
*or* our clean 64.7 peak read +3.9% high. **A session with no multipath burst settles it**: if
Slopes still reads 2–4% over our accuracy-gated Doppler, it is systematically ungated; if it lands
on our number, then it published the glitch and the top-speed wedge applies to *both* competitors,
not just Carve. This costs nothing but recording — see §5.1.2. Compare afterwards with:
`Tools/analyze.py <file>` → the "MAX SPEED" block, against Slopes' Today's Stats top speed.

**✅ DONE IN S7 — the phone was plugged in at 16:17 and this was run.** Build succeeded,
`UIBackgroundModes = ["location"]` verified in the **built** Info.plist with `plutil -p` (R14,
R14a), installed, launched, process confirmed alive from the new bundle. **The fuse now runs to
~2026-09-08.** Kept below because it is the recipe every future reinstall uses:

```sh
cd ~/Desktop/Projects/Vertical/iOS
xcodebuild -project Vertical.xcodeproj -scheme Vertical -configuration Debug \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates build
xcrun devicectl device install app --device 270B9EDA-7298-5206-9E67-71C0E8F60CF6 \
  ~/Library/Developer/Xcode/DerivedData/Vertical-hhltzbilrpjrdxgsdbemtrfnvlhq/Build/Products/Debug-iphoneos/Vertical.app
```

It **resets the 7-day provisioning fuse** (S7 reset it to ~2026-09-08, just past the end of the
trip) *and* ships the S6 screen, which shows accuracy-gated top speed and run-segmented vertical
live — the three numbers that get compared against Slopes on the mountain, without a file pull.

**Then smoke-test it before skiing with it** (R16 — it has never run on the device): launch, press
START, confirm no yellow background-mode warning, walk ~2 minutes, watch GPS FIXES climb, press
STOP, and check the session appears in Sessions. `LiveMetrics` is additive and off the write path —
it only reads samples already written — so the worst realistic failure is a wrong number on screen,
not a lost recording. But that is an argument, not a test.

**Then, while Martin is still at Portillo (until ~2026-09-07) — this window does not come back:**

1. **Record more days, and record a long one.** S6 made the competitor deltas n=2, but the
   multipath glitch is still a single sample and **battery is still entirely unmeasured** —
   `batteryLevel` moves in 5% steps and no session has been long enough to see more than one, so
   the "5.5 %/h" that has been in these docs since S5 was never a measurement. **A single 3 h+
   recording fixes that**, and it is the only outstanding question that just needs time on the
   mountain rather than thought at the desk.
2. **Answer the five questions in "Asks for Martin" below.** They are batched deliberately; three of
   them take under a minute each and two of them are decisions only he can make.
3. **Reinstall the build before the last ski day** — the 7-day profile expires ~2026-09-08 and D5
   is deferred, so this is now a scheduled chore, not a contingency. See the box below.

**Next, at the desk:**

4. **Phase 1 auto-detection.** The detector already matched the hand tags to 16 s at the top and 2 s
   at the bottom of run 1 — closer than expected. The work is lift detection (Portillo's
   *va-et-vient* platters are the hard case) and validating against every day we have, not just the
   first.
5. ~~**Fold the S5 analyzer fixes into the app itself.**~~ **Done S6** —
   `iOS/Vertical/Recorder/LiveMetrics.swift` is the streaming port of the hAcc speed gate and
   run segmentation with the descent merge, wired into `TrackRecorder` and shown on the main
   screen as VERTICAL / TOP SPEED / RUNS with the naive figure under each. `Tools/replay.sh` runs
   that exact source over the fixtures and it agrees with `analyze.py` to the metre and the decimal
   on both. **Built, replay-verified, not yet run on the device** — needs an install (below).
6. **Phase 2 maps.** Unchanged and unblocked — MapKit in 2D is fine, OpenSkiMap data is alive
   (§13, A7). Read the three licences in A8 before shipping any data.

**Deferred with a reason, not by drift:** 3D (Phase 3, cut — see below), Apple Watch, social.

### Decisions — answered by Martin, 2026-09-01

| # | Decision | Answer |
|---|---|---|
| **D1** | Platform | **iOS only.** Settled, not provisional. |
| **D4** | 3D in v1 | **Postponed.** Not killed — revisit when MapLibre ships iOS terrain, or when there's appetite for a Metal-shaped project. Phase 3 stays written down so the option is costed rather than forgotten. **Note it is a Slopes Premium feature, so D7 puts it back on the target list — see §13.6.** |
| **D5** | $99 Apple Developer Program | **Yes — after Yomi ships** (answered S9). Not "eventually": a real trigger with a real dependency. Until then, free provisioning and its 7-day fuse; TestFlight is unreachable, so "friends and family" is blocked on Yomi, not on this project. |
| **D6** | Name | **"Vertical" stays a placeholder.** Don't spend cycles on naming; revisit before anything is published. |
| **D7** | **What is this project for?** (opened S8) | ✅ **ANSWERED S9 — closest to (b), stated in Martin's own words: "have Slopes and all its paid functions for free," and "eventually I would like for my friends and family to have it too."** Accuracy was a *secondary* goal added while planning — "make it more accurate and maybe better if possible" — not the premise. Not a playground, not primarily the IMU axis, and not stop. **This changes the target list; read §13.6 below.** |
| **A5** | Does Carve use the barometer? | **No** — absent from Motion & Fitness after a real 1 h 05 m recording. Its pipeline is now fully characterised (`RESEARCH.md` §2.2). |

#### §13.6 — What D7's answer actually changes (S9)

**1. The S8 audit was a smaller blow than it was written up as.** It concluded "the thesis is half
falsified" because accuracy was believed to be the load-bearing claim — S4 wrote down that it was
"the ONLY differentiator". **That was our framing, not Martin's.** His goal has been *Slopes'
paid features for free* since the beginning; accuracy was an opportunistic extra. So the finding
that we tie Slopes on accuracy costs the *marketing line* and costs nothing at all on the goal.
Keep R20 — don't claim accuracy we don't have — and stop treating the tie as a strategic problem.

**2. The audit cut features on the wrong criterion, and two come back.** S8 cut maps because
"Slopes gives trail maps away free". True, and irrelevant: the goal is what Slopes *charges* for.
Slopes Premium gates **run-by-run stats, speed heatmaps, offline maps, 3D, and run comparison** —
so that list *is* the target list.

| Slopes Premium feature | Status |
|---|---|
| Run-by-run stats | ✅ **shipped S9** (`SessionDetailView`) |
| Run comparison | Not built. Cheap — the data is already there and it needs no map. **Next.** |
| Speed heatmap | Not built. Needs a map view plus a coloured track; the per-fix speed is already logged and gated. |
| Offline maps | Not built. The expensive one, and the one with a real licensing story (OpenSkiMap/ODbL, §7.1). |
| 3D replay | D4, postponed on a real technical finding (MapKit flattens on custom overlays, S5). Still the right call — but it is now a *deferred target*, not out of scope. |

**3. "Friends and family" adds a requirement nothing has tested: other mountains.** Every number
in this project comes from one resort over two sessions. Portillo's va-et-vient platters already
broke the detector once. Before anyone else uses this, the detector needs days from resorts we have
never seen — which is a **D3** question (where we test next) that just became load-bearing.

**4. The three-app comparison keeps its purpose.** It is no longer evidence for an accuracy claim;
it is the **specification**. Slopes is what we are trying to match feature-for-feature and, on
tomorrow's session, Strava too. Keep running it.

D2 (backend/social) and D3 (where we test next) are still open, but neither blocks current work:
everything in Phase 1 and Phase 2 is on-device, and the test site is Portillo until ~2026-09-07.

### ⚠️ The standing cost of D5 until Yomi ships — read this before the trip ends

**D5 is answered: Martin pays for the Apple Developer Program once Yomi is finished (S9).** So
everything below is a cost with an end date rather than a ceiling — but the end date belongs to
another project, and none of it is fixable from a chairlift in the meantime.

A free account issues **7-day provisioning profiles**. The current build was installed
**2026-09-01 20:03** (S9), so it **stops launching around 2026-09-08** — just after the week Martin
stops skiing. Consequences to manage rather than discover:

- **Reinstall before the trip's last ski day, not after the app dies.** A rebuild + `devicectl
  install` resets the clock for another 7 days and takes minutes *when the phone is at the Mac*. It
  is not something that can be fixed from a chairlift.
- **Every future recording session has this same 7-day fuse.** Northern season starts in ~3 months;
  if Yomi has not shipped by then, every ski day begins with a reinstall at a Mac.
- **TestFlight and the App Store are unavailable**, so "friends and family" — the thing D7 says
  this project is for — is **blocked on Yomi shipping**, via D5. Worth knowing when weighing work
  on this project against work on that one.
- `mobile-mcp` stays unusable on the device for the same reason (`RESEARCH.md` §13, A14).

### Pulling and analysing a day (the routine, now that it works)

```sh
xcrun devicectl device copy from --device 270B9EDA-7298-5206-9E67-71C0E8F60CF6 \
  --domain-type appDataContainer --domain-identifier com.gamberg.vertical \
  --source Documents/Sessions --destination ~/Desktop/Projects/Vertical/Data/pull-$(date +%Y%m%d)
~/Desktop/Projects/Vertical/Tools/analyze.py <the new file>.jsonl
```

Read, in this order: **the Doppler ratio** (the whole max-speed approach depends on it), then the
GPS fix rate, then vertical run-segmented vs. the naive methods, then the battery notes, then the
hand-placed tags. If the report says the session auto-resumed, that means the app died and
recovered — note the gap and why (battery? thermal? jetsam?).

**Always look at the seconds around the reported max speed before believing it** (S5). The
analyzer's headline number is now hAcc-gated, but the honest check is still by eye: a real peak is
a smooth 10–20 s ramp with hAcc steady under 15 m, and position-differentiation agrees with Doppler
to within about 10%. A glitch is a step change with hAcc degrading past 20 m and a position jump
that implies a speed no skier reaches. On 2026-09-01 the day contained one of each.

Two test files from the S4 verification are on the phone and will show up in the pull:
`2026-08-31_230847_TESTRESU.jsonl` and `2026-08-31_231638_TESTRES2.jsonl`. **Both are synthetic —
delete them.** They are closed with an `end` record so they cannot auto-resume.

### If the build has expired

Free provisioning lasts 7 days; reinstalled **2026-08-31 23:24**, so it dies around
**2026-09-08**. If the app won't launch, rebuild + reinstall:
   ```sh
   cd ~/Desktop/Projects/Vertical/iOS
   xcodebuild -project Vertical.xcodeproj -scheme Vertical -configuration Debug \
     -destination 'generic/platform=iOS' -allowProvisioningUpdates build
   xcrun devicectl device install app --device 270B9EDA-7298-5206-9E67-71C0E8F60CF6 \
     ~/Library/Developer/Xcode/DerivedData/Vertical-hhltzbilrpjrdxgsdbemtrfnvlhq/Build/Products/Debug-iphoneos/Vertical.app
   ```
Note the destination must be a **file path, not a directory**, when copying a single file —
`copy from ... --destination somedir/` fails with a bare "Is a directory" I/O error.

### Verified working (measured on Martin's iPhone 17, not assumed)

- **Auto-resume after the app is killed mid-session** (S4). Verified by planting an interrupted
  session with a torn final line, `SIGKILL`ing the process and relaunching: it reopened the same
  file on the same `dt` timeline, reported a 301 s gap, and restored the sample counts. A
  cleanly-closed session is correctly left alone.

- Recording, clean session close, files on disk, `devicectl` pull path.
- Location authorization is **Always** (`auth=3` in the log).
- **The barometer is excellent.** 184 samples at ~0.9 Hz, **zero gaps > 5 s**.
  **Noise floor: 0.85 m total drift over 3.2 min stationary.** With 3 m hysteresis the analyzer
  reports exactly 0 m of phantom descent.
- Barometric pressure read 72.359 kPa ≈ **2,880 m, which matches Portillo's base elevation** — so
  the sensor is not just stable but correct.
- Over the same stationary 3.2 min, **GPS altitude accumulated 10 m of phantom vertical.** That
  ratio, on real hardware, is the project thesis in miniature.

### ✅ ANSWERED — GPS health outdoors (2026-09-01)

The indoor smoke test looked alarming (0.34 Hz, Doppler valid on 8 of 68 fixes, hAcc ±12 m). All
of it was the building. Outdoors, on the first chairlift:

- **GPS 1.00 Hz**, 3,342 fixes over 56 min, no gaps.
- **Doppler valid on 3,342/3,342 fixes.** The field the entire max-speed approach rests on works.
- hAcc **median ±8 m, p90 ±12.3 m**, 99.2% of fixes usable — with one four-second multipath burst
  where it degraded past 30 m, which is exactly the kind of event the gate now catches.
- Battery: one 5-point step in 55 min. **`batteryLevel` is quantised to 5%**, so the honest
  reading is **0–11 %/h** and the "5.5%/h → 38% a day" this once said is not a measurement
  (S6). A battery number needs a session of 3 h or more.

The `DOPPLER` tile has served its purpose and can come out of the UI whenever the recording screen
is next touched.

### Design correction from Martin (2026-08-31) — important

> "on slope, you do not need to press 'top' and 'bottom' or lift. it identifies them
> automatically. You only press start."

He is right, and the shipped app must work that way. **The tag buttons are temporary scaffolding,
not the product** — they exist only to produce hand-labelled ground truth for building and
validating the auto-detector. Tags are **optional** for him and must never interfere with skiing.
Once run/lift detection is accurate, remove the buttons from the UI.

This was my framing error, not his misunderstanding — worth not repeating.

### Also from Martin: Strava's 3D map is a design reference

He likes Strava's map and specifically its 3D. Relevant to the §9.1 renderer spike — and note
Strava absorbed FATMAP's technology (see `RESEARCH.md` §3.3). Worth looking at directly before
choosing an approach.

### Device facts

| | |
|---|---|
| Device | iPhone 17 (`iPhone18,3`), iOS 26.5.2 — dual-band L1+L5 GNSS + barometer |
| devicectl id | `270B9EDA-7298-5206-9E67-71C0E8F60CF6` |
| Team | `F9R33MN82P` (Personal Team, tintin@gamberg.com.ar) |
| Bundle | `com.gamberg.vertical` |
| Repo | https://github.com/PacoDealer/Ski-app |

---

## Current state — S1 (2026-08-31)

**Research only. No code, no repo, no Xcode project yet.**

What S1 established:
- Full competitive landscape mapped (`RESEARCH.md` §2).
- **8 of Slopes' 10 premium features are free to build with no running cost** (§8).
- **Trail maps are solved** — OpenSkiMap ships 6,992 ski areas / 96,693 runs as daily GeoJSON +
  vector tiles under ODbL. (The "~140× Slopes" comparison this line used to carry was
  withdrawn in S5 — see `RESEARCH.md` §13, A2.)
- **Live lift status is solved** — Liftie (BSD-3, actively maintained) with a public REST API. This
  was the feature I initially assessed as the expensive one; it isn't.
- **The wedge is accuracy, not features** — the whole category has documented 5–10% vertical
  overestimation and ~10 mph max-speed error, and nobody has fixed it (§5.1, §10).
- **One real technical blocker found**: MapLibre Native has no 3D terrain on iOS yet (§9.1). This
  invalidates the obvious "just use MapLibre" plan for the 3D feature and needs a spike.
- Two features to cut from v1: **AR replay** (won't georeference on a mountain, lowest value) and
  **Apple Watch** (a reliability liability — it's where Slopes' 1★ reviews come from).

---

## Blocked on Martin — decide before Phase 1

These are in `RESEARCH.md` §11 in full. The three that actually gate work:

**Updated S5 (2026-09-01) — D1, D4, D5 and D6 are answered; see "Decisions" in START HERE.**

| # | Decision | Status |
|---|---|---|
| D1 | iOS-only first? | ✅ **Decided: iOS only.** |
| D2 | Social/backend in scope? | ⏳ Open, but not blocking — all of Phase 1 and Phase 2 is on-device. |
| D3 | Where + when is the first real snow test? | ✅ Answered by events: Portillo, and it already happened (2026-09-01). Where the *next* one is remains open. |
| D4 | 3D renderer | ✅ **Postponed out of v1.** |
| D5 | $99 Apple Developer Program | ⏳ **Deferred by Martin** — "eventually". Carries a standing cost; see START HERE. |
| D6 | Name | ⏳ "Vertical" stays a placeholder by choice. |

---

## What we can actually claim (S5 — read before writing any copy)

The pitch in `CLAUDE.md` was written against forum folklore. Now that three apps have recorded the
same morning, here is what survives contact with data. **Never claim more than this without a new
measurement.**

| Against | True claim | Claim we must NOT make |
|---|---|---|
| **Slopes** ($34.99/yr) | Same numbers, free — measured at **0.8%, 1.2% and 1.0%** on vertical across two sessions and the saved day total, ~2% on run-1 top speed. Plus **run-by-run stats free** (Slopes' free tier gives a *daily summary only*; per-run detail, speed heatmaps, offline maps, 3D and run comparison are all Premium), and your raw track is a file you can read. | That Slopes is inaccurate. It isn't. **And do not say "maps aren't paywalled" — S8 checked, and Slopes' free tier includes resort trail maps.** What Premium gates is the *analysis*, not the map. |
| **Carve** (free) | **+10.1% vertical** on the same four descents, **+18.9% on the saved whole day** (S7 — the two figures are different questions: what its pipeline costs while skiing, and what a real day with a lunch break costs). And it published a **GPS multipath glitch as the day's top speed** — a number we can point at, second by second, in our own raw file. | That Carve is a toy. It ships more features than we do today. Also: don't quote +18.9% as if it were the skiing error, or +10.1% as if it were what a user sees at the end of the day. Quote both, labelled. |
| **The category** | Naive methods cannot reject a bad second, and one bad second owns the day's headline number. We can show the second. | "+136% more accurate." That ratio is glitch-vs-gate; on clean data the same comparison is +9%. See WORKFLOW R12. |

**The honest one-line positioning:** *as accurate as the app people pay for, free, worldwide, and
it shows its work.* "Accuracy" is a wedge against the free competitor and a **tie** against the paid
leader — and a tie against a $34.99/yr product, given away, is still a reason to switch.

**What is n=1 and must be said as such:** all of it. One morning, one mountain, one phone
(`WORKFLOW.md` R5).

---

## Phase 0 — Foundations

- [x] `git init`, GitHub repo, Xcode project, `CLAUDE.md` — done S2–S3.
- [ ] Settle D1–D3 above; pick a real name.
- [ ] **D5 (new, S5): buy the $99 Apple Developer Program, or accept the ceiling.** A free account
      gives 7-day profiles, 3 devices, no TestFlight and no App Store (`RESEARCH.md` §13, A14). It
      is already costing us: the build dies ~2026-09-08, and every reinstall is a manual
      cycle through Martin. This is the cheapest blocker on the board to clear.
- [ ] **Install and actually use the competitors** — Slopes free tier, Ski Tracks, Open Ski Map.
      Yomi's S114 lesson: hands-on surfaces what reading never does.
- [ ] Re-run community research in-season (see `CLAUDE.md` → Tooling → `last30days`).

## Phase 1 — The recording engine (the whole bet lives here)

This is not the boring part. This is the product.

**Done as of S2–S3:** background recording with correct entitlements, crash-safe append-only
store, raw capture of every CoreLocation + barometer field, live diagnostics, on-device install.
**Not started:** everything below that isn't ticked — all the actual maths.

> **Auto-detection is a hard requirement, not a nice-to-have.** The user presses START and pockets
> the phone; the app works out lifts and runs by itself. Slopes does this and it is the baseline
> expectation for the category. The tag buttons currently in the UI are scaffolding for building
> that detector and must be removed once it works.

- [ ] `CoreLocation` background recording, correct entitlements + privacy manifest.
- [ ] **Crash-safe append-only track store.** Every sample hits disk as it arrives. A kill, crash,
      or dead battery loses one sample, and recovery on next launch is silent — never a "resume or
      finish?" prompt. (Directly targets the 1★ reviews in `RESEARCH.md` §5.2.)
- [ ] **Barometric + GPS altitude fusion** (`CMAltimeter`), drift-corrected over long windows so
      weather pressure change doesn't inflate vertical.
- [ ] **Doppler max speed** from `CLLocation.speed` with `speedAccuracy` gating. Never differentiate
      positions. (Targets the "+10 mph" bug.)
- [~] **Automatic lift vs. run segmentation** — **prototyped S5 in `Tools/detect.py`, scoring
      every hand tag on the first day** (see below). Deliberately physics-only so far: no
      `aerialway` proximity, because a detector that needs the piste map can't work at a resort OSM
      hasn't mapped and can't be validated against the one tagged day we have. Add the map later as
      confirmation, not as a dependency. Still to do: port to Swift, validate on more days, and
      check Portillo's *va-et-vient* slingshot platters, which won't look like a chairlift.
- [ ] **Adaptive sampling** — high rate on descent, low on lift. Fixes both battery *and* the
      "faster skiing records less vertical" artefact at once.
- [ ] Per-run stats; average speed over **descent time only**, excluding lifts and lift lines.
- [ ] **Accuracy harness** — replay recorded GPX/raw-sample fixtures through the pipeline in tests,
      so accuracy work is measurable and can't silently regress. Build this *with* the engine.

**Phase 1 exit criterion:** a real recorded ski day whose vertical and max speed we can defend
against a known reference, with the error quantified.

## Phase 2 — Maps

- [ ] Ingest OpenSkiMap data; per-resort offline packs (a resort is a few MB).
- [ ] 2D vector map with runs coloured by difficulty, lifts, run names — **all unpaywalled**.
- [ ] Search trails by name / difficulty.
- [ ] ODbL attribution surface, correctly placed.
- [ ] Track drawn over the map; run replay with speed heatmap; scrubber.

## Phase 3 — 3D — **cut from v1** (S5)

**The S4 narrowing was wrong and is withdrawn.** MapKit flattens the terrain the moment any custom
overlay is added; only `MKDirections` routes follow it (`RESEARCH.md` §9.1, S5 amendment, quoting
WWDC22 session 10035). So MapKit gives us 3D terrain *or* our track, never both — and our track on
the terrain is the entire feature.

What that leaves:

- **MapLibre Native** — terrain in active development, nothing shipped. Watch it; don't plan on it.
- **SceneKit/RealityKit + DEM mesh** — the front-runner by elimination, and the terrain source is
  now solved and free: **Mapterhorn** global Terrain-RGB, CC BY 4.0 (`RESEARCH.md` §13, A16). The
  unsolved piece is the **satellite imagery drape**, which needs its own licensed source — Apple's
  imagery cannot be lifted out of MapKit into our own scene.
- **MapLibre GL JS in a `WKWebView`** — works today, at a real UX cost for a glove-panned map.

**Decision (D4), recommended: cut 3D from v1 and say so publicly.** It is now known-expensive
rather than assumed-cheap, nothing else depends on it, and the accuracy work is worth more. Revisit
when MapLibre ships terrain, or when there is appetite for a Metal-shaped project.

- [ ] Martin to confirm the cut (it is his call — Strava's 3D is a design reference he likes).
- [ ] If confirmed: state "2D maps in v1" openly rather than letting it read as a missing feature.
- [ ] Park a watch on MapLibre Native's terrain milestone.

## Phase 4 — Lift status

- [ ] **Contact the Liftie maintainer before pointing anything at `liftie.info`.** Non-negotiable.
- [ ] Self-host Liftie or consume the API; contribute resort adapters upstream.
- [ ] Be honest in the UI about which resorts have live data and how stale it is. Never render a
      stale report as if it were live.
- [ ] Grooming: partial coverage at best. Treat as best-effort, not a promise.

## Phase 5 — Retention

- [ ] Season + lifetime totals (the actual retention hook per `RESEARCH.md` §4).
- [ ] End-of-season recap.
- [ ] Run comparisons: you vs. you.
- [ ] Sunlight-readable, glove-usable design pass. High contrast is a *functional* requirement here.

## Backlog — unserved requests worth stealing (`RESEARCH.md` §6)

- Gear quiver tracking (log skis/bindings/boots per day, days-on-gear, wax/tune reminders) — asked for, served by nobody
- Average run pitch/angle as a first-class stat
- Trail/lift **closures**, not just openings
- Turn/edge-change count from the gyroscope — genuinely novel
- **Show error bars on stats.** A category first, and it makes the accuracy work legible to users
- **GPX import from other ski apps** — stolen from Carve (`RESEARCH.md` §2.2). Cheap, and it means
  a switcher arrives with their history instead of an empty season total

## Explicitly out of scope for v1

- AR replay — `ARGeoTrackingConfiguration` doesn't cover ski resorts; lowest value on the list
- Apple Watch — reliability liability, see `RESEARCH.md` §9.5
- Social graph / friend-finding — network effects favour the incumbent, and Slopes gives it away free anyway
- Competing on human support responsiveness — a 12-person company wins that; don't play

---

## Session log

### S10 — 2026-09-02 · the walk test came back green, and gave us the control we never ran

**The IMU works in the background, and it is now observed rather than inferred.** Martin recorded
**81 minutes** over dinner with the phone locked and pocketed — far longer than the 2 minutes
asked for, which is what makes it evidence. `2026-09-01_portillo_stationary.jsonl`:

- **122,358 motion samples in 4,898 batches. Effective 25.1 Hz against a nominal 25. Coverage
  100%. No gap over 2 s across the whole 81 minutes.** The S8 note that background delivery for
  device motion was *inferred from `CMAltimeter` behaving the same way* can be closed: it is
  measured. **The IMU is cleared to ski with.**

**And then the file turned out to be the negative control this project has never run.** Every
accuracy claim so far has had the form "our number is close to Slopes' number". None has had the
form "our number is **zero** when nothing happened". A phone sitting still on a table for 81
minutes is exactly that test, and the answer is stark:

| Method, same 81 stationary minutes | Vertical reported |
|---|---|
| **Ours — barometric, run-segmented** | **0 m** |
| Barometric, summed deltas | 22 m |
| GPS altitude, 10 m hysteresis | 147 m |
| **GPS altitude, 3 m hysteresis — our reproduction of Carve's pipeline (S6)** | **674 m** |
| GPS altitude, summed deltas | 1,162 m |

Zero runs, zero sub-threshold metres, gated top speed 2.5 km/h. **Say this carefully (R20):** it is
*indoors*, where GPS is at its worst — 0.44 Hz here against 1.00 Hz outdoors, hAcc median ±13.8 m,
and only 278 of 2,132 fixes carrying valid Doppler. So 674 m is an **upper bound on the failure
mode, not a prediction of Carve's error while skiing.** What it does establish, and could not be
established from any ski day, is *the direction and the mechanism* — and that our own method
reports nothing at all when nothing happens.

**It is also independent evidence for A20.** Carve's vertical grew **116 m across a paused lunch**
on 2026-09-01, which we could only treat as an unexplained residual. A pipeline that accrues
hundreds of metres an hour from a stationary phone makes "Carve's pause freezes the elapsed clock
but not the track" the ordinary explanation rather than a guess. **Not yet proof** — that still
needs the before/after pause screenshots — but the hypothesis now has a measured mechanism behind
it. `RESEARCH.md` A20.

**Battery, still not answered, but the bound is tighter.** 90% → 90% over 1.33 h with **zero 5%
steps observed**, so the honest range is now **0–3.7 %/h**, down from 0–11. Recording with the IMU
running did not visibly move a battery in 81 minutes. A real number still needs 3 h+ — which is
what today's one-START-no-STOP session is for.

**Filed as a fixture and as a test.** `Data/fixtures/2026-09-01_portillo_stationary.jsonl` (10 MB)
and `stationaryDinnerInventsNothing()`, which asserts zero runs, zero vertical, 122,358 motion
samples and no gap over 2 s. **20 tests now.** A control is worth more as a test than as a
paragraph: it fails the day a threshold change starts inventing vertical out of noise.

### S9 — 2026-09-01 · the app stops throwing the day away

**The gap that closed.** `LiveMetrics` computed runs, vertical and top speed live and then
discarded all of it at STOP. After a ski day the app showed a filename and a byte count, so every
number that mattered needed a Mac, a cable and Python — and the S8 audit had just established that
per-run detail is exactly what Slopes charges for. Two new files fix it:

- **`SessionReplay.swift`** (app, pure Foundation, `nonisolated`) — reads a JSONL session back and
  drives the same `LiveMetrics` the recorder used, returning a `Summary`. It adds nothing
  analytical; every number in it comes from that struct or from counting records.
- **`SessionDetailView.swift`** — three headline stats, a per-run list (drop, elapsed window,
  vertical rate), and a **RECORDING QUALITY** section: Doppler ratio, median hAcc, fixes the speed
  gate rejected, pre-start cached fixes excluded, barometer count, IMU coverage and longest motion
  gap, format version. Replay runs on a detached task and the screen says what it is replaying —
  a 3 h day is ~20 MB and ~35,000 lines.

**Why the quality block, and why it is the important half.** Every other app in the category prints
a number and stops. Ours is the one that can say *how much to believe it*: 3342 of 3342 fixes with
valid Doppler and a median of ±8.0 m is a day worth arguing about; 40 minutes of motion inside a
3-hour recording is a ruined one that looks fine by every other measure — which is precisely why
coverage and max gap are on the screen rather than just the sample rate.

**The harness got stricter, not looser.** `Tools/replay.swift` no longer parses anything itself; it
calls `SessionReplay` and prints. So `replay.sh` now validates the *whole* path the phone takes —
including what counts as a resume seam — against `analyze.py`, instead of a lookalike of it (R12a).
Both fixtures agree exactly: **3342 / 2773 fixes, 0 / 5 without valid Doppler, median ±8.0 m /
±7.9 m, 905 m / 462 m, 4 / 3 runs, 12 m / 24 m sub-threshold, ski time 19.9 + 23.8 = 43.7 min.**
Adding the stale-fix exclusion to the replay (negative `dt`, a cached fix carrying the car's speed)
is what closed the last one-fix discrepancy against the analyzer.

**One build-system fact, found the hard way.** The app target defaults to **main-actor isolation**,
so `LiveMetrics` was implicitly `@MainActor` — invisible until something tried to use it off the
main thread, which is exactly what replaying a 20 MB file must do. It is now `nonisolated`, like
everything else in `Recorder/`. `swiftc` in `replay.sh` never had that default, which is why the
harness had compiled it happily for two sessions.

**A ranked item was already built.** S8's #1 "urgent, ~20 lines" `ShareLink` has shipped since
`5b1aacc` — per row *and* a Share-all toolbar item. It was ranked from memory of the screen rather
than from the file. **R21** now says to open the file before ranking work on it.

**Then the tests, which were #3 and are now done — 19 of them, `Tools/test.sh`.** A `VerticalTests`
unit-test target (hand-written into the `.pbxproj`, which is small and hand-authored, so this was
~90 lines rather than a fight). Three suites:

- **The rules that were paid for.** The hAcc speed gate rejecting a ±31 m fix; the pre-start cached
  fix never becoming the day's top speed; the descent-merge rule keeping the 16 m tail a pressure
  blip used to delete; the merge *not* firing across a long gap, with the sub-threshold metres
  reported rather than dropped; the A19 leading-plateau trim moving the clock but never the
  vertical; a descent straddling a resume seam being abandoned instead of measured across it.
- **The Portillo days as golden numbers** — 3342/2773 fixes, 905/462 m, 4/3 runs, 64.7 and 43.9
  km/h, ski time 19.9 + 23.8 = 43.7 min, and the 1,367 m day total the head-to-head was run on.
  A failure here is not automatically a bug; it means the day's number changed, and that is a
  claim needing a session-log entry.
- **Not losing the day** — the 6-hour resume window at both edges, an old crash staying buried
  under a newer clean session, the deliberately-forgiving `"t": "end"` probe, and the two
  `SampleWriter` failures that have already happened once each: reopening truncating the file, and
  a torn final line gluing itself onto the next record.

**The suite was mutation-checked before being believed.** Nineteen tests passing on the first run
is evidence of nothing on its own, so `mergeAscentM` was set to 1.0 to re-introduce the S5 bug: it
failed `descentMergeKeepsTheTail`, `portilloS1` and `dayTotal`, and the threshold was put back.
**R22.** Synthetic session files are written through the real `SampleWriter` and the real sample
structs — a fixture that isn't byte-identical to production output tests the fixture (S4).

**Installed 2026-09-01 20:03**, fuse reset to ~2026-09-08. Martin was asked whether to replace
tomorrow's build and answered "do what you think is best"; installed on the grounds that
`SessionReplay` only reads closed files and cannot reach a recording. The built `Info.plist` was
re-checked for `UIBackgroundModes`, `UIFileSharingEnabled` and
`LSSupportsOpeningDocumentsInPlace` before installing (R-the-hard-way, S3). The launch could not be
confirmed from here — the phone was locked and `devicectl` cannot open an app on a locked device —
so **Martin confirmed it by hand: the app opens and the detail screen opens.** The *appearance* of
the screen is still unseen; one screenshot of a real day would retire that.

### S7 — 2026-09-01 · the build ships to the phone, and the saved day tells a different story

**The install finally happened.** The phone was plugged in at 16:17. Rebuilt, verified
`UIBackgroundModes` in the **built** Info.plist with `plutil -p` (R14/R14a — the command that ate a
bundle in S6), installed with `devicectl`, launched, and confirmed the process running from the new
bundle path. The provisioning fuse now runs to ~2026-09-08, past the end of the trip, and the S6
screen is on the device. A human still has to press START on it — that is ask #1.

**The detector was missing a whole class of lift.** Session 2 has a 38 s, +36 m surface tow at
13:14:24 that the 60 s minimum threw away, leaving two descents with no ride between them. It is
real and not a pressure artifact: GPS independently shows 130 m of travel at a rock-steady 3.0 m/s
on a constant 70–78° course while climbing +45 m, hAcc flat at 8–9 m. Printing every raw ascent
candidate on both days first (R7) showed real rides start at 42.6 m / 44.6 s and the largest
non-ride is 5.1 m / 17 s — a wide empty gap, so 30 s / 20 m recovers the tow and leaves session 1
bit-for-bit unchanged. **Both days now parse as strictly alternating lift → run → lift → run**, and
`detect.py` prints that timeline and complains when it breaks. That check needs no hand tags, which
matters: session 2 had one, and the miss was invisible to tag scoring while being obvious to
gravity.

**Martin sent the finished day records at 16:18/16:20, and Carve's number had moved.** Its live
screen at 13:39 read 1,509 m; its saved logbook entry for the same recording reads **1,625 m** —
same 7 runs, same elapsed once rounded, no afternoon skiing. Slopes moved 4 m the other way
(1,384 → 1,380). **Against our 1,367 m the saved figures are Slopes +1.0% and Carve +18.9%**, and
the +10.4% in S6 was computed against a live screen that Carve itself no longer agrees with. Our
GPS-hysteresis model of Carve's pipeline gives 1,588 m for the day at 3 m — it matches the *saved*
number, which makes 1,509 the anomaly. Written up as `RESEARCH.md` §5.1.3 with the error
decomposed (~221 m pipeline, ~37 m lunch break, the rest unexplained), and opened **A19** and
**A20**.

**Slopes graded our detector for free.** Its day card breaks the time down: 41 min skiing, 40 min on
lifts, 1 h 28 m at rest. Our lift detection sums to **37.4 min against its 40** — a −6.5% agreement
from a source that has never heard of us, with no hand tags involved. Our run durations sum to
**54.5 min against its 41** — a +33% error, because runs were segmented between altitude turning
points and standing at the top of a run was still counted as run time. Vertical is unaffected;
every duration and rate we printed was not.

**A19 fixed the same session.** A run now starts at the end of the leading plateau at the top —
the mirror of the trim already applied to lift starts, and *only* the leading plateau, since
trimming the runout at the bottom too undershoots Slopes by 13%. Both external checks agree: the
day 54.5 → 43.7 min against Slopes' 41, and session 1's run 1 378 → 341 s against the 5 m 26 s
Slopes itemises for it. Ported to `LiveMetrics` as one rule rather than two — streaming cannot walk
forward from the turning point, because those samples are consumed by the ascending branch before
the descent is declared, so the plateau is tracked live and read off at the transition. `replay.sh`
runs the app's own source over both fixtures and every duration matches to the decimal (R12a). One
trap worth recording: scoring the *new* run start against the old "Top" hand tags dropped run
starts from 2/2 to 0/2, which looks like a regression and isn't — Martin taps on arrival, 37–66 s
before pushing off, so `detect.py` now scores the turning point against that tag and the skiing
start is simply a different event the tags never labelled.

### S6 — 2026-09-01 · the second session, and the first result that isn't n=1

Pulled session 2 off the phone (`12:39:04–13:27`, 48 min) and ran both tools on it. Committed as
`Data/fixtures/2026-09-01_portillo_s2.jsonl`; the first fixture was renamed `_s1` to match, and the
references in `RESEARCH.md`, `Tools/detect.py` and the comparisons README were updated with it.

**The point of this session is replication, and it replicated.** Fix quality: **0.97 Hz**, hAcc
median **±7.9 m**, 99.9% of fixes usable, Doppler valid on **2,768/2,773** — session 1's outdoor
result was not a fluke of one morning. Against the 13:39 day-total screenshots, **Slopes is +1.2%**
over our 1,367 m and **Carve is +10.4%**, against +0.8% and +10.1% on session 1. Two apps, two
independent day-halves, the same two places. Carve's error is now a property of its pipeline, not a
bad morning.

**The detector was right before the file was opened.** The comparisons README had predicted ~3 runs
for session 2 by subtracting the two screenshot batches; `detect.py` found exactly 3 runs and 2
lift rides, from one hand tag in the entire session (matched to 15.7 s). Slopes and Carve also both
agree on 3 for session 2 — the day-total run-count disagreement (8 vs 7) is entirely session 1's
base-area split, already explained in §5.1.1 finding 4.

**A slow session put an honest bound on the headline.** Session 2 tops out at 43.9 km/h with no
multipath anywhere, and position-differentiation beats gated Doppler by only **+8.8%**. That is the
real cost of the naive method on a clean session; §5.1.1's +136.5% is what a single bad second does
to it. Both numbers should always appear together.

**New open question, tracked as A18 — where does Slopes' 67.2 km/h come from?** Session 2's maximum
is 43.9, so it is from session 1, and the whole day holds only four samples ≥62 km/h: the clean
64.7 at 11:01:11 and the three-sample 11:28:59 burst (66.8 / 69.6 / 63.4, hAcc 22–25 m). Either
Slopes published the glitch as Carve did, or it read the clean peak +3.9% high — consistent with
the +2.3% it ran over us on run 1. Every smoothed estimator tried (3 s / 5 s rolling means of
Doppler and of position-differentiation) peaks inside the burst, which leans (a); Slopes' Run 2
stamp of 10:57 containing the clean peak leans (b). The Premium blur over Run 2's top speed is too
heavy to recover — tried. **Neither version goes in a doc until a burst-free session settles it**
(R1). Full argument in `RESEARCH.md` §5.1.2.

**And one number we had been quoting is not a number.** Session 2 looked like 6.7 %/h against
session 1's 5.5 %/h, which invited an explanation — cold, thermal, signal. There is nothing to
explain: `UIDevice.batteryLevel` is **quantised to 5%**, every reading in both files is a multiple
of 0.05, and each session observed exactly **one step**. 65→60 over 0.92 h and 85→80 over 0.75 h
are the same observation. The true rate is somewhere in **0–11 %/h** and both published figures
were decimals the instrument cannot produce. `analyze.py` now prints the step count and the range,
and refuses the precise figure under three steps — R7, applied to our own instrument this time.

**The app now shows the honest numbers instead of the naive ones (plan item 5, done).** Its live
display had both category bugs in it: `roughDescent` sums every negative barometric delta — the
method that puts Carve +10.4% over the truth — and the speed tile showed raw ungated Doppler, the
field that made a multipath burst Carve's day. `iOS/Vertical/Recorder/LiveMetrics.swift` is the
streaming port of the two S5 rules (hAcc ≤ 15 m gate; run segmentation with the merge applied
before the min-drop filter), and the main screen leads with **VERTICAL / TOP SPEED / RUNS**, each
carrying its naive counterpart underneath in small type. The gap between the two lines is the
product, and it should be readable on a chairlift.

**A port is a claim, so `Tools/replay.sh` proves it.** It compiles the app's *own*
`LiveMetrics.swift`, unmodified, against the fixtures. It matches `analyze.py` exactly on both —
64.7 / 69.6 km/h, 4 runs, 905 m, 12 m sub-threshold; and 43.9, 3 runs, 462 m, 24 m. Batch and
streaming are two different algorithms that owe the same answer, and this is what keeps a threshold
from being changed in only one of the two places (new rule R12a).

**The replay found a real hole while proving it.** CoreLocation hands over its cached last-known
fix the instant updates begin, so every session's first sample predates the session. `analyze.py`
had always excluded those; `LiveMetrics` was counting them — meaning **a fix cached in the car on
the drive up would have been published as the day's top speed before the first run.** Both exclude
them now. Finding it took one run of a harness that did not exist an hour earlier.

**Cost of the day: one self-inflicted wound worth writing down.** Verifying the built product's
`UIBackgroundModes` with `plutil -extract … Info.plist` **overwrote that Info.plist** with the
extracted array — `plutil -extract` edits in place without `-o -`. It hit DerivedData, so a rebuild
fixed it, but the same command aimed at `Vertical-Info.plist` destroys source. Now R14a.

### S5 — 2026-09-01 · the three-app head-to-head, and the gate we had backwards

Martin recorded the same Portillo morning on **Slopes, Carve and Vertical at once** and sent
screenshots of the other two. Full write-up in `RESEARCH.md` §5.1.1; the parts that change what we
do next are here.

**The comparison is not what the pitch assumed.** Slopes' run 1 — the only one it shows for free —
came in at **415 m vs our 407 m and 53.8 vs 52.6 km/h**. Two percent on both. Slopes is not
overestimating anything; the §5.1 folklore is about Ski Tracks and Garmin, and we had quietly let
it stand in for the whole category including the market leader. Carve is the one that fits the
pattern: **996 m vs our 905 m, +10.1%**, on the same four descents. Over the whole morning Slopes
lands at 912 m against our 905 m — **0.8%**.

**The best single finding of the project so far.** Carve reports the day's top speed as
**66.8 km/h**. Our file contains, at **11:28:59**, a Doppler sample of exactly 66.8 km/h — inside a
four-second burst where hAcc degrades from 8 m to 31 m and one consecutive pair of fixes is
**42.5 m apart in one second** (153.1 km/h, which is where our own "naive method" headline number
came from). Carve published the glitch. We could only see that because we keep the raw fixes, which
is the argument for the whole capture design in one example.

**And the finding aimed at us.** Checking why we disagreed with Slopes on run-1 top speed exposed
that `MAX_SPEED_ACC = 2.0` was the wrong knob:

- The **median `speedAcc` for the day was 2.04**, so the gate threw away **57% of a healthy 1 Hz
  track** — it was sitting on top of the distribution, not out in its tail.
- `speedAcc` **rises with speed**, so the gate cut hardest exactly where it mattered. The day's
  real peak is a textbook 15-second ramp from a standstill to **64.7 km/h**, hAcc steady at 8–13 m,
  altitude falling 52 m, with position-differentiation independently agreeing at 70.6 km/h. The old
  gate reported **58.7 km/h** — it clipped the peak mid-acceleration because one sample crossed
  2.0.
- Meanwhile it **passed the 11:28:59 multipath burst**, because a receiver that has lost the sky
  still reports a confident speed for a wrong position.

`hAcc` is the field that separates the two cases: the real peak stays under 15 m, the burst does
not. Gating Doppler on **hAcc ≤ 15 m** keeps 94% of the day and lands on 64.7 km/h; every
alternative tried (accel-plausibility at 2.5/4/6 m/s², relative `speedAcc`, hAcc ≤ 20) agrees, and
hAcc ≤ 25 does not — it lets the burst back in. `analyze.py` now gates on hAcc and keeps a loose
`speedAcc ≤ 3.0` as a sanity bound only.

**The honest restatement of the thesis.** Our headline is now "+136.5% vs. position-differentiated"
(64.7 vs 153.1 km/h), but that ratio is glitch-versus-gate and should never be quoted on its own.
On the same clean acceleration, position-differentiation reads 70.6 vs Doppler's 64.7 — **about
+9%**. The real claim is not that naive methods are 100%+ wrong all day; it is that **naive methods
have no way to reject a bad second, and one bad second is all it takes to own the day's headline
number.** Carve is the proof.

**Also measured:** our run detector matched Martin's hand tags to **16 s at the top and 2 s at the
bottom** of run 1. Descent-only distance 5.58 km, against Slopes' 5.1 km and Carve's 5.69 km.
Slopes' own run-1 fields don't reconcile (2.1 km in 5 m 26 s is 23.2 km/h, not the 31.0 it prints).

**The 5-runs-vs-4 question, answered — and it caught a second bug of ours.** Martin confirmed he
stopped at 11:30, so there were **four descents**. Slopes' fifth run is an artefact, and the cause
is in our own file: at **11:28:57**, arriving at the base, the barometer jumped **+4.1 m in two
seconds** at the same instant GPS scattered — one physical event (a building) corrupting both
sensors at once. That blip splits the last descent. Slopes counted the tail as a run.

**We did something worse with the same blip.** `segment_runs` split the run *and then dropped the
orphaned 16 m tail on the floor*, because it fell under `MIN_RUN_DROP_M = 30`. The day was reported
**895 m when it was 905 m** — we were losing vertical, the mirror image of the bug this project
exists to fix, and we would have shipped it as the honest number. Fixed: descents separated by less
than **15 m of re-ascent and less than 60 s** are merged *before* the minimum-drop filter, measured
top-to-bottom. Both conditions are load-bearing — the height rule alone swallowed five minutes of
shuffling around the base area into "run 2" and inflated descent distance by 0.5 km. The analyzer
now also **prints what the threshold discarded** instead of letting it vanish.

**The generalisable lesson:** a single physical event corrupts every sensor at once. Barometer and
GPS disagreeing is a useful signal; barometer and GPS *agreeing* is not independent confirmation.

**Corrected totals: Vertical 905 m / 5.58 km descent distance / 4 runs.**

**End of S5 — Martin's answers, and the finding they unlocked.** iOS only (D1). 3D postponed, not
killed (D4). The $99 program deferred (D5) — so the 7-day provisioning fuse is now a scheduled
chore rather than a contingency, and "ship it" is out of reach until that changes. "Vertical" stays
a placeholder (D6).

And the one that mattered: **Carve is absent from Motion & Fitness even after a real 1 h 05 m
recording**, so it never started `CMAltimeter` and its altitude is GPS-only. Replaying our own GPS
altitude with 3 m hysteresis and summing gives **992 m against its printed 996 m** — 0.4%. The
run-segmented variants give 928–933 and do not match. So Carve smooths GPS altitude and sums it,
uses no barometer, and never measures a run top-to-bottom; its +10.1% is exactly what those two
choices cost. Three independent confirmations now agree: the permission list, the numeric
reproduction, and its top speed being a multipath sample we can point at second by second.
Written up in `RESEARCH.md` §2.2.

**Auto-detection now works, unassisted, on the first day.** Built `Tools/detect.py` — the Phase 1
prototype. It reads only the barometer, smooths over 20 s, classifies each sample as
climbing/descending/flat, and turns the sustained stretches into lift rides and runs. Scored
against Martin's hand tags on 2026-09-01:

| Boundary | Matched | Median error | Worst |
|---|---|---|---|
| Lift start | 4/4 | 18.6 s | 36.8 s |
| Lift end | 3/3 | 2.8 s | 19.6 s |
| Run start | 2/2 | 15.9 s | 15.9 s |
| Run end | 1/1 | 2.4 s | 2.4 s |

**No missed tags, no spurious lift, and it independently recovered the 11-minute ride** that the
tags record as 10:45:36 → 10:56:55.

Two corrections were needed to get there, and both are the same shape as the S5 analyzer bugs —
a threshold measuring the wrong moment:

- **Lift ends were 55–157 s early (0/3 matched).** A chairlift flattens out before its station, so
  the smoothed climb rate falls under the threshold while the rider is still on the chair. A ride
  ends where the altitude *peaks*, not where the climbing gets lazy. Extending each ascent forward
  to its peak before the next descent fixed all three — and collapsed a spuriously split ride into
  the single 11-minute one.
- **Lift starts were 25–44 s early.** The mirror problem: smoothing bleeds the end of a run and the
  lift-line wait into the front of the ascent. Trimming the start to the last moment the altitude
  is still at its lowest took the median from 25 s to 18.6 s.

**Stopped tuning there deliberately.** 18.6 s against a button Martin taps in gloves is at the
precision of the tag itself, and this is one day — `WORKFLOW.md` R5. Tuning further would be
fitting the detector to n=1. The next real gain comes from more tagged days, not more knobs.

**Worth noticing about our own reasoning:** in the first pass I read "996 sits between our
baro-summed 944 and GPS-summed 1,227" as evidence Carve *did* use the barometer. It was evidence of
smoothing, not of a sensor. A number landing between two of your own numbers constrains almost
nothing — `WORKFLOW.md` R2 again, in a quieter register.

---

### S4 — 2026-08-31 (late) · made the app survive a full day, and found a real peer

Purpose of the session: **tomorrow is the first outdoor recording, so make the thing that would
waste it impossible.** The pulled recordings confirmed no outdoor data existed yet — the newest
file was 20:38, indoors and stationary — so the GPS question is still open and untouched.

**The gap that mattered.** `SampleWriter`'s own documentation promised that an interrupted file
"can be picked up silently on next launch". Nothing implemented it. A jetsam kill in a pocket or
a cold-weather cut-off would have brought the app back **IDLE** while Martin kept skiing. Built
`SessionRecovery` + `TrackRecorder.resumeIfInterrupted()`: on every launch, foreground or
background, an `end`-less session that stopped within six hours is silently reopened and appended
to on the same timeline. No prompt — a "resume or finish?" question tapped wrong on a chairlift is
what triples other apps' totals — just a green banner saying it happened. Significant-location-
change monitoring is registered while recording solely because it is the only API that asks iOS
to relaunch a terminated app.

Two correctness bugs fell out of building it:

- `SampleWriter` called `createFile` unconditionally, and `createFile` **truncates**. Reopening a
  recording would have erased the recording. It now creates only when absent, and closes off a
  torn final line so a power cut costs one record rather than two.
- **`CMAltimeter.relativeAltitude` restarts from zero at every resume.** Summing deltas across
  that seam invents vertical. Demonstrated with a synthetic day where the phone dies at the top of
  a lift: the analyzer reported **800 m for a 400 m descent**, a 100 % overstatement — the exact
  category bug this project exists to fix, reproduced in our own code. The analyzer now marks
  resume seams and measures each stretch separately; 400 m exactly. Vertical skied while the app
  was dead is reported as unknown, never guessed.

**Verified on hardware, not just compiled** — planted an interrupted session, `SIGKILL`ed the
process, relaunched, watched it recover; then confirmed a closed session is left alone. The first
attempt at that second check *falsely passed as a failure*: the probe searched for the literal
`"t":"end"`, and the Python-written fixture had `"t": "end"` with a space. `JSONEncoder` never
emits that space, so real files were always fine — but a recovery check that silently decides a
finished session is still running is not something to leave resting on byte-exact formatting. The
field reader is now whitespace-tolerant. **The lesson is the older one restated: a test fixture
that isn't byte-identical to production output tests the fixture.**

**Carve.** Martin asked about an ad for "Carver". It is
[Carve: Ski & Snowboard](https://apps.apple.com/gb/app/carve-ski-snowboard/id6758206264) — a
solo-dev, free, no-paywall, donation-funded ski tracker that already ships auto lift detection,
3D terrain replay with satellite drape, speed heatmaps, run comparison and GPX import. Written up
in `RESEARCH.md` §2.2. It makes §2.1's "unoccupied position" claim wrong as written, and it makes
the accuracy thesis the only load-bearing part of this project — it claims nothing about accuracy
anywhere. It also proves 3D terrain on iOS is solo-dev-reachable, which de-risks §9.1 / D4.

---

### S3 — 2026-08-31 · shipped to the device, first real data, two bugs found
Signing sorted: Xcode had **no Apple ID signed in at all** (which is why Yomi has never run on a
device — simulator only). After Martin signed in, the real team ID turned out to be `F9R33MN82P`,
read from the certificate's `organizationalUnitName` — my earlier guess of `8RNGM77QFU` was the
certificate's own ID, not the team. Xcode's GUI handled DDI mount + device registration after
`xcodebuild` couldn't.

**Crash on START, root-caused and fixed.** `INFOPLIST_KEY_UIBackgroundModes` is **silently ignored
by Xcode's Info.plist generator** — no warning, the key just never reaches the build. Without the
`location` background mode, `allowsBackgroundLocationUpdates = true` raises an uncatchable ObjC
exception. Checking the built binary the same way found `INFOPLIST_KEY_UIFileSharingEnabled` had
vanished too. Both now come from a real base plist (`Vertical-Info.plist`) merged under
`GENERATE_INFOPLIST_FILE`. Added a runtime guard so a missing background mode degrades to
foreground-only with a visible warning rather than crashing.

**Lesson, generalised:** verify Info.plist keys by reading them out of the *built product*, never
by trusting that a build setting was honoured. Same family as Yomi's S118 build-settings trap.

**First real recording** (3.2 min, indoors, stationary) gave the numbers in the handoff above:
barometer excellent and correct, GPS unproven. Three follow-up fixes shipped: live `DOPPLER`
health tile, visible tag confirmation (the log showed three "Top" taps in three seconds because
nothing acknowledged the first), and analyzer exclusion of pre-start cached fixes.

Martin corrected the interaction model — auto-detection, not manual tagging. Captured above.

---

### S2 — 2026-08-31 · decisions settled, recorder built
**Martin is at Ski Portillo, Chile, for the week.** That inverts the plan: raw capture is now
urgent, everything else can wait. Decisions: **D1 iOS-only ✓**, **D2 social deferred** ("whatever
is easier" — so on-device only, zero running cost), **D3 Portillo, this week**.

Built a deliberately minimal recorder — Xcode project, `TrackRecorder`, `SampleWriter`,
recording UI, sessions list. Compiles zero-error zero-warning. **It does no analysis at all**: it
appends every `CLLocation` and barometer sample to JSONL at full fidelity, fsync'd, append-only,
so a crash or dead battery costs a few samples and never asks a "resume or finish?" question.
The reasoning: analysis can be rewritten and replayed all week against real files; a day skied
without capture is gone forever.

Also built `Tools/analyze.py` — the accuracy harness. Computes vertical four ways and max speed
two ways on the same data, so the project thesis becomes measurable rather than asserted.
Validated on synthetic data (recovered 1,399 m from a 1,400 m ground truth; 4/4 runs matched
hand markers). **Its error magnitudes on synthetic data are inflated** — synthetic noise is
independent per-sample, real GPS noise is correlated. Real magnitudes pending real data.

One build-settings trap hit and fixed, exactly as [[project-yomi]] S118 warned: with
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the plain data structs got MainActor-isolated
`Encodable` conformances and couldn't satisfy a `Sendable` requirement. Fixed by marking them
`nonisolated`.

**Blocked on Martin:** Developer Mode is disabled on the iPhone 17 (Settings → Privacy &
Security → Developer Mode, then reboot). Nothing installs until then. Build is ready and waiting.


### S1 — 2026-08-31 · market + feasibility research
Martin asked for a ski app with Slopes' premium features free, then redirected to research and
planning first. Swept App Store review feeds, ski forums, comparison blogs, GitHub, the Slopes
founder's own dev blog, and MapLibre release notes. Wrote `RESEARCH.md`, this file, and `CLAUDE.md`.
No code. Headline findings in "Current state" above. Three decisions (D1–D3) handed back to Martin.
