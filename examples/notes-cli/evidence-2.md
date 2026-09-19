---
iteration: 2
candidate: .=b09036615657da9ce3436129bc7c4c9c1d3ed50d
plan: plan-2.md
gate: gate-2.md
build: ok
tests: 31 passed in 2.86s
qa_status: fail
regressions: 1
gaps: 6 (blocker 0, major 0, minor 3, note 3)
coverage: complete
---

# Freeze check

| check | observed | verdict |
|---|---|---|
| `git rev-parse HEAD` in `.` | `b09036615657da9ce3436129bc7c4c9c1d3ed50d` | matches the given candidate |
| `git status --porcelain` in `.` | empty (rechecked after all QA work, including `compileall`) | clean |
| branch | `hoh/notes` | matches `config.md` |
| `candidate:` line of `gate-2.md` | `.=b09036615657da9ce3436129bc7c4c9c1d3ed50d` | same tree the gate checked |
| `candidate_dirty:` | `no` | — |
| `built_at` vs commit time | gate `2026-09-19T01:43:22` vs commit `2026-09-19T01:42:25+09:00` | gate ran after the commit |

Inspection proceeded.

# Gate quoted (from gate-2.md, verbatim)

```
build: ok
tests_status: ok
tests: 31 passed in 2.86s
# Artifacts
(none)
# Logs
hoh/notes/logs/build-2.log
hoh/notes/logs/test-2.log
```

`# Artifacts` is `(none)`, so nothing was marked `older_than_commit` and no rebuild was
required; the build was not repeated. `hoh/notes/logs/build-2.log` is 0 bytes (a silent,
successful build). `hoh/notes/logs/test-2.log` ends `31 passed in 2.86s`.

My own independent run reproduces the gate exactly: `31 passed in 2.88s`
(`hoh/notes/logs/qa-2-code.log`, section `V2-8 suite`), 31 collected. `known_fail:` in
`config.md` is empty, so there is no baseline failure to discount. Iteration 1 was
`25 passed` (`gate-1.md`), so the count rose by 6 and nothing was lost.

# Environment note

The shell alias `python` shadows the venv, as the orchestrator stated. Every observation
below invokes the interpreter directly
(`<workspace>/.venv/bin/python`). This changes
nothing about the candidate.

The venv interpreter is **Python 3.14.7**. To verify the PRD's 3.9 constraint by execution
and not only by grep, I reused the scratch CPython **3.9.25** that iteration 1 fetched with
`uv` (it still exists outside the repository) and ran `compileall`, every new code path and
the whole suite under it — `31 passed in 2.51s` (`hoh/notes/logs/qa-2-py39run.log`).
Nothing was installed into the repository; `git status --porcelain` is empty afterwards.

Observation logs, all under `hoh/notes/logs/`:
`qa-2-probe.sh` (the black-box probe, 10 sections), `qa-2-cli.log` (237 lines, its output),
`qa-2-pty.py` + `qa-2-pty.log` (the terminal harness), `qa-2-code.log` (suite, deps, static
3.9), `qa-2-py39run.log` (real CPython 3.9.25), `qa-2-edge.log` and `qa-2-edge2.log`
(default store path, the two deferred minors, the escape-in-text edge).
`qa-2-tests.log` is superseded by `qa-2-code.log` — its last loop was mangled by zsh array
subscripting and was re-run correctly under `bash`; cite `qa-2-code.log`.

# Claims

