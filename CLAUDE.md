# Vertical — Claude Code Project Context

> Name is a **placeholder**. Pick a real one before the repo goes public.

## What this app is

A ski / snowboard day tracker for iOS that gives away everything Slopes charges for.

The bet is **not** "same features, zero dollars" — it's that the whole category has soft numbers
(documented 5–10% vertical overestimation, ~10 mph max-speed error, two phones side by side
disagreeing by 1,878 ft) and **nobody has fixed accuracy**. That's a pure engineering problem with
no dataset and no payroll behind it, which is exactly the kind of thing one careful developer beats
a 12-person company at. Free is the distribution strategy; accuracy is the product.

Slopes' paywall protects GIS headcount and per-resort data labour, not hard technology. The open
data is already **3× larger** than what Slopes sells (6,992 ski areas vs. ~50 hand-crafted).

## Project path

`/Users/martingamberg/Desktop/Projects/Vertical`

## Status

**➡️ Read `ROADMAP.md` → "⚡ START HERE" first. It has the handoff, the exact commands, and the
one open question.**

**S3 (2026-08-31): the app is built, signed, installed and recording on Martin's iPhone 17.**
He is at Ski Portillo, Chile until ~2026-09-07. The build expires ~2026-09-07 (free provisioning).

Verified on real hardware: barometer is excellent (0.85 m drift over 3.2 min stationary; pressure
matches Portillo's 2,880 m), location auth is Always, background recording is correctly entitled.
**Unverified: GPS outdoors** — indoors it ran at 0.34 Hz with Doppler speed valid on only 8 of 68
fixes. The first chairlift is the test; check the `DOPPLER` tile.

**Interaction model:** the app must **auto-detect** runs and lifts. Press START, pocket the phone.
The tag buttons in the UI are temporary scaffolding for building the detector and get removed once
it works — Martin flagged this and he's right.

## Key docs

- `RESEARCH.md` — market, competitor teardown, user complaints, data-source feasibility, technical risks. **Start here.**
- `ROADMAP.md` — current state, phases, open decisions, session log.

Deliberately kept to three docs. Yomi's five-doc split earned its keep after 120 sessions; starting
there on day one would be ceremony. Split more out when a doc actually gets unwieldy.

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

Learned here, S3:

- **Verify Info.plist keys by reading the built product, not the build settings.** Xcode's
  generator silently ignores some `INFOPLIST_KEY_*` settings — `UIBackgroundModes` and
  `UIFileSharingEnabled` both vanished with no warning, and the first caused an instant crash.
  `plutil -p <built>.app/Info.plist` is the source of truth.
- **Never drop sensor data at capture time.** A discarded sample is gone forever; a filter can be
  changed at any point. Log everything raw (including obviously-bad values like pre-start cached
  fixes) and filter in `Tools/analyze.py`.
- **Make the app self-diagnosing.** The `DOPPLER` tile exists because the alternative was Martin
  skiing a full day and only then discovering the data was unusable. On-device readouts beat
  post-hoc file analysis when the user is somewhere you can't debug.
