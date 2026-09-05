#!/bin/sh
# Compile the app's own LiveMetrics together with the replay driver and run it over a session file.
#
#   Tools/replay.sh Data/fixtures/*.jsonl
#
# The point is that this uses iOS/Vertical/Recorder/LiveMetrics.swift *unmodified* — the same source
# the app ships — so the numbers it prints can be diffed against Tools/analyze.py to prove the
# on-device port agrees with the offline analyzer. See the header of replay.swift.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
out=${TMPDIR:-/tmp}/vertical-replay
swiftc -O -parse-as-library -o "$out" \
    "$root/Tools/replay.swift" \
    "$root/iOS/Vertical/Recorder/LiveMetrics.swift" \
    "$root/iOS/Vertical/Recorder/SessionReplay.swift" \
    "$root/iOS/Vertical/Recorder/SessionTrack.swift"
exec "$out" "$@"
