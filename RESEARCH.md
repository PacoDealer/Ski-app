# RESEARCH.md — Ski / snowboard tracking apps

Master research doc for the project working-titled **Vertical** (name is a placeholder — see §12).

**Session:** S1 — 2026-08-31. Research only, no code.
**Goal of this doc:** know the market cold before writing a line of Swift. What exists, what people
love, what they hate, what data is legally free, and which of Slopes' paywalled features are
genuinely hard vs. merely gated.

**Confidence markers used throughout:**
- **[V]** verified — read directly from the primary source (repo README, App Store review feed, dev's own blog)
- **[S]** secondary — reported by a review site / forum summary, not independently confirmed
- **[A]** assumption / my own engineering judgement, not sourced

---

## 1. Method + limits

Sources swept: App Store (Slopes' live customer-review RSS feed, read directly), Google Play
listings, ski forums (SkiTalk, Snowjournal, Newschoolers, AlpineZone, Snowboarding Forum),
comparison blogs (OnTheSnow, SkiMag, Piste's own blog, Courchevel.VIP, Granite Alpine Lab),
GitHub (OpenSkiMap/openskidata-processor, Liftie, openskistats), the Slopes founder's own dev blog
("Slopes Diaries", Curtis Herbert), and MapLibre's release notes/newsletters.

**Known gaps in this sweep — worth closing later:**
- Reddit itself returned poorly through search (results kept redirecting to AlternativeTo). Direct
  r/skiing, r/snowboarding, r/icecoast, r/backcountry threads have **not** been read. The
  `last30days` skill is installed and can do this properly — but note it's late August, i.e. the
  dead centre of the northern off-season, so a 30-day window will be thin. **Better to re-run this
  in November–March.**
- No Google Play review feed was read directly (Play has no public RSS equivalent); Android
  complaints below are **[S]** from review-site summaries.
- No hands-on install of any competitor. Yomi's S114 precedent says actually building and running
  the competitor surfaces things no amount of reading does — worth doing for Slopes free tier,
  Ski Tracks, and Open Ski Map before committing to a design.

---

## 2. The field

| App | Platform | Price | What it's for | Weakness |
|---|---|---|---|---|
| **Slopes** | iOS + Android + watchOS | Free tier; Premium **$34.99/yr, $59.99 family** (re-read 2026-09-01), plus in-app day and week passes | The category leader. Auto lift/run detection, hand-made trail maps, 3D, social, leaderboards | Key features paywalled — incl. *run names on the map* **[S]**; Android lags iOS |
| **Ski Tracks** | iOS + Android | ~$1.99 one-time | The old guard. Speed/distance/vertical/altitude, GPX export, 3D replay, offline | No maps-as-navigation, no social, plain UI |
| **Ski Tracker** (exatools) | Android-first | ~$1.99 / freemium | Stats + GPX export free | No trail maps, no social |
| **We Ski & Snowboard** | iOS + Android | Freemium | 3D trail maps, ~2,000 resorts, lift wait times, leaderboards, live friend location | Less polished; smaller community |
| **Piste** | iOS + watchOS | ~£14.99/yr | Europe-focused piste maps, live friend sharing, challenges | Europe only, thin social |
| **Skiline** | iOS + Android | Free | Resort-lift-scan based day stats | Only works at partner resorts |
| **Strava** | iOS + Android | Freemium | General fitness; absorbed some FATMAP | **Counts chairlift rides as uphill skiing** — a real, cited reason people leave it for Slopes **[V]** |
| **FATMAP** | — | — | **Dead.** Strava acquired it and shut it down 1 Oct 2024 | See §3.2 — this is the biggest opening in the market |
| **OUTMAP / OnX Backcountry / CalTopo / Gaia** | iOS + Android | Paid | Backcountry route planning, high-res winter imagery | Not resort-day trackers; different job |
| **Open Ski Map** | iOS | Free | OpenSkiMap data browser: search any run/lift by name, offline download | **Map only — no tracking, no stats.** Proof the data works on iOS |
| **iSKI / OnTheSnow** | iOS + Android | Free (ad/affiliate) | Resort info, snow reports, webcams | Not trackers |

### 2.1 The one-line read

The market splits three ways and **nobody owns the middle**:

1. **Trackers** (Ski Tracks, Ski Tracker) — accurate-ish, cheap, ugly, no maps.
2. **Map/navigation** (Open Ski Map, OUTMAP, OnX) — great maps, no tracking.
3. **Slopes** — the only one doing both well, and it charges for it.

A free app that does both well is a genuinely unoccupied position.

### 2.2 Carve — the position is no longer unoccupied (found S4, 2026-08-31)

Martin saw an ad for something he read as "Carver". It resolves to two different products, and
only one of them matters to us.

**[Carve: Ski & Snowboard](https://apps.apple.com/gb/app/carve-ski-snowboard/id6758206264)**
(App Store id `6758206264`, developer **Angel Terziev**, ©2026, iOS 17+, also Mac/visionOS) is a
solo-developer ski tracker that is **free with no paywall at all** — monetised entirely by
optional donation IAPs (£1.99 "buy me a coffee" up to £19.99 "buy me a ski pass"). Its shipped
feature list:

- automatic lift detection
- real-time speed / altitude / distance / vertical
- **3D replay over real terrain elevation with satellite imagery draped on it**, cinematic drone
  camera and free-fly
- speed heatmaps — colour-coded GPS traces showing where top speed happened
- run-by-run comparison with synchronised altitude and speed profile charts
- **GPX import from other ski apps**
- local-first storage, optional iCloud backup

That is a large fraction of Phases 1, 2, 3 and 5 of this roadmap, already shipping, at the same
price. §2.1's "genuinely unoccupied position" was written before it existed and is now wrong as
stated. Being wrong here is worth more than being early: it says the *feature* framing of this
project was never the defensible part.

**Does it use the barometer? ANSWERED, S5 (2026-09-01): no.** After Carve recorded a real **1 h
05 m** session at Portillo, it is **still absent** from Settings → Privacy & Security →
Motion & Fitness on Martin's phone. iOS lists an app there once it requests motion access, and
`CMAltimeter` cannot deliver a sample without it — so Carve never started the altimeter. **Its
altitude is GPS-only.** (S4's version of this check was void: Carve's only session then was 00:00
long, so the prompt could not have fired. **Slopes is present in that same list**, which is what
validates the method.)

**And we can reproduce its number.** Replaying our own raw fixture from the same morning with the
barometer switched off:

| Method, on our GPS altitude | Result |
|---|---|
| Summed deltas, unfiltered | 1,227 m |
| **3 m hysteresis, summed** | **992 m** |
| 5 m hysteresis, summed | 974 m |
| Run-segmented (any hysteresis) | 928–933 m |
| *Carve reported* | *996 m* |

**GPS altitude + ~3 m hysteresis, summed, lands within 0.4% of what Carve printed** — and the
run-segmented variants do not. So Carve smooths GPS altitude and sums it; it neither uses the
barometer nor measures runs top-to-bottom. Its **+10.1%** against our 905 m is precisely the cost of
those two choices, and this is now corroborated three independent ways: the permission list, the
numeric reproduction, and its top speed being a multipath sample we can point at (§5.1.1).

**This is the clearest result the project has produced.** We characterised a competitor's entire
altitude pipeline from the outside, using nothing but our own raw capture and one settings screen.

**What it does not claim, anywhere:** accuracy. No barometric fusion, no Doppler-gated speed, no
error bars, no statement about vertical being measured rather than integrated. It reports the same
GPS-derived numbers as everyone else, and §5.1's category-wide 5–10 % overestimate is presumably
inherited whole. **The thesis in `CLAUDE.md` survives this intact and is now the *only* thing
holding the project up** — which is clarifying, not fatal.

Also relevant: it has **too few ratings for the App Store to show an overview**. It is brand new
and has no traction or community. This is a peer, not an incumbent.

**Three things worth taking from it:**

1. **It answers §9.1 outright — it is built on MapKit.** Its replay screen carries the
   " Maps · Legal" attribution (observed on Martin's phone, 2026-08-31). So the solo developer
   did not solve the 3D-terrain problem: **he sidestepped it, because Apple ships it.** §9.1
   framed MapLibre's missing iOS terrain as *the* blocker; the framing was wrong, and D4 is
   much closer to decided than the roadmap says. See the amendment in §9.1.
2. **GPX import** is a cheap, high-leverage switching-cost lever we hadn't considered: it lets
   someone bring their history over instead of starting from zero. Add to the backlog.
3. **Donation-tier IAPs** are a proven-enough monetisation shape for a genuinely free app, and
   consistent with "free is the distribution strategy" — no paywall decisions needed.

**Not the same product:** [Carv](https://getcarv.com/products/carv) (no "e") is a ~£200 in-boot
pressure-sensor hardware coach that scores technique. Different category, different price, not a
competitor — though its content marketing ranks for every "best ski app" query, which is likely
where the ad came from.

**Snowduck**, surfaced alongside, advertises **~1 % battery per hour**. Unverified, and probably a
low sample rate rather than cleverness, but it's a public number to measure ourselves against —
see §9.4.

---

## 3. Slopes — the actual target

### 3.1 The free/premium split (from Martin's screenshot, 2026-08-31)

Everything behind the paywall:

- Per-run stats & advanced analytics
- Run comparisons (you vs. you, you vs. friends)
- Run replays with speed heatmaps
- Hand-crafted trail maps ("detailed, accurate, up-to-date")
- 3D maps
- Live lift status & grooming reports (60+ resorts)
- Offline access to trail maps
- Search trails by name or difficulty
- Replay your tracks in AR

Pricing shown: annual, plus a **$3.99 Day Pass** that "auto-activates when you record."

Free tier keeps: unlimited recording, key stats & day summaries, friend finding, snow conditions,
season & lifetime overviews, ad-free. **[S]**

### 3.2 Business reality — why this matters

- Slopes is not a hobby project. Curtis Herbert (ex-Apple engineer) had **12 full-time staff as of
  June 2025** **[V]**, with dedicated GIS and resort-data staff.
- One paywall-tracking site estimated **~$20K/month** from the paywall (March 2025) **[S]**.
- The founder blogs openly about the model: he **shifted to consumable IAP (day passes), which
  became 75% of sales** — annual subscriptions didn't fit a big chunk of the market (people who ski
  3 days a year) **[V]**. He also A/B-tested the paywall heavily and found shorter copy converts
  better, and moved upsells inline/contextual rather than buried in settings **[V]**.
- The hand-crafted trail maps started at **~30 resorts at launch, ~50 by end of that season** **[V]**
  — i.e. the "hand-crafted" moat is a headcount moat, not a technology moat, and it took years.

**Implication for us:** the paywall isn't protecting hard technology. It's protecting *payroll* —
GIS labour and per-resort data deals. Everything Slopes gates that is **computed on the user's own
GPS track is cheap to give away**. Everything that requires *someone maintaining a dataset per
resort* is where "free forever" gets expensive. That line runs right through the middle of the
premium list — see §8.

### 3.3 The FATMAP hole

Strava bought FATMAP and killed it on **1 Oct 2024**. The 3D winter map mode, guidebooks, waypoints,
adventures and grades did **not** survive into Strava **[V]**. Consensus across the coverage is that
nothing has replaced it — "nothing fully matches what FATMAP built over 10 years with a 50-person
team" **[S]**. OUTMAP is the closest and is still in beta.

There is an unusual amount of unserved demand for *good 3D winter mapping* right now, and it is not
a demand Slopes fully serves either (its 3D is resort-map 3D, not terrain/backcountry 3D).

---

## 4. What people actually like (keep these — they're table stakes)

Drawn from the live App Store review feed **[V]** and forum threads **[S]**:

1. **"Leave it in your pocket."** Automatic lift/run detection with zero interaction is the single
   most-praised thing. Nobody wants to tap "start run."
2. **Battery honesty.** Every well-reviewed app in this category advertises low power. Users
   explicitly choose apps on this. Ski Tracks' whole reputation is "award-winning low power."
3. **Season & lifetime totals.** The retention hook. Multiple reviewers describe skiing *more* to
   move a number. One went from twice a year to 23 days in 6 weeks **[S]**.
4. **End-of-season recap slideshow.** Repeatedly, specifically loved.
5. **Friend leaderboards.** Named in a large share of positive reviews.
6. **Top speed.** The one stat everyone shows their friends. It's the app's word-of-mouth engine.
7. **Works with no signal.** Non-negotiable — half of skiing happens without bars.
8. **Sunlight-readable, glove-usable UI.** Slopes explicitly ships higher-contrast design for this **[V]**.
9. **Responsive human support.** Cited a lot. Not replicable by a solo dev — don't try to compete here.

---

## 5. What people complain about — the actual opening

Ranked by how often it comes up and how fixable it is.

### 5.1 Accuracy. This is the biggest one, and it's industry-wide.

The strongest, most specific complaints in the entire sweep:

- Tracking apps (Garmin Connect, Ski Tracks) **overestimate vertical by 5–10%** **[S]**
- Users observe **elevation drift**: "the top elevation keeps getting higher and the bottom does the same" **[S]**
- **The faster you ski, the less vertical gets recorded** per run **[S]** — a sampling-rate artefact
- Ski Tracks records **max speed ~10 mph high** on every run **[S]**
- **Two people skiing side by side got an 1,878 ft vertical difference** **[S]**
- Slopes on Android has "a flaw in its GPS data collection which causes random elevation change in
  the magnitude of hundreds of feet, and random speed" **[S]**
- One App Store reviewer directly questions max-speed accuracy **[V]**
- Users complain **chairlift and lift-line time is included in average speed** **[S]**

**This is the wedge.** Nobody in this category has credibly solved accuracy, everybody knows the
numbers are soft, and it's a pure *engineering* problem — no dataset, no payroll, no per-resort
labour. It's exactly the kind of problem a careful solo dev can beat a 12-person company at, because
it doesn't scale with headcount.

Concretely, the fixes are known **[A]**:
- Barometric altimeter (`CMAltimeter.relativeAltitude`) fused with GPS altitude, not GPS alone.
  Barometric is ~±0.3 m relative vs. GPS's ±10 m. Must be drift-corrected against GPS over long
  windows to handle weather pressure changes (this is the "wild weather day" complaint).
- Max speed from **Doppler** (`CLLocation.speed`, which is receiver-derived), never from
  differentiating successive positions. Reject samples where `speedAccuracy < 0` or is poor. This
  alone kills the "+10 mph" bug.
- Vertical measured **per-run bottom-to-top**, not by summing every negative delta (summing noise
  is what produces the 5–10% overestimate and the drift).
- Higher sample rate on descent than on lift (fixes "faster skiing loses vertical" *and* saves battery).
- Average speed computed over **descent time only**, excluding lifts and lift lines.

### 5.1.1 The head-to-head, finally measured (S5, 2026-09-01, Portillo)

Everything above §5.1 is forum posts and star ratings. This is the first time the claim has been
tested: Martin recorded **the same morning simultaneously on Slopes, Carve, and Vertical**, and
Vertical's raw JSONL (`Data/fixtures/2026-09-01_portillo_s1.jsonl`, 3,342 fixes at 1.00 Hz,
hAcc median ±8 m) is the referee — because unlike the other two, we can open it.

**Windows are not identical.** Vertical recorded 10:35:07–11:30:39 local and **Martin confirmed he
stopped skiing at 11:30** — nothing was missed after that. Slopes was still recording at 11:46
(1 h 11 m elapsed) and Carve was paused at 1:05:43, so both had ~16 minutes of standing around
inside their totals. Timestamps line up where they can be checked: Slopes' Run 1 is stamped
**10:38** and ours starts 10:39:15 (Martin's hand tag "Top" is 10:38:59); Slopes' Run 2 is stamped
**10:57** and our Run 2 starts **10:56:57**.

| Whole morning (4 real descents) | Slopes | Carve | Vertical |
|---|---|---|---|
| Runs reported | 5 | 4 | 4 |
| Vertical | 912 m | 996 m | **905 m** |
| Distance | 5.1 km | 5.69 km | 5.58 km (descents only) |
| Top speed | 53.8 km/h (run 1 only, free tier) | 66.8 km/h | **64.7 km/h** |
| Elapsed | 1 h 11 m | 1 h 05 m | 55 m |

**Run 1, the only run Slopes shows without paying:**

| Run 1 | Slopes | Vertical | Δ |
|---|---|---|---|
| Vertical | 415 m | 407 m | +2.0% |
| Distance | 2.1 km | 2.17 km | −3.2% |
| Top speed | 53.8 km/h | 52.6 km/h | +2.3% |
| Duration | 5 m 26 s | 6 m 18 s (hand tags: 6 m 36 s) | — |

Five findings, in order of how much they change the plan:

1. **Slopes is good, and the "5–10% high" folklore does not describe it.** Over the whole morning
   it is **912 m to our 905 m — 0.8%**. On run 1 it agrees to 2.0% on vertical and 2.3% on top
   speed. Any marketing that says Slopes' numbers are wrong is not supported by this day's data.
   What we can still say is narrower and true: we produce the same numbers *from a file the user
   can inspect*, and we do it for free.

2. **Carve overstates vertical by +10.1%** on the same four descents (996 m vs 905 m), which is the
   §5.1 category error showing up in a shipping 2026 app — **and we know exactly why.** It is
   GPS-only (absent from Motion & Fitness after a real 1 h 05 m recording) and does not
   run-segment: replaying our own GPS altitude with 3 m hysteresis and summing gives **992 m**
   against its printed 996 m. See §2.2.

3. **Carve's 66.8 km/h top speed is, to the decimal, a corrupt sample in our own file.** At
   11:28:59 our receiver reported Doppler 66.8 km/h with hAcc degraded to 22.3 m, in the middle of
   a four-second burst that also contains a **42.5 m one-second position jump** (=153.1 km/h, and
   the source of this project's own "naive method" headline). Carve reported the glitch as the
   day's top speed. That is the most concrete accuracy failure the project has found in a
   competitor, and it was found by having the raw data.

4. **Slopes' fifth run does not exist, and we know exactly where it came from.** Martin skied four
   descents. At **11:28:57**, arriving at the base, the barometer jumped **+4.1 m in two seconds**
   and GPS scattered in the same instant — one physical event (a building) hitting both sensors.
   That blip splits the last descent into 296 m + a short tail. Slopes counted the tail as run 5.
   Our own analyzer did the same thing and was *worse*: it split the run **and then silently
   deleted the orphan tail** for being under the 30 m run threshold, reporting the day 16 m short
   (895 m instead of 905 m). Both are now fixed — see ROADMAP S5. The lesson generalises: **a
   single physical event corrupts every sensor at once, so cross-sensor agreement is not
   independent confirmation.**

5. **Slopes' printed run-1 fields do not reconcile with each other.** 2.1 km in 5 m 26 s is
   23.2 km/h, but it prints 31.0 km/h average — so its average is over some unstated moving-time
   subset (our own moving-average for that run, gated at >1 m/s, is 24.0 km/h). Minor, but it's the
   kind of thing "show your work" can beat.

**Where this leaves the positioning.** Against Slopes, accuracy is a *tie*, not a wedge — the
honest claims are price, an inspectable file, and 6,992 resorts against ~50. Against Carve, which
is the free competitor, accuracy is a real and demonstrable gap. See ROADMAP → "What we can
actually claim".

### 5.1.2 Session 2 and the day total — the head-to-head repeated (S6, 2026-09-01)

Martin skied again **12:39:04–13:27** on the same day, all three apps recording, and screenshotted
Slopes and Carve at 13:39 (`Data/comparisons/`, second batch). Vertical's file is
`Data/fixtures/2026-09-01_portillo_s2.jsonl` — 2,773 fixes at **0.97 Hz**, hAcc median **±7.9 m**,
99.9% of fixes usable, Doppler valid on 2,768 of 2,773. **The outdoor-GPS result from S5 replicates
on a second session.** This is the first number in the project that is no longer n=1.

The competitor screenshots are day cumulative totals, so the comparison is against our two sessions
summed:

| Whole day, 2026-09-01 | Slopes | Carve | Vertical |
|---|---|---|---|
| Runs reported | 8 | 7 | **7** (+2 descents under the 30 m threshold) |
| Vertical | 1,384 m | 1,509 m | **1,367 m** (1,403 m counting those two) |
| Δ vs. Vertical | **+1.2%** | ~~+10.4%~~ | — |
| Top speed | 67.2 km/h | 66.8 km/h | **64.7 km/h** |

> ⚠️ **The Carve column is a live screen, not a saved day, and the two disagree.** Carve's finished
> logbook entry for this same recording reads **1,625 m**, not 1,509 — **+18.9%** over our 1,367,
> not +10.4%. The Slopes column is unaffected (its saved entry is 1,380 m, +1.0%). See **§5.1.3**,
> which supersedes the Carve row here.

**Both S5 conclusions survive the repeat, which is the point of running it twice.** Slopes is within
1.2% of us over 1.4 km of vertical (0.8% on session 1); Carve is +10.4% (+10.1% on session 1). The
same two apps land in the same two places on a second, independent day-half, and Carve's error is
stable enough to be a property of its pipeline rather than a bad day.

**A prediction made before the file was pulled came true.** The comparisons README subtracted the
two screenshot batches and predicted session 2 was ~3 runs (Slopes 8−5, Carve 7−4). `detect.py`
finds exactly **3** runs and 2 lift rides, with no tags to lean on — Martin placed one marker all
session ("Lift on", matched to 15.7 s). All three apps agree on the run count for session 2.

**Session 2 was slow skiing, and that is useful.** 462 m over three descents at 0.1–0.3 m/s
vertical rate, against session 1's 1.1 m/s on run 1; top speed **43.9 km/h** against 64.7. Nothing
in the session goes near the multipath regime, and the naive-vs-gated gap collapses accordingly:
position-differentiation reads 47.7 vs Doppler's 43.9, **+8.8%**. That is the honest shape of the
headline claim — **on a clean session the naive method costs ~9%; the +136.5% in §5.1.1 is what one
bad second does to it.** Two sessions now agree on the ~9% figure (§5.1.1 finding 3 measured +9% on
the clean acceleration).

**Battery: there is no measurement here, and there never was.** Session 2 reads 6.7 %/h against
session 1's 5.5 %/h, but `UIDevice.batteryLevel` is quantised to 5% and **each session saw exactly
one step** (65→60 over 0.92 h; 85→80 over 0.75 h). The same single observation, divided by two
different spans. The honest range from either is **0–11 %/h**, and no battery claim should be made
until a session runs long enough to accumulate three or more steps — about 3 h. `Tools/analyze.py`
now prints the step count and refuses the decimal below that.

#### The open question this raised: where does Slopes' 67.2 km/h come from?

Slopes' day top speed is **67.2 km/h**, ours is 64.7. Session 2's maximum is 43.9, so the number
comes from session 1, and **the whole day contains only four Doppler samples at or above 62 km/h:**

| Time | Doppler | hAcc | Reading |
|---|---|---|---|
| 11:01:11 | 64.7 km/h | ±9.3 m | clean — a smooth 10 s ramp, pos-diff agrees at 70.6 |
| 11:28:59 | 66.8 km/h | ±22.3 m | the multipath burst (Carve's published number) |
| 11:29:00 | 69.6 km/h | ±23.7 m | same burst |
| 11:29:01 | 63.4 km/h | ±25.4 m | same burst |

So 67.2 has exactly two possible origins, and **the data cannot separate them:**

- **(a) Slopes published the glitch too**, as Carve did — 67.2 sits between the burst's 66.8 and
  69.6, and every smoothed estimator tested (3 s and 5 s rolling means of Doppler and of
  position-differentiation) peaks *inside* the burst rather than at the clean sample.
- **(b) Slopes read the clean peak high.** On run 1 Slopes ran **+2.3%** over our accuracy-gated
  Doppler (53.8 vs 52.6); 67.2 is **+3.9%** over 64.7 — the same order. Slopes' Run 2 is stamped
  **10:57** against our run 2 at 10:56:57, and the clean 11:01:11 peak falls inside it. The Run 2
  top-speed field in the 11:46 screenshot would settle this, but it is behind the Premium blur;
  recovering it by crop-and-upscale was attempted and the blur is too heavy.

**Do not write either version down as fact** (`WORKFLOW.md` R1). What settles it is a recording day
that contains **no multipath burst at all**: if Slopes still reports 2–4% above our gated Doppler,
it is a systematic offset in its estimator and (b) is right; if Slopes lands on our number, then
(a) was right and Slopes' 67.2 was the glitch. Either answer is worth having — (a) would mean
*both* competitors publish corrupt peaks and the top-speed wedge is much wider than the Carve-only
claim in §5.1.1; (b) would mean Slopes is simply ungated and reads a few percent high, which is a
far weaker claim we should stop implying. Tracked as **A18** in §13.4.

### 5.1.3 The saved day, not the live screen — Carve's number moved after skiing stopped (S7, 2026-09-01)

Martin sent the two apps' **finished day records** at 16:18/16:20, after skiing had ended (he did
not ski in the afternoon). They do not say what the 13:39 live screens said, and the difference is
the finding.

| Whole day, 2026-09-01 | Slopes | Carve | Vertical |
|---|---|---|---|
| Live screen at 13:39 | 1,384 m | 1,509 m | — |
| **Saved day record** | **1,380 m** | **1,625 m** | **1,367 m** |
| Live → saved | −4 m (−0.3%) | **+116 m (+7.7%)** | — |
| Δ saved vs. Vertical | **+1.0%** | **+18.9%** | — |
| Runs | 8 | 7 | 7 |
| Distance | 8.4 km | 9.4 km | — |
| Top speed | 67.2 km/h | 67 km/h (66.8 live) | 64.7 km/h |
| Elapsed | 2 h 50 m | 3 h 02 m | 1 h 43 m recorded |

**Slopes' saved number is its live number. Carve's is not.** Carve's run count is unchanged at 7 and
its elapsed time went 3:01:43 → "3h 2m", which is that same figure rounded — so at most ~47 s of
further recording separates the two readings, and no new run. **[V]** on both readings (the 13:39
one is `Data/comparisons/2026-09-01_carve_1339.png`, re-read from the image rather than from our own
notes). Whatever produces the 116 m, it is not more skiing.

**Which of the two numbers is the pipeline we characterised?** Replaying our own GPS altitude with
hysteresis over both sessions — the model that reproduced Carve's session-1 figure to 0.4% in S6 —
gives, for the day: **1,588 m at 3 m, 1,645 m at 2 m, 1,541 m at 4 m.** Carve's **saved** 1,625
lands inside that band; its live 1,509 needs a ~6 m threshold and sits below it. So the saved figure
is the better match to the pipeline S6 characterised, and **1,509 now looks like the anomaly.**
**[A]** — this is model-fitting, not a mechanism, and it is not to be written down as one.

**Honest decomposition of the +18.9%,** because the headline is not all one effect:

- **~221 m of it is Carve's pipeline** on data we both recorded — no barometer, smoothed GPS
  altitude, summed rather than measured top-to-bottom. That is the S6 finding, unchanged.
- **~37 m of it is the lunch break.** Carve started at ~10:37 (13:39 minus 3:01:43) and ran
  **continuously through the 69 minutes we were not recording at all** — our two sessions bracket
  that gap. Slopes recorded the same gap and booked it as **1 h 28 m of "rest", adding no
  vertical.** An app that sums altitude accrues vertical while its owner eats lunch; an app that
  measures runs does not.
- The remainder is the live-vs-saved gap above, which we cannot explain.

**What must change in our own claims (R6):** §5.1.2's "Carve +10.4% on the day" was computed
against the live 1,509. **The number a Carve user keeps is 1,625, and against our 1,367 that is
+18.9%.** Quote the skiing-only figure (~+10%) and the whole-day figure (+18.9%) together, and say
which is which — the first is what its pipeline costs while skiing, the second is what a real day
with a lunch break costs. Slopes over the same day is **+1.0%**, which is the third independent
measurement of a tie (0.8%, 1.2%, 1.0%) and R20 still applies.

**A cheap experiment this suggests, for the next ski day:** leave Vertical recording *through
lunch*. We have never recorded a break, so the ~37 m above is inferred from a residual rather than
measured, and it is the one part of Carve's error we have not reproduced directly. It costs
nothing but leaving the app running, and it doubles as the 3 h+ recording the battery question
needs (§13.4).

**Two things the Slopes screen gave us for free, about our own detector:**

- **Lift time: Slopes 40 min, our detector 37.4 min (−6.5%)** across both sessions — with no hand
  tags involved, and including the surface tow the detector only started finding today. That is an
  independent check on lift detection from a source that has no idea we exist.
- **Ski time: Slopes 41 min, our detected run durations 54.6 min (+33%).** This one is a defect,
  and it is ours. Runs are segmented between altitude turning points, so **standing still at the
  top of a run counts as run time** — session 2's third run is 10.6 min of which 4.5 min is
  stationary at 94 m before the first turn. **Vertical is unaffected** (measured top-to-bottom), but
  every duration, vertical rate and average speed we print is wrong by about a third. The fix is the
  mirror of the trim `detect.py` already applies to lift *starts*. Tracked as **A19**.

### 5.2 Recording reliability

- **"Recording stops prematurely 50% of attempts after starting"** — 2★ App Store review **[V]**
- Android: reopening the app asks "resume or finish", and getting it wrong **doubles or triples run
  totals** **[S]**
- **"You lose your data if your watch dies"** — 1★ **[V]**
- **"Watch app always pops out"** (crashes/exits) — 1★ **[V]**

Losing a day's recording is the worst possible failure in this category — it's unrecoverable and
personal. **[A]** Design implication: append-only crash-safe write of every location sample to disk
as it arrives, so a crash/kill/battery-death loses at most the last sample, and recovery on next
launch is automatic and silent rather than a "resume or finish?" prompt.

### 5.3 Battery

- "Live widget drains battery significantly" — 4★ **[V]**
- The whole forum discourse is people trading battery tips (keep phone warm, kill WiFi/BT) and
  people abandoning phones for Garmin watches entirely **[S]**

Cold is the compounding factor — lithium cells lose a large fraction of usable capacity near
freezing, so a mediocre power budget becomes a dead phone at 2pm.

### 5.4 Android is a second-class citizen

- **"It would be a great app if it worked as well as it does on iOS"** **[S]**
- Google Play media-library policy changes mean **photos no longer appear** in Android logbook,
  activity summary, or timeline **[V — Slopes' own release notes]**
- Speed/vertical discrepancies between Android and iPhone side by side **[S]**
- Health Connect / Oura data not integrated despite being connected **[S]**

**[A]** A cross-platform-parity app is a real differentiator — but it doubles the build. Not a v1 call.

### 5.5 Smaller, specific, and unserved

- **Trail/lift *closures* aren't shown, only openings** — feature request in a review **[V]**
- Friend location "lacks real-time accuracy" — 4★ **[V]**
- Calorie counts implausibly high vs. other trackers **[S]**
- Edits to recorded data sometimes don't stick **[S]**
- Run names on the map are behind the paywall — repeatedly the single most-cited annoyance **[S]**
- Province/country boundary rendering only good in US/Canada **[V]**

---

## 6. Feature requests nobody is serving

Straight from App Store reviews **[V]** — free roadmap material:

- **Gear quiver tracking** — log which skis/bindings/boots were used per day, days-on-gear, when to
  wax/tune. Requested and unserved.
- **Trip photos + in-app messaging** for a group trip.
- **Direct friending from a trip page.**
- **Average run pitch/angle** (vertical ÷ horizontal distance) as a first-class stat.
- **Deeper historical per-run stats** across seasons.
- **Trail/lift closure tracking**, not just what's open.

**[A]** Two more that the accuracy discussion implies but nobody asked for directly, because users
don't know to ask:
- **Show the error bars.** No app tells you its confidence. "Top speed 68 km/h ±3" would be a
  category-first and instantly signals the app is more honest than its competitors.
- **Turn count / edge-change count** from the gyroscope. Genuinely novel; the phone has the sensor.

---

## 7. Data sources — the feasibility study

This is the section that determines whether "all premium features, free" is actually possible.

### 7.1 Trail maps → **solved, free, worldwide**

**OpenSkiMap / `openskidata-processor`** (russellporter) **[V]**
- Pipeline over OpenStreetMap + Skimap.org data.
- Outputs: **GeoJSON** per run/lift, a single **GeoPackage** (`openskidata.gpkg`) with ski areas +
  runs + lifts layers, and **Mapbox Vector Tiles** (`.mbtiles`).
- **Updated daily.**
- Coverage: **6,992 downhill ski areas in 70 countries, 96,693 downhill runs** **[V]**.
  **Do not compare this to Slopes without a measured number** (S5, A2). The ~50 figure this doc
  used to cite is from the founder's blog describing an *early season* of hand-crafted maps, and
  the "50+" in Slopes' current marketing is **live lift & trail status in North America**, not map
  coverage. Slopes' present-day map coverage is stated only as "thousands of resorts worldwide"
  with no count. Open data is very likely broader — but "3× larger" was a claim we invented, and
  it is withdrawn.
- Features come pre-enriched with elevation, reverse-geocoded country/region/locality, VIIRS
  satellite snow cover, and multi-resort ski-pass membership.
- **License: ODbL** (Open Database License, inherited from OSM).

**Consequences of ODbL — read this before shipping [A, needs legal sanity-check]:**
- Attribution is required and must be visible.
- ODbL is **share-alike on the database**: if we produce a *Derivative Database* (e.g. our own
  cleaned/re-tagged run geometry) and make it publicly available, that derived database must be
  offered under ODbL too. Our *app code* is unaffected — ODbL covers data, not the software using
  it, and a map image rendered from the data is a "Produced Work" that only needs attribution.
- Practically: shipping the data, rendering it, and searching it is fine. Publishing our own
  improved run dataset means publishing it open. That's acceptable and arguably good.
- **Open question:** the pipeline also ingests Skimap.org data and ski-pass data credited to *The
  Storm Skiing Journal* — those may carry their own terms. Verify before shipping.

Also: **Open Ski Map** is already a shipping iOS app built on exactly this data, with offline
per-resort download and search-by-name **[V]**. That is live proof that two of Slopes' paywalled
features — *offline trail maps* and *search trails by name/difficulty* — are free to build.

### 7.2 Live lift status → **mostly solved, free** (the surprise of this research)

**Liftie** (`pirxpilot/liftie`, originally FATMAP's) **[V]**
- **BSD-3-Clause.** Actively maintained — 2,235 commits, live CI.
- Per-resort adapters: scrapes resort HTML with CSS selectors, *or* calls the resort's own REST API
  where one exists. Has a generator tool for adding new resorts.
- Refreshes every 65s, caches server-side.
- **Public hosted instance with a public REST API: `GET https://liftie.info/api/resort/<resort>`**

This collapses the single feature I flagged as the expensive one. Options, in order of preference **[A]**:
1. Consume `liftie.info`'s public API directly — zero infrastructure. **Must ask the maintainer
   first**; pointing an app at someone's free hosted instance without asking is how you get blocked,
   and it's the polite thing regardless.
2. Self-host Liftie (it's a Node app) on a cheap box, contributing new resort adapters upstream.
3. Both — self-host, fall back to nothing rather than hammering theirs.

**Caveat:** Liftie is lift status. **Grooming reports are a separate, harder problem** — far less
standardised across resorts, and the search found no open source for it. **[A]** Expect grooming to
be genuinely partial, and be honest in the UI about which resorts have it rather than showing stale
data as if it were live. Slopes' own "60+ resorts" caveat tells you they hit the same wall.

### 7.3 Commercial fallbacks (only if needed)

- **Mountain News / OnTheSnow Partner API** — real-time snow reports, trail *and* lift status
  worldwide. Fee-based, aimed at media companies. Their own docs warn reports can be stale — filter
  on `updatedDt` **[V]**.
- **skiapi.com** — free tier via RapidAPI, rate-limited **[S]**.

### 7.4 Terrain / 3D

Free DEM tile sources exist (AWS Terrain Tiles / Mapzen lineage). No licensing blocker. The blocker
is rendering — see §9.1.

---

## 8. Feasibility of each Slopes premium feature

| Slopes premium feature | Free? | How | Difficulty |
|---|---|---|---|
| Per-run stats & advanced analytics | ✅ Yes | Computed from our own track. Zero marginal cost | Low |
| Run comparisons (you vs. you / friends) | ✅ Self: yes. Friends: needs sync | Resample two tracks by distance along a matched run, diff | Low (self) / Med (social) |
| Run replays + speed heatmaps | ✅ Yes | Polyline coloured by speed, time-scrubbed | Low |
| Hand-crafted trail maps | ✅ Yes — **better** | OpenSkiMap: 6,992 areas vs. Slopes' ~50 hand-made | Low (data) / Med (cartography) |
| 3D maps | ⚠️ Yes, with a real technical fight | See §9.1 — this is the hardest item on the list | **High** |
| Live lift status | ✅ Probably | Liftie, self-hosted or via its API | Med |
| Grooming reports | ⚠️ Partial at best | No open source found; per-resort scraping | High, ongoing |
| Offline trail maps | ✅ Yes | Pre-bundle/download MVT per resort. A resort is a few MB | Low |
| Search trails by name/difficulty | ✅ Yes | It's a field in the OSM data. Open Ski Map already ships it | Low |
| AR track replay | ✅ Yes | ARKit world-tracking + heading. See §9.2 | Med — **and low value** |

**Verdict: 8 of 10 premium features are free-to-build with no running cost.** 3D is a real
engineering problem. Grooming is a real *data* problem and the only one with recurring cost.

---

## 9. Technical risks — the things that could actually bite

### 9.1 MapLibre Native does not have 3D terrain on iOS yet ⚠️

This is the most important technical finding in the whole sweep, and it contradicts the obvious plan.

- MapLibre **GL JS** (web) has had 3D terrain since v2 **[V]**.
- MapLibre **Native** (iOS/Android) **does not**. As of the **December 2025** newsletter, Terrain 3D
  for Native was still *being worked on* by two named contributors **[V]**. Native currently has
  2.5D extrusion and terrain *tiles*, not full 3D terrain rendering.
- MapLibre Native iOS 6.0.0 did ship **Metal** support (OpenGL is deprecated on Apple) **[V]** — so
  the renderer is modernising, terrain just isn't there yet.

**Options [A]:**
1. **MapKit** — `MKMapView` has real 3D/pitch and Apple maintains it, but styling arbitrary OSM
   piste geometry over it is limited and it has no vector-tile styling story.
2. **MapLibre Native for the 2D map, and defer 3D** — ship the strong 2D map first, add 3D when
   upstream lands it (and contribute to it — that's a genuinely useful thing to do).
3. **Render terrain ourselves in SceneKit/RealityKit** from DEM tiles + drape the run geometry.
   Total control, most work, and honestly the most interesting version.
4. **MapLibre GL JS in a `WKWebView`** — gets 3D terrain today, at the cost of performance and a
   web bridge. Yomi already proved a `WKWebView`-based core view can be the right call, so this
   isn't heresy — but for a map you pan continuously in gloves, it's a real UX risk.

**This decision needs a spike before the roadmap can commit to it.** Don't pick from the armchair.

#### Amendment, S4 (2026-08-31): a shipping app already answered this — option 1

Carve's replay screen carries the " Maps · Legal" attribution (§2.2, observed on Martin's
phone). **Its 3D terrain with satellite drape is MapKit.** The "most important technical finding
in the whole sweep" above was real about MapLibre but wrong about the *problem*: 3D terrain on
iOS was never gated on MapLibre shipping it, because Apple already gives it away — with no tile
hosting, no bandwidth bill, and no ODbL obligation on the base map.

That reshapes the option list rather than closing it. The open question is no longer "can we get
3D terrain?" but **"how well does arbitrary OSM piste geometry overlay onto `MKMapView`?"** — the
one weakness listed under option 1. A hybrid is now the obvious front-runner: **MapKit for the
3D/satellite base, our own OpenSkiMap runs and lifts as overlays on top.**

Still a spike, and still not settled from the armchair — but it is now a small, well-aimed spike
against `MKMapView` + `MKOverlay`, not a four-way exploration. **Verify MapKit's real elevation
and overlay behaviour against Apple's docs (`apple-docs` MCP) before committing.**

**Lesson, and it's the Keiyoushi one again:** the blocker had been sitting in this document since
S1 as a hard technical limit. It took one screenshot of a competitor to show the limit was real
and the conclusion drawn from it was not. Look at what shipping apps actually do before believing
a capability is out of reach.

#### Amendment, S5 (2026-09-01): MapKit cannot do it, and the spike is already answered

The S4 amendment closed by saying "verify MapKit's real elevation and overlay behaviour against
Apple's docs before committing." Done, and **the answer is no.** From Apple's own WWDC22 session
10035, *What's new in MapKit*:

> "When adding an overlay to a map with realistic terrain, MapKit will automatically transition the
> map to a flat representation. The map will automatically go back to realistic when you remove the
> last overlay." … "One notable exception to this rule are overlays sourced through MapKit's
> directions API. Those overlays automatically follow the terrain."

A ski track is a custom `MKPolyline`. OpenSkiMap piste geometry is custom overlays. **Adding either
one flattens the mountain.** `MKDirections` returns driving/walking routes on the road network and
cannot be made to return a run down La Parva. So option 1 does not deliver the product — it
delivers 3D terrain *or* our data, never both, and the whole point is our data on the terrain.

Consequences, in order:

- **Option 1 is dead for replay.** MapKit remains an excellent *2D* map (which is what Carve's
  record screen uses, and what our own screenshot of it shows) and is still the right default for
  every non-3D map surface. Nothing about the 2D case changed.
- **Option 2 (MapLibre Native) is still not ready.** Terrain is in active development — named
  contributors in the December 2025 newsletter, MLT 3D tile-format research in April 2026 — with no
  shipped release (A11). Watchable, not plannable.
- **Option 3 (SceneKit/RealityKit + DEM) becomes the front-runner by elimination,** and it got
  cheaper: **Mapterhorn** now serves global Terrain-RGB tiles (Copernicus 30 m worldwide, national
  LIDAR where it exists) in PMTiles, **data CC BY 4.0, code BSD-3** (A16). That is the elevation
  mesh, free and attributable. The remaining unsolved piece is the **satellite imagery drape** —
  Apple's imagery cannot be lifted out of MapKit into our own 3D scene, so that needs its own
  licensed source. **That, not the terrain, is the real open question now.**
- **Carve is doing something we have not identified.** Its listing promises "satellite imagery
  draped over the actual mountain surface", "cinematic drone camera… free-fly", and a "speed
  heatmap trail rendered in 3D" — MapKit does none of that with a custom overlay present. So it is
  a hand-built 3D scene, and the S4 inference from an attribution string was wrong.

**Recommendation: cut 3D from v1 entirely and say so out loud.** It was always Phase 3, it is now
known-expensive rather than assumed-cheap, and nothing else in the project depends on it. Revisit
when either MapLibre ships terrain or the accuracy work is finished and there is appetite for a
Metal-shaped project.

**Lesson, and it is the mirror of the S4 one:** S4 corrected an over-pessimistic conclusion by
looking at a competitor, and then immediately drew an over-optimistic conclusion from the same
screenshot. *"A shipping app does X, therefore X is easy with the framework I think it uses"* is
not evidence — it is two inferences stacked, and both were wrong. The primary source settled in one
lookup what the screenshot could not.

### 9.2 ARKit geo-tracking won't work on a mountain

`ARGeoTrackingConfiguration` requires Apple's localisation imagery and only works in specific mapped
cities — not ski resorts **[A, high confidence]**. AR replay therefore needs world-tracking plus true
heading plus our own georeferencing, which is doable but drifts. Combined with AR being the
lowest-value item on the premium list, **cut it from v1.**

### 9.3 App Review and background location

Always-on background location is one of the more scrutinised entitlements. Needs a clear
`NSLocationAlwaysAndWhenInUseUsageDescription`, a privacy manifest, and a justification. Fine —
recording a ski day is an obviously legitimate use — but it's a rejection risk if sloppy. Yomi's
S104 lesson applies directly: **verify compliance claims against live sources, not doc recall.**

### 9.4 Cold-weather battery

Not a bug, a physics constraint. Design the power budget assuming a phone that's cold and already
at 40%. Adaptive sampling isn't a nice-to-have, it's the core of the recording engine.

### 9.5 Watch app reliability

Two of the handful of 1★ Slopes reviews are watch problems — data loss on watch battery death, and
the watch app crashing **[V]**. A watch app is a *reliability liability*, not a free win. **[A]**
If we build one, phone must be the source of truth and the watch a display, or the watch must
persist independently and reconcile.

---

## 10. Where a free app can actually win

Synthesising all of the above — three positions, in order of strength:

1. **Be the accurate one.** Everyone in this category has soft numbers and the community knows it
   (§5.1). Barometric fusion + Doppler speed + honest error bars. This is a pure engineering win
   available to a solo dev, it's the loudest unmet complaint, and it's defensible because it doesn't
   scale with headcount.
2. **Be the one that never loses your day.** Crash-safe append-only recording, silent auto-recovery,
   no "resume or finish?" prompt that can triple your totals. The 1★ reviews are almost all this.
3. **Be the one with the whole world's map, free.** 6,992 resorts from OpenSkiMap vs. Slopes' ~50
   hand-crafted, with names and difficulty search unpaywalled. Slopes' single most-resented gate is
   charging to see run names on a map.

**Explicitly do not try to compete on:** human support responsiveness, social network size (network
effects favour the incumbent and a ghost town is worse than no feature), or per-resort data
partnerships.

---

## 11. Open questions for Martin

1. **Platform.** iOS-only first (plays to your Yomi experience, and Android is where Slopes is
   *weakest*, which is a real argument for Android). Can't do both well at once.
2. **The 3D decision** (§9.1) — needs a spike, not a guess. Which of the four options do we
   prototype?
3. **Social or solo?** Comparisons-vs-friends, leaderboards and friend-finding all need a backend,
   accounts, and ongoing cost. A solo-only v1 has zero running cost. Slopes' free tier already
   gives away friend-finding, so it's not much of a differentiator anyway.
4. **Backend at all?** Everything except lift status and social can be 100% on-device.
5. **Apple Watch?** §9.5 says it's a liability. Defer.
6. **Where do we ski?** Real testing needs real snow. It's late August — northern season starts in
   ~3 months, southern is *right now*. This shapes the whole schedule. (Los Andes / Bariloche is in
   season through September–October.)
7. **Name.** "Vertical" is a placeholder.

---

## 13. Assumption register (opened S5, 2026-09-01)

Everything the plan rests on that had never actually been checked, with what it costs to be wrong.
This section exists because S5 found three separate claims in this document that were repeated for
five sessions and turned out to be false or unsupported — including one that was steering a whole
phase of the roadmap.

**Verdict key:** ✅ verified against a primary source · ❌ **wrong, corrected below** ·
⚠️ unverified, and here is how to check it.

### 13.1 Positioning and competitors

| # | Assumption | Verdict | What actually holds |
|---|---|---|---|
| A1 | Ski apps overestimate vertical 5–10%, so accuracy is our wedge against Slopes | ❌ | **Slopes: 912 m vs our 905 m, 0.8%** (§5.1.1). The folklore is about Ski Tracks and Garmin. **Carve** does fit it (+10.1%). Accuracy is a wedge against Carve, a tie against Slopes. |
| A2 | Slopes' hand-crafted premium maps cover ~50 resorts, vs 6,992 open — "3× larger" | ❌ | Two different numbers got welded together. The ~50 **[V]** is from the founder's blog about an *early season* of hand-crafted maps — years stale. The "50+" in current Slopes marketing is **live lift & trail status in North America**. Present-day map coverage is stated only as "thousands of resorts worldwide", uncounted. **"3× larger" was our own arithmetic on mismatched figures and is withdrawn.** Open data is probably broader; nobody has measured it. |
| A3 | Slopes Premium is ~$29.99/yr, ~$49.99 family | ❌ | **$34.99/yr, $59.99 family** (getslopes.com/premium, read 2026-09-01), plus in-app day and week passes. Prices had drifted since S1. |
| A4 | Carve's 3D replay is MapKit, so Apple gives us 3D free (the S4 finding that reopened D4) | ❌ | See A9. MapKit **cannot** do what Carve's listing describes, so the inference from the " Maps · Legal" attribution was wrong — that attribution is on Carve's 2D *record* screen (visible in `Data/comparisons/2026-09-01_carve.png`), not necessarily on the 3D replay. |
| A5 | Carve is GPS-only and inherits the category error | ✅ **confirmed** | Still absent from **Motion & Fitness** after a real 1 h 05 m recording (2026-09-01) — it never started `CMAltimeter`, so altitude is GPS-only. Our own GPS altitude with 3 m hysteresis, summed, gives **992 m** against its printed **996 m** (0.4%). My earlier reading — that 996 sitting between our baro-summed 944 and GPS-summed 1,227 implied barometer use — was wrong: it implied *smoothing*, not a barometer. See §2.2. |
| A6 | Carve has no traction | ✅ | Still "not received enough ratings or reviews to display an overview" (App Store, 2026-09-01). |

### 13.2 Data and licensing

| # | Assumption | Verdict | What actually holds |
|---|---|---|---|
| A7 | OpenSkiMap's pipeline is alive and produces what we need | ✅ | `openskidata-processor` active, 561 commits, Docker pipeline, outputs GeoJSON + `openskidata.gpkg` + optional MVT. Elevation now comes from **Mapterhorn** terrain tiles; ski-pass data from The Storm Skiing Journal's chart; snow cover from VIIRS **with a mandatory citation** (`VNP10A1 v2`, Riggs & Hall 2023) if we enable it. |
| A8 | The data is ODbL, attribution visible, derived DBs must be shared | ⚠️ | The processor README **does not state a license** — the ODbL conclusion comes from OSM upstream, which is sound but not read from this project's own terms. Skimap.org's terms and the Storm Skiing Journal spreadsheet's terms remain unread. **Before shipping data, read all three.** Cost of being wrong: a takedown after launch. |
| A16 | Free global DEM tiles exist for 3D | ✅ | **Mapterhorn** — global Terrain-RGB in PMTiles, Copernicus 30 m worldwide plus national LIDAR where available, **data CC BY 4.0, code BSD-3**. This is the terrain source if we build 3D ourselves. |
| A17 | Liftie solves live lift status, free | ✅ (mostly) | BSD-3, 2,235 commits, live CI, public API `GET https://liftie.info/api/resort/<resort>`, 65 s refresh. **No published rate limits or terms** — which is a reason to ask the maintainer, not a licence to hammer it. Self-hosting stays the honest default. |

### 13.3 Apple platform (the section that changed the roadmap)

| # | Assumption | Verdict | What actually holds |
|---|---|---|---|
| A10 | **MapKit gives us 3D terrain with our track drawn on it** | ❌ **This is the big one.** | Apple's own WWDC22 session 10035: *"When adding an overlay to a map with realistic terrain, MapKit will automatically transition the map to a flat representation."* Only routes from the **MKDirections** API follow terrain. **A ski track is a custom `MKPolyline`, so the instant we draw it the mountain goes flat.** MapKit can give us 3D terrain, or our track, never both. §9.1's amendment in S4 is withdrawn and **D4 is reopened**. |
| A11 | MapLibre Native still has no iOS 3D terrain | ✅ (still true) | Terrain work is in progress (named contributors in the Dec 2025 MapLibre newsletter; MLT 3D tile-format research in April 2026). **No shipped release.** Do not plan on it landing. |
| A12 | The barometer is the right primary altitude source | ✅ | Measured, repeatedly (§5.1.1, ROADMAP S3–S5). Additionally `CMAltimeter` offers **absolute** altitude (`CMAbsoluteAltitudeData`, iOS 15+, **iPhone 12 and later only**) — we already log it, and it is the drift check that `relativeAltitude` alone cannot provide. |
| A13 | Background recording is correctly configured | ✅ on device, ⚠️ in design | It works (S3–S5). But Apple's current guidance is `CLBackgroundActivitySession` / `CLServiceSession`, and states plainly: **"If your app terminates, you must recreate the `CLServiceSession` immediately upon launch in the background"** and **"Don't start these services at launch time if your app's authorization status is undetermined."** Our S4 auto-resume must be re-read against both sentences. |
| A14 | Free provisioning is a minor inconvenience | ❌ | Free accounts get **7-day profiles, 10 App IDs, 3 devices, and no TestFlight and no App Store at all**. The **$99/yr Apple Developer Program is not optional** for anything past personal testing — and it is *already* costing us: the build dies ~2026-09-07, mid-trip, and `mobile-mcp` can't drive the device for want of a wildcard App ID. |
| A15 | Apple Watch is a liability, defer | ⚠️ | Unchanged from S1 and still untested. Left deferred deliberately, not by oversight. |

### 13.4 What is still genuinely unknown

1. **~~Everything rests on one 56-minute morning.~~ Partly answered, S6.** A second session
   (`_s2.jsonl`, 48 min) replicates the fix-quality result and both competitor deltas — Slopes
   +1.0% and Carve +18.9% against the **saved** day records (§5.1.3; the +1.2%/+10.4% pair came
   from live screens). Still one mountain, one phone, one weather system, and still **n=1 for the
   multipath glitch**, which is the single sample the top-speed claim rests on.
2. **No battery data at all, cold or otherwise.** The 5.5%/h and 6.7%/h figures are one 5%
   quantisation step each and mean nothing (§5.1.2); the real bound from both days is 0–11 %/h.
   Needs a 3 h+ recording, and then a cold one — lithium cells lose capacity below freezing and
   Portillo at ~10 °C is not that test either.
3. **No competitor has been installed and driven by us** — S1 flagged this and it is still true.
   Slopes' free tier and Carve are both installed on Martin's phone, which is as close as we get
   without the paid account.
4. **No App Store review exposure has been assessed at all** for background location and the
   health/fitness framing.
5. **A18 — does Slopes publish the multipath glitch, or is it just ungated?** Its day top speed of
   67.2 km/h is either the 11:28:59 burst (as Carve's demonstrably is) or the clean 11:01:11 peak
   read +3.9% high. §5.1.2 has both cases and the evidence for each; neither may be asserted. **The
   test is a session containing no multipath burst** — cheap, and every future recording is one.
   **Still open after S7:** the finished day records add nothing — Slopes' saved top speed is the
   same 67.2, Carve's saved 67 km/h is its 66.8 rounded. Both readings come from the day that
   contains the burst, so only a new burst-free day can separate the cases.
6. **A19 — our run durations include standing still, by about a third.** Slopes books 41 min of ski
   time for the day; our detected run durations sum to 54.6 min, because a run is segmented between
   altitude turning points and a skier stopped at the top is still at the top (§5.1.3). Vertical is
   unaffected; duration, vertical rate and average speed are not. The fix is the mirror of the
   lift-start trim already in `detect.py`, and it needs the same care: trimming the start of a
   descent to the last moment at the ceiling must not eat a slow traversing start.
7. **A20 — why did Carve's day vertical move 116 m between its live screen and its saved logbook
   entry, on a recording that gained no runs and at most 47 s?** (§5.1.3.) Our GPS-hysteresis model
   of its pipeline matches the **saved** number, which makes the live 1,509 the odd one out. We
   cannot see inside the app, so this may stay a documented observation rather than an answer — but
   it must be quoted as one reading superseding another, never as "Carve says 1,509".

---

## 12. Sources

- [Slopes App Store customer review feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=643351983/sortby=mostrecent/json) — read directly
- [Slopes on the App Store](https://apps.apple.com/us/app/slopes-ski-snowboard/id643351983) · [Google Play](https://play.google.com/store/apps/details?id=com.consumedbycode.slopes) · [Slopes Premium](https://getslopes.com/premium) · [Android release notes](https://getslopes.com/whatsnew_android) · [Slopes Apple Watch](https://getslopes.com/apple-watch)
- [Slopes Diaries #26: Killing the Slopes Pass](https://blog.curtisherbert.com/slopes-diaries-26-killing-the-slopes-pass/) · [#46: An Intentional Dozen](https://blog.curtisherbert.com/slopes-diaries-46-an-intentional-dozen/) · [#4: The Great Wall](https://medium.com/@parrots/slopes-diaries-4-the-great-wall-74d39ea69b2)
- [OpenSkiMap.org](https://openskimap.org/) · [openskidata-processor](https://github.com/russellporter/openskidata-processor) · [openskimap.org repo](https://github.com/russellporter/openskimap.org) · [OpenSkiStats](https://github.com/dhimmel/openskistats) · [Open Ski Map iOS app](https://apps.apple.com/us/app/open-ski-map/id6775258969)
- [Liftie](https://github.com/pirxpilot/liftie) · [FATMAP/liftie (original)](https://github.com/FATMAP/liftie) · [liftie.info](https://liftie.info/)
- [Mountain News / OnTheSnow Partner API](https://partner.docs.onthesnow.com/) · [Ski API](https://skiapi.com/)
- [MapLibre Native](https://github.com/maplibre/maplibre-native) · [Metal support for iOS](https://maplibre.org/news/2024-01-19-metal-support-for-maplibre-native-ios-is-here/) · [Native 3D Terrain discussion](https://github.com/maplibre/maplibre/discussions/326) · [MapLibre Newsletter Dec 2025](https://maplibre.org/news/2026-01-03-maplibre-newsletter-december-2025/) · [MapLibre V2 3D terrain](https://www.maptiler.com/news/2022/05/maplibre-v2-add-3d-terrain-to-your-map/)
- [Strava turned off FATMAP — POWDER](https://www.powder.com/gear/strava-is-turning-off-fatmap-what-that-means-for-skiers-) · [Strava opens up about FATMAP](https://www.powder.com/gear/strava-opens-up-about-fatmap-winter-3d-mapping) · [TechCrunch](https://techcrunch.com/2024/06/26/strava-to-shutter-3d-mapping-platform-fatmap-18-months-after-acquisition) · [OUTMAP review](https://alpsinsight.com/stories/outmap-review/)
- [Ski tracking app accuracy — Snowjournal](https://www.snowjournal.com/discussion/1142/ski-tracking-app-accuracy-or-lack-thereof) · [Vertical on ski apps/watches](https://www.snowjournal.com/discussion/3847/vertical-on-ski-tracking-apps-watches) · [Ski Tracker App Discrepancy — SkiTalk](https://www.skitalk.com/threads/ski-tracker-app-discrepancy.26491/) · [Android app recommendations — SkiTalk](https://www.skitalk.com/threads/ski-tracking-app-recommendation-for-android.28793/) · [Speed apps inaccurate — Snowboarding Forum](https://www.snowboardingforum.com/threads/speed-board-ski-apps-inaccurate-why.78162/)
- [Is Slopes Premium worth it — Newschoolers](https://www.newschoolers.com/forum/thread/940640/Who-uses-the-Slopes-App--Is-Premium-version-worth-it-) · [Best Ski Apps 2026 — Piste blog](https://pisteapp.com/blog/posts/comparison_of_skiing_app/) · [Best skiing apps — OnTheSnow](https://www.onthesnow.com/news/the-best-skiing-apps/) · [Best ski-tracking apps — SkiMag](https://www.skimag.com/performance/fitness/best-ski-tracking-apps/) · [Slopes alternatives — AlternativeTo](https://alternativeto.net/software/slopes)
- [Ski Tracks](https://apps.apple.com/us/app/ski-tracks/id365724094) · [We Ski & Snowboard](https://apps.apple.com/us/app/we-ski-snowboard-tracker/id1541405311) · [Piste](https://apps.apple.com/us/app/piste-ski-tracker/id1672012106) · [Ski Tracker (exatools)](https://play.google.com/store/apps/details?id=com.exatools.skitracker)
