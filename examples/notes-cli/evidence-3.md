---
iteration: 3
candidate: .=039c471757418955e9871c95e3eeb5a630f68b0b
plan: plan-3.md
gate: gate-3.md
build: ok
tests: 37 passed in 3.18s
qa_status: fail
regressions: 0
gaps: 5 (blocker 0, major 0, minor 2, note 3)
coverage: incomplete
---

# Freeze check

| check | result |
|---|---|
| `git rev-parse HEAD` | `039c471757418955e9871c95e3eeb5a630f68b0b` = the given candidate |
| `git status --porcelain` | empty, before and after every probe (`qa-3-cli.log:4-5`, `qa-3-py39.log` tail) |
| `gate-3.md` `candidate:` | `.=039c471757418955e9871c95e3eeb5a630f68b0b` — same tree |
| branch | `hoh/notes` |

# Gate quote (verbatim from gate-3.md)

```
build: ok
tests_status: ok
tests: 37 passed in 3.18s
# Artifacts
(none)
# Logs
hoh/notes/logs/build-3.log
hoh/notes/logs/test-3.log
```

Nothing is marked `older_than_commit`, so no gate step was repeated on that ground.
I did independently re-run the suite three times — twice on the gate's interpreter and
once after deleting every `__pycache__` under `src/` and `tests/` — so the pass is not a
stale-artifact pass: `37 passed` each time (`qa-3-py39.log`, and the post-cleanup run
recorded below). `37 passed` also reproduces under real CPython 3.9.25.

# Claims

