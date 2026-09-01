# Vertical — iOS

## Build + install on the phone

Developer Mode must be on: **Settings → Privacy & Security → Developer Mode**, then reboot.

```sh
cd ~/Desktop/Projects/Vertical/iOS
xcodebuild -project Vertical.xcodeproj -scheme Vertical -configuration Debug \
  -destination 'id=270B9EDA-7298-5206-9E67-71C0E8F60CF6' -allowProvisioningUpdates build

# then install the built .app
xcrun devicectl device install app --device 270B9EDA-7298-5206-9E67-71C0E8F60CF6 \
  "$(xcodebuild -project Vertical.xcodeproj -scheme Vertical -configuration Debug \
     -destination 'id=270B9EDA-7298-5206-9E67-71C0E8F60CF6' -showBuildSettings \
     2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')"
```

First launch on the phone: **Settings → General → VPN & Device Management → trust the developer
certificate**, then grant location as **Always**.

> **Free provisioning expires after 7 days.** Rebuild and reinstall from the Mac before it lapses,
> or the app stops launching mid-trip. The Mac must be on the trip.

## Before skiing — the checklist that matters

1. Location permission is **Always**, not "While Using". While-Using dies when the phone locks in
   a pocket, which is where it spends the entire day. The app shows a yellow warning if this is
   wrong — don't start a day with that banner up.
2. Press **START** before the first lift. That's the only required interaction.
3. **On the first chairlift, glance at the `DOPPLER` tile.** Green is good. Orange means GPS isn't
   giving us usable speed data and the config needs fixing — worth knowing on run one rather than
   at the end of the day.
4. Leave the phone in a pocket. The blue location pill in the status bar means it's alive.
5. **If the phone dies or the app disappears, just open it again.** It reopens the same session
   and carries on recording by itself, and shows a green "Recording resumed automatically"
   banner so you know it happened. **Do not press START again** — you don't need to, and the
   banner tells you so. (If the phone rebooted, unlock it; iOS won't relaunch anything until
   the first unlock.)
6. Press **STOP** at the end of the day. If you forget, the file on disk is still valid and
   complete up to that moment. Nothing is lost and nothing will ask you a question about it.
7. **Bring a battery pack, and keep the phone in an inside pocket.** All-day GPS at full rate is
   the heaviest thing a phone can do, and a cold lithium cell can read 20 % and then cut out.
   The app logs battery level and thermal state every 5 minutes, so a shortened day still tells
   us something useful.

### About the tag buttons

They are **optional**, and they are **not** how the finished app will work. The shipped app
auto-detects lifts and runs from the sensor data — press START and forget it, like Slopes.

The buttons exist right now only to produce hand-labelled ground truth for *building* that
detector: knowing exactly when a real run started lets the segmentation be checked against
reality instead of against a guess. If you happen to remember at the top of a run, one tap is
genuinely valuable. If you don't, nothing is lost. Never let them interfere with skiing.

They get deleted from the UI once auto-detection is accurate.

## Getting the data off

Three independent routes, on purpose:

- **Sessions → share icon** → AirDrop to the Mac (no cable)
- **Files.app → On My iPhone → Vertical → Sessions**
- Finder → iPhone → Files → Vertical

## Analysing a session

```sh
~/Desktop/Projects/Vertical/Tools/analyze.py ~/Downloads/2026-08-31_*.jsonl
```

## What this app does and does not do

It records. That's all it does.

Every `CLLocation` and every barometer reading is appended to a JSONL file as it arrives, at full
fidelity, with no processing whatsoever. The vertical figure on screen is a deliberately naive
running total and is **not** the real metric — it's a liveness indicator so you can tell the thing
is working.

All the actual work — sensor fusion, lift/run segmentation, honest vertical, Doppler max speed —
happens offline against these files, and can be rewritten and re-run as many times as we like
without needing to be on a mountain again. Getting the analysis wrong is recoverable. Not
capturing is not.
