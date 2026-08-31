# Ski-app (working title: Vertical)

An iOS ski and snowboard day tracker that gives away everything Slopes charges for.

The bet is **not** "same features, zero dollars". It's that the whole category has soft numbers —
documented 5–10% vertical overestimation, ~10 mph max-speed error, two phones side by side
disagreeing by 1,878 ft — and **nobody has fixed accuracy**. That's a pure engineering problem with
no dataset and no payroll behind it, which is exactly what one careful developer beats a 12-person
company at. Free is the distribution strategy; accuracy is the product.

## Where things stand

Early. There is a working raw-sample recorder and an offline accuracy harness. There is no map, no
stats UI, and no analysis in the app itself — by design, see below.

## Repo layout

| Path | What |
|---|---|
| `RESEARCH.md` | Market research, competitor teardown, user complaints, data-source feasibility, technical risks. **Start here.** |
| `ROADMAP.md` | Current state, phases, open decisions, session log |
| `CLAUDE.md` | Project context and tooling notes |
| `iOS/` | The app. See `iOS/README.md` for build + on-mountain checklist |
| `Tools/analyze.py` | The accuracy harness — replays a session and compares methods |

## Why the app does no analysis

It records, and that is all it does. Every `CLLocation` and every barometer reading is appended to
a JSONL file as it arrives, at full fidelity, unprocessed, `fsync`'d, append-only.

Analysis can be rewritten twenty times and replayed against saved files. A day skied without
capture is gone forever. So capture is the app's only job until the maths is settled, and the
recording is built around the failure mode that produces every competitor's 1★ reviews: a crash,
force-quit, or dead battery costs a few seconds and recovers silently — it never asks
"resume or finish?", the prompt that triples people's run totals elsewhere.

## Data sources

- [OpenSkiMap / openskidata](https://github.com/russellporter/openskidata-processor) — **ODbL**.
  6,992 ski areas, 96,693 runs, updated daily. Attribution is required and share-alike applies to
  derived databases.
- [Liftie](https://github.com/pirxpilot/liftie) — BSD-3. Live lift status.
  **Ask the maintainer before pointing anything at the public instance.**

## Status

Not released. Not affiliated with, or derived from, Slopes or any other app.
