#!/bin/bash
# HoH project profile — Go
# Copy to <workspace>/hoh/project.sh.

HOH_REPOS_DEFAULT="."

hoh_build() {
  go build ./... || return 1
  go vet ./...
}

hoh_test() {
  go test ./...
}

hoh_test_summary() {
  local ok fail
  ok=$(grep -cE '^ok[[:space:]]' "$HOH_LOGS/test-$HOH_T.log")
  # Anchor on the package line: a failing test binary also prints a bare "FAIL",
  # which would count every failing package twice.
  fail=$(grep -cE '^FAIL[[:space:]]' "$HOH_LOGS/test-$HOH_T.log")
  echo "packages ok $ok / FAIL $fail"
}
