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

**R18a — `devicectl copy from` stops at exactly 40,000,000 bytes, and calls it a network error.**
The message is `CoreDeviceError 7000` / `NSPOSIXErrorDomain error 60 — socket closed unexpectedly`,
which reads like flakiness. It is not: four attempts and a whole-directory copy all produced
byte-identical 40,000,000-byte files with the same md5, while a 10 MB file in the same run came
across whole. **Always check the size of what you pulled against the size `devicectl device info
files` reports.** At ~7.6 MB/h with motion capture on, the cap is hit around **5¼ hours** — i.e.
partway through any full ski day. The prefix is still good data: it is plain JSONL and the reader
already tolerates a torn final line. *(S12.)*

**R18b — Pull the file while the session is still open; don't wait for STOP.** The format is
append-only and fsync'd, so a copy taken mid-recording is a valid prefix and costs nothing. S11
ended with a full ski day sitting on a phone whose provisioning fuse dies in six days, because the
handoff said to ask Martin to press STOP first. Copy first, ask second. *(S12.)*

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

**R22 — A test suite that has never failed has not been tested.** Nineteen green tests on the first
run is evidence about the tests, not about the code. Break the rule on purpose — move the threshold,
delete the guard — confirm the suite goes red in the place you expect, then put it back. S9 set
`mergeAscentM` to 1.0, watched the exact S5 bug fail three tests including the day total, and only
then believed the suite. *(S9.)*

**R23 — A live tile and the total beside it must count the same events.** The screen showed
VERTICAL provisionally (it added the descent that was closed-but-still-mergeable, plus the leg still
in progress) and RUNS conservatively (completed runs only). Both were individually defensible and
together they were wrong: on 2026-09-02 the phone read **7 runs / 1,386 m** where a replay of the
same bytes read **8 runs / 1,386 m**, and standing at the bottom after the last run of the day it
was **two** descents low, not one. Nobody caught it on the mountain because each number looks
plausible alone. When two numbers on one screen describe the same events, derive them from the same
provisional state, and assert it in a test that never calls `finish()`. *(S12.)*

**R24 — A rate needs the interval it was measured over, not the endpoints.** `analyze.py` read
75% → 50% over 5.25 h and printed 4.8 %/h. The phone had been on a charger for ten minutes in the
middle; excluding that time gives **7.0 %/h**, ~46% higher. The file already recorded
`batteryState` on every sample — the bug was arithmetic that assumed monotonicity, not a missing
measurement. Before dividing a delta by a span, check the file for the thing that would invalidate
it. *(S12.)*

**R25 — A guard against division by zero is not a guard against division by nearly zero.** The
naive-max-speed estimator skipped fix pairs with `dt <= 0` and then divided by `dt`. The pairs that
broke it had positive intervals — CoreLocation redelivers fixes microseconds apart, 384 of them
under 0.2 s on 2026-09-02 and the tightest **95 µs** — so a metre of ordinary scatter came out as
**341,659 km/h**. The condition to test is not "is the denominator zero" but "is this denominator a
sampling interval that could carry the quantity I am computing". Sensor streams deliver duplicates,
batches and replays; assume it. The sting: this was the number we quote to describe *other apps'*
error, and publishing a glitch as a speed is the exact thing S5 caught Carve doing. *(S13.)*

**R26 — Read the expiry off the artifact, not off the calendar.** "Reinstalling resets the 7-day
provisioning fuse" was in the docs from S7 and was never true. `-allowProvisioningUpdates` reuses
any cached profile that has not yet expired, so S13's reinstall produced a brand-new build signed
with a three-day-old profile: installed 3 Sep, dead 7 Sep, on the last ski day of the trip. The
install date told us nothing; `security cms -D -i <app>/embedded.mobileprovision` told us
everything. The general form: when a deadline is a property of a *file*, check the file. Anything
you derive from "I did the thing that usually refreshes it" is an assumption wearing a date.
*(S13.)*

**R27 — Two systems' lists of the same events line up in time, not by index.**
`Tools/falsetop.py --score` zipped our runs against Slopes' itemised runs positionally. It worked
for two days because both days happened to agree on the count. On 2026-09-03 we detected 9 runs to
Slopes' 8 — a real and *benign* difference, we split one of its runs across a 4-minute mid-run gap
and the halves sum to +0.7% of its figure — and every row from the third on was scored against the
wrong run. The report printed a **−11,964 s** start error and a "mean" of 1,974 s, which is not a
number any process produces; it was an alignment artifact. Pair by overlap, allow many-to-one, and
print the group size so a split is visible as a split. A comparison harness that cannot survive the
two lists disagreeing is measuring its own indexing. *(S14.)*

