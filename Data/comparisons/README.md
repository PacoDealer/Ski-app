# Competitor screenshots — the evidence behind `RESEARCH.md` §5.1.1

Screenshots Martin took of the **other two apps recording the same morning as
`../fixtures/2026-09-01_portillo_day1.jsonl`**. They are the only record of those numbers: neither
app exports raw samples, and both screens are live views that are gone once the session is cleared.
Keep them.

| File | App | Taken | What it shows |
|---|---|---|---|
| `2026-09-01_slopes.png` | Slopes (free tier) | 11:46 local | Today's Stats: 1 h 11 m, 5 runs, 912 m vertical, 5.1 km. Run 1 (10:38) itemised — 415 m, 2.1 km, 53.8 km/h top, 31.0 km/h avg, 5 m 26 s. Runs 2+ blurred behind the paywall; only run 2's **10:57** start time is legible, and it matches ours to three seconds. |
| `2026-09-01_carve.png` | Carve | 11:47 local | Record screen, paused at 1:05:43: 4 runs, 996 m vertical, 5.69 km, **66.8 km/h top speed** — the number that turns out to be a multipath glitch in our own file at 11:28:59. Altitude 2868 m. Also confirms Carve renders on Apple Maps (the S4 MapKit finding). |

Vertical's own numbers for the same morning come from the fixture, via
`Tools/analyze.py`, not from a screenshot.
