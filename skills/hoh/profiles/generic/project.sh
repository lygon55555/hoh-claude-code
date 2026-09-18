#!/bin/bash
# HoH project profile — template.
# Lives at <workspace>/hoh/project.sh. The gate (gate.sh) sources this file.
# Contract: skills/hoh/references/setup.md.
#
# The gate runs without a model, deterministically. The commands here must be
# exactly what a human would type in a terminal — nothing interactive.

# Repositories to check when the task's config.md has no `repos:` line.
# Keep "." for a single-repository project.
HOH_REPOS_DEFAULT="."

# Required. exit 0 = build succeeded. Output is captured to logs/build-<t>.log.
hoh_build() {
  # e.g. npm run build / cargo build / go build ./... / make
  echo "TODO: put the build command here"
  return 1
}

# Required. exit 0 = all tests passed. Output is captured to logs/test-<t>.log.
# No tests? Leave `return 0` here and state "no automated tests" in the PRD.
hoh_test() {
  # e.g. npm test / pytest / go test ./... / cargo test
  echo "TODO: put the test command here"
  return 1
}

# Optional. One-line summary on stdout; becomes the `tests:` field of gate-<t>.md.
# Delete the function if there is nothing sensible to extract (the exit code decides anyway).
# hoh_test_summary() {
#   grep -Eo "[0-9]+ passed" "$HOH_LOGS/test-$HOH_T.log" | tail -1
# }

# Optional. Artifact paths, one per line. The gate compares their mtime with the
# candidate commit time and flags artifacts older than the commit. Concrete paths only — globs are not expanded.
# hoh_artifacts() {
#   echo "dist/app.js"
# }
