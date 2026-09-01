# ROADMAP.md — Vertical

Current state, planned work, and the decisions that gate it.
Companion docs: `RESEARCH.md` (market + feasibility), `CLAUDE.md` (project context + tooling).

---

## ⚡ START HERE — handoff for the next session (updated 2026-09-01, S5)

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

**Now, while Martin is still at Portillo (until ~2026-09-07) — this window does not come back:**

1. **Record more days.** Every number we have is n=1: one 56-minute morning, one clean speed peak,
   one glitch. The same signature across three days is a finding; one day is an anecdote. Costs
   nothing but pressing START, and no amount of analysis substitutes for it.
2. **Answer the five questions in "Asks for Martin" below.** They are batched deliberately; three of
   them take under a minute each and two of them are decisions only he can make.
3. **Reinstall the build before the last ski day** — the 7-day profile expires ~2026-09-07 and D5
   is deferred, so this is now a scheduled chore, not a contingency. See the box below.

**Next, at the desk:**

4. **Phase 1 auto-detection.** The detector already matched the hand tags to 16 s at the top and 2 s
   at the bottom of run 1 — closer than expected. The work is lift detection (Portillo's
   *va-et-vient* platters are the hard case) and validating against every day we have, not just the
   first.
5. **Fold the S5 analyzer fixes into the app itself.** The hAcc speed gate and the descent-merge
   rule live only in `Tools/analyze.py`; the app still reports its own live numbers.
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
| **A5** | Does Carve use the barometer? | **No** — absent from Motion & Fitness after a real 1 h 05 m recording. Its pipeline is now fully characterised (`RESEARCH.md` §2.2). |

D2 (backend/social) and D3 (where we test next) are still open, but neither blocks current work:
everything in Phase 1 and Phase 2 is on-device, and the test site is Portillo until ~2026-09-07.

### ⚠️ The standing cost of deferring D5 — read this before the trip ends

A free account issues **7-day provisioning profiles**. The current build was installed
**2026-08-31 23:24**, so it **stops launching around 2026-09-07** — which is the same week Martin
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
**2026-09-07**. If the app won't launch, rebuild + reinstall:
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
- Battery **5.5%/h** → ~38% over a seven-hour day.

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
| **Slopes** ($34.99/yr) | Same numbers, free — measured at **0.8% on vertical** over a real morning, ~2% on run-1 top speed. Plus: your raw track is a file you can read, and maps aren't paywalled. | That Slopes is inaccurate. It isn't. Saying so would be the exact sin we caught Carve committing. |
| **Carve** (free) | **+10.1% vertical** on the same four descents, and it published a **GPS multipath glitch as the day's top speed** — a number we can point at, second by second, in our own raw file. | That Carve is a toy. It ships more features than we do today. |
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
      is already costing us: the build dies ~2026-09-07 mid-trip, and every reinstall is a manual
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
- [ ] **Automatic lift vs. run segmentation** — sustained ascent + proximity to `aerialway`
      geometry. Zero user interaction. Validate against the hand-placed tags in recorded sessions.
      Portillo's *va-et-vient* slingshot platter lifts are an unusual edge case worth checking:
      they won't look like a chairlift to a naive detector.
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
