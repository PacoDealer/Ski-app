# 2026-09-03 — Slopes export vs. Vertical

Source: `3 September 2026 - Portillo.slopes`, unzipped to `slopes_2026-09-03/`
(`Metadata.xml`, `RawGPS.csv` 1,654 rows, `GPS.csv` 1,600 rows).
Ours: `Data/fixtures/2026-09-03_portillo_s4.jsonl`, 42,328,503 bytes, 11:54:01–17:19:19 local,
17,440 GPS fixes, 18,304 barometer, 489,904 IMU.

**This is the third graded day, and it is the one that let the false-top fix ship** (R5).

## Day totals

| | Slopes | Vertical | Δ |
|---|---|---|---|
| vertical | 1,335.2 m | 1,379.7 m | **+3.3%** |
| runs itemised | 8 | 9 | see below |
| top speed | 69.1 km/h (processed) | 67.0 km/h (gated) | +3.17% |
| top speed, raw | 66.999 km/h | 66.999 km/h | **identical** |
| recording window | 11:53:59–17:19:07 | 11:54:01–17:19:19 | — |
| fixes kept | 1,654 | 17,440 | Slopes keeps 9.5% |

## Run-by-run (`Tools/falsetop.py --score`)

| # | Slopes start | vert | ours | Δs | vert | n |
|---|---|---|---|---|---|---|
| 1 | 12:06:11 | 301.8 | 12:05:36 | −35 | 309.4 | 1 |
| 2 | 12:23:45 | 414.1 | 12:24:23 | +39 | 416.9 | **2** |
| 3 | 12:56:09 | 56.1 | 12:56:14 | +5 | 57.2 | 1 |
| 4 | 16:15:38 | 132.6 | 16:15:32 | −5 | 133.3 | 1 |
| 5 | 16:29:34 | 120.1 | 16:29:38 | +4 | 129.3 | 1 |
| 6 | 16:43:55 | 68.9 | 16:43:42 | −12 | 75.4 | 1 |
| 7 | 16:50:50 | 120.0 | 16:50:37 | −13 | 134.4 | 1 |
| 8 | 17:03:59 | 121.6 | 17:04:11 | +13 | 123.8 | 1 |

**Mean |start error| 16 s** — against 36 s on 2026-09-01 and 56 s on 2026-09-02. Six of eight runs
are inside 13 s, which is under the precision of a glove-tapped button.

**The 9-vs-8 run count is not a defect.** We split Slopes' run 2 (12:23:45–12:43:36) in two across
a ~4-minute gap in the middle, and the halves sum to **417.0 m against its 414.1 m, +0.7%**. Slopes
calls a mid-run stop part of the run; we start a new descent when the gap exceeds `MERGE_GAP_S`
(60 s). That is a labelling difference, not lost or invented vertical.

⚠️ The scorer originally reported a **−11,964 s** error on this day. That was the harness pairing
the two lists by index while their lengths differed — see **R27**.

## The false-top decision (R5)

`Tools/falsetop.py` finds **zero false tops on 2026-09-03**; all three in the project remain on
2026-09-02. With the third graded day in hand, the pre-registered candidate fix — *on merge, adopt
the higher of the two tops* — scores:

| day | false tops | mean start err. now | fixed | day vertical now → fixed |
|---|---|---|---|---|
| 2026-09-01 | 0 | 36 s | 36 s | 1,366.8 → 1,366.8 |
| 2026-09-02 | 3 | 56 s | **29 s** | 1,386.0 → **1,390.1** |
| 2026-09-03 | 0 | 16 s | 16 s | 1,379.7 → 1,379.7 |

A no-op on the two days without the defect, and it halves the error on the one that has it
(run 8: −168 s → −7 s). **Shipped** in `analyze.py` and `LiveMetrics.swift`.

**Its known cost, recorded rather than hidden:** on 2026-09-02 run 6 it goes −9 s → **+54 s**,
because there the higher peak lands *after* the real push-off; and 2026-09-02's vertical moves
1,386 → 1,390, which takes us from +1.9% to +2.2% against Slopes on that day. A fourth graded day
should test that regression rather than leave it as an accepted cost.

## Top speed — A18, confirmed a second time on a burst day

S12b answered A18 from 1 Sep: Slopes rejects a multipath burst just as we do, and its published
number is its own smoothing of the same clean fix. That was one dirty day. **This day is the
second, and it repeats exactly.**

Our four highest ungated fixes, all at 17:16:56–17:16:59, *after the last run ended at 17:09*:

| speed | hAcc | speedAcc |
|---|---|---|
| 78.444 km/h | ±12.2 | **−1 (invalid)** |
| 78.444 km/h | ±15.2 | −1 |
| 78.264 km/h | ±20.4 | −1 |
| 73.656 km/h | ±19.2 | −1 |

The gate rejects all four on the invalid `speedAcc` (`analyze.py:367`). Note the hAcc on the first
is ±12.2 m — **under** the 15 m gate, so hAcc alone would have passed it; the loose `speedAcc`
sanity bound kept as a secondary check in S5 is what caught this one. Worth remembering before
anyone simplifies that gate.

What the gate lands on instead is **66.999 km/h @ 12:57:16**, hAcc ±7.9 — and Slopes' `RawGPS.csv`
peaks at **66.999 km/h @ 12:57:16.999, hAcc ±7.9**. Same fix, bit-for-bit, a fourth confirmation
that Slopes and Vertical read the identical CoreLocation stream. Slopes published **69.1 km/h**:
its `GPS.csv` (processed) value for that same second, **+3.17%**. On 1 Sep that uplift was +3.81%
at the peak and +2.72% mean above 54 km/h. **Neither app published the burst.**

## The 2 h 55 m break — the hardest negative control yet

Slopes' `Metadata.xml` carries `overrides="1788455709...-1788466194...:ignore;"` =
**13:15:09–16:09:54 ignored**. Over that same window our file holds:

- 9,860 barometer samples, altitude span **14.7 m**, net drift **−2.6 m/h**
- **8,829 GPS fixes with Doppler up to 47.5 km/h** — real horizontal motion, not a parked phone
- **zero runs** from our segmenter, and none of the 23 sub-threshold candidates came near 30 m

The dinner control (S10) was indoors and still. The S13 tail was outdoors and still. **This one is
outdoors and moving**, which is the case that actually threatens a barometric segmenter, and it
invents nothing. Slopes needed an `ignore` override on the same window; we needed no annotation.
