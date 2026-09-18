#!/bin/bash
# HoH project profile — Rust / cargo
# Copy to <workspace>/hoh/project.sh.

HOH_REPOS_DEFAULT="."

hoh_build() {
  cargo build --all-targets || return 1
  cargo clippy --all-targets -- -D warnings
}

hoh_test() {
  cargo test
}

hoh_test_summary() {
  # "test result: ok. 41 passed; 1 failed; 0 ignored" — cargo prints one such line
  # per test binary plus one for doc-tests, so sum them. Taking the last line
  # would report a green total while an earlier binary had failures.
  awk '/^test result:/ {
         seen = 1
         for (i = 1; i < NF; i++) {
           if ($(i+1) ~ /^passed/) p += $i
           if ($(i+1) ~ /^failed/) f += $i
         }
       }
       END { if (seen) printf "%d passed, %d failed", p, f }' "$HOH_LOGS/test-$HOH_T.log"
}

hoh_artifacts() {
  find target/debug -maxdepth 1 -type f -perm -111 2>/dev/null | head -5
}
