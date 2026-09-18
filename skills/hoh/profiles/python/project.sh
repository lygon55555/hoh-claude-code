#!/bin/bash
# HoH project profile — Python / pytest
# Copy to <workspace>/hoh/project.sh and adjust the virtualenv path if needed.

HOH_REPOS_DEFAULT="."
VENV="${VENV:-.venv}"

hoh_build() {
  [ -d "$VENV" ] || python3 -m venv "$VENV" || return 1
  # shellcheck source=/dev/null
  . "$VENV/bin/activate"
  if [ -f pyproject.toml ] || [ -f setup.py ]; then
    pip install -q -e . || return 1
  elif [ -f requirements.txt ]; then
    pip install -q -r requirements.txt || return 1
  fi
  # Type checking counts as part of the build when mypy is installed. Remove if unwanted.
  if python -c "import mypy" 2>/dev/null; then
    python -m mypy . || return 1
  fi
  python -m compileall -q -x "$VENV" .
}

hoh_test() {
  # shellcheck source=/dev/null
  . "$VENV/bin/activate"
  python -m pytest -q
}

hoh_test_summary() {
  # pytest's last line: "41 passed, 1 failed in 2.10s"
  grep -Eo "[0-9]+ (passed|failed|error)[^=]*" "$HOH_LOGS/test-$HOH_T.log" | tail -1
}
