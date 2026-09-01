# ROADMAP.md — Vertical

Current state, planned work, and the decisions that gate it.
Companion docs: `RESEARCH.md` (market + feasibility), `CLAUDE.md` (project context + tooling).

---

## ⚡ START HERE — handoff for the next session (updated 2026-09-01, S8)

### 🔴 The two things outstanding right now, before anything else

**1. The walk test has not been done.** The build on the phone (`494d537`) records device motion at
25 Hz and **has never been run**. Martin will do it later. Ask him for it, then verify from the
data, not from his description:

```sh
xcrun devicectl device copy from --device 270B9EDA-7298-5206-9E67-71C0E8F60CF6 \
  --domain-type appDataContainer --domain-identifier com.gamberg.vertical \
  --source Documents/Sessions --destination ~/Desktop/Projects/Vertical/Data/pull-$(date +%Y%m%d)
./Tools/analyze.py <newest>.jsonl     # read the "--- MOTION (IMU) ---" block
```

The test: START, check the **MOTION** tile is green and climbing, **lock the phone and pocket it
for ~2 min** (this is the part that matters — it tests background delivery for device motion, which
is inferred from `CMAltimeter` behaving that way, not yet observed), unlock, STOP. What to look for:
effective rate near 25 Hz, coverage near 100%, **no gap spanning the locked stretch**.

**2. Whether to ski with it tomorrow is Martin's call, and he has not made it.** For: one more day
out of ~5 before three months without snow. Against: new code on the last data days, and it makes
the 3 h battery number "app + IMU" rather than "app". Worst realistic case is a crash, which
`SessionRecovery` silently reopens and appends to (proven against a real `SIGKILL` in S4) — seconds
lost and a baro seam, not a day. **If the walk test is clean, recommend skiing with it. If not, the
previous build is two minutes away:** `git checkout 7ebef4e -- iOS/` then rebuild and reinstall.

### ⚠️ S8 was a full audit, and it changes the framing. Read `RESEARCH.md` §13.5 first.

Short version: **the accuracy thesis is half falsified by our own data** (Slopes ties us three
times over; the app we beat, Carve, has no users), **"maps aren't paywalled" was false** (Slopes'
free tier has trail maps), and the real paid line in this category is **analysis** — Slopes' free
tier gives a daily summary only, and per-run detail is Premium. That last one is the better
positioning and it is the half we already built.

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

**1. Get a session off the phone without a Mac. ⬅ do this first, it is urgent and small.**
Today the *only* route out is `devicectl` over a cable. Martin is at Portillo with limited time at
the Mac, and **if he skis and doesn't plug in, we cannot see the day at all.** A `ShareLink` per row
in `SessionsView` — AirDrop, WhatsApp, email, Files — removes that dependency permanently and lets
him send a recording from a chairlift. Perhaps twenty lines, and it unblocks every other thing on
this list for the rest of the trip. **The IMU files are ~5.7 MB/hour, so a 3 h day is ~20 MB** —
fine for AirDrop, worth knowing before trying to email one.

**2. A session detail screen — the biggest gap between "capture rig" and "app".**
After a ski day the app shows *filenames and byte counts*. Every interesting number — runs,
vertical, top speed, how the day was split — requires a Mac and Python. Meanwhile `LiveMetrics`
computes exactly those live and then **throws them away at STOP**. Replaying the file back through
that same struct on open would give a per-run list on the phone, reusing the identical code path
`Tools/replay.sh` already validates against `analyze.py` (R12a — one rule, one implementation).
It is also precisely the thing the S8 audit says people pay Slopes for: **their free tier gives a
daily summary only, and per-run detail is Premium.** Parse off the main thread; a 3 h file is big.

**3. There is not a single automated test in the project.**
For an app whose entire value proposition is *not losing a ski day*, that is the gap that should be
most uncomfortable. `LiveMetrics` is pure logic with two real fixtures sitting next to it, so the
segmentation and gating rules are trivially testable. So are the two bugs that already bit us and
would bite again silently: `SampleWriter` reopening a file with a truncated final line (S4), and
`SessionRecovery`'s 6-hour window. `replay.sh` is a harness, not a test — nothing fails a build.

**4. Port the detector into the app** (`Tools/detect.py` → Swift). This is what makes the app
behave like Slopes — press START, pocket the phone, get runs and lifts with no input. It is also
the precondition for **R19**: the four tag buttons come out of the UI once detection works, and
Martin flagged them as scaffolding back in S4.

**5. GPX export.** Named in `RESEARCH.md` §2.2 as the switching-cost lever, but it is worth more
than that here: it makes a recording usable in Strava, Slopes, or anything else, which is the whole
"your data is a file you own" claim made real rather than asserted.

**6. A design pass.** `ContentView` says "deliberately ugly" at the top and it is right to have
waited. But sunlight readability and glove-sized targets are *functional* requirements on a
mountain, not polish, and the `design` skill is installed.

**Deliberately not on this list:** maps (cut by the audit — Slopes gives trail maps away free), 3D
(cut S5), naming (D6, don't spend cycles), and the $99 program (D5, deferred — and pointless until
D7 says whether anything ships).

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

### Decisions — answered by Martin 2026-09-01, end of S5

| # | Decision | Answer |
|---|---|---|
| **D1** | Platform | **iOS only.** Settled, not provisional. |
| **D4** | 3D in v1 | **Postponed.** Not killed — revisit when MapLibre ships iOS terrain, or when there's appetite for a Metal-shaped project. Phase 3 stays written down so the option is costed rather than forgotten. |
| **D5** | $99 Apple Developer Program | **Not yet** — "I will eventually get it done." See the standing cost below; plan around a free account until then. |
| **D6** | Name | **"Vertical" stays a placeholder.** Don't spend cycles on naming; revisit before anything is published. |
| **D7** | **What is this project for?** (opened S8) | **Open — and it gates everything else.** (a) personal tool + engineering playground, (b) narrow product for people who want their data, (c) chase the IMU "how you ski" axis, (d) stop. The accuracy-vs-Slopes framing that the rest of this file was built on did not survive the audit, so the plan should not be executed as written until this is answered. `RESEARCH.md` §13.5. |
| **A5** | Does Carve use the barometer? | **No** — absent from Motion & Fitness after a real 1 h 05 m recording. Its pipeline is now fully characterised (`RESEARCH.md` §2.2). |

D2 (backend/social) and D3 (where we test next) are still open, but neither blocks current work:
everything in Phase 1 and Phase 2 is on-device, and the test site is Portillo until ~2026-09-07.

### ⚠️ The standing cost of deferring D5 — read this before the trip ends

A free account issues **7-day provisioning profiles**. The current build was installed
**2026-09-01 16:17** (S7), so it **stops launching around 2026-09-08** — just after the week Martin
stops skiing. Consequences to manage rather than discover:

- **Reinstall before the trip's last ski day, not after the app dies.** A rebuild + `devicectl
  install` resets the clock for another 7 days and takes minutes *when the phone is at the Mac*. It
  is not something that can be fixed from a chairlift.
- **Every future recording session has this same 7-day fuse.** Northern season starts in ~3 months;
  by then D5 needs an answer or every ski day begins with a reinstall.
- **TestFlight and the App Store are unavailable**, so "ship it" is not reachable on a free account
  at all — this is a ceiling, not a friction.
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
