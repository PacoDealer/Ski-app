# WORKFLOW.md — how we work on Vertical

Rules of process, written because we broke each one and paid for it. Every rule names the
session that earned it, so none of them are here on general principle. If a rule stops paying for
itself, delete it and say why.

Companion docs: `CLAUDE.md` (project context), `RESEARCH.md` (market + assumption register),
`ROADMAP.md` (plan + session log).

---

## 1. Evidence

**R1 — A claim in a doc carries a confidence marker or it is a bug.** `[V]` verified from a primary
source, `[S]` secondary, `[A]` our own judgement. Unmarked claims get repeated for five sessions as
if they were facts. *(S1–S5: the "3× larger than Slopes" line survived five sessions unmarked.)*

**R2 — Never stack two inferences.** S4 saw " Maps · Legal" on a competitor's screen, inferred
the framework, then inferred a capability of that framework, and declared a roadmap phase
unblocked. Both links were wrong. One inference is a hypothesis; two is fiction. After the first
inference, go find the primary source. *(S4 → corrected S5.)*

**R3 — Primary source or it didn't happen.** Apple's own WWDC session settled in one lookup what
five sessions of reasoning got backwards. Framework capabilities come from `apple-docs`, licences
from the LICENSE file, prices from the vendor's own page, competitor behaviour from their own
listing. A blog summarising Apple is not Apple. *(S5.)*

**R4 — Re-read anything a competitor controls before quoting it.** Slopes' price moved
$29.99 → $34.99 between S1 and S5 with nothing in our docs noticing. Prices, feature lists and
resort counts are re-checked when they matter to a decision, and stamped with the date they were
read. *(S5.)*

**R5 — State the sample size next to the number.** Everything in `RESEARCH.md` §5.1.1 is n=1: one
morning, one mountain, one phone. "Carve overstates by 10.1%" and "Carve overstated by 10.1% on the
one day we have" are different claims, and only the second one is ours to make. *(S5.)*

**R6 — When a claim turns out wrong, withdraw it where it lives.** Don't leave the original
standing and add the correction elsewhere. Edit the line, mark it withdrawn, point at the
correction. A doc that contradicts itself is worse than one that is simply out of date. *(S5.)*

---

## 2. Measurement

**R7 — Print the distribution before choosing a threshold.** `MAX_SPEED_ACC = 2.0` looked like a
tail cut and was sitting on the median: it discarded 57% of a healthy track. One `sorted()[len//2]`
would have caught it before it shipped. *(S5.)*

**R8 — Gate on the field that fails, not the field that correlates.** `speedAcc` rises with speed,
so gating on it censors exactly the samples you are trying to measure while passing genuinely
corrupt ones. `hAcc` is what actually degrades. Ask which failure you are excluding, not which
number looks like a quality score. *(S5.)*

**R9 — No filter deletes data silently.** A minimum-run-drop threshold quietly ate a 16 m tail and
under-reported the day. Every filter reports what it discarded; a run that discards a lot is a
signal that the filter is wrong for that mountain. *(S5.)*

**R10 — Cross-sensor agreement is not independent confirmation.** At 11:28:57 one physical event —
arriving at a building — spiked the barometer and scattered GPS in the same second. Two sensors
agreeing that something happened can mean one thing happened *to both of them*. Disagreement is the
informative case. *(S5.)*

**R11 — Look at the raw seconds around any headline number before believing it.** Carve published a
multipath glitch as its top speed for the day. The analyzer now prints the ten seconds around the
max for exactly this reason; read them. *(S5.)*

**R12 — Quote a ratio with its mechanism and its worst case.** "+136% vs. the naive method" is true
and misleading: it compares our gated peak against a one-second glitch, and on clean data the same
comparison is +9%. Lead with what goes wrong and why, not with the largest number the data will
support. *(S5.)*

**R12a — One rule, one implementation, and a harness that proves it.** The hAcc gate and the
descent-merge rule now exist twice: in `Tools/analyze.py` and in the app's `LiveMetrics`. Two copies
of a threshold drift the moment one is tuned, and the drift is invisible because both look right on
their own. `Tools/replay.sh` runs the **app's own source** over the fixtures so the two can be
diffed in one command; run it after touching either. Batch and streaming implementations of the
same rule are not the same algorithm written twice — they are two algorithms that owe you the same
answer. *(S6.)*

**R12b — Compare against the record the user keeps, not the screen we happened to photograph.**
Carve's live screen said 1,509 m at 13:39; its saved logbook entry for that same recording says
**1,625 m**. We had built a competitor delta (+10.4%) on a number the app itself no longer reports.
A live view is a work in progress and may be recomputed on save. Screenshot the *finished* record,
and when only a live one exists, label it as such in the table. *(S7.)*

