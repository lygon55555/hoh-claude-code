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
  ok=$(grep -c '^ok  ' "$HOH_LOGS/test-$HOH_T.log")
  fail=$(grep -c '^FAIL' "$HOH_LOGS/test-$HOH_T.log")
  echo "packages ok $ok / FAIL $fail"
}