**R28 — Calibrate an estimator against a reference that isolates it, or you will fit the wrong
thing.** S14 added per-run distance and tuned `MIN_DISTANCE_DT` so our day totals matched Slopes'.
That gave 3.0 s and looked excellent: −1.5% / +0.1% / +1.5% across three days. It was two errors
cancelling. Our runs end ~60 s later than Slopes' — we deliberately keep the runout — so the day
total mixes a *distance estimator* question with a *segmentation* question, and the knob was
quietly absorbing the second. Re-running the identical sweep over **Slopes' own run windows**, with
segmentation taken out of the comparison, moved the optimum to 2.5 s and dropped the per-run error
from 8.8% to 1.6%. The generalisable form: before fitting a parameter, ask what else varies between
you and the reference, and construct a comparison where only the thing you are fitting can move.
A fit that lands on zero while two known differences point opposite ways has not been validated —
it has been balanced. *(S14.)*

**R29 — When a signal won't separate, try the same method on the part of the day you weren't
looking at.** S14b spent a session on run comparison and concluded there was no threshold: the
shape scores across descents were a continuum — 11, 21, 25, 30, 35, 43 m — with no gap to cut at,
which was read as a fact about the resort's overlapping corridors. It was a fact about *skiers*.
People do not repeat a line down a piste. Run the identical resample-and-compare over the **lift
rides** in the same files and the same metric produces two clean populations, 3–109 m within a lift
against 169 m and up across lifts, because a cable hangs where it hangs. The lift then partitions
the runs, which is what the run question needed all along. The generalisable form: a metric that
fails to separate has been tested on one class of object, not proven useless — before discarding
it, ask whether some *other* object in the same data is more repeatable, and whether identifying
that object answers the original question indirectly. Half a ski day is ascending. *(S15.)*

**R29b — A commercial competitor's export can validate your model better than your own hand tags.**
The lift clustering was not scored against anything Martin tagged. Slopes puts a stable per-lift
UUID (`trackIDs`) on every `<Action type="Lift">` in its export and nothing on its runs — a slice
of the resort database its paywall protects, handed over free. Clustering our own rides recovered
that partition exactly: five clusters, five UUIDs, 21/21, no cluster spanning two IDs and no ID
split, plus two rides Slopes' own database failed to identify that we placed anyway. Hand tags have
Martin's 18 s glove-tap precision and n=1 attention; an external database has neither problem.
Before building a labelling exercise, read the reference export attribute by attribute and check
whether the answer is already sitting in it. *(S15.)*

**R30 — An identifier a human types against must be unique, and duplicate-check it before you ask.**
The run-labelling page keyed every descent as `09-01 r1`, built from the date and the run index. It
is not unique: 1 September is **two** recording sessions, so `09-01 r1` named both the 10:39 descent
off La Laguna and the 12:48 descent off Plateau. The page stored labels under that key, so each of
the three colliding pairs silently overwrote the other, and Martin's 1 September answers came back
identical in pairs and unusable — his work, wasted, by a key. A `collections.Counter` over the
labels would have caught it in one line before the sheet was ever handed over. Any id shown to a
person, or used as a storage key, gets that check at the point it is generated. *(S15b.)*

**R31 — When the labels come back and disagree with the metric, read the disagreement before
touching the metric.** Martin's labels put a pair he named identically at 59 m and a pair he
described differently at 43 m, so no threshold on mean deviation reproduces his answers. The first
instinct is that the metric needs tuning. It does not: he had not written piste *names*, he had
written *routes* — "Las Lomas, a Canarios, hasta el hotel" — because at Portillo a descent links
several pistes, and two descents can share five eighths of their line and part at the bottom.
Splitting the separation into eighths along the track makes all four cases legible where the mean
ranked two of them backwards. The generalisable form: a label set that contradicts your metric is
usually telling you the *unit* is wrong, not the threshold. *(S15b.)*

**R31b — Normalise free text before comparing it, and distrust a verdict that improves.** The first
scoring run compared labels with `==`, so "Plateau a lomas" and "Plateau a Lomas" were two different
pistes. That removed the single overlapping pair and printed **SEPARATED**, an empty 19 m band, and
a threshold of 34 m — a confident, shippable, wrong number, produced by a capital L. The tool
existed specifically to refuse invented thresholds and it nearly emitted one. When a comparison
suddenly reports a cleaner result than the data felt like, suspect the comparison. *(S15b.)*
