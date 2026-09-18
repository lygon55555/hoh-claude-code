#!/bin/bash
# HoH project profile — Xcode / xcodebuild
# Copy to <workspace>/hoh/project.sh and set the project (or workspace), scheme and destination.

HOH_REPOS_DEFAULT="."
XCODE_PROJECT="${XCODE_PROJECT:-MyApp.xcodeproj}"           # for a workspace, change -project to -workspace below
XCODE_SCHEME="${XCODE_SCHEME:-MyApp}"                       # the scheme must include the test targets
XCODE_DESTINATION="${XCODE_DESTINATION:-platform=macOS}"   # e.g. "platform=iOS Simulator,name=iPhone 16"

_xcb() {
  xcodebuild -project "$XCODE_PROJECT" -scheme "$XCODE_SCHEME" -destination "$XCODE_DESTINATION" "$@"
}

hoh_build() {
  # build-for-testing compiles the app and the test bundles in one pass.
  # Use plain `build` if the scheme has no tests.
  _xcb build-for-testing
}

hoh_test() {
  _xcb test-without-building -resultBundlePath "$HOH_LOGS/xcresult-$HOH_T-$(date +%s).xcresult"
}

hoh_test_summary() {
  # The last "Executed N tests, ..." line is the run total. Skips show up as
  # "with N tests skipped and M failures", so keep the whole clause.
  grep -Eo "Executed [0-9]+ tests?,[^(]*" "$HOH_LOGS/test-$HOH_T.log" | tail -1
}
