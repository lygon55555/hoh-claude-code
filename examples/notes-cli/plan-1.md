---
iteration: 1
status: active
targets: 3
---

# Diagnosis

- Root cause: no CLI exists at all. `src/notes/` is a stub holding only `__version__`, there is no `__main__.py`, so `python -m notes` cannot run and R1-R8 are all unmet (evidence: gate-0 baseline — build ok, `1 passed`, which is `tests/test_smoke.py::test_package_imports` alone; prd section 1, confidence high).
- Strategy: build the CLI bottom-up in one pass — entry point and dispatch first (nothing is observable without it), then the durable JSON store together with `add`/`list`, then `done`. Stop at R1-R6; leave `search` (R7) and `--color` (R8) for iteration 2 so that the 3-iteration budget in config.md keeps one iteration in reserve for repair.
- Stop condition: stop and report if the gate build fails twice for the same reason, or if any `python -m notes` invocation named in a V item still shows a `Traceback` after two repair attempts. Do not start R7 or R8 this iteration even if time remains.

# Evidence summary (for the Developer, 3 lines max)

- There is no previous QA bundle; the t=0 baseline gate was green (build: ok, tests: `1 passed`) and `config.md` records an empty `known_fail:`, so the tree is clean and every failure you see is one you introduced.
- The single existing test is `tests/test_smoke.py::test_package_imports`; it must keep passing, and `pytest -q` exits 5 on an empty collection, so never leave the tree testless.
- `src/notes/__init__.py` is three lines and `src/notes/__main__.py` does not exist, so `python -m notes` currently fails with "No module named notes.__main__".

# Targets (priority order, at most 3)

| id | type | title | instruction | target paths | linked issue/gap | done_when | validation |
|---|---|---|---|---|---|---|---|
| T1-1 | blocker | `python -m notes` entry point, subcommand dispatch and usage line | Add `src/notes/__main__.py` so `python -m notes` runs, plus the CLI module it delegates to. Parse a subcommand and dispatch to a handler. No subcommand, an unknown subcommand, or a subcommand missing its required argument must print a usage line to stderr and exit 2; stdout stays empty in all three cases. The usage line must name every subcommand that exists after this iteration (`add`, `list`, `done`); `search` is added to the same line in the iteration that implements R7. Note that argparse subparsers are optional by default on Python 3.9, so the bare `python -m notes` case needs explicit handling to reach exit 2. Resolve the store path once here: `NOTES_FILE` if set and non-empty, otherwise `~/.notes.json`. | `src/notes/__main__.py`, `src/notes/cli.py`, `tests/test_cli.py` | I1 | `python -m notes`, `python -m notes bogus` and `python -m notes add` each exit 2 with a `usage:` line on stderr naming `add`, `list` and `done`, and print nothing on stdout | V1-1, V1-2, V1-11, V1-12 |
| T1-2 | requirement | Durable JSON store with `add` and `list` | Add a store module that reads and writes `{"notes": [{"text": <string>, "done": <boolean>}]}` and validates that shape on every read: invalid JSON, a top-level value that is not an object, a missing or non-list `notes`, or an element that is not an object with a string `text` and a boolean `done` must all make the running subcommand print a message naming the store path to stderr and exit 4, with no traceback and without writing to the file. Then implement `add <text>` (append, exit 0) and `list` (one line per note, insertion order, `<n>. [ ] <text>` with `n` from 1, `[x]` when done). A store that does not exist or holds no notes makes `list` print exactly `no notes` and exit 0 without creating the file. `add` creates the file and its parent directory if needed. | `src/notes/store.py`, `src/notes/cli.py`, `tests/test_cli.py`, `tests/test_store.py` | I2, I3, I4, I5, I10 | after two `add` calls `list` prints the two texts numbered 1 and 2 in insertion order; `list` on a path that does not exist prints exactly `no notes`, exits 0 and leaves the path absent; a store holding `{` makes every subcommand exit 4 naming the path and leaves the bytes unchanged | V1-3, V1-4, V1-5, V1-6, V1-11, V1-12 |
| T1-3 | requirement | `done <n>` with argument validation | Implement `done <n>`: mark note `n` (1-based) done and exit 0; a following `list` shows `[x]` for it. An `n` that is not a positive integer (`0`, `-1`, `abc`, `1.5`) or is past the end of the list prints a message naming the `<n>` the user gave to stderr and exits 3, leaving the store byte-identical. Keep the boundary with R5 exact: `done` with no argument at all is a usage error (exit 2), while `done` with a present but invalid argument is exit 3. Marking a note that is already done stays exit 0 and leaves it done. | `src/notes/cli.py`, `src/notes/store.py`, `tests/test_cli.py` | I6, I10 | `done 1` after an `add` exits 0 and `list` shows `1. [x] <text>`; `done 0`, `done abc` and `done 99` each exit 3 with the given `<n>` in the stderr message and the store file unchanged; `done` with no argument exits 2 | V1-7, V1-8, V1-11, V1-12 |

# Preservation constraints

| id | behavior to preserve | verified in (evidence id) | how to check (V-id) |
|---|---|---|---|
| P1-1 | `import notes` succeeds and exposes a truthy `__version__`, and the whole test suite is green — the existing smoke test keeps passing alongside the new tests. | gate-0 (build: ok, tests: `1 passed`) | V1-9 |
| P1-2 | The package still installs editable from `pyproject.toml` into `.venv` so `import notes` works from the tests with no path juggling, and the dependency set stays standard-library-plus-pytest. | gate-0 (build: ok) | V1-10 |

