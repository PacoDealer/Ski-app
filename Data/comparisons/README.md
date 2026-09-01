# Competitor screenshots — the evidence behind `RESEARCH.md` §5.1.1

Screenshots Martin took of the **other two apps recording the same morning as
`../fixtures/2026-09-01_portillo_day1.jsonl`**. They are the only record of those numbers: neither
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

**Not yet analysed: Vertical's own second session.** The file is still on the phone. Pull it and run
both tools before drawing any conclusion from the numbers above — the whole point of this project is
that a screenshot is not evidence about a pipeline.

---

Vertical's own numbers for the first session come from the fixture, via `Tools/analyze.py` and
`Tools/detect.py`, not from a screenshot.