| id | claim | source (plan/PRD) | evidence (command / file:line / log path) | status | severity | note |
|---|---|---|---|---|---|---|
| V2-1 | `search` matches a case-insensitive substring and prints matches in the `list` format at their **full-list** positions, `[x]` for done | plan-2.md V2-1 (T2-1, R7) | `qa-2-cli.log:1-18` — store `Buy Milk`/`call mom`/`Milk run`; `search milk`, `MILK`, `Milk` each rc 0, empty stderr, stdout exactly `1. [ ] Buy Milk~3. [ ] Milk run`; `search "uy mi"` → `1. [ ] Buy Milk`; `cat -v` at `:14-15` shows no `^[`; after `done 3`, `search milk` → `1. [ ] Buy Milk~3. [x] Milk run` (`:18`) | verified | — | The positions are `1` and `3`, not `1`/`2` — the plan's numbering decision holds, so a number from `search` output is safe to feed to `done`. I added `MILK RUN` (a cross-word query) → `3. [ ] Milk run` (`:12`) |
| V2-2 | `no matches` is exact and rc 0; an absent store stays absent; wrong arity is the usual rc 2 | plan-2.md V2-2 (T2-1, R7) | `qa-2-cli.log:20-32` — (a) `search zzz` rc 0, stdout `no matches`, `wc -c` = 11 (10 + newline), stderr empty; (b) `NOTES_FILE` three directories deep and absent → rc 0, `no matches`, store `no`, parent `no`, grandparent `no`; (c) `search` and `search a b` → rc 2, 0 stdout bytes, one usage line, `store exists after usage errors: no` | verified | — | `search` never calls `save`. Two unspecified edges recorded, not gaps: `search ""` matches every note (`:229`) and `search --color` is treated as a query, printing `no matches` (`:230`) — the PRD defines neither |
| V2-3 | The single usage line names `add`, `list`, `done` **and** `search`; every usage-error form is rc 2 with that line, empty stdout, no traceback, no store created | plan-2.md V2-3 (T2-1, P2-1, R5) | `qa-2-cli.log:34-51` — bare invocation: `usage line count: 1`, line is `usage: python -m notes {add <text> \| list [--color] \| done <n> \| search <query>}`, `grep -c` = 1 for each of `add`/`list`/`done`/`search`; `bogus`, `add`, `done`, `search`, `list extra`, `add a b`, `search a b`, `done 1 2` all rc 2, `stdout_bytes=0`, `traceback=0`, identical line; `store exists after all usage errors: no` | verified | — | R5's "names every subcommand" clause is now fully closed for the first time (it could not be at iteration 1 — evidence-1 G1-1). `[--color]` is documented in the same line |
| V2-4 | `list --color` wraps only a done note's **text** in `ESC[2m`/`ESC[0m`; prefix and not-done lines byte-identical to plain `list` | plan-2.md V2-4 (T2-2, R8) | `qa-2-cli.log:53-70` — `cat -v` gives `1. [ ] plain one` then `2. [x] ^[[2mdone one^[[0m`, rc 0; raw bytes `b'1. [ ] plain one\n2. [x] \x1b[2mdone one\x1b[0m\n'` vs plain `b'1. [ ] plain one\n2. [x] done one\n'`; `plain esc count: 0`, `color esc count: 2`; `not-done line identical: True`, `prefix unchanged: True`, `dim before text: True` | verified | — | Byte-for-byte match to the `done_when` in plan-2.md T2-2. `SGR_DIM`/`SGR_RESET` are named constants (`src/notes/cli.py:27-28`), as instructed |
| V2-5 | The flag alone decides, never `isatty`: plain `list` emits zero `0x1b` on a real pty **and** a pipe; `list --color` emits escapes on both | plan-2.md V2-5 (T2-2, P2-7, R8) | `qa-2-pty.log` (harness `qa-2-pty.py`) — sanity child on the same pty reports `isatty=True`; pty plain `list` rc 0, `b'1. [ ] plain one\r\n2. [x] done one\r\n'`, `ESC count = 0`, `CSI count = 0`; pty `list --color` rc 0, `ESC count = 2`; pipe `list --color` `ESC count = 2`; pipe plain `ESC count = 0`; summary line `flag alone decides (not isatty): True` and `pty colour bytes == pipe colour bytes modulo CRLF: True` | verified | — | The harness closes the parent's slave fd before reading and keeps the isatty sanity child, as evidence-1's Coverage section warned. I also added `search` on a pty → `ESC count = 0` |
| V2-6 | `--color` with an empty store, every rejected spelling/position, and a corrupt store | plan-2.md V2-6 (T2-2, R8) | `qa-2-cli.log:72-89` — (a) absent store + `--color` → rc 0, stdout exactly `no notes`, `esc bytes: 0`, `store created: no`; (b) `list --colour`, `list -c`, `list --color extra`, `list extra --color`, `--color list` all rc 2 with the usage line, plus my additions `list --color --color` and `list --COLOR` also rc 2, `store sha unchanged: yes`; (c) corrupt store: `list --color` and `search x` both rc 4, path named in stderr (`grep -c` = 1), no traceback | verified | — | `--color` is accepted only as `_cmd_list`'s single argument (`src/notes/cli.py:68`); it is not a global pre-subcommand option |
| V2-7 | `done` rejects every non-canonical spelling of an integer with rc 3, names the argument, leaves the store byte-identical; canonical indices still work | plan-2.md V2-7 (T2-3, R4) | `qa-2-cli.log:91-130` — 10-note store, sha `783f3e75…`; the plan's five (`" 1 "`, `1_0`, `+1`, `١`, `010`) plus `0x1`, `1e0`, `0`, `-1`, `abc`, `1.5`, `99`, `""`, `" "`, `11` and my additions `"1 "`, `" 1"`, `٢`, `１` (fullwidth), `00`, `0010`, `+10`, `1__0`, `\t1` — **all 24 rc 3, `stdout_bytes=0`, `arg_named=1`, `traceback=0`, `store_unchanged=yes`**; then `done 1` and `done 10` rc 0 and `list` shows `[x]` on exactly lines 1 and 10 (`count of [x] lines: 2`) | verified | — | Closes evidence-1 G1-5. The message is still `notes: no note <given>`, unchanged. 24 spellings vs the 5 the plan required; the fullwidth `１` and `\t1` are new cases the plan did not name and they are handled too |
| V2-8 | Suite green, passed count > 25 and equal to `gate-2.md`; smoke test alone passes; R7/R8 have test docstrings; no test touches the real home | plan-2.md V2-8 (T2-1..T2-3, P2-10) | `qa-2-code.log` §`V2-8 suite` — `31 passed in 2.88s`, `31 tests collected`; `tests/test_smoke.py` alone `1 passed`; `grep -rn "R7\|R8" tests/` → 5 hits (`test_cli.py:208,229,252,266,285`); `grep -rn "Path.home\|expanduser\|~/.notes.json" tests/` → rc 1, no output | verified | — | 31 > 25 and matches the gate's `31 passed` exactly. Every one of R1–R8 appears in at least one docstring (per-requirement counts in the same log). Also confirmed by execution: the real `$HOME/.notes.json` does not exist after all my runs (`qa-2-edge.log` §E1) |
| V2-9 | The whole evidence-1 black-box matrix still holds, now including `search` and `list --color` | plan-2.md V2-9 (P2-1, P2-2, P2-3, P2-5, P2-6) | `qa-2-cli.log:152-198` — corrupt matrix **9 payloads × 5 argument forms = 45 runs, `0 deviations`** (rc 4, empty stdout, path in stderr, no traceback, sha unchanged); `:200-226` — `list` on an absent 3-deep path → `no notes`, `wc -c` = 9, `store created by list: no`, `parent created by list: no`; ten notes list in insertion order with the boundary correct (`9. [x] note nine`, `10. [ ] note ten`); `:91-116` — the rejected `done` arguments (evidence-1's 8 plus 16 more) all rc 3 with the store byte-unchanged; `:34-51` — the usage-error forms | verified | — | Widened past evidence-1: 45 corrupt runs vs 27, because `search x` and `list --color` were added to the matrix. Not one deviation, so no regression on P2-1/P2-2/P2-3/P2-5/P2-6 |
| V2-10 | The on-disk shape is untouched by the new code paths, and no escape byte ever reaches the file | plan-2.md V2-10 (P2-4) | `qa-2-cli.log:132-150` — after `add`, `add`, `done 2`, `list --color` and `search`: raw file printed; `toplevel keys: ['notes']`, `note keys: [['done','text'],['done','text']]`, `done types: ['bool','bool']`, `text types: ['str','str']`, `escape bytes in file: 0` | verified | — | `--color` is a presentation-layer concern only; `store.save` still writes the plain text (`src/notes/store.py:55`) |
| V2-11 | Only `src/notes/` and `tests/` changed; `pyproject.toml` and `requirements.txt` untouched; stdlib-only imports; dependency set unchanged | plan-2.md V2-11 (P2-8) | `qa-2-code.log` §`V2-11` — `git diff --name-only 0cdf922..HEAD` → exactly `src/notes/cli.py`, `tests/test_cli.py`; the same diff restricted to `-- pyproject.toml requirements.txt` → empty; `git diff aa71252..HEAD -- pyproject.toml` → empty (untouched since the project seed); `cat requirements.txt` → `pytest`; imports are `json`, `os`, `pathlib.Path`, `sys`, `from . import store`, `from .cli import main`; `pip list` → `iniconfig`, `notes 0.1.0` (editable), `packaging`, `pip`, `pluggy`, `Pygments`, `pytest` | verified | — | Nothing beyond pytest's own tree plus `notes`. `store.py` was not touched at all this iteration — the whole change is `cli.py` + its tests |
| V2-12 | 3.9-compatible and actually running under CPython 3.9; function-length limit held | plan-2.md V2-12 (P2-9, P2-10) | `qa-2-code.log` §`V2-12` — `ast.parse(..., feature_version=(3,9))` ok for all 7 files, `files failing 3.9 parse: 0`; no `match` statement, no PEP 604 runtime annotation (both greps rc 1); `compileall -q src/notes` rc 0; longest function is a test at 26 lines, longest in `src/notes` is `_parse_index` at 18 — `longest function under 50: True`. `qa-2-py39run.log` — under real CPython **3.9.25**: `compileall` rc 0; `search MILK` → `1. [ ] Buy Milk` / `3. [ ] Milk run` rc 0; `search zzz` → `no matches` rc 0; `list --color` → `3. [x] ^[[2mMilk run^[[0m` rc 0; `list --colour` rc 2; `done 1_0` rc 3; `done " 1 "` rc 3; corrupt store rc 4 for both `list --color` and `search`; **`31 passed in 2.51s`** | verified | — | `str.isascii()` (the new validator's basis) is 3.7+ — confirmed live on 3.9.25: `"1".isascii() True`, `"١".isascii() False`. The module-length half of P2-9 does **not** hold; see G2-1 and the P2-9 row |
| V2-13 | R8's dim rendering as it actually looks in a terminal is legible | plan-2.md V2-13 (I9 / G1-4, prd.md:70-73) | Not automatable by design. The byte half is verified (V2-4, V2-5): the codes present are `ESC[2m` (SGR 2, dim/faint) and `ESC[0m` (reset), correct and correctly paired around the text only. Appearance re-filed as **G2-4** | **gap** | note | Exactly what prd.md:70-73 and plan-2.md:78 ask QA to do — verify the codes, leave the appearance to a human. Owner `user`; now genuinely actionable for the first time because the escapes exist |
| P2-1 | Usage errors: rc 2, empty stdout, one `usage:` line naming **every** subcommand, no traceback, no store created | plan-2.md P2-1 (verified@evidence-1 V1-1, V1-2) | Same as V2-3 and V2-9 — `qa-2-cli.log:34-51`, 9 forms, all rc 2 with one line naming all four subcommands; `qa-2-cli.log:77-84`, 7 flag-misuse forms also rc 2 | verified | — | Strengthened rather than broken: the line now names `search` too, which is what the constraint demands of "every subcommand the build supports" |
| P2-2 | `add` then `list` in insertion order, `<n>. [ ] <text>` from 1, `[x]` for done, correct past 9 | plan-2.md P2-2 (verified@evidence-1 V1-3, V1-7) | `qa-2-cli.log:6` (`1. [ ] Buy Milk~2. [ ] call mom~3. [ ] Milk run`), `:120-129` (ten notes, `1.`…`10.`, `[x]` on 1 and 10), `:205-215` (`9. [x] note nine`, `10. [ ] note ten`) | verified | — | Byte-identical to evidence-1's format; `format_note`'s default `color=False` keeps the old output path unchanged (`src/notes/cli.py:45-56`) |
| P2-3 | `list` on an empty/absent store prints exactly `no notes`, rc 0, creates neither file nor parent directory | plan-2.md P2-3 (verified@evidence-1 V1-4) | `qa-2-cli.log:201-204` — rc 0, `stdout_bytes=8`, `wc -c` = 9, `store created by list: no`, `parent created by list: no`; `:74-76` — the same with `--color`: rc 0, `no notes`, `esc bytes: 0`, `store created: no` | verified | — | The new flag does not disturb the empty-store path |
| P2-4 | On-disk store is exactly `{"notes":[{"text":str,"done":bool}]}` | plan-2.md P2-4 (verified@evidence-1 V1-5) | Same as V2-10 — `qa-2-cli.log:132-150` | verified | — | `store.py` unchanged this iteration (V2-11), and the shape is re-confirmed by execution anyway |
| P2-5 | A corrupt store makes **every** subcommand rc 4, name the path, print nothing on stdout, no traceback, file byte-unchanged | plan-2.md P2-5 (verified@evidence-1 V1-6) | `qa-2-cli.log:152-198` — 9 payloads × `list`, `add x`, `done 1`, `search x`, `list --color` = **45 runs, 0 deviations**; `:87-89` — the stderr text names the full path | verified | — | The two new argument forms fall on the same exit-4 path because `_cmd_search`/`_cmd_list` validate arity first and then let `store.StoreError` propagate to `main` (`src/notes/cli.py:39-42`) |
| P2-6 | A valid `done <n>` is rc 0 and idempotent; a rejected `<n>` is rc 3, names the argument, no traceback, store byte-unchanged | plan-2.md P2-6 (verified@evidence-1 V1-7, V1-8) | `qa-2-cli.log:93-119` — evidence-1's eight rejected arguments (`0`, `-1`, `abc`, `1.5`, `99`, `""`, `" "`, one past the end = `11`) all still rc 3 with `store_unchanged=yes`; `done 1`/`done 10` rc 0; idempotence re-covered by `tests/test_cli.py:114-123` in the green suite (`qa-2-code.log`) | verified | — | The stricter `_parse_index` only **adds** rejections; nothing that used to be accepted is now refused (`done 1`, `done 10`, `done 3` all rc 0 in `qa-2-cli.log:17,118,119`) |
| P2-7 | Without `--color`, `list` output contains zero `0x1b` bytes — including on a real terminal | plan-2.md P2-7 (verified@evidence-1 S-R8, `qa-1-pty.log`) | `qa-2-pty.log` — pty plain `list` `ESC (0x1b) count = 0` with the sanity child proving `isatty=True` on that same pty; pipe plain `list` count 0; `qa-2-cli.log:55-56,65` — `cat -v` shows no `^[` and the raw count is 0; `qa-2-cli.log:14-15` — `search` likewise | verified | — | Held under the exact pressure the plan flagged as most likely to break it. Scope note: this is about escapes the CLI *generates*. A note whose own text contains `0x1b` is echoed verbatim, so plain `list` can emit that byte — pre-existing, filed separately as **G2-6**, not counted against P2-7 |
| P2-8 | Editable install from an unmodified `pyproject.toml`; dependency set stays stdlib + `pytest` | plan-2.md P2-8 (verified@evidence-1 V1-10, P1-2) | Same as V2-11, plus `gate-2.md` `build: ok` with a 0-byte `build-2.log` (the gate's own editable install succeeded on this tree) and `pip list` showing `notes 0.1.0` editable at the workspace root | verified | — | `pyproject.toml` is byte-identical to the project seed `aa71252` |
| P2-9 | 3.9-compatible and running under CPython 3.9; **every module under 200 lines**; every function under 50 | plan-2.md P2-9 (verified@evidence-1 V1-11) | 3.9 half **verified**: `qa-2-py39run.log` `31 passed` under CPython 3.9.25, `compileall` rc 0, `ast.parse(feature_version=(3,9))` clean for all 7 files; function half **verified**: longest function 26 lines. Module half **fails**: `qa-2-code.log` §`V2-12` `wc -l` → **`tests/test_cli.py` 303**, over the 200-line limit (it was 163 at `0cdf922`, `git show 0cdf922:tests/test_cli.py \| wc -l`) | **gap** | minor | **regression** — `verified@evidence-1 V1-11`. See G2-1. The 3.9 and function-length clauses hold; only the module-length clause broke, and only in the test file |
| P2-10 | `import notes` with a truthy `__version__`, smoke test passes, suite no smaller than 25, every PRD requirement has a test, no test reads the real home | plan-2.md P2-10 (verified@evidence-1 V1-9, V1-12, P1-1) | Same as V2-8 — `31 passed`, `tests/test_smoke.py` alone `1 passed` (it asserts the import and a truthy `__version__`, `tests/test_smoke.py:1-5`), 31 > 25, R1–R8 each named in at least one docstring, home-leak grep rc 1, and `$HOME/.notes.json` still absent after every run (`qa-2-edge.log` §E1) | verified | — | Six tests added, none removed; `test_smoke.py` and `test_store.py` are byte-identical to iteration 1 (V2-11's diff) |
| S-R1 | `add <text>` appends a note and exits 0; a following `list` shows that text | prd.md R1 — covered by plan-2.md P2-2/V2-9 | `qa-2-cli.log:3-6` — three adds rc 0, `list` shows all three in order | verified | — | — |
| S-R2 | `list` prints `<n>. [ ] <text>` from 1 in insertion order, `[x]` when done | prd.md R2 — covered by plan-2.md P2-2/V2-9 | `qa-2-cli.log:120-129`, `:205-215` | verified | — | — |
| S-R3 | `list` on an empty store prints exactly `no notes`, exits 0, creates no file | prd.md R3 — covered by plan-2.md P2-3/V2-9 | `qa-2-cli.log:201-204` | verified | — | — |
| S-R4 | `done <n>` marks note `n`, exits 0; a non-positive-integer or out-of-range `n` names `<n>` on stderr, exits 3, store unchanged | prd.md R4 — covered by plan-2.md V2-7/P2-6 | `qa-2-cli.log:93-130` — 24 rejected spellings rc 3, `done 1`/`done 10` rc 0 marking exactly those two | verified | — | Materially stronger than at iteration 1, which silently accepted `1_0` and `١` (evidence-1 G1-5) |
| S-R5 | No/unknown subcommand or a missing argument prints a usage line to stderr and exits 2; the line names every subcommand | prd.md R5 — covered by plan-2.md V2-3/P2-1 | `qa-2-cli.log:34-51` | verified | — | Fully closed for the first time; `search` is now named |
| S-R6 | The store is the documented JSON object; an invalid one makes every subcommand name the path on stderr and exit 4, never a traceback, never a silent overwrite | prd.md R6 — covered by plan-2.md P2-4/P2-5/V2-10/V2-9 | `qa-2-cli.log:132-198` — shape verified; 45-run corrupt matrix, 0 deviations | verified | — | — |
| S-R7 | `search <query>` prints matching notes in the `list` format, case-insensitive substring; no match prints exactly `no matches` and exits 0 | prd.md R7 — covered by plan-2.md V2-1/V2-2 | `qa-2-cli.log:1-32`, plus real 3.9 in `qa-2-py39run.log` | verified | — | Closes evidence-1 G1-1 |
| S-R8 | `list --color` dims done notes' text with ANSI SGR and leaves not-done notes unchanged; without `--color` no escape sequence appears at all, even on a terminal | prd.md R8 — covered by plan-2.md V2-4/V2-5/V2-6/V2-13 | `qa-2-cli.log:53-89`, `qa-2-pty.log` (both halves, pty and pipe), `qa-2-py39run.log` | verified | — | Closes evidence-1 G1-2. The **appearance** half stays open by PRD design — G2-4 / V2-13. Byte-level edge on text that already contains `0x1b`: G2-6 |
| S-sec3 | With `NOTES_FILE` unset (or empty) the store path is `~/.notes.json` | **prd.md:29-30, section 3 preamble — not covered by any V-id or P-id in plan-2.md** | `qa-2-edge.log` §E1 — with `HOME` pointed at a scratch directory and `NOTES_FILE` unset: `list` → `no notes` rc 0 and no file created; `add` → rc 0 and `$HOME/.notes.json` created; `list`/`search DEFAULT` read it back; `NOTES_FILE=""` also falls back (`store.resolve_path`, `src/notes/store.py:26-32`, treats empty as unset). The real `$HOME/.notes.json` is still absent | verified | — | The PRD clause has no `R<n>` of its own, so the id names its section; I did not invent an `R` number. The plan's omission is filed as **G2-5** so the next Planner gives it a V-id |

# Gap details

## G2-1 — `tests/test_cli.py` grew past the 200-line module limit — minor, **regression**, owner: developer

- Last verified: `verified@evidence-1 V1-11` (P2-9's "every module stays under 200 lines").
- Reproduction:
  ```sh
  cd <workspace>
  wc -l src/notes/*.py tests/*.py
  git show 0cdf922c5d11c9a2e4882e842a364c355683e047:tests/test_cli.py | wc -l
  ```
- Observed: `tests/test_cli.py` is **303** lines; it was **163** at the iteration-1 candidate.
  All other modules are fine (`cli.py` 145, `store.py` 90, `test_store.py` 97).
- Expected: `hoh/project.md` coding rules — "a module over 200 lines gets split" — and
  plan-2.md P2-9, "every module stays under 200 lines".
- User impact: none at runtime. It is a maintainability cost: the single CLI test file now
  mixes usage errors, the store shape, the corrupt matrix, `done` canonicality, `search` and
  `--color`, which makes the next iteration's edits harder to place and review.
- Recommended fix: split `tests/test_cli.py` by area, the way `hoh/project.md` describes
  ("one file per area") — e.g. `tests/test_cli_usage.py` (R5 and the flag-spelling cases),
  `tests/test_cli_store.py` (R3, R6, the corrupt matrix), `tests/test_cli_done.py` (R4 and
  the canonicality table), `tests/test_cli_search.py` (R7), `tests/test_cli_color.py` (R8).
  Pure test motion, no production change, so it cannot alter any verified behavior — but
  re-run V2-8 afterwards so the passed count is still 31.
- Suggested owner: developer.
- Note for the next Planner: plan-2.md is internally inconsistent here. P2-9 says "every
  module", but the V2-12 command that is supposed to check it reads
  `wc -l src/notes/*.py` only, so the constraint as written can never fail on a test file.
  Either narrow P2-9's wording to `src/` or widen V2-12's command; right now the plan
  disagrees with itself and I graded against the constraint text.

## G2-2 — an unwritable store still produces a traceback and exit 1 — minor, owner: developer

- Reproduction:
  ```sh
  d=$(mktemp -d) && mkdir -p "$d/ro" && chmod 500 "$d/ro"
  NOTES_FILE="$d/ro/x.json" .venv/bin/python -m notes add hi; echo "rc=$?"
  chmod 700 "$d/ro"
  ```
- Observed (`qa-2-edge.log` §E2): a full 8-frame traceback ending
  `PermissionError: [Errno 13] Permission denied: '.../ro/x.json'`, exit code **1**. The same
  happens for `done 1` against a valid store in a read-only directory. The frames now point
  at `src/notes/cli.py:63` → `src/notes/store.py:56`.
- Expected: `hoh/project.md` coding rules — "Never let a traceback reach the user where an
  exit code is specified." plan-2.md's Deferred section already rules that `save` should turn
  `OSError` into `StoreError`, which `main` maps to **exit 4**.
- User impact: an unwritable `NOTES_FILE`, a read-only home or a full disk turns `add` and
  `done` into a stack trace instead of a one-line message. The user cannot tell this apart
  from a crash.
- Recommended fix: exactly what plan-2.md:82-88 already decided — wrap the body of
  `store.save` so `OSError` becomes `StoreError` (exit 4), and add a test using a `chmod 500`
  directory under `tmp_path`. No new exit code, no PRD change, no decision left to make.
- Suggested owner: developer.
- Status note: this is evidence-1 G1-6, re-observed unchanged on this candidate. plan-2.md
  deliberately deferred it to keep R7/R8 the only risk, and reserved iteration 3 for it. Not
  a regression and not a missed Target — re-filed only so it is not lost.

## G2-3 — `add ""` and `add "   "` still store a blank note — note, owner: developer

- Reproduction:
  ```sh
  export NOTES_FILE=$(mktemp -u)/g7/store.json
  .venv/bin/python -m notes add ""; echo "rc=$?"
  .venv/bin/python -m notes add "   "
  .venv/bin/python -m notes list
  ```
- Observed (`qa-2-edge2.log`): both rc 0; `list` emits `b'1. [ ] \n2. [ ]    \n'`, and the
  store holds `{"text": "", …}` and `{"text": "   ", …}`. `search ""` matches both.
- Expected: undefined by the PRD. plan-2.md:89-93 has already decided the remedy (treat
  empty or whitespace-only text as a usage error, exit 2) and deferred it to iteration 3.
- User impact: cosmetic. An accidental `add ""` leaves a row that cannot be removed — there
  is no `delete` subcommand.
- Recommended fix: as plan-2.md decided — reject empty/whitespace-only text with the usage
  line and exit 2, with a test. Cheap, and it needs no new exit code.
- Suggested owner: developer.
- Status note: evidence-1 G1-7, re-observed unchanged. Deferred on purpose, not a regression.

## G2-4 — R8's dim rendering as it actually looks is still a human judgement — note, owner: user

- Reproduction (for the human, in their own terminal):
  ```sh
  cd <workspace>
  export NOTES_FILE=$(mktemp -u)
  .venv/bin/python -m notes add "still to do" && .venv/bin/python -m notes add "already done"
  .venv/bin/python -m notes done 2
  .venv/bin/python -m notes list --color
  ```
- Observed: I can verify the bytes and I have — `2. [x] \x1b[2malready done\x1b[0m`, SGR 2
  (dim/faint) opened before the text and SGR 0 (reset) closed after it, nothing wrapping the
  `<n>. [x] ` prefix and nothing on not-done lines (`qa-2-cli.log:62-70`, `qa-2-pty.log`).
  What I cannot observe is whether dim text is legible on the user's background.
- Expected: prd.md:70-73 explicitly assigns this to a human and tells QA to leave it as a
  gap. plan-2.md:78 (V2-13) and plan-2.md:94-95 repeat that it never becomes a Target.
- User impact: on some terminal themes SGR 2 renders close to the background and done notes
  could become hard to read. Only a human on a real terminal can say.
- Recommended fix: none unless the human reports a problem. If dim proves illegible, the
  follow-up is a PRD amendment choosing a different SGR code, not a defect fix.
- Suggested owner: **user**. This is the PRD-mandated manual gap; it is now actionable for
  the first time (at iteration 1 there was nothing to look at — evidence-1 G1-4).

## G2-5 — plan-2.md gives the default store path no V-id or P-id — minor, owner: developer

- Reproduction: grep plan-2.md's Validation and Preservation tables for `NOTES_FILE` — the
  V-ids all *set* it to a temp path (plan-2.md:59-62 mandates that, correctly, so nothing
  touches the real home), and no id checks the fallback when it is **unset**. prd.md:29-30
  states the fallback as a requirement of section 3.
- Observed vs expected: the behavior itself is correct — I verified it with `HOME` pointed at
  a scratch directory (`qa-2-edge.log` §E1, claim `S-sec3`). What is missing is coverage: no
  plan id and, more importantly, **no test** asserts it. `grep -rn "Path.home\|expanduser"
  tests/` returns nothing, which V2-8 requires for home-safety but also means the fallback is
  untested. A future refactor of `store.resolve_path` could break `~/.notes.json` and the
  suite would stay green.
- User impact: none today. It is an unguarded requirement — the most common invocation
  (`python -m notes list` with no environment set) is the one with no test behind it.
- Recommended fix: add a test that monkeypatches `HOME` (or `Path.home`) to `tmp_path`,
  deletes `NOTES_FILE` from the environment, and asserts the store lands at
  `tmp_path/".notes.json"` — safe for the real home because `HOME` is redirected. Give it a
  docstring naming prd.md section 3. The next plan should carry it as a V-id.
- Suggested owner: developer.

## G2-6 — plain `list` echoes escape bytes that are inside a note's own text — note, owner: user

- Reproduction:
  ```sh
  export NOTES_FILE=$(mktemp -u)
  .venv/bin/python -m notes add "$(printf 'red\033[31mtext')"
  .venv/bin/python -m notes list | cat -v      # shows red^[[31mtext
  ```
- Observed (`qa-2-edge.log` §E4): plain `list` emits `b'1. [ ] red\x1b[31mtext\n'` — one
  `0x1b` byte, with no `--color` flag given.
- Expected, on the strictest reading of prd.md R8: "Without `--color`, no escape sequence
  appears in the output at all." On the intended reading, R8 governs the escapes the CLI
  *generates* for dimming, and text the user typed is echoed verbatim — which is what
  happens.
- User impact: low but real — a note containing an escape sequence can recolor or reposition
  the rest of the terminal output. There is no way to store such text by accident; it takes a
  deliberate `printf`.
- Recommended fix: a wording decision first, code second. Either add a sentence to R8
  scoping it to escapes the CLI adds, or require `list` to escape non-printable bytes in
  stored text (which would change the exact output strings R2 fixes, so it needs a PRD
  amendment).
- Suggested owner: **user** (PRD wording); developer implements only if the user chooses
  sanitization.
- Status note: **not a regression.** Iteration 1's `format_note`
  (`git show 0cdf922:src/notes/cli.py:37-39`) interpolated `note["text"]` verbatim in exactly
  the same way; the behavior is unchanged, it was simply never probed. P2-7 is verified
  separately on stores without embedded escapes, which is the constraint's real subject.

# Coverage

`coverage: complete`. No `qa.coverage_incomplete` gap is filed. Nothing was skipped for
environment, permission or time reasons.

- **Real CPython 3.9.** The venv is 3.14.7. The scratch CPython 3.9.25 that iteration 1
  fetched with `uv` still exists outside the repository, so I reused it rather than
  re-downloading: `compileall` rc 0, all the new code paths at the expected exit codes, and
  the whole suite `31 passed in 2.51s` (`qa-2-py39run.log`). `git status --porcelain` is
  empty afterwards — nothing was installed into the repository.
- **The pty half of R8.** Reproduced with the harness caveat evidence-1 recorded: the parent
  closes its copy of the slave fd before reading and a sanity child confirms `isatty=True` on
  the same pty, so an empty capture cannot be misread as "no output" (`qa-2-pty.py`,
  `qa-2-pty.log`). Both directions checked — plain `list` emits nothing on a pty, and
  `list --color` emits escapes on a pty *and* on a pipe, which is what proves the flag and
  not `isatty` is the gate.
- **V2-13** is unverifiable by script by the PRD's own design, not by any limitation of this
  environment. It is filed as G2-4 with `owner=user`, which is what prd.md:70-73 asks for.
- One harness defect of my own, recorded so the log is not misread: `hoh/notes/logs/qa-2-tests.log`
  ends in `bad math expression` errors — zsh parsed `$r[:,. ]` as an array subscript. That is
  my shell quoting, not a finding. The loop was re-run under `bash` and its correct output is
  in `qa-2-code.log`. Likewise `cat -A` in the first `qa-2-edge.log` §E3 failed because BSD
  `cat` has no `-A`; §E3 was redone in `qa-2-edge2.log`.
- The candidate tree was byte-clean before and after (`git status --porcelain` empty both
  times). All QA output lives under `hoh/notes/logs/qa-2-*`, which `.gitignore` excludes via
  `hoh/*/`.

# Why `qa_status: fail` with no blocker and no major gap

All three Targets are fully verified — T2-1 (`search`, R7) by V2-1/V2-2/V2-3, T2-2
(`list --color`, R8) by V2-4/V2-5/V2-6, T2-3 (canonical `done` index, R4) by V2-7 — and
every one of the ten Preservation constraints was re-driven through the public interface with
zero deviations across 45 corrupt-store runs and 24 `done` spellings. All eight PRD
functional requirements are verified black-box for the first time in this loop.

`fail` follows from the rule mechanically, for two reasons only:

1. **V2-13 / G2-4 can never be `verified` by QA.** prd.md:70-73 requires QA to leave R8's
   appearance as a gap for a human. As long as that stands, `qa_status: pass` is unreachable
   by construction — it is not a statement about the Developer's work.
2. **P2-9 is a gap** because `tests/test_cli.py` is 303 lines against a 200-line rule
   (G2-1) — a test-only maintainability regression, minor, and fixable by pure test motion.

# Planner handoff

- **Preservation candidates** (verified on this candidate — keep them true):
  V2-1, V2-2, V2-3, V2-4, V2-5, V2-6, V2-7, V2-8, V2-9, V2-10, V2-11, V2-12,
  P2-1, P2-2, P2-3, P2-4, P2-5, P2-6, P2-7, P2-8, P2-10, and S-R1…S-R8, S-sec3.
  In behavioral terms, iteration 3 must not disturb: exit codes 0/2/3/4 and their
  stdout/stderr split; the exact strings `no notes` and `no matches`; the line formats
  `<n>. [ ] <text>` / `<n>. [x] <text>`; the single usage line
  `usage: python -m notes {add <text> | list [--color] | done <n> | search <query>}` naming
  all four subcommands; `search` numbering by full-list position (renumbering would make
  `search` output feed `done` the wrong note); `2. [x] \x1b[2m<text>\x1b[0m` as the exact
  colored form with the prefix and not-done lines unescaped; the flag — never `isatty` —
  deciding escapes; `list`/`search` never creating the store; a corrupt store never
  overwritten; 24 non-canonical `done` spellings all rc 3; the on-disk JSON shape;
  stdlib-only imports with `pyproject.toml` and `requirements.txt` untouched; and
  **31 passing tests under both 3.14 and real 3.9** as the new floor.
  Newly measured and worth naming explicitly: `search` on a pty emits zero escape bytes, and
  no escape byte ever reaches the store file even after a `list --color` run.
- **Next target candidates** (owner=developer only, priority order):
  1. **G2-2** (minor) — guard `store.save` so `OSError` becomes `StoreError` → exit 4. The
     decision is already made in plan-2.md:82-88, so it needs no new ruling; it is the only
     remaining path where a traceback reaches the user, which `hoh/project.md` forbids
     outright.
  2. **G2-1** (minor, regression) — split `tests/test_cli.py` (303 lines) by area. Pure test
     motion, cannot change behavior; re-run V2-8 and confirm the count is still 31. While
     there, reconcile P2-9's "every module" with V2-12's `src/notes/*.py`-only command.
  3. **G2-5** (minor) — add the missing test for the `~/.notes.json` fallback with `HOME`
     redirected to `tmp_path`, and give prd.md section 3's store-path rule a V-id.
  4. **G2-3** (note) — reject empty/whitespace-only `add` text as a usage error (exit 2).
     The decision is already made in plan-2.md:89-93.
  All four are small and independent; iteration 3 is the last one (`config.md` `T: 3`) and no
  repair of T2-1..T2-3 is needed, so the whole budget is available for them. If the Planner
  wants to keep risk near zero, taking only G2-2 and G2-1 still leaves the PRD's Definition
  of Done satisfied.
- **Further verification needed:**
  - **G2-4 is the only user-owned item.** The bytes are verified; a human must run
    `.venv/bin/python -m notes list --color` on their usual background and confirm the dimmed
    lines are legible. Until they do, `qa_status` cannot be `pass` — the Planner should not
    treat that as an open defect.
  - **G2-6 needs a PRD wording call from the user**, not code: does R8's "no escape sequence
    at all" cover bytes the user themselves stored? Pair this question with G2-3's
    empty-text question so the user answers both at once.
  - If G2-2 lands, re-run the 45-run corrupt matrix (`qa-2-probe.sh` section 8) plus a new
    unwritable-store case: `save` gaining a `StoreError` path touches the same exit-4 code
    that P2-5 depends on.
  - If `tests/test_cli.py` is split (G2-1), re-check V2-8's greps: `R7`/`R8` docstrings and
    the per-requirement coverage must survive the move, and no test may acquire a real-home
    dependency.
  - Two behaviors remain unspecified and unpinned by any test, so a later change could alter
    them silently: `search ""` matches every note, and `search --color` / `add --color` treat
    `--color` as ordinary text. Neither is a defect; both deserve a PRD sentence or a test if
    the user cares.
