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
  # --if-present: a library with only tests has no build script, and a script
  # that does not exist is not a build failure.
  npm run build --if-present
}

hoh_test() {
  # CI=1 keeps test runners out of watch mode. Anything interactive hangs the gate forever.
  CI=1 npm test
}

hoh_test_summary() {
  local sum
  # jest / vitest print: "Tests:  1 failed, 41 passed, 42 total"
  sum=$(grep -Eo "Tests:.*" "$HOH_LOGS/test-$HOH_T.log" | tail -1)
  # node --test prints counters instead: "# pass 41", "# fail 1"
  [ -n "$sum" ] || sum=$(awk '$1=="#" && ($2=="pass" || $2=="fail") {c[$2]=$3}
    END { if (c["pass"] != "" || c["fail"] != "") printf "%d passed, %d failed", c["pass"], c["fail"] }' \
    "$HOH_LOGS/test-$HOH_T.log")
  echo "$sum"
}