# Validation requirements

All commands run from the workspace root after `. .venv/bin/activate`. Where a store is needed, set `export NOTES_FILE="$(mktemp -u)"` first so the real home directory is never touched.

| id | target | kind | method |
|---|---|---|---|
| V1-1 | T1-1 | runtime | Run `python -m notes; echo "rc=$?"`. Expect `rc=2`, stdout empty, and stderr containing a line starting with `usage:` that names `add`, `list` and `done`. |
| V1-2 | T1-1 | runtime | Run `python -m notes bogus; echo "rc=$?"`, then `python -m notes add; echo "rc=$?"`, then `python -m notes done; echo "rc=$?"`. Expect `rc=2` for all three, stdout empty, a `usage:` line on stderr each time, and no `Traceback` anywhere in stderr. |
| V1-3 | T1-2 | runtime | With a fresh `NOTES_FILE`: `python -m notes add "buy milk"` then `python -m notes add "call mom"`, each `rc=0`. Then `python -m notes list` must print exactly two lines, `1. [ ] buy milk` and `2. [ ] call mom`, in that order, `rc=0`. |
| V1-4 | T1-2 | runtime | With `NOTES_FILE` pointing at a path that does not exist: `python -m notes list` prints exactly `no notes` and nothing else, `rc=0`. Then `test ! -e "$NOTES_FILE"` must succeed — `list` may not create the store. |
| V1-5 | T1-2 | code | After the two adds of V1-3, read the file back: `python -c "import json,os; d=json.load(open(os.environ['NOTES_FILE'])); print(sorted(d), [sorted(n) for n in d['notes']], [type(n['done']).__name__ for n in d['notes']])"`. Expect the top-level keys to be exactly `['notes']`, each note's keys exactly `['done', 'text']`, and every `done` of type `bool`. |
| V1-6 | T1-2 | runtime | Corrupt-store matrix. For each of the payloads `{`, `[]`, `{"notes": "nope"}`, `{"notes": [{"text": "x"}]}`: write it to `NOTES_FILE`, copy it to `$NOTES_FILE.bak`, then run `python -m notes list`, `python -m notes add "x"` and `python -m notes done 1`. Each of the twelve runs must give `rc=4`, print a stderr message containing the store path, print no `Traceback`, and leave `cmp "$NOTES_FILE" "$NOTES_FILE.bak"` silent. |
| V1-7 | T1-3 | runtime | With a fresh `NOTES_FILE`: `python -m notes add "buy milk"`, `python -m notes done 1` (`rc=0`), then `python -m notes list` prints exactly `1. [x] buy milk`, `rc=0`. Run `python -m notes done 1` a second time: still `rc=0`, and `list` output is unchanged. |
| V1-8 | T1-3 | runtime | After one `add`, copy the store to `$NOTES_FILE.bak`. For each of `done 0`, `done -1`, `done abc`, `done 1.5`, `done 99`: expect `rc=3`, a stderr message containing the argument as the user typed it, no `Traceback`, and `cmp "$NOTES_FILE" "$NOTES_FILE.bak"` silent. |
| V1-9 | P1-1 | code | Run `python -m pytest -q`: green, and the passed count is strictly greater than the baseline `1`. Run `python -c "import notes; print(notes.__version__)"`: prints a non-empty version and exits 0. Confirm `tests/test_smoke.py` still runs, e.g. `python -m pytest -q tests/test_smoke.py` reports `1 passed`. |
| V1-10 | P1-2 | code | `git diff --name-only <baseline>..HEAD -- pyproject.toml` is empty. `cat requirements.txt` shows `pytest` as the only entry. `grep -rnE "^\s*(import\|from) " src/notes` shows only standard-library modules (expect `json`, `os`, `sys`, `argparse`, `pathlib` and the package's own modules). |
| V1-11 | T1-1, T1-2, T1-3 | code | Python 3.9 compatibility and size limits: `grep -rn "match .*:" src/notes` shows no `match` statement, `grep -rnE ":\s*\w+\s*\|\s*\w+" src/notes` shows no runtime `X \| Y` annotation, `python -m compileall -q src/notes` exits 0, and `wc -l src/notes/*.py` shows every module at or under 200 lines. Report any function longer than 50 lines. |
| V1-12 | T1-1, T1-2, T1-3 | code | Test coverage of the requirements: `grep -rn "def test_" tests/` lists at least one test per R1-R6, identifiable by name or by an `R<n>` mention in the test or its docstring; name any of R1-R6 with no test. Also confirm isolation: no test references `Path.home()`, `expanduser` or a literal `~/.notes.json`, and every test that invokes the CLI sets `NOTES_FILE` under a `tmp_path`. |

# Deferred

- R7 `search <query>` (I7) — case-insensitive substring match printed in the `list` format, `no matches` plus exit 0 when nothing matches. Iteration 2. The usage line from T1-1 must gain `search` in the same iteration, and R5 is only fully verifiable then, because "the usage line names every subcommand" cannot be checked while a subcommand is missing.
- R8 `list --color` (I8) — dim ANSI SGR on done notes, and no escape sequence at all without the flag, including when stdout is a terminal. Iteration 2 or 3.
- R8's appearance (I9, owner `user`) — whether the dim rendering is legible on a dark background is a human judgement. QA verifies the escape codes are present and correct and leaves the appearance as a gap for a human; this never becomes a Target.
- Budget note: `config.md` sets `T: 3`. With R1-R6 here and R7-R8 in iteration 2, iteration 3 is the only slack for regressions, so prefer repairing a failed V item over adding scope.
