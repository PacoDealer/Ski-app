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
2. Press **START** before the first lift.
3. Tag moments with the four buttons. **These are worth more than they look** — they're the ground
   truth that run/lift segmentation gets validated against, and they can't be reconstructed later.
   Even a handful per day is plenty.
4. Leave the phone in a pocket. The blue location pill in the status bar means it's alive.
5. Press **STOP** at the end of the day. If you forget, or the phone dies, or the app crashes —
   the file on disk is still valid and complete up to that moment. Nothing is lost and nothing
   will ask you a question about it.

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
