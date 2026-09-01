# Competitor screenshots — the evidence behind `RESEARCH.md` §5.1.1

Screenshots Martin took of the **other two apps recording the same morning as
`../fixtures/2026-09-01_portillo_s1.jsonl`**. They are the only record of those numbers: neither
app exports raw samples, and both screens are live views that are gone once the session is cleared.
Keep them.

| File | App | Taken | What it shows |
|---|---|---|---|
| `2026-09-01_slopes.png` | Slopes (free tier) | 11:46 local | Today's Stats: 1 h 11 m, 5 runs, 912 m vertical, 5.1 km. Run 1 (10:38) itemised — 415 m, 2.1 km, 53.8 km/h top, 31.0 km/h avg, 5 m 26 s. Runs 2+ blurred behind the paywall; only run 2's **10:57** start time is legible, and it matches ours to three seconds. |
| `2026-09-01_carve.png` | Carve | 11:47 local | Record screen, paused at 1:05:43: 4 runs, 996 m vertical, 5.69 km, **66.8 km/h top speed** — the number that turns out to be a multipath glitch in our own file at 11:28:59. Altitude 2868 m. Also confirms Carve renders on Apple Maps (the S4 MapKit finding). |

## Second batch — 13:39, cumulative for the whole day

Martin skied a second morning session and screenshotted both apps again before lunch. **These are
day totals, not session-2 totals** — they include the 10:35–11:30 session in the table above.

| File | App | Day total at 13:39 |
|---|---|---|
| `2026-09-01_carve_1339.png` | Carve | 3:01:43 elapsed (paused), **7 runs, 1,509 m vertical, 9.08 km**, top speed **66.8 km/h**, altitude 2,875 m |
| `2026-09-01_slopes_1339.png` | Slopes | **8 runs, 1,384 m vertical**, altitude 2,875 m, top speed **67.2 km/h** |

Three things worth noting before the second session's raw file is pulled and analysed:

1. **Carve's top speed is still exactly 66.8 km/h** — unchanged from the 11:28:59 multipath sample
   identified in `RESEARCH.md` §5.1.1. Nothing in a second session of skiing beat it. A glitch is
   still sitting at the top of that app's day.
2. **By subtraction, session 2 was ~3 runs**: Slopes 8−5, Carve 7−4. Carve's day total is **+9.0%**
   over Slopes' (1,509 vs 1,384), consistent with the +10.1% measured on session 1 against our own
   barometric number.
3. **Slopes and Carve now disagree on run count by one in the same direction as before** (8 vs 7),
   which is the base-area split described in §5.1.1 finding 4 — worth re-checking against the
   second file rather than assumed.

**Analysed S6 (2026-09-01).** The second session was pulled and is now
`../fixtures/2026-09-01_portillo_s2.jsonl`. Results in `RESEARCH.md` §5.1.2. All three predictions
above held: session 2 is **3 runs** exactly as the subtraction said, Carve is **+10.4%** on the day
total against our 1,367 m, and Slopes is **+1.2%**. The run-count disagreement (8 vs 7) is entirely
session 1's base-area split — both apps agree with us on 3 runs for session 2.

One thing the subtraction could **not** settle: Slopes' 67.2 km/h day top speed. Session 2's maximum
is 43.9 km/h, so it comes from session 1, where the only candidates are the clean 64.7 peak and the
11:28:59 multipath burst. See §5.1.2 and assumption **A18** — it is not yet known which, and the
Run 2 top-speed field in `2026-09-01_slopes.png` that would answer it is behind the Premium blur.

## Third batch — 16:18 / 16:20, the finished day records

`2026-09-01_slopes_1618.png` and `2026-09-01_carve_1620.png`. Martin skied no afternoon and
**confirmed he pressed stop straight after the 13:39 screenshot** — he did not ski again — so these
are the same recording as the 13:39 batch, saved rather than live.

| App | Saved day record | Live at 13:39 | Moved |
|---|---|---|---|
| Slopes | 8 runs, **1,380 m**, 8.4 km, 2 h 50 m, top **67,2 km/h**, tallest run 415 m, peak alt 3.173 m, ski 41 min / lift 40 min / rest 1 h 28 m | 1,384 m | −4 m |
| Carve | 7 runs, **1,625 m**, 9.4 km, 3 h 2 m, top **67 km/h** | 1,509 m, 9.08 km, 3:01:43 paused | **+116 m** |

**The finding is the Carve row.** Same run count, same elapsed once rounded, and **Martin confirms
he pressed stop and skied nothing further** — and 116 m (+7.7%) more vertical in the saved entry
than on the live screen. Slopes moved 4 m the
other way. Against our 1,367 m the saved figures are **Slopes +1.0%, Carve +18.9%**. Written up in
`RESEARCH.md` §5.1.3, with the decomposition of Carve's error and the two questions it opened
(A19, A20).

Also worth keeping from the Slopes screen: it recorded the same 10:37–13:27 span we did, including
the 69-minute lunch break, and booked that break as **1 h 28 m of rest with no vertical**. And its
**40 min of lift time** is an independent check on our own lift detector, which finds 37.4 min.

---

Vertical's own numbers for the first session come from the fixture, via `Tools/analyze.py` and
`Tools/detect.py`, not from a screenshot.
