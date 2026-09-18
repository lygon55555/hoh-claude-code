#!/bin/bash
# gate.sh <task> <t> — deterministic build-and-test gate. Writes hoh/<task>/gate-<t>.md.
# No model is involved: this is Runtime.check from Algorithm 1 of the HoH paper.
#
# Project-neutral. The workspace's hoh/project.sh defines how to build and test.
# Contract (see references/setup.md):
#   hoh_build()          required. exit 0 = success. stdout/stderr -> logs/build-<t>.log
#   hoh_test()           required. exit 0 = all tests passed. -> logs/test-<t>.log
#   hoh_test_summary()   optional. one-line summary on stdout (for example "42 passed")
#   hoh_artifacts()      optional. artifact paths to check, one per line
#   HOH_REPOS_DEFAULT    optional. repositories used when config.md has no `repos:` line
#
# Run from the workspace root:  bash <path-to-hoh>/skills/hoh/scripts/gate.sh <task> <t>
# or set HOH_WORKSPACE to the workspace root.
set -uo pipefail
cd "${HOH_WORKSPACE:-.}" || exit 1

if [ ! -d hoh ]; then
  echo "gate.sh: no hoh/ directory in $(pwd). Run from the workspace root, or set HOH_WORKSPACE." >&2
  exit 1
fi
if [ ! -f hoh/project.sh ]; then
  echo "gate.sh: hoh/project.sh not found. Run '/hoh init <profile>' to create it." >&2
  exit 1
fi

TASK=${1:?usage: gate.sh <task> <t>}; T=${2:?usage: gate.sh <task> <t>}
DIR="hoh/$TASK"; LOGS="$DIR/logs"
# Validate the task before creating anything, so a typo does not leave an
# empty state directory behind.
[ -f "$DIR/config.md" ] || { echo "gate.sh: no such task ($DIR/config.md missing). Create it with '/hoh start <task> <prd>'." >&2; exit 1; }

# shellcheck source=/dev/null
. hoh/project.sh
for fn in hoh_build hoh_test; do
  declare -F "$fn" > /dev/null || { echo "gate.sh: hoh/project.sh does not define $fn()" >&2; exit 1; }
done

REPOS=$(sed -n 's/^repos: *//p' "$DIR/config.md")
REPOS=${REPOS:-${HOH_REPOS_DEFAULT:-.}}
KNOWN=$(sed -n 's/^known_fail: *//p' "$DIR/config.md")
mkdir -p "$LOGS"

# Values the profile may use.
export HOH_TASK="$TASK" HOH_T="$T" HOH_TASK_DIR="$DIR" HOH_LOGS="$LOGS" HOH_REPOS="$REPOS" HOH_KNOWN_FAIL="$KNOWN"

# Pin down the tree under test. QA compares this with the evidence's candidate
# to detect a gate that checked a different tree.
BUILT_AT=$(date +%s); CANDIDATE=""; DIRTY=no
for r in $REPOS; do
  if git -C "$r" rev-parse --git-dir > /dev/null 2>&1; then
    # --verify -q prints nothing on failure (a repository with no commits yet).
    CANDIDATE="$CANDIDATE $r=$(git -C "$r" rev-parse --verify -q HEAD || echo "(no-commits)")"
    [ -n "$(git -C "$r" status --porcelain)" ] && DIRTY=yes
  else
    CANDIDATE="$CANDIDATE $r=(not-a-git-repo)"
  fi
done
CANDIDATE=${CANDIDATE# }

echo "[gate] build..." >&2
hoh_build > "$LOGS/build-$T.log" 2>&1 && BUILD_OK=ok || BUILD_OK=fail

TESTS_OK=skipped; SUMMARY="n/a"
if [ "$BUILD_OK" = ok ]; then
  echo "[gate] test..." >&2
  hoh_test > "$LOGS/test-$T.log" 2>&1 && TESTS_OK=ok || TESTS_OK=fail
  if declare -F hoh_test_summary > /dev/null; then
    SUMMARY=$(hoh_test_summary 2>/dev/null)
    SUMMARY=${SUMMARY:-n/a}
  fi
fi

# An artifact older than the candidate commit may mean a stale binary was tested.
# The gate only flags it; QA decides.
ARTIFACTS=""
if declare -F hoh_artifacts > /dev/null; then
  primary=$(echo "$REPOS" | awk '{print $1}')
  cmt=$(git -C "$primary" log -1 --format=%ct 2>/dev/null || echo 0)
  while read -r a; do
    [ -n "$a" ] || continue
    if [ -e "$a" ]; then
      amt=$(stat -f %m "$a" 2>/dev/null || stat -c %Y "$a" 2>/dev/null || echo 0)
      flag=ok; [ "$cmt" -gt 0 ] && [ "$amt" -lt "$cmt" ] && flag=older_than_commit
      ARTIFACTS="$ARTIFACTS
- $a mtime=$(date -r "$amt" +%FT%T 2>/dev/null || date -d "@$amt" +%FT%T) $flag"
    else
      ARTIFACTS="$ARTIFACTS
- $a MISSING"
    fi
  done <<< "$(hoh_artifacts 2>/dev/null)"
fi

{
  echo "---"
  echo "iteration: $T"
  echo "candidate: $CANDIDATE"
  echo "candidate_dirty: $DIRTY"
  echo "built_at: $(date -r "$BUILT_AT" +%FT%T 2>/dev/null || date -d "@$BUILT_AT" +%FT%T)"
  echo "build: $BUILD_OK"
  echo "tests_status: $TESTS_OK"
  echo "tests: $SUMMARY"
  echo "---"
  echo "# Artifacts"; echo "${ARTIFACTS:-(none)}" | sed '/^$/d'
  echo "# Logs"
  echo "$LOGS/build-$T.log"
  [ -f "$LOGS/test-$T.log" ] && echo "$LOGS/test-$T.log"
  # Extra logs the profile or QA wrote for this iteration (e.g. logs/unit-3-api.log).
  ls "$LOGS" 2>/dev/null | grep -E "^[a-z].*-$T(-|\.)" | grep -v -E "^(build|test)-$T\.log$" | sed "s|^|$LOGS/|"
} > "$DIR/gate-$T.md"

echo "gate-$T.md: build=$BUILD_OK tests=$TESTS_OK ($SUMMARY) dirty=$DIRTY"
[ "$BUILD_OK" = ok ]
