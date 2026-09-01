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
| **Slopes** | iOS + Android + watchOS | Free tier; Premium ~$29.99/yr, ~$49.99 family, **$3.99 day pass** | The category leader. Auto lift/run detection, hand-made trail maps, 3D, social, leaderboards | Key features paywalled — incl. *run names on the map* **[S]**; Android lags iOS |
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

**What it does not claim, anywhere:** accuracy. No barometric fusion, no Doppler-gated speed, no
error bars, no statement about vertical being measured rather than integrated. It reports the same
GPS-derived numbers as everyone else, and §5.1's category-wide 5–10 % overestimate is presumably
inherited whole. **The thesis in `CLAUDE.md` survives this intact and is now the *only* thing
holding the project up** — which is clarifying, not fatal.

Also relevant: it has **too few ratings for the App Store to show an overview**. It is brand new
and has no traction or community. This is a peer, not an incumbent.

**Three things worth taking from it:**

1. **It is an existence proof for §9.1.** A solo developer shipped 3D terrain with satellite drape
   on iOS. Whatever MapLibre Native can't do, the feature is clearly reachable — which materially
   de-risks D4 and means the Phase 3 spike should start by working out *how* Carve does it.
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
  Compare: Slopes' "hand-crafted" premium maps = ~50 resorts **[V]**; its general interactive maps =
  2,000+ resorts **[S]**. **The free open dataset is 3× larger than Slopes' paid one.**
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
