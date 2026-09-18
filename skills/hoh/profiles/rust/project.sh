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
  # "test result: ok. 41 passed; 1 failed; 0 ignored"
  grep -Eo "test result:.*" "$HOH_LOGS/test-$HOH_T.log" | tail -1
}

hoh_artifacts() {
  find target/debug -maxdepth 1 -type f -perm -111 2>/dev/null | head -5
}
