# Ski-app (working title: Vertical)

An iOS ski and snowboard day tracker that gives away everything Slopes charges for.

That sentence is the project, and it is Martin's: *"the objective of the app was basically have
Slopes and all its paid functions for free."* Accuracy was added during planning — *"make it more
accurate and maybe better if possible"* — and is a property we hold ourselves to, **not** the pitch.

> ⚠️ **This file used to say the opposite** — "the whole category has soft numbers … nobody has
> fixed accuracy … free is the distribution strategy, accuracy is the product". Withdrawn (R6).
> Two things falsified it. Against **Slopes** accuracy is a **tie**: 912 m to our 905 m on the
> first measured day, and across four graded days and 43 runs our per-run vertical sits +0.63% from
> its figures. And the one gap that did survive — our vertical reading ~3% under Slopes inside its
> own run windows — turned out in S17 to be **Slopes reading high, not us reading low**: it takes
> max-minus-min of *GPS* altitude, we take the barometer top-to-bottom, and a control on windows
> where the barometer says nothing moved shows GPS max−min inventing 8.5 m of phantom vertical out
> of nothing. The category's soft numbers are real — **Carve** is +10.1% on vertical and published
> a multipath glitch as its top speed for the day — but Slopes is not the one with them, and we
> should never have implied it was.

## Where things stand

Four graded ski days at Portillo (1–4 September 2026), 43 runs graded run-by-run against Slopes'
own `.slopes` exports. The fourth was **held out** — every threshold frozen and installed on the
phone before it was skied — and the rules predicted it.

**The app records, and it now also reports.** Per-run vertical, distance, duration, top speed and
average speed on a session detail screen, plus the day's track drawn over a base map and coloured
by speed. Auto-detection of runs is validated against an external commercial database, not against
our own hand tags: our five lift clusters map 1:1 onto Slopes' five internal `trackIDs`, 21 of 21
rides.

**Battery: 6.5–6.7 %/h**, replicated over three full days of 5.4–6.9 h, 7–9 discrete 5% steps each.
A 7-hour day costs roughly 45% of an iPhone.

**The standing caveat (R5): one resort, one phone, one week.** Capture ended 5 September 2026, so
that is now permanent rather than pending. Nothing here has been tested on a second mountain.

## Repo layout

| Path | What |
|---|---|
| `RESEARCH.md` | Market research, competitor teardown, user complaints, data-source feasibility, technical risks, and §13 the assumption register. **Start here.** |
| `ROADMAP.md` | Current state, phases, open decisions, session log. Its "⚡ START HERE" is the handoff. |
| `WORKFLOW.md` | The rules of process (R1–R36b), each tied to the session that earned it |
| `CLAUDE.md` | Project context and tooling notes |
| `iOS/` | The app. See `iOS/README.md` for build + on-mountain checklist |
| `Tools/` | Offline harnesses, stdlib-only Python. `analyze.py` is the accuracy harness; `grade.py` grades us against Slopes; `parity.py` proves the app's Swift and the Python agree |

## What the app computes, and what it refuses to

It captures first: every `CLLocation`, every barometer reading and 25 Hz device motion, appended to
a JSONL file as it arrives, at full fidelity, unprocessed, `fsync`'d, append-only. Analysis can be
rewritten twenty times and replayed against saved files; a day skied without capture is gone.

On top of that it computes the honest numbers — and the discipline is that the app, the offline
analyzer and the replay harness run **one implementation of each rule**, with `Tools/parity.py`
diffing them run-by-run so they cannot drift apart quietly:

- **Vertical is measured top-to-bottom per run**, never by summing deltas. Summing every barometric
  step reads +13.8% on a real day; summing GPS altitude reads +65.5%.
- **Top speed is the Doppler field, gated on horizontal accuracy**, never differentiated positions.
  Differentiating positions on day 4 gives 204.8 km/h against the true 75.7.
- **Distance steps over a decimated trail**, because at 1 Hz a skier moves ~10 m between fixes while
  the median fix is ±7 m, and scatter only ever adds.
- **Display layers may smooth; published numbers may not.** The map's colour uses a rolling median
  and a percentile range. No reported figure does, and a test fails if that boundary moves.

The recording is built around the failure mode that produces every competitor's 1★ reviews: a
crash, force-quit, or dead battery costs a few seconds and recovers silently — it never asks
"resume or finish?", the prompt that triples people's run totals elsewhere.

## Data sources

- [OpenSkiMap / openskidata](https://github.com/russellporter/openskidata-processor) — **ODbL**.
  6,992 ski areas, 96,693 runs, updated daily. Attribution is required and share-alike applies to
  derived databases. **Not yet ingested** — the speed map deliberately needs no trail database.
- [Liftie](https://github.com/pirxpilot/liftie) — BSD-3. Live lift status.
  **Ask the maintainer before pointing anything at the public instance.**

## Status

Not released. Not affiliated with, or derived from, Slopes or any other app.
