#!/bin/sh
# Run the test suite on a simulator.
#
#   Tools/test.sh
#
# Sim only: the tests read Data/fixtures directly off the Mac's filesystem (see Fixtures.swift),
# and nothing in them needs a real sensor. `replay.sh` is still the harness that proves the Swift
# and the Python agree; this is what *fails* when a rule changes.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
sim=${VERTICAL_SIM:-'platform=iOS Simulator,name=iPhone 17,OS=26.0'}
exec xcodebuild test \
    -project "$root/iOS/Vertical.xcodeproj" -scheme Vertical -destination "$sim" "$@"