| id | claim | source (plan/PRD) | evidence (command / file:line / log path) | status | severity | note |
|---|---|---|---|---|---|---|
| V3-1 | Every file in `src/notes/*.py tests/*.py` is ≤ 200 lines; T3-1 touched no production file beyond `src/notes/store.py`/`cli.py` | plan T3-1 | `qa-3-cli.log:7-24` (`wc -l`, longest `src/notes/cli.py` 146, `tests/test_cli_store.py` 112, none over 200); `git diff --stat b090366..HEAD -- src/` = `cli.py 3 ++-`, `store.py 39 +++---` only | verified | — | T3-1 `done_when` met. `tests/test_cli.py` went 303 → 40 lines |
| V3-2 | Suite green, ≥ 31 passed, count equals the gate; smoke alone passes; each of `R1`…`R8` still named in a test docstring | plan T3-1, P3-12 | `.venv/bin/python -m pytest -q` → `37 passed in 3.09s` (= gate's 37); `--collect-only` → `37 tests collected`; `tests/test_smoke.py` → `1 passed`; per-file 2+3+2+4+4+3+1+4+14 = 37; R1→`test_cli.py:11`,`test_store.py:48`; R2→`test_cli.py:11,31`; R3→`test_cli.py:21`,`test_store.py:32`; R4→`test_cli_done.py:9,20,34`,`test_cli_store.py:101`,`test_store.py:91`; R5→`test_cli_usage.py:10,22,32,50`; R6→`test_cli_store.py:47,59,81,101`,`test_store.py:37,69`; R7→`test_cli_search.py:9,29`; R8→`test_cli_color.py:9,22`,`test_cli_usage.py:50` | verified | — | Rose 31 → 37, never fell. No docstring lost in the split |
| V3-3 | An unwritable store makes `add` and `done` exit 4 with one stderr line naming the path, zero stdout, no traceback, in both the parent-exists and parent-must-be-created shapes | plan T3-2 | `qa-3-cli.log:277-290`: `add` into `chmod 500` dir → `rc=4 stdout_bytes=0 stderr_lines=1 path_named=1 tb=0 claims_json=0 created=no`; same for `ro/sub/x.json`; `done 1` against a `chmod 400` valid store → same, and `store unchanged by the failed done: yes`, `list` still works afterwards | verified | — | T3-2 `done_when` met. Message: `notes: unwritable store <path>: cannot be written (Permission denied)` — distinct from the JSON reason, as the plan required |
| V3-4 | The corrupt-store matrix still shows 0 deviations under the new `StoreError` path in `save` | plan P3-5 (under pressure from T3-2) | `qa-3-cli.log:219-276` — 9 payloads × 5 subcommands = 45 runs, `deviations=0`; plus an exact re-run of iteration 2's 9 payloads from `qa-2-probe.sh:178` appended at `qa-3-cli.log:339-349`, 45 runs, `deviations=0`. **90 runs, 0 deviations**: rc 4, 0 stdout bytes, path named, 1 stderr line, no traceback, sha256 unchanged every time | verified | — | Exit 4's two reasons stay distinguishable: `invalid store …: is not valid JSON` vs `unwritable store …: cannot be written` |
| V3-5 | The `~/.notes.json` fallback is tested and behaves; `NOTES_FILE=""` falls back too | plan T3-3 | `tests/test_store_path.py` → `4 passed in 0.15s` in isolation; `grep -n "section 3"` → lines 1, 18, 29, 37, 54; black-box repro with `HOME` redirected (`qa-3-cli.log:291-301`): `list` → `no notes` rc 0 with no file created, `add` → rc 0 creating `$HOME/.notes.json`, `list` reads it back; identical for `NOTES_FILE=""` | verified | — | T3-3 `done_when` met. Closes the coverage hole evidence-2 G2-5 raised |
| V3-6 | All 16 usage-error and flag-misuse forms exit 2 with exactly one `usage:` line naming all four subcommands, zero stdout, no traceback, no store created | plan P3-1 | `qa-3-cli.log:26-54` (usage forms) and `:55-77` (flag forms) — 9 usage forms + 7 flag forms, every one `rc=2 stdout_bytes=0 usage_lines=1 names=1,1,1,1 store_created=no tb=0` | verified | — | Usage line: `usage: python -m notes {add <text> | list [--color] | done <n> | search <query>}` |
| V3-7 | `add` then `list` prints insertion order from 1, `[x]` only on done notes, correct across 9→10 | plan P3-2 | `qa-3-cli.log:78-104`: raw bytes `b'1. [ ] buy milk\n2. [ ] call mom\n3. [ ] water it\n'`; ten-note store with `done 1`/`done 10` → `9. [ ] note nine` / `10. [x] note ten`, `x-marked lines: 2` | verified | — | Byte-identical to evidence-2's record |
| V3-8 | `list` on an absent 3-deep store prints exactly `no notes` (9 bytes), exits 0, creates neither file nor any parent; same with `--color` and zero escapes | plan P3-3 | `qa-3-cli.log:105-115`: `rc=0 bytes=9`, all four `exists … -> no`; `list --color` → `bytes=9 esc=0`, `a/ exists after --color: no` | verified | — | |
| V3-9 | The on-disk store is exactly `{"notes":[{"text":str,"done":bool}]}` and never receives an escape byte | plan P3-4 | `qa-3-cli.log:116-135` after `add`,`add`,`done 2`,`list --color`,`search`: `top-level keys ['notes']`, per-note keys `[['done','text'],['done','text']]`, types `str`/`bool`, `0x1b bytes in file : 0` | verified | — | |
| V3-10 | 24 non-canonical/out-of-range `done` spellings all exit 3 naming the argument with the store byte-identical; canonical `done` is idempotent | plan P3-6 | `qa-3-cli.log:136-177`: `spellings=24 deviations=0`, each `rc=3 bytes=0 tb=0 named=1 sha_same=yes`, including `1_0`, `+1`, `010`, `0x1`, `1e0`, `\t1`, `١`, `٢`, `１`, `""`, `" "`; then `done 1`/`done 10` rc 0 and a repeated `done 1` rc 0 with `sha unchanged by the repeat: yes` | verified | — | |
| V3-11 | `search` matches a case-insensitive substring at full-list positions, prints exactly `no matches` (11 bytes) with rc 0, creates nothing, emits zero escapes including on a pty | plan P3-7 | `qa-3-cli.log:178-202`: `search milk|MILK|Milk` → `1. [ ] Buy Milk` + `3. [ ] Milk run` (positions 1 and 3); `uy mi` → 1 line; `zzz` → `no matches`, 11 bytes; absent 3-deep path leaves file/parent/grandparent absent; `cat -v` shows no `^[`; `qa-3-pty.log:28-30` `search one on a pty … ESC count = 0` | verified | — | `search ""` returns every note (`qa-3-cli.log:189`) — the substring rule's own consequence, still unpinned by a test (G3-4) |
| V3-12 | `list --color` wraps only a done note's text as `<n>. [x] \x1b[2m<text>\x1b[0m`; the flag, never `isatty`, decides | plan P3-8 | `qa-3-cli.log:203-218`: colored raw `b'1. [ ] plain one\n2. [x] \x1b[2mdone one\x1b[0m\n'` = expected, plain `b'1. [ ] plain one\n2. [x] done one\n'`, plain esc 0 / colored esc 2, not-done line identical, prefix unchanged. `qa-3-pty.log`: sanity child `isatty=True`, pty plain esc=0, pty color esc=2, pipe plain esc=0, pipe color esc=2, `the flag alone decides (not isatty): True` | verified | — | Byte half of R8 only; appearance is G3-1 |
| V3-13 | Only `src/notes/` and `tests/` changed; `pyproject.toml`/`requirements.txt` byte-identical; every import stdlib or `notes`; dependency set unchanged | plan P3-9 | `git diff --name-only b090366..HEAD` → 2 paths under `src/notes/`, 8 under `tests/`, nothing else; the same diff `-- pyproject.toml requirements.txt` → empty; `git diff aa71252..HEAD -- pyproject.toml` → empty; `requirements.txt` = `pytest`; AST import audit → `['.', '.cli', contextlib, json, notes, os, pathlib, pytest, subprocess, sys]`, non-stdlib non-`notes` = `['pytest']` only; `pip list` = iniconfig, notes (editable), packaging, pip, pluggy, Pygments, pytest | verified | — | AST audit used instead of the plan's `^import` grep, which would miss an indented import; none exist |
| V3-14 | Every `.py` parses at `feature_version=(3,9)`, no `match`, no PEP 604 runtime annotation, byte-compiles, and the whole suite passes under real CPython 3.9 | plan P3-10 | 14 files, `3.9 parse failures / match statements: 0`; no `match`-statement candidates; no `X | Y` annotations; `compileall` rc 0. `qa-3-py39.log`: Python 3.9.25 / pytest 8.4.2, caches cleared first, `compileall rc=0`, **`37 passed in 2.77s`**, and the iteration-3 paths spot-checked under 3.9 — unwritable `add` rc 4 one line both shapes, default-path round trip, corrupt store rc 4, `done 1_0`/`done " 1 "` rc 3, `list --color` → `1. [x] ^[[2mone^[[0m` | verified | — | `find src tests -name '*.py'` returns exactly the 14 files the glob matches, so the glob is the whole set |
| V3-15 | Every function in `src/notes/*.py tests/*.py` is under 50 lines | plan P3-11 | AST walk, longest per file: `cli.py` 18 (`_parse_index`), `store.py` 19 (`save`), `conftest.py` 18, `test_cli_done.py` 25, `test_cli_store.py` 20, `test_cli_search.py` 20, `test_cli_usage.py` 19, `test_cli_color.py` 16, `test_store_path.py` 15, `test_store.py` 12, `test_cli.py` 11, `test_smoke.py` 2. **Longest overall 25** (`test_done_rejects_non_canonical_integers_against_a_ten_note_store`), `under 50 = True` | verified | — | |
| V3-16 | The suite never creates the real `$HOME/.notes.json`; every home-touching test redirects home first | plan P3-12, T3-3 | `test -e $HOME/.notes.json` → `absent` before and `absent` after `pytest -q` (rc 0); every hit of `Path.home|expanduser|.notes.json|HOME|USERPROFILE` in `tests/` sits in `tests/test_store_path.py` (each test calls `redirect_home()` at line 23/30 or uses `run_notes_at_home`) or `tests/conftest.py:54-55` (sets `HOME`/`USERPROFILE` in the child env before the run). No hit fails the rule | verified | — | Also confirmed under 3.9: `real $HOME/.notes.json: absent` |
| V3-17 | R8's dim rendering is legible in a real terminal | plan P3-8 appearance half / prd.md:70-73 | Not machine-observable by the PRD's own design. Bytes verified (V3-12); appearance not | **gap** | note | **G3-1**, owner user, issue I9. The single reason `coverage: incomplete` |
| V3-18 | Every size/length constraint in plan-3 names the same subject its command measures | plan P3-11, T3-1 / issue I17 | Read plan-3:36-39, 44, 58: P3-11 says "the files matched by `src/notes/*.py tests/*.py`" and V3-15 measures exactly that glob; T3-1's `done_when` and V3-1 use the same glob. No constraint is graded against a wider subject than its own command measures. The plan-2 P2-9/V2-12 mismatch is gone | verified | — | One cosmetic residue: P3-10 says "every `.py` file **under** `src/notes/` and `tests/`" while V3-14's command is a non-recursive glob. Empirically moot — `find` shows no `.py` outside the glob (V3-14). Worth one word in a future plan, not a gap |
| P3-1 | Usage errors exit 2 with one `usage:` line naming all four subcommands, no stdout, no traceback, no store created | plan P3-1 | V3-6 above | verified | — | preserved (verified@evidence-2 V2-3, P2-1) |
| P3-2 | `add`/`list` insertion order and `[ ]`/`[x]` rendering, correct across 9→10 | plan P3-2 | V3-7 above | verified | — | preserved (verified@evidence-2 P2-2) |
| P3-3 | Empty/absent store → exactly `no notes` (9 bytes), rc 0, nothing created, with and without `--color` | plan P3-3 | V3-8 above | verified | — | preserved (verified@evidence-2 P2-3, V2-6) |
| P3-4 | On-disk shape exact, no escape byte ever reaches the file | plan P3-4 | V3-9 above | verified | — | preserved (verified@evidence-2 P2-4, V2-10) |
| P3-5 | Every subcommand exits 4 on a mis-shaped store, names the path, no stdout, no traceback, file byte-identical | plan P3-5 | V3-4 above — 90 runs, 0 deviations | verified | — | preserved (verified@evidence-2 P2-5, V2-9). The new `save` guard did **not** disturb it |
| P3-6 | Canonical `done` is idempotent; the 24 non-canonical spellings exit 3 leaving the store byte-identical | plan P3-6 | V3-10 above | verified | — | preserved (verified@evidence-2 V2-7, P2-6) |
| P3-7 | `search` semantics, full-list positions, exact `no matches`, creates nothing, zero escapes on a pty | plan P3-7 | V3-11 above | verified | — | preserved (verified@evidence-2 V2-1, V2-2, P2-7) |
| P3-8 | `list --color` byte layout; the flag alone decides, never `isatty` | plan P3-8 | V3-12 above | verified | — | byte half preserved (verified@evidence-2 V2-4, V2-5). Appearance half = G3-1 |
| P3-9 | Only `src/notes/` and `tests/` change; build files byte-identical; stdlib-only imports; dependency set unchanged | plan P3-9 | V3-13 above | verified | — | preserved (verified@evidence-2 V2-11, P2-8) |
| P3-10 | 3.9-parsable, no `match`, no PEP 604 runtime annotations, byte-compiles, suite green on real CPython 3.9 | plan P3-10 | V3-14 above — 37 passed on 3.9.25 | verified | — | preserved (verified@evidence-2 V2-12) |
| P3-11 | Every function in the measured glob is under 50 lines | plan P3-11 | V3-15 above — longest 25 | verified | — | preserved (verified@evidence-2 V2-12) |
| P3-12 | Suite green with ≥ 31 passing agreeing with the gate, smoke alone passes, `R1`…`R8` each named in a docstring, no test touches the real home | plan P3-12 | V3-2 and V3-16 above | verified | — | preserved (verified@evidence-2 V2-8, P2-10). 31 → 37 |
| S-R1 | `add <text>` appends a note and exits 0; a following `list` shows that text | prd.md:32 | V3-7 (`qa-3-cli.log:78-90`); also under 3.9 (`qa-3-py39.log`) | verified | — | |
| S-R2 | `list` prints `<n>. [ ] <text>` in insertion order from 1, `[x]` when done | prd.md:33-34 | V3-7 — raw bytes compared, 9→10 boundary intact | verified | — | |
| S-R3 | `list` on an empty store prints exactly `no notes`, exits 0, creates no store file | prd.md:35-36 | V3-8 — 9 bytes, file/parent/grandparent all absent | verified | — | |
| S-R4 | `done <n>` marks note `n` and exits 0; a non-positive-integer or out-of-range `n` names `<n>` on stderr, exits 3, store unchanged | prd.md:37-39 | V3-10 — 24 spellings, 0 deviations, sha256 unchanged | verified | — | |
| S-R5 | No/unknown subcommand or a missing argument prints a usage line to stderr and exits 2; the line names every subcommand | prd.md:40-41 | V3-6 — 16 forms, one `usage:` line naming all four each time | verified | — | |
| S-R6 | The store is the documented JSON object; an invalid or mis-shaped store makes every subcommand name the path on stderr and exit 4 — never a traceback, never a silent overwrite | prd.md:42-45 | V3-9 (shape) + V3-4 (90 corrupt runs) + V3-3 (unwritable now exits 4 instead of the traceback evidence-2 recorded) | verified | — | The exit-1 traceback that evidence-1 G1-6 and evidence-2 G2-2 recorded is gone |
| S-R7 | `search <query>` prints matches in `list` format, case-insensitive substring; no match prints exactly `no matches` and exits 0 | prd.md:46-48 | V3-11 | verified | — | |
| S-R8 | `list --color` dims done notes with ANSI SGR and leaves not-done notes unchanged; without `--color` no escape sequence appears in the output at all, including on a terminal | prd.md:49-51 | Byte half verified: V3-12 + `qa-3-pty.log` (pty and pipe). Two halves still open: appearance (G3-1) and the literal "at all" when the escape byte is in the user's own stored text — `qa-3-pty.log:46-51` shows plain `list` echoing `\x1b[31m` verbatim, `ESC count = 2` | **gap** | minor | **G3-1** (appearance, owner user) and **G3-2** (wording, owner user). Not a regression — verbatim echo has held since `0cdf922` |
| S-sec3 | The store path comes from `NOTES_FILE`; unset → `~/.notes.json` | prd.md:29-30 | V3-5 — tested and reproduced black-box with a redirected home, `NOTES_FILE=""` included | verified | — | Was the PRD requirement plan-2 omitted (I15); plan-3 covered it as T3-3 |
| S-sec4 | Standard library only, `requirements.txt` keeps `pytest` alone, Python 3.9 compatible, every requirement has a test, exit codes and the `no notes`/`no matches` text unchanged | prd.md:54-59 | V3-13 (imports/deps) + V3-14 (3.9.25, 37 passed) + V3-2 (R1…R8 docstrings) + V3-6/V3-8/V3-10/V3-11 (exit codes 0/2/3/4 and the exact 9-byte `no notes` / 11-byte `no matches`) | verified | — | No fifth exit code was invented for the unwritable case |
| S-sec5 | Each requirement is checkable from a shell; `pytest -q` green; `list \| cat -v` shows no `^[` | prd.md:61-68 | Every S-claim above rests on a shell run recorded in `qa-3-cli.log` / `qa-3-pty.log` / `qa-3-py39.log`; `37 passed`; `cat -v` output at `qa-3-cli.log:198-201, 204-209` | verified | — | |
| S-sec6 | Definition of done: R1–R8 verified with R8's appearance left as a manual gap; `pytest -q` green at the final commit | prd.md:75-78 | R1–R7 verified above, R8's byte half verified with the appearance recorded as G3-1 exactly as prd.md:70-73 prescribes; `37 passed` at `039c471` | verified | — | Met on its own terms. G3-2 is a defect in the PRD's wording, not an unmet DoD item |

**PRD sweep result: no PRD requirement is left uncovered by plan-3.** R1–R8, section 3's
store-path rule, section 4's non-functional rules and section 5's verification constraints
all map onto a P-id or a Target. There is therefore no plan-omission gap this iteration —
the omission evidence-2 raised (section 3, I15) was closed by T3-3.

# Gap details

## G3-1 — R8's dim rendering is not legible-checked (note, owner user)

- **Reproduction**: in your usual terminal, `export NOTES_FILE=$(mktemp -u); .venv/bin/python -m notes add "still to do" && .venv/bin/python -m notes add "already done" && .venv/bin/python -m notes done 2 && .venv/bin/python -m notes list --color`
- **Observed vs expected**: the bytes are exactly right — `2. [x] \x1b[2malready done\x1b[0m`, `\x1b[2m` opened before the text and `\x1b[0m` after, nothing around the `<n>. [x] ` prefix, nothing on not-done lines, on a pipe and on a real pty alike (`qa-3-pty.log`). Whether SGR 2 "dim" is *readable* on your background is not something a script can assert.
- **User impact**: on a terminal theme where dim collapses into the background, done notes become invisible. Nothing else is affected.
- **Recommended fix**: none until a human looks. Run the command above and confirm. If dim is illegible, the fix is a different SGR code — a one-line change in `src/notes/cli.py:28`.
- **Suggested owner**: user. Issue I9. Never a Target, by prd.md:73.
- **Note on severity and coverage**: this is the one claim I could not check, so `coverage: incomplete`. I am deliberately **not** filing it as a major `qa.coverage_incomplete`: prd.md:70-73 designs it as a manual gap plus a note, and it is not an environment, permission or time limitation on my side. Grading it major would misreport otherwise-complete work on the last iteration. It is nonetheless the reason `qa_status` cannot be `pass`.

## G3-2 — R8's "no escape sequence at all" does not survive a user-stored escape byte (minor, owner user)

- **Reproduction**: `export NOTES_FILE=$(mktemp -u); .venv/bin/python -m notes add $'sneaky \x1b[31mRED\x1b[0m text'; .venv/bin/python -m notes list | cat -v`
- **Observed vs expected**: observed `b'1. [ ] sneaky \x1b[31mRED\x1b[0m text\n'` — `ESC count = 2` from plain `list` with no `--color` (`qa-3-pty.log:46-51`); `search` behaves the same. prd.md:50-51 read literally says "Without `--color`, no escape sequence appears in the output at all". The tool generates none; it re-emits what the user stored.
- **User impact**: a note's text can recolor or reposition subsequent terminal output. Low, since the user has to have written those bytes themselves, and the store is per-user; it matters if a store is ever shared or generated by another program.
- **Recommended fix**: decide the wording first. Either (a) amend prd.md:50-51 to scope the guarantee to escapes the tool itself emits — zero code change, and the reading plan-3 already assumes; or (b) sanitize stored text on output, which changes the exact output strings R2 fixes and so needs R2 amended in the same breath.
- **Suggested owner**: user (a PRD decision; a developer cannot pick between (a) and (b) without it). Issue I16.
- **Not a regression**: verbatim echo has held since iteration 1 (`git show 0cdf922:src/notes/cli.py`), and is unchanged at `039c471`.

## G3-3 — `add ""` and `add "   "` store a blank note that cannot be removed (minor, owner developer)

- **Reproduction**: `export NOTES_FILE=$(mktemp -u); .venv/bin/python -m notes add ""; .venv/bin/python -m notes list`
- **Observed vs expected**: observed rc 0, empty stderr, and `list` printing `1. [ ] ` — a bare prefix with no text; on disk `{"text": "", "done": false}`. `"   "` behaves the same (`qa-3-pty.log:36-44`). The PRD does not define empty text, so there is no specified expectation; the CLI has no `delete`, so the blank note is permanent.
- **User impact**: a typo (`notes add ""`) silently permanent-clutters the list, and only hand-editing the JSON removes it.
- **Recommended fix**: the decision is already recorded in issue I13 and plan-3:66 — treat empty or whitespace-only text as a usage error (exit 2 with the existing usage line), no new exit code, with one test. Small, self-contained. Decide together with G3-2, since both are questions about input the PRD never described.
- **Suggested owner**: developer. Issue I13.
- **Not a regression**: present and unchanged since iteration 1.

## G3-4 — `--color` outside `list` is undefined by the PRD and unpinned by any test (note, owner developer)

- **Reproduction**: `.venv/bin/python -m notes add --color` then `.venv/bin/python -m notes list`; and `.venv/bin/python -m notes search --color`
- **Observed vs expected**: `add --color` exits 0 and stores a note whose text is the literal `--color` (`qa-3-pty.log:53-56`: `list` afterwards shows `3. [ ] --color`); `search --color` exits 0 and treats it as a query. `search ""` returns every note (`qa-3-cli.log:189`). All three follow from R7's substring rule and R8 scoping the flag to `list`, which is the reading plan-3:70 adopted — but no test freezes any of them, so a future refactor could change them with the suite still green.
- **User impact**: none today. This is regression exposure, not a defect.
- **Recommended fix**: three small tests (one per behavior) pinning today's output. No code change. If instead you want `add --color` to be a usage error, that is a PRD amendment first.
- **Suggested owner**: developer (the decision is already recorded; only the test is missing).

## G3-5 — the suite pins fewer argument spellings than QA verified (note, owner developer)

- **Reproduction**: `grep -n "list\", \"--" tests/test_cli_usage.py` versus `qa-3-cli.log:55-77`
- **Observed vs expected**: I verified 9 usage forms and 7 flag-misuse forms, all rc 2. `tests/test_cli_usage.py` pins 8 of the 9 usage forms (no `done 1 2`) and 5 of the 7 flag forms (no `list --color --color`, no `list --COLOR`). So for those three spellings the only protection is this log, not an assertion.
- **User impact**: none observable. Regression exposure only.
- **Recommended fix**: add `("done", "1", "2")` to the tuple at `tests/test_cli_usage.py:33-40` and `("list", "--color", "--color")`, `("list", "--COLOR")` to the tuple at `:54-60`. Two one-line edits.
- **Suggested owner**: developer.
- **Not caused by T3-1**: `git show b090366:tests/test_cli.py` (lines 59-76, 284-303) has exactly the same 6 and 5 tuples, so the split moved the tests faithfully; the limit predates it.

# T3-1 faithfulness audit (no gap, recorded because "pure test motion" is hard to verify from a diff)

T3-1's instruction forbade weakening, renaming away or dropping any assertion. Checked
directly against `b090366`:

- All 16 test function names from the 303-line `tests/test_cli.py` exist in the split files, one each: `test_no_subcommand_is_a_usage_error`, `test_unknown_subcommand_is_a_usage_error`, `test_subcommand_missing_its_argument_is_a_usage_error` and `test_list_accepts_only_the_exact_color_flag` → `test_cli_usage.py`; `test_add_then_list`, `test_list_on_a_missing_store_says_no_notes_and_creates_nothing`, `test_list_renders_mixed_done_flags` → `test_cli.py`; `test_add_writes_the_documented_json_shape`, `test_a_corrupt_store_exits_4_from_every_subcommand` → `test_cli_store.py`; the three `done` tests → `test_cli_done.py`; the two `search` tests → `test_cli_search.py`; the two colour tests → `test_cli_color.py`.
- Bodies compared line by line on the three tests most at risk: the argument tuples and every assertion are identical; only the fixture plumbing changed (module-level `run()`/`store_file(tmp_path)` → the `run_notes`/`store_path` fixtures in the new `tests/conftest.py`).
- Assertion count rose: 77 in the old `test_cli.py` → 88 across the six split CLI files, plus 13 new in `test_store_path.py`; `tests/test_store.py` untouched at 14. Total 92 → 116.
- Test count rose 31 → 37 (+2 unwritable-store tests, +4 store-path tests). Nothing was deleted: `git diff --name-only b090366..HEAD` shows additions only, `tests/test_cli.py` retained as a 40-line remainder.

# What a human is left holding

This was the last iteration (`config.md` `T: 3`). Nothing follows, so the list below is the
final state, not a backlog for another loop turn.

**The product is in good shape.** All eight PRD functional requirements, the section 3
store-path rule and every section 4 non-functional rule are verified black-box at
`039c471`, on the venv interpreter (3.14.7) and on real CPython 3.9.25, with `37 passed`
both times and 0 regressions against evidence-2. The three iteration-3 Targets all met
their `done_when`. The defect that had survived two iterations — an unwritable store
producing an 8-frame traceback and exit 1 — is fixed and now exits 4 with one line, without
disturbing any of the 90 corrupt-store runs that share exit 4.

**One thing needs a human before the run can be called clean:**

1. **Run V3-17** (G3-1, two minutes): `export NOTES_FILE=$(mktemp -u); .venv/bin/python -m notes add "still to do" && .venv/bin/python -m notes add "already done" && .venv/bin/python -m notes done 2 && .venv/bin/python -m notes list --color` and say whether the dimmed line is readable on your background. This is the only claim in this bundle that no script can settle, and the only reason `qa_status` is `fail`. The PRD wrote it that way on purpose (prd.md:70-73), and prd.md:77 explicitly allows the run to be done with it open.

**Two decisions only you can make** (both are "what should the CLI do with input the PRD never described", and they are cheaper to settle together):

2. **G3-2 / I16** — scope R8's "no escape sequence at all" to escapes the *tool* emits (zero code change), or sanitize stored text (also changes R2's exact strings). A wording change to prd.md:50-51 is the cheaper branch.
3. **G3-3 / I13** — make `add ""` / `add "   "` a usage error. Decision already written down; one small commit with a test. Until then a typo leaves a permanent blank note, because there is no `delete` subcommand.

**Two cheap test-only follow-ups, no decision needed:** G3-4 (freeze `add --color`,
`search --color`, `search ""`) and G3-5 (three argument spellings the suite does not pin).
Both are regression exposure, not defects.

**Not attempted, by scope:** a `delete` subcommand (nothing in the PRD asks for one, though
its absence is what makes G3-3's blank note permanent), and any change to `pyproject.toml`,
`requirements.txt` or `hoh/`, which prd.md section 2 puts out of scope.

**One note for whoever maintains the harness rather than the product:** issue I17 — the
plan-2 self-inconsistency where a constraint was graded against a wider file set than its
own command measured — is confirmed fixed in plan-3 (V3-18). The residue is cosmetic and
recorded in V3-18's note: P3-10 says "every `.py` file *under* `src/notes/` and `tests/`"
while its command is a non-recursive glob. Harmless today because no `.py` file lives in a
subdirectory, but the same class of mismatch is what I17 was about.

# Planner handoff

- **Preservation candidates** (verified at `039c471`, safe to carry forward as-is):
  P3-1, P3-2, P3-3, P3-4, P3-5, P3-6, P3-7, P3-9, P3-10, P3-11, P3-12; plus the byte half of
  P3-8; plus S-R1, S-R2, S-R3, S-R4, S-R5, S-R6, S-R7, S-sec3, S-sec4, S-sec5, S-sec6.
  New this iteration and worth pinning as constraints in any future plan: exit 4 with a
  single `unwritable store <path>: cannot be written (...)` line for an unwritable store
  (V3-3); the `~/.notes.json` and `NOTES_FILE=""` fallback (V3-5); every file in
  `src/notes/*.py tests/*.py` ≤ 200 lines (V3-1).
- **Next target candidates** (owner=developer only, priority order):
  1. G3-3 — `add ""` / `add "   "` as a usage error (decision recorded, needs a test).
  2. G3-4 — freeze `add --color`, `search --color`, `search ""` with one test each.
  3. G3-5 — add the three unpinned argument spellings to `tests/test_cli_usage.py`.
- **Not developer-ownable**: G3-1 (user, run V3-17), G3-2 (user, PRD wording decision).
- **Further verification needed**: nothing mechanical is outstanding. The only unverified
  claim is V3-17, which requires a human at a terminal. If G3-2 is resolved toward
  sanitization, R2's exact output strings must be re-verified (V3-7, V3-12) because the
  sanitizer would sit in the same `format_note` path.

# Observation harness (all output cited above is reproducible)

| file | what it does |
|---|---|
| `hoh/notes/logs/qa-3-probe.sh` | The black-box shell probe: sizes, 16 usage forms, ordering, `no notes`, on-disk shape, 24 `done` spellings, `search`, colour bytes, the 45-run corrupt matrix, the unwritable-store cases, the redirected-home default path, the dependency surface. Output: `qa-3-cli.log` |
| `hoh/notes/logs/qa-3-pty.py` | Real-pty harness for V3-12 (a sanity child asserts `isatty=True` first, and the parent closes its slave fd before reading, so an empty capture cannot be mistaken for a pass — earlier bundles record two such false empties), plus the G3-2/G3-3/G3-4 probes. Output: `qa-3-pty.log` |
| `hoh/notes/logs/qa-3-py39.sh` | Clears byte-code caches, then runs `compileall`, the whole suite and the iteration-3 paths under real CPython 3.9.25. Output: `qa-3-py39.log` |

Scratch stores, the fake `$HOME` and the `chmod 500` directories lived under
`hoh/notes/logs/qa-3-scratch/` (git-ignored via `hoh/*/`, so the candidate tree stayed
clean throughout) and were removed afterwards. Every mode change was restored.
`git status --porcelain` is empty and `HEAD` is still `039c471757418955e9871c95e3eeb5a630f68b0b`.
No file under `src/`, `tests/`, `pyproject.toml` or `requirements.txt` was written by QA.