**R12c — A metric that gets more correct can score worse against old ground truth. Check what the
tag actually meant before believing the regression.** Trimming the wait at the top out of run
durations dropped run-start scoring from 2/2 to 0/2, which reads as a broken change. It wasn't:
Martin taps "Top" when he *arrives*, 37–66 s before he pushes off, so the improved number was being
graded against an event nobody had labelled. Ask what the human was doing when they pressed the
button. *(S7.)*

**R13 — Never drop sensor data at capture time.** A discarded sample is gone forever; a filter can
be changed any time. Log everything raw, including obviously-bad values, and filter in
`Tools/analyze.py`. Every accuracy finding this project has made came from data an app with a
tidier pipeline would have thrown away. *(S3, vindicated S5.)*

---

## 3. Verification on device

**R14 — Verify the built product, not the build settings.** Xcode's Info.plist generator silently
ignores some `INFOPLIST_KEY_*` settings; a missing `UIBackgroundModes` crashed the app on START
with no warning anywhere. `plutil -p <built>.app/Info.plist`. *(S3.)*

**R14a — `plutil -extract` rewrites the file in place unless you pass `-o -`.** Checking
`UIBackgroundModes` in the built app with `plutil -extract UIBackgroundModes json <app>/Info.plist`
**replaced that Info.plist with the extracted array** — a 12-byte bundle-breaking file, produced by
the very command that was supposed to verify the bundle. It cost only a rebuild here because
DerivedData is disposable, but the same command aimed at `Vertical-Info.plist` destroys source.
Use `plutil -p` to look, and `-o -` whenever extracting. *(S6.)*

**R15 — A test fixture that isn't byte-identical to production output tests the fixture.** A
Python-written `"t": "end"` with a space made a Swift probe silently miss. Generate fixtures with
the production writer, or make the reader tolerant and prove it. *(S4.)*

**R16 — Simulators produce no GPS and no barometer.** A green simulator build says nothing about
this app. Anything sensor-shaped is verified on the device or replayed from a real fixture. *(S3.)*

**R17 — Make the app self-diagnosing.** Martin is on a mountain we can't debug from. The `DOPPLER`
tile existed so that a bad day would be caught on the first chairlift instead of at the end of the
day. Any new sensor dependency gets a readout before it gets a feature. *(S3.)*

**R18 — `mobile-mcp` cannot drive the physical device and cannot be made to on a free account.**
Do not retry. Use `devicectl` for launch/kill/file copy, and ask Martin for taps and screenshots.
*(S5, after S4 wasted a cycle on it.)*

---

## 4. Session ritual

**Start:** read `ROADMAP.md` → "⚡ START HERE". It is the handoff and it is kept current.

**During:** work the plan; when a fact is needed, check R1–R4 before writing it down.

**End of every advancement — not end of session:**
1. Update the doc the change belongs in (`RESEARCH.md` for findings, `ROADMAP.md` for plan and
   session log, `CLAUDE.md` only for context that outlives the session).
2. **Commit and push.** Standing authorization from Martin, 2026-09-01: commit and push after every
   advancement, no asking. A commit message says *why*, not what the diff already shows.
3. If the finding changes what someone should do next, it goes in "⚡ START HERE" too — that is the
   only section anyone is guaranteed to read.

**Martin's time is the scarce resource.** He is on the mountain; we are not. Batch everything that
needs his hands or his phone into one clearly-worded ask, and never ask for something we could have
checked ourselves. *(S5.)*

---

## 5. Product discipline

**R19 — The app auto-detects; the tag buttons are scaffolding.** Press START, pocket the phone.
Tags exist to produce ground truth for building the detector and come out of the UI when it works.
Martin corrected this once already; don't make him do it twice. *(S4.)*

**R20 — Don't claim accuracy we haven't measured, and don't claim it where we don't have it.**
Against Slopes we are within 1% — that is a tie, not a wedge, and marketing it as a win would be
the same sin we caught Carve committing. Against Carve the gap is real and demonstrable. Say the
true thing in each case. *(S5.)*

**R21 — Read the file before ranking the work.** S8 put a `ShareLink` in `SessionsView` at the top
of the no-snow list as urgent and unbuilt. It had shipped in the very first recorder commit, per
row *and* in the toolbar. A plan written about remembered code is a plan about the wrong codebase,
and the cost is not a wasted hour — it is a real item displaced from the top of a ranked list.
Open the file, then rank. *(S9.)*
