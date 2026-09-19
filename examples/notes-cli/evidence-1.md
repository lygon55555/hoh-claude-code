---
iteration: 1
candidate: .=0cdf922c5d11c9a2e4882e842a364c355683e047
plan: plan-1.md
gate: gate-1.md
build: ok
tests: 25 passed in 1.09s
qa_status: fail
regressions: 0
gaps: 7 (blocker 0, major 2, minor 2, note 3)
coverage: complete
---

# Freeze check

| check | observed | verdict |
|---|---|---|
| `git rev-parse HEAD` in `.` | `0cdf922c5d11c9a2e4882e842a364c355683e047` | matches the given candidate |
| `git status --porcelain` in `.` | empty (rechecked after all QA work) | clean |
| `candidate:` line of `gate-1.md` | `.=0cdf922c5d11c9a2e4882e842a364c355683e047` | same tree the gate checked |
| `built_at` vs commit time | gate `2026-09-19T01:22:38` vs commit `2026-09-19T01:20:53+09:00` | gate ran after the commit |

Inspection proceeded.

# Gate quoted (from gate-1.md, verbatim)

```
build: ok
tests_status: ok
tests: 25 passed in 1.09s
# Artifacts
(none)
# Logs
hoh/notes/logs/build-1.log
hoh/notes/logs/test-1.log
```

`# Artifacts` is `(none)`, so nothing was marked `older_than_commit` and no rebuild was
required. The build was not repeated. `hoh/notes/logs/build-1.log` is 0 bytes (a silent,
successful build).

My own independent run of the suite reproduces the gate exactly: `25 passed in 1.07s`
(`hoh/notes/logs/qa-1-tests.log`). Baseline at t=0 was `1 passed`
(`hoh/notes/logs/test-0.log`), and `known_fail:` in `config.md` is empty, so there is no
baseline failure to discount.

# Environment note

The shell alias `python` shadows the venv, as the orchestrator stated. Every observation
below invokes the interpreter directly
(`<workspace>/.venv/bin/python`). This changes
nothing about the candidate; the plan's V items say `. .venv/bin/activate && python`, which
is the same interpreter.

The venv interpreter is **Python 3.14.7**, not 3.9. To verify the PRD's 3.9 constraint at
runtime rather than only by static grep, I fetched a real CPython 3.9.25 into a scratch
directory with `uv` and re-ran the CLI and the whole suite under it
(`hoh/notes/logs/qa-1-py39run.log`). Nothing was installed into the repository.

# Claims

Observation logs, all under `hoh/notes/logs/`:
`qa-1-probe.sh` (the probe script), `qa-1-cli.log` (283 lines, the main black-box run),
`qa-1-tests.log`, `qa-1-code.log`, `qa-1-tty.log`, `qa-1-pty.log`, `qa-1-edge.log`,
`qa-1-py39.log`, `qa-1-py39run.log`.

