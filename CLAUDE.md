# Vertical — Claude Code Project Context

> Name is a **placeholder**. Pick a real one before the repo goes public.

## What this app is

A ski / snowboard day tracker for iOS that gives away everything Slopes charges for.

> ✅ **D7 answered by Martin, 2026-09-01 (S9), and the sentence above is his:** *"the objective of
> the app was basically have Slopes and all its paid functions for free."* Accuracy was added
> during planning — *"make it more accurate and maybe better if possible"* — and was never the
> premise. *"Eventually I would like for my friends and family to have it too."*
>
> **So the target list is Slopes' Premium list:** run-by-run stats (✅ shipped S9), **run
> comparison**, speed heatmaps, offline maps, 3D. Slopes' free tier gives a **daily summary only**;
> the paid line in this category is drawn around **analysis**, and the old "Slopes paywalls maps"
> line was simply wrong — the free tier has trail maps.
>
> ⚠️ **Do not re-litigate the accuracy thesis as if it were the project.** S4–S8 wrote it up as
> "the ONLY differentiator", and the S8 audit then read the measured tie with Slopes as a
> half-falsification. That framing was ours. On the actual goal, tying the market leader on
> accuracy is a fine outcome; it only costs a marketing line we should not have been writing.
> **R20 still stands: never claim accuracy we haven't measured.** `ROADMAP.md` §13.6 has the
> re-plan; `RESEARCH.md` §13.5 has the audit that is still valid underneath it.
>
> **D5 answered too: yes to the $99 Apple Developer Program, after Yomi ships.** Friends and family
> need TestFlight, so distribution is blocked on Yomi finishing — not on an undecided question.

Slopes' paywall protects GIS headcount and per-resort data labour, not hard technology. Open trail-map data
(OpenSkiMap, 6,992 ski areas) is free and worldwide — but **do not repeat the old "3× larger than
Slopes" line**; S5 found it was built from two unrelated numbers and withdrew it (`RESEARCH.md`
§13, A2).

## Project path

`/Users/martingamberg/Desktop/Projects/Vertical`

## Status

**➡️ Read `ROADMAP.md` → "⚡ START HERE" first. It has the handoff, the exact commands, and the
one open question.**

**S18 (2026-09-05): capture is closed. Four graded days, 43 runs, and the dataset is final.**
Martin left Portillo on 2026-09-05 without skiing again, so `Data/fixtures/` is now everything this
project will ever have: 1–4 September 2026, one resort, one phone, `.slopes` exports for all four.
**R5 is no longer a to-do; it is a permanent caveat** — nothing in the pipeline has been tested on a
second mountain, and no amount of desk work changes that.

