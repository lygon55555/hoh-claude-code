#!/bin/bash
# HoH project profile — Node / npm
# Copy to <workspace>/hoh/project.sh and match the script names to package.json.

HOH_REPOS_DEFAULT="."

hoh_build() {
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund || return 1
  else
    npm install --no-audit --no-fund || return 1
  fi
  npm run build
}

hoh_test() {
  # CI=1 keeps test runners out of watch mode. Anything interactive hangs the gate forever.
  CI=1 npm test
}

hoh_test_summary() {
  # jest / vitest print: "Tests:  1 failed, 41 passed, 42 total"
  grep -Eo "Tests:.*" "$HOH_LOGS/test-$HOH_T.log" | tail -1
}