| id | claim | source (plan/PRD) | evidence (command / file:line / log path) | status | severity | note |
|---|---|---|---|---|---|---|
| V1-1 | Bare `python -m notes` exits 2, stdout empty, stderr has a `usage:` line naming `add`, `list`, `done` | plan-1.md V1-1 (T1-1, R5) | `qa-1-cli.log:2-7` — `rc=2`, `stdout||`, `stderr|usage: python -m notes {add <text> \| list \| done <n>}|`, `traceback=0` | verified | — | All three names present in the single usage line |
| V1-2 | `bogus`, `add` (no arg) and `done` (no arg) each exit 2 with a `usage:` line, empty stdout, no traceback | plan-1.md V1-2 (T1-1, R5) | `qa-1-cli.log:8-36` — three required cases all `rc=2 stdout_bytes=0 stderr_has_traceback=0`; I also added `list extra` and `add a b`, both `rc=2` | verified | — | `qa-1-cli.log:38` also shows no store file is created by a usage error |
| V1-3 | Two `add`s then `list` prints exactly `1. [ ] buy milk` / `2. [ ] call mom`, rc 0 | plan-1.md V1-3 (T1-2, R1, R2) | `qa-1-cli.log:51-73` — both adds `rc=0`; `list` `rc=0`, `list_line_count=2`, `cat -v` shows the two lines with no escape bytes | verified | — | Numbering past 9 also correct: `qa-1-edge.log` shows `9. [ ] note nine` / `10. [ ] note ten` |
| V1-4 | `list` on an absent store prints exactly `no notes`, rc 0, and does not create the file | plan-1.md V1-4 (T1-2, R3) | `qa-1-cli.log:41-48` — `rc=0`, `stdout|no notes|` (`stdout_bytes=8`), empty stderr, `file_exists_after_list: no`, `parent_dir_created: no` | verified | — | Path used was three levels deep and absent; no parent directory was created either |
| V1-5 | On-disk shape is exactly `{"notes":[{"text":str,"done":bool}]}` | plan-1.md V1-5 (T1-2, R6) | `qa-1-cli.log:76-91` — `toplevel ['notes']`, `notekeys [['done','text'],['done','text']]`, `donetypes ['bool','bool']`, `texttypes ['str','str']` | verified | — | Raw file also printed in the log |
| V1-6 | Corrupt store: every subcommand exits 4, names the path on stderr, no traceback, file untouched | plan-1.md V1-6 (T1-2, R6) | `qa-1-cli.log:182-253` — I widened the plan's 4 payloads to **9** (`{`, `[]`, `{"notes":"nope"}`, `{"notes":[{"text":"x"}]}`, `{"notes":[{"text":"x","done":1}]}`, `{"notes":[1]}`, `null`, `"hello"`, `{"notes":[],"extra":1}`) x 3 subcommands = 27 runs: all `rc=4 path_in_stderr=1 traceback=0 stdout_empty=yes store_unchanged=yes` | verified | — | Stronger than required (27 runs vs 12). Each message also says *why* the store is invalid |
| V1-7 | `done 1` exits 0, `list` shows `1. [x] buy milk`, repeating `done 1` stays 0 and unchanged | plan-1.md V1-7 (T1-3, R4) | `qa-1-cli.log:93-123` — `done 1` `rc=0`; `list` `stdout|1. [x] buy milk|`; second `done 1` `rc=0` and `list` byte-identical | verified | — | Mixed flags also correct: `qa-1-tty.log` shows `1. [ ] plain one` / `2. [x] done one` |
| V1-8 | `done 0`, `-1`, `abc`, `1.5`, `99` each exit 3, name the given argument, no traceback, store byte-identical | plan-1.md V1-8 (T1-3, R4) | `qa-1-cli.log:125-180` — all five `rc=3`, `arg_named_in_stderr=1`, `traceback=0`, `store_unchanged: yes`; messages are `notes: no note 0` / `-1` / `abc` / `1.5` / `99`. I added `""`, `" "` and `2` (past end of a 1-note store): also `rc=3`, store unchanged | verified | — | See G1-5: other spellings of an integer are *not* rejected |
| V1-9 | Suite green, passed count > baseline 1, `import notes` gives a truthy `__version__`, smoke test still passes | plan-1.md V1-9 (P1-1) | `qa-1-tests.log` — full suite `25 passed in 1.07s`; `tests/test_smoke.py` alone `1 passed`; `notes.__version__` = `'0.1.0'`, rc 0; 25 test ids collected, `tests/test_smoke.py::test_package_imports` among them | verified | — | 25 > 1. Matches the gate's `25 passed` |
| V1-10 | `pyproject.toml` unchanged since baseline; `requirements.txt` is `pytest` only; `src/notes` imports stdlib only | plan-1.md V1-10 (P1-2) | `qa-1-code.log` — `git diff --name-only 20a49e4..HEAD -- pyproject.toml` empty; changed files are only the 3 src + 2 test files; `requirements.txt` diff empty, content `pytest`; imports are `json`, `os`, `pathlib.Path`, `sys`, `from . import store`, `from .cli import main`; `pip list` shows only pytest and its own deps plus `notes==0.1.0` | verified | — | Editable install works (`import notes` from tests needs no path juggling) |
| V1-11 | 3.9-compatible syntax, no module over 200 lines, no function over 50 lines | plan-1.md V1-11 | `qa-1-code.log` — no `match` statement, no `X \| Y` annotation, `compileall -q src/notes` rc 0; `wc -l`: `__init__.py` 3, `__main__.py` 8, `cli.py` 99, `store.py` 90. `qa-1-tty.log` — longest function is `store.load` at 13 lines; nothing near 50. `qa-1-py39.log` — `ast.parse(..., feature_version=(3,9))` succeeds for all 7 source and test files | verified | — | Strengthened beyond the plan: `qa-1-py39run.log` runs the CLI **and all 25 tests under real CPython 3.9.25** — `compileall` rc 0, `add`/`list`/`done`/usage/corrupt paths give rc 0/0/0/2/4, `25 passed in 0.96s` |
| V1-12 | At least one test per R1-R6, identifiable by name or `R<n>` in the docstring; tests isolated from the real home | plan-1.md V1-12 | `qa-1-code.log` + `tests/test_cli.py`, `tests/test_store.py`. R1: `test_add_then_list:70-71`, `test_save_creates_the_parent_directory:47-48`. R2: `test_add_then_list:71`, `test_list_renders_mixed_done_flags:152-153`. R3: `test_list_on_a_missing_store_says_no_notes_and_creates_nothing:82-83`, `test_load_of_a_missing_file_is_empty:31-32`. R4: `test_done_marks_a_note_and_is_idempotent:107-108`, `test_done_rejects_a_bad_index_without_touching_the_store:119-120`, `test_marked_done_does_not_mutate_its_input:90-91`. R5: `test_no_subcommand_is_a_usage_error:37-38`, `test_unknown_subcommand_is_a_usage_error:49-50`, `test_subcommand_missing_its_argument_is_a_usage_error:59-60`. R6: `test_add_writes_the_documented_json_shape:94-95`, `test_a_corrupt_store_exits_4_from_every_subcommand:134-135`, `test_save_then_load_round_trips:36-37`, `test_load_rejects_a_shape_that_does_not_match:68-69`. Isolation: grep for `Path.home`/`expanduser`/`~/.notes.json` in `tests/` returns nothing; `tests/test_cli.py:21-30` `run()` sets `NOTES_FILE` to `tmp_path/notes.json` for every CLI invocation | verified | — | Every one of R1-R6 has a docstring naming it. R7 and R8 have no tests — see G1-1, G1-2 |
| P1-1 | `import notes` succeeds with a truthy `__version__` and the whole suite stays green alongside the new tests | plan-1.md P1-1 (last verified gate-0) | Same as V1-9: `qa-1-tests.log` `25 passed`, `tests/test_smoke.py` `1 passed` on its own, `notes.__version__ == '0.1.0'` | verified | — | Not a regression; the baseline test still passes and 24 tests were added |
| P1-2 | The package still installs editable from `pyproject.toml`; the dependency set stays stdlib + pytest | plan-1.md P1-2 (last verified gate-0) | Same as V1-10, plus `gate-1.md` `build: ok` with an empty `build-1.log` (the gate's own editable install succeeded on this tree) | verified | — | `pyproject.toml` is byte-identical to the baseline |
| S-R7 | `search <query>` prints matching notes in the `list` format, case-insensitive substring; no match prints exactly `no matches` and exits 0 | **prd.md R7 — not covered by plan-1.md** | `qa-1-cli.log:255-267` — with notes `Buy Milk` and `call mom` present, `python -m notes search milk` gives `rc=2`, empty stdout and a `usage:` line; `search zzz` likewise `rc=2`. No `search` handler exists (`src/notes/cli.py:95-99` `_HANDLERS` has only `add`, `list`, `done`) | **gap** | major | G1-1. The plan defers this to iteration 2 (`plan-1.md:55`) |
| S-R8 | `list --color` dims done notes with ANSI SGR; without `--color` no escape sequence appears at all, including on a terminal | **prd.md R8 — not covered by plan-1.md** | `qa-1-cli.log:270-274` and `qa-1-pty.log` — `list --color` gives `rc=2` with a `usage:` line and empty stdout, on a pipe and on a real pty. The *absence* half holds: `qa-1-pty.log` shows a sanity child reporting `isatty=True` on the same pty, and plain `list` there emits `b'1. [ ] plain one\r\n2. [x] done one\r\n'` with `ESC (0x1b) count = 0`, `CSI count = 0` | **gap** | major | G1-2. Absence half verified; the dimming half is absent. Appearance is G1-4 |

# Gap details

## G1-1 — `search` (PRD R7) is not implemented — major, owner: developer

- Reproduction:
  ```sh
  export NOTES_FILE=$(mktemp -u)
  .venv/bin/python -m notes add "Buy Milk"
  .venv/bin/python -m notes search milk; echo "rc=$?"
  ```
- Observed: `rc=2`, stdout empty, stderr `usage: python -m notes {add <text> | list | done <n>}`.
  `search zzz` behaves identically (`qa-1-cli.log:255-267`). `_HANDLERS` in
  `src/notes/cli.py:95-99` contains no `search` key.
- Expected (prd.md R7): matching notes printed in the `list` format, matched
  case-insensitively on a substring; no match prints exactly `no matches` and exits 0.
- User impact: a user cannot find a note in a long list; the only way to look for text is
  to read all of `list`. `search` is also reported as an unknown subcommand rather than an
  unimplemented one, so there is no signal that it is coming.
- Recommended fix: add a `search` handler reusing `cli.format_note` for the line format and
  `str.casefold()` on both sides for the match; print `no matches` and return `EXIT_OK` when
  nothing matches. **In the same change, add `search` to the `USAGE` string**
  (`src/notes/cli.py:20`) — PRD R5 requires the usage line to name every subcommand, and
  that clause cannot be fully closed until `search` exists. Add tests for both the hit and
  the `no matches` branch (prd.md section 4 requires at least one test per requirement).
- Suggested owner: developer.

## G1-2 — `list --color` (PRD R8) is not implemented — major, owner: developer

- Reproduction:
  ```sh
  export NOTES_FILE=$(mktemp -u)
  .venv/bin/python -m notes add a && .venv/bin/python -m notes add b && .venv/bin/python -m notes done 2
  .venv/bin/python -m notes list --color; echo "rc=$?"
  ```
- Observed: `rc=2`, stdout empty, stderr a `usage:` line. `_cmd_list`
  (`src/notes/cli.py:50-52`) rejects any argument at all, so `--color` is a usage error.
  Confirmed on a real pty as well (`qa-1-pty.log`).
- Expected (prd.md R8): done notes' text dimmed with ANSI SGR codes, notes that are not
  done unchanged, exit 0.
- User impact: no way to tell done from not-done at a glance beyond the `[x]` marker; the
  documented flag fails with a usage error.
- Note on the half that *is* verified: the "no escape sequence without `--color`, including
  when stdout is a terminal" clause holds today and must keep holding. `qa-1-pty.log` shows
  the child confirming `isatty=True` on the pty and plain `list` producing zero `0x1b`
  bytes. Treat this as a preservation constraint for whichever iteration implements
  `--color`.
- Recommended fix: accept `--color` in `_cmd_list` only (not globally), wrap the *text* of
  done notes in `\033[2m` ... `\033[0m`, and gate the escapes on the flag alone, never on
  `isatty` — the PRD forbids escapes without the flag even on a terminal. Add a test that
  asserts the exact bytes with the flag and a test that asserts `\x1b` is absent without it.
- Suggested owner: developer.

## G1-3 — plan-1.md leaves two PRD requirements out of its Targets — note, owner: developer

- Reproduction: `plan-1.md:19-25` lists Targets T1-1..T1-3, covering R1-R6 only.
  `plan-1.md:55-57` records R7, R8 and R8's appearance under `# Deferred`.
- Observed vs expected: the omission is deliberate and documented (the plan reserves
  iteration 3 for repair, `plan-1.md:58`), not an oversight. Recorded here so it is not
  lost: at the end of iteration 1, 2 of the PRD's 8 functional requirements are unverified,
  and the PRD's Definition of Done (prd.md:75-78) is therefore not met.
- User impact: none directly; this is a coverage record.
- Recommended fix: iteration 2's plan should make R7 and R8 Targets, and must fold the
  `USAGE` string update into the R7 Target (see G1-1).
- Suggested owner: developer (the remedy is implementation; the next Planner reads this
  entry when choosing Targets).

## G1-4 — R8's dim rendering as it actually looks is unverifiable by script — note, owner: user

- Reproduction: none possible yet; `list --color` does not exist (G1-2).
- Observed vs expected: prd.md:70-73 asks QA to confirm the escape codes are present and
  correct and to leave the *appearance* — whether dim text is legible on a dark background —
  as a gap for a human. I can verify the absence half today (G1-2) but there are no escape
  codes to inspect and nothing to look at.
- User impact: a legibility problem would only surface for a real user in a real terminal.
- Recommended fix: once G1-2 is closed, a human runs `python -m notes list --color` in their
  own terminal on their usual background and confirms the done lines are readable. This
  never becomes a Target (`plan-1.md:57`).
- Suggested owner: user. Blocked on G1-2.

## G1-5 — `done` accepts non-canonical spellings of an integer and silently mutates the store — minor, owner: developer

- Reproduction (store seeded with 10 notes, restored between runs; `qa-1-edge.log`):
  ```sh
  .venv/bin/python -m notes done " 1 "; echo "rc=$?"
  .venv/bin/python -m notes done "1_0"; echo "rc=$?"
  .venv/bin/python -m notes done "+1";  echo "rc=$?"
  .venv/bin/python -m notes done "١";   echo "rc=$?"   # Arabic-Indic digit one, U+0661
  .venv/bin/python -m notes done "010"; echo "rc=$?"
  ```
- Observed: all five exit 0, print nothing, and change the store. `done 1_0` marks note
  **10** done. `done "١"` marks note 1 done. (`done 0x1` and `done 1e0` correctly exit 3.)
- Expected (prd.md R4): "An `n` that is not a positive integer ... prints a message naming
  `<n>` to stderr and exits 3, leaving the store unchanged." `1_0`, `١` and arguably `" 1 "`
  and `+1` are not positive integers as the user typed them.
- Cause: `cli._parse_index` (`src/notes/cli.py:75-83`) uses bare `int(raw)`, which accepts
  surrounding whitespace, a leading `+`, PEP 515 underscores and non-ASCII decimal digits.
- User impact: a typo such as `done 1_0` quietly marks the wrong note done instead of
  reporting an error, and there is no output to notice it by. Graded minor because the PRD's
  phrasing is ambiguous for `" 1 "`/`+1`/`010` and the plan's five required cases all behave
  correctly (V1-8 verified).
- Recommended fix: require a canonical decimal spelling before converting, e.g.
  `if not raw.isascii() or not raw.isdigit(): return None` followed by `int(raw)` and the
  existing `< 1` check — that rejects whitespace, `+`, `_`, non-ASCII digits and `-1` while
  keeping `0` on the exit-3 path. Add the new spellings to
  `test_done_rejects_a_bad_index_without_touching_the_store`.
- Suggested owner: developer.

## G1-6 — a traceback reaches the user when the store cannot be written — minor, owner: developer

- Reproduction:
  ```sh
  d=$(mktemp -d) && mkdir -p "$d/ro" && chmod 500 "$d/ro"
  NOTES_FILE="$d/ro/x.json" .venv/bin/python -m notes add hi; echo "rc=$?"
  chmod 700 "$d/ro"
  ```
- Observed (`qa-1-edge.log`, last block): a full 8-frame Python traceback ending in
  `PermissionError: [Errno 13] Permission denied: '.../ro/x.json'`, exit code **1**.
- Expected: a one-line message naming the store path and a documented exit code, as every
  other error path does. `hoh/project.md` coding rules: "Never let a traceback reach the
  user where an exit code is specified."
- Cause: the asymmetry between `store.load`, which converts `OSError` into `StoreError`
  (`src/notes/store.py:41-42`), and `store.save`, which does not guard
  `path.mkdir` / `path.write_text` at all (`src/notes/store.py:50-56`).
- User impact: a read-only home directory, a full disk, or `NOTES_FILE` pointing somewhere
  unwritable turns `add` and `done` into a stack trace instead of an error message. Graded
  minor rather than major because the PRD assigns no exit code to this case and no V item
  covers it; `load`'s equivalent path is already handled, so this is an inconsistency rather
  than an unmet requirement.
- Recommended fix: wrap the body of `store.save` so `OSError` becomes a `StoreError` (or a
  sibling error the CLI maps to a documented code), and add a test using a `chmod 500`
  directory under `tmp_path`. Note for the Planner: the exit code for a write failure is not
  in the PRD, so pick one and record it.
- Suggested owner: developer.

## G1-7 — `add ""` stores an empty note that lists as a bare `1. [ ] ` — note, owner: developer

- Reproduction:
  ```sh
  export NOTES_FILE=$(mktemp -u)
  .venv/bin/python -m notes add ""; echo "rc=$?"
  .venv/bin/python -m notes list | cat -A | head -1
  ```
- Observed (`qa-1-edge.log`): `add ""` exits 0 and `list` prints `1. [ ] ` — the marker
  followed by a trailing space and nothing else.
- Expected: undefined. prd.md R1 does not say whether empty text is allowed. Recorded so the
  decision is explicit rather than accidental.
- User impact: cosmetic; an accidental `add ""` leaves an unremovable blank row (there is no
  delete subcommand).
- Recommended fix: a decision, not necessarily code. Either reject empty or whitespace-only
  text as a usage error (exit 2) or state in the PRD that it is allowed.
- Suggested owner: developer (to raise the question); the PRD wording is the user's call.

# Coverage

`coverage: complete`. No `qa.coverage_incomplete` gap is filed. The two things that looked
environment-blocked were both closed:

- **Python 3.9 at runtime.** The venv is 3.14.7 and no 3.9 interpreter was on `PATH`
  (`qa-1-py39.log`: only 3.11 and 3.14). I obtained CPython 3.9.25 into a scratch directory
  with `uv` and ran `compileall`, the six CLI paths and the full suite under it — `25 passed
  in 0.96s` (`qa-1-py39run.log`). The PRD's 3.9 constraint is verified by execution, not
  just by grep.
- **"No escape sequence even when stdout is a terminal" (R8, absence half).** My first two
  attempts were bad harnesses, not findings: `script -q` produced an empty capture, and a
  naive `pty.openpty` read returned `b''` even for a sanity child. The third attempt closes
  the parent's slave fd before reading and includes a sanity child that reports
  `isatty=True` on the same pty; only then did the real bytes appear
  (`qa-1-pty.log`). Recorded here because the two empty captures would have been easy to
  misread as "no output".

Nothing was left unexamined for permission or time reasons. The candidate tree was
byte-clean before and after (`git status --porcelain` empty both times); all QA output lives
under `hoh/notes/logs/qa-1-*`, which `.gitignore` excludes via `hoh/*/`.

# Planner handoff

- **Preservation candidates** (verified this iteration, keep them true):
  V1-1, V1-2, V1-3, V1-4, V1-5, V1-6, V1-7, V1-8, V1-9, V1-10, V1-11, V1-12, P1-1, P1-2.
  In behavioral terms: exit codes 0/2/3/4 and their stdout/stderr split; the exact strings
  `no notes`, `1. [ ] <text>`, `1. [x] <text>`; the usage line naming every existing
  subcommand; `list` never creating the store; a corrupt store never being overwritten;
  the on-disk JSON shape; stdlib-only imports; `pyproject.toml` untouched; the suite green
  at 25 tests. Add one more, newly measured and easy to break:
  **plain `list` emits zero ANSI escape bytes even when stdout is a tty** — this is half of
  R8 and the `--color` work is the thing most likely to break it.
- **Next target candidates** (owner=developer, priority order):
  1. **G1-1** (major) — `search`, PRD R7. Must carry the `USAGE` string update with it, which
     is what finally closes R5's "names every subcommand" clause.
  2. **G1-2** (major) — `list --color`, PRD R8. These two are the whole remaining functional
     gap; with the 3-iteration budget (`config.md` `T: 3`) both belong in iteration 2 so
     iteration 3 stays free for repair, exactly as `plan-1.md:58` intends.
  3. **G1-5** (minor) — `_parse_index` accepting `1_0`, `١`, `" 1 "`, `+1`, `010`. Cheap, and
     it is the only finding where a wrong note is silently modified.
  4. **G1-6** (minor) — unguarded `store.save` producing a traceback. Needs a PRD decision on
     the exit code for a write failure; pair it with G1-7's empty-text question so the user
     answers both at once.
  5. **G1-7** (note) — `add ""`. Decision first, code second.
- **Further verification needed:**
  - **G1-4 is the only user-owned item** and it is blocked on G1-2. Once `--color` lands,
    QA verifies the SGR bytes and a human confirms legibility on a dark background.
  - R5 is verified only for the subcommands that exist today. Re-verify the usage line in
    the iteration that adds `search`; a stale `USAGE` string would be a regression against
    V1-1 (`verified@evidence-1 V1-1`).
  - When `--color` lands, re-run the pty check in `qa-1-pty.log` (note the harness caveat in
    the Coverage section) to confirm plain `list` still emits no escapes on a terminal.
  - prd.md section 4 requires at least one test per requirement; R7 and R8 currently have
    none, so the R7/R8 work must ship with tests to keep V1-12's successor green.