GPS outdoors is green (0.94–1.00 Hz, hAcc median ±7–8 m). **Battery is measured and replicated:
6.7 / 6.5 / 6.5 %/h** over three full days of 6.00 / 5.42 / 6.92 h unplugged, with 8 / 7 / 9
discrete 5% steps — so all three clear `analyze.py`'s own "meaningful" bar, and a 7-hour day costs
~45% of the phone. *(This entry read "battery is still unmeasured" until S18, twelve sessions after
it stopped being true; `ROADMAP.md`'s session log had the numbers all along.)*

**The thesis survived contact with reality, but not in the shape it was written above.** Over the
whole morning **Slopes reported 912 m to our 905 m — 0.8%**, and matched us to ~2% on run-1
vertical and top speed. Slopes is not the app with soft numbers, and we must stop implying it is:
**against Slopes, accuracy is a tie.** **Carve** is the one that fits the pattern — **+10.1%** on
vertical, and its published top speed for the day is *bit-for-bit a multipath glitch* visible in
our own raw file. The real claim is that naive methods cannot reject a bad second, and one bad
second owns the headline. `RESEARCH.md` §5.1.1 has the tables, `ROADMAP.md` → "What we can actually
claim" has the positioning that follows.

The same comparison caught **two bugs in our own analyzer** (ROADMAP S5): the speed gate used
`speedAcc` when `hAcc` is the field that fails, and run segmentation was **silently deleting
vertical** — a 4 m pressure blip split a run and the orphaned tail fell under the minimum-drop
threshold. We reported 895 m for a 905 m day. Both fixed.

A recording interrupted by a jetsam kill, a crash, or a cold-weather power cut is now reopened
silently on next launch and appended to on the same timeline — verified on the device with a real
`SIGKILL`, not just compiled. See `ROADMAP.md` S4.

**A real peer exists.** [Carve](https://apps.apple.com/gb/app/carve-ski-snowboard/id6758206264) is
a free, no-paywall, solo-dev tracker already shipping auto lift detection, 3D terrain replay,
speed heatmaps and run comparison (`RESEARCH.md` §2.2). It says nothing about accuracy anywhere.
**The accuracy thesis above is now the only load-bearing part of this project** — treat "we'll be
the free one" as dead.

Verified on real hardware: barometer is excellent (0.85 m drift over 3.2 min stationary; pressure
matches Portillo's 2,880 m), location auth is Always, background recording is correctly entitled,
and **GPS outdoors is fine** — the alarming indoor numbers (0.34 Hz, Doppler on 8 of 68 fixes) were
the building.

**Interaction model:** the app must **auto-detect** runs and lifts. Press START, pocket the phone.
The tag buttons in the UI are temporary scaffolding for building the detector and get removed once
it works — Martin flagged this and he's right.

## Key docs

- `RESEARCH.md` — market, competitor teardown, user complaints, data-source feasibility, technical
  risks, and **§13, the assumption register**: every claim the plan rests on, with a verdict against
  a primary source. **Start here.**
- `ROADMAP.md` — current state, phases, open decisions, session log. Its "⚡ START HERE" is the
  handoff.
- `WORKFLOW.md` — the rules of process (R1–R20), each tied to the session that earned it.

**Fifteen offline tools now, all stdlib-only, all run against a raw session file.** The five that
carry weight:
- `Tools/analyze.py` — the accuracy harness. Computes every metric the careful way *and* the naive
  way on the same data, so the thesis is measurable rather than asserted.
- `Tools/grade.py` — grades our per-run numbers against Slopes' `.slopes` exports, the only
  external ground truth the project has. Pairs by time overlap, never by index (R27).
- `Tools/parity.py` — diffs `replay.sh` (the app's own Swift) against `analyze.py`, run by run.
  R12a's "harness that proves it"; added S18, when the audit found the comparison had only ever
  been done by a human reading two printouts.
- `Tools/replay.sh` — compiles `iOS/Vertical/Recorder/*.swift` *unmodified* and runs it over a
  fixture, which is what makes that diff meaningful.
- `Tools/compare.py` — the run-comparison twin of `RunComparison.swift`: how much of the mountain
  two descents share and how far apart they were over it, graded against Martin's 24 labels. Added
  S18. **Its grading table is the evidence that the feature must not claim two descents are the
  same run**, so read it before anyone is tempted to add a threshold.

The rest are single-question instruments, each written to answer one thing and kept because the
answer is reproducible: `runout.py` / `runup.py` (what is inside the seconds at each end of a run),
`trimend.py` (grading eleven candidate end rules), `altsrc.py` (the −3% vertical, answered),
`liftid.py` / `liftname.py` / `similar.py` / `label.py` / `runmap.py` (the lift key and the
labelling work), `falsetop.py`, `detect.py` (the original Phase-1 prototype, superseded by
`LiveMetrics` shipping in the app).

> ⚠️ **Anything that calls `analyze.segment_runs` must pass `speed_at`.** Without it the S16 runout
> trim silently degrades to a no-op (R33) and every run ends 41–91 s late, out on the flat by the
> base. Four tools had this bug until S18 and none of them looked wrong.

**Seven docs**, not the four this line used to claim: the four below plus `README.md`,
`iOS/README.md` and `Data/comparisons/README.md` — and three per-day `*_slopes_export.md` notes
under `Data/comparisons/`, which are records of a specific export rather than living documents.
Split more out when a doc actually gets unwieldy.

## Tech stack (provisional — nothing committed until Phase 0)

- Swift + SwiftUI, iOS 26 target (matching Yomi's no-back-deployment stance)
- `CoreLocation` + `CoreMotion` (`CMAltimeter`) — the recording engine
- Map renderer: **MapKit, for the 2D case, decided by shipping it** (S17). The speed-coloured track
  draws the user's own file over Apple's base map, which needs no trail database, no OpenSkiMap
  ingest and no ODbL attribution surface. **3D terrain is still undecided** — MapLibre Native has
  none on iOS yet, see `RESEARCH.md` §9.1, and that is the decision worth an ADR when it comes
- Persistence: GRDB is the known-good choice from Yomi. Tracks are time-series; revisit if that shape fights it
- Backend: **ideally none.** Everything except lift status and social works fully on-device

## Data sources

| Source | License | Use |
|---|---|---|
| [OpenSkiMap / openskidata](https://github.com/russellporter/openskidata-processor) | **ODbL** | Runs, lifts, ski areas. GeoJSON + GeoPackage + vector tiles, daily |
| [Liftie](https://github.com/pirxpilot/liftie) | BSD-3 | Live lift status. Public API at `liftie.info` |
| DEM terrain tiles | varies | 3D terrain |

**Two hard rules:**
1. **ODbL attribution must be visible in the app.** Publishing our own derived run database means
   publishing it under ODbL too. App code is unaffected. Verify the Skimap.org / ski-pass sub-terms
   before shipping (`RESEARCH.md` §7.1).
2. **Ask the Liftie maintainer before pointing the app at `liftie.info`.** Never quietly aim traffic
   at someone's free hosted instance.

## Tooling — what's worth using on this project

Surveyed S1 against the installed skill + MCP set.

**High value:**
- **`apple-docs` (MCP)** — the single most useful tool here. `CoreLocation`, `CoreMotion`,
  `MapKit`, `ARKit`, `WorkoutKit`, background-execution rules. This project is deep in Apple
  frameworks Yomi never touched; do not answer sensor questions from memory.
- **`XcodeBuildMCP`** — build/sim loop. Note: **simulators can't produce real GPS or barometer
  data.** Everything in Phase 1 needs either recorded fixtures replayed through the pipeline or a
  real device on a real mountain. Plan for that; don't let a green simulator build read as "works".
- **`last30days`** — proper Reddit/HN/X sweep, which plain web search failed at in S1. **Re-run
  in-season (Nov–Mar)** — a 30-day window in August is the dead centre of the northern off-season.
- **`archify`** — the recording pipeline (sample → fusion → segmentation → run model) is genuinely
  worth a diagram once it exists.
- **`dataviz`** — this is a stats app. Read it before writing the first chart, not after.
- **`design`** — Yomi's design track paid off. Sunlight readability and glove-sized targets are
  *functional* requirements here, not polish.
- **`context7`** — live docs for MapLibre / GRDB.
- **`github` (MCP)** — repo, and reading Liftie/openskidata source directly.

**Later:**
- `architecture-decision-records` — good fit for the 3D-renderer decision (`RESEARCH.md` §9.1),
  which will have four rejected alternatives worth recording.
- `api-design` — only if D2 lands on "yes, backend".
- `code-review` / `simplify` / `security-review` — once there's code.
- `init` — regenerate this file properly once the Xcode project exists.
- `claude-in-chrome` — App Store / Play review scraping (WebFetch got 403'd on review aggregators
  in S1), and poking Liftie endpoints.

**Not useful here:** PubMed, Gmail, Calendar, Drive.

## Lessons carried over from Yomi

These cost real sessions to learn there. They apply here unchanged:

- **Never say "impossible" without asking the second question.** Yomi's Keiyoushi verdict was
  "architecturally impossible" for 70 sessions and turned out to be two bugs. In S1 I assessed live
  lift status as the expensive feature; Liftie already solves it. Assume the same is true of
  whatever looks blocked next.
- **Verify against live sources, not doc recall** — especially App Store compliance claims
  (Yomi S104) and framework capability claims.
- **Screenshot beyond the math.** Contrast and colour decisions need a real screenshot of the real
  default. Doubly true for an app used in direct alpine sunlight.
- **Rule out stale simulator state first** when behaviour doesn't match the code (Yomi S96:
  `cfprefsd` caches preferences at a device-level path that `simctl uninstall` does not clear).
- **A dead button is tooling flakiness, a state race, *or* a real capability gate** — check all
  three before concluding. `mobile-mcp`'s swipe `distance` parameter is ignored entirely.
- **Check `project.pbxproj` build settings before asserting a violation.** Every false positive in
  Yomi's S118 audit came from reasoning about Swift source without reading build settings.

**Learned here (S3–S5): all of it now lives in `WORKFLOW.md`,** as numbered rules R1–R20 with the
session that earned each one — evidence standards, threshold and filter discipline, on-device
verification, the session ritual, and the commit rule. Read it before writing a claim into a doc or
a threshold into the analyzer.
