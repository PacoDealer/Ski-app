# Vertical — Claude Code Project Context

> Name is a **placeholder**. Pick a real one before the repo goes public.

## What this app is

A ski / snowboard day tracker for iOS that gives away everything Slopes charges for.

The bet is **not** "same features, zero dollars" — it's that the whole category has soft numbers
(documented 5–10% vertical overestimation, ~10 mph max-speed error, two phones side by side
disagreeing by 1,878 ft) and **nobody has fixed accuracy**. That's a pure engineering problem with
no dataset and no payroll behind it, which is exactly the kind of thing one careful developer beats
a 12-person company at. Free is the distribution strategy; accuracy is the product.

Slopes' paywall protects GIS headcount and per-resort data labour, not hard technology. Open trail-map data
(OpenSkiMap, 6,992 ski areas) is free and worldwide — but **do not repeat the old "3× larger than
Slopes" line**; S5 found it was built from two unrelated numbers and withdrew it (`RESEARCH.md`
§13, A2).

## Project path

`/Users/martingamberg/Desktop/Projects/Vertical`

## Status

**➡️ Read `ROADMAP.md` → "⚡ START HERE" first. It has the handoff, the exact commands, and the
one open question.**

**S5 (2026-09-01): the first outdoor day is recorded, and the three-app head-to-head is done.**
GPS outdoors is green (1.00 Hz, Doppler valid on 3,342/3,342 fixes, hAcc median ±8 m, 5.5%/h
battery). Martin is at Portillo until ~2026-09-07; the build expires ~2026-09-07 (free
provisioning).

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

Four docs. The fourth was added in S5 because three separate false claims had survived five
sessions, and "be careful" is not a process. Split more out when a doc actually gets unwieldy.

## Tech stack (provisional — nothing committed until Phase 0)

- Swift + SwiftUI, iOS 26 target (matching Yomi's no-back-deployment stance)
- `CoreLocation` + `CoreMotion` (`CMAltimeter`) — the recording engine
- Map renderer: **undecided.** MapLibre Native has no 3D terrain on iOS yet — see `RESEARCH.md` §9.1
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
