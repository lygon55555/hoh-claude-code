---
iteration: 2
status: active
targets: 3
---

# Diagnosis

- Root cause: iteration 1 was scoped to R1–R6 on purpose (evidence-1 G1-3), so R7 and R8 have
  no code path at all — `_HANDLERS` in `src/notes/cli.py:95-99` holds only `add`/`list`/`done`
  and `_cmd_list` (`src/notes/cli.py:50-52`) rejects every argument, so `search …` and
  `list --color` both fall through to the exit-2 usage error; the one behavioural defect worth
  fixing now comes from using bare `int()` as a validator in `_parse_index`
  (`src/notes/cli.py:75-83`) (evidence: evidence-1 G1-1, G1-2, G1-5, confidence high).
- Strategy: close the two remaining functional requirements (R7, R8) with their tests, fold the
  `USAGE` string update into the R7 change because R5's "names every subcommand" clause cannot
  close without it, and add the one cheap fix where a typo silently marks the wrong note done.
  No refactor of `store.py`, no new modules, no change to any exit code or public string that
  evidence-1 verified. Iteration 3 stays free for repair.
- Stop condition: stop and report if the same `python -m pytest -q` failure, or the same
  usage-line/escape-byte mismatch, recurs on two consecutive attempts, or if any fix attempt
  makes a P2-* constraint fail; do not widen scope to the deferred minors to compensate.

# Evidence summary (for the Developer, 3 lines max)

- R1–R6 are all verified black-box (evidence-1 V1-1..V1-8) including 27 corrupt-store runs and
  the whole suite under real CPython 3.9.25; 25 tests pass and `pyproject.toml` is untouched.
- `search <query>` and `list --color` both exit 2 with the usage line today (evidence-1 G1-1,
  G1-2) — they are the entire remaining functional gap against the PRD.
- The half of R8 that already holds must keep holding: plain `list` emits zero `0x1b` bytes even
  on a real pty (evidence-1 S-R8, `qa-1-pty.log`); `done 1_0` and `done "١"` wrongly exit 0 and
  mark the wrong note (evidence-1 G1-5).

# Targets (priority order, at most 3)

| id | type | title | instruction | target paths | linked issue/gap | done_when | validation |
|---|---|---|---|---|---|---|---|
| T2-1 | requirement | `search <query>` (R7) and a usage line that names it (R5) | Add a `search` handler to `_HANDLERS` taking exactly one argument. Match case-insensitively on a substring of `note["text"]` (`str.casefold()` on both sides). Print each match with the existing `format_note` helper, **keeping the note's position in the full list** (see the numbering decision below), exit 0. When nothing matches print exactly `no matches` and exit 0. `search` with no argument or more than one argument is the usual exit-2 usage error. A missing store must stay missing — read through `store.load` and never call `store.save`. In the same change add `search <query>` to `USAGE` (`src/notes/cli.py:20`) so the single usage line names `add`, `list`, `done` and `search`; also extend the module docstring's exit-code list if it needs it. Add tests for the hit branch (including a mixed-case query and a done note rendering `[x]`) and the `no matches` branch, each docstring naming R7. **Numbering decision (PRD R7 is silent):** print the matching note's index in the full list, not a fresh 1..k sequence — the numbers in the `list` format are exactly what `done <n>` consumes, so renumbering would make `search` output cause the wrong note to be marked done. | `src/notes/cli.py`, `tests/test_cli.py` | I7, I1, I10, G1-1, G1-3 | `NOTES_FILE` set to a temp file holding `Buy Milk`, `call mom`, `Milk run`: `search milk` prints `1. [ ] Buy Milk` and `3. [ ] Milk run` and exits 0; `search zzz` prints exactly `no matches` and exits 0; bare `python -m notes` exits 2 with one usage line naming all four subcommands; `pytest -q` green | V2-1, V2-2, V2-3, V2-8 |
| T2-2 | requirement | `list --color` dims done notes with ANSI SGR (R8) | Accept the flag `--color` in `_cmd_list` only — never as a global argument before the subcommand, and only that exact spelling. With the flag, wrap **only the text** of notes whose `done` is true in `\033[2m` … `\033[0m`, leaving the `<n>. [x] ` prefix and every not-done line byte-identical to plain `list`. Gate the escapes on the flag alone and **never on `isatty`**: the PRD forbids escapes without the flag even on a terminal, and requires them with the flag even when stdout is a pipe. `no notes` is unaffected by the flag. Keep the escape strings as named constants rather than inline literals. Add one test asserting the exact bytes with the flag and one asserting `\x1b` is absent without it, each docstring naming R8. | `src/notes/cli.py`, `tests/test_cli.py` | I8, I10, G1-2, G1-3 | store with note 1 not done and note 2 done: `list --color` exits 0 and prints `1. [ ] plain one` unchanged plus `2. [x] ` followed by the done text wrapped in `ESC[2m`/`ESC[0m`; plain `list` piped through `cat -v` still shows no `^[`; `list --colour`, `list -c`, `list --color extra` and `--color list` all exit 2; `pytest -q` green | V2-4, V2-5, V2-6, V2-8 |
| T2-3 | defect | `done` must reject non-canonical spellings of an integer (R4) | In `_parse_index` (`src/notes/cli.py:75-83`) require a canonical ASCII decimal spelling before converting: return `None` unless the raw argument is ASCII and all digits, then `int()` it and keep the existing `< 1` rejection. That rejects surrounding whitespace, a leading `+`, PEP 515 underscores, non-ASCII decimal digits and leading zeros while leaving `0` and `-1` on the existing exit-3 path. Do not touch any other behaviour of `_cmd_done`: the message stays `notes: no note {given}` on stderr with exit 3 and the store untouched. Extend `test_done_rejects_a_bad_index_without_touching_the_store` with `" 1 "`, `"1_0"`, `"+1"`, `"١"` (U+0661) and `"010"`. | `src/notes/cli.py`, `tests/test_cli.py` | I11, G1-5 | against a 10-note store, each of `done " 1 "`, `done "1_0"`, `done "+1"`, `done "١"`, `done "010"` exits 3, names the argument on stderr, emits no traceback and leaves the store file byte-identical, while `done 1` and `done 10` still exit 0 | V2-7, V2-8 |

# Preservation constraints

| id | behavior to preserve | verified in (evidence id) | how to check (V-id) |
|---|---|---|---|
| P2-1 | No subcommand, an unknown subcommand, or a subcommand given the wrong number of arguments exits 2 with empty stdout and a single `usage:` line on stderr that names **every** subcommand the build supports; no traceback, and no store file is created by a usage error. | evidence-1 V1-1, V1-2 | V2-3, V2-9 |
| P2-2 | `add` then `list` shows the added text; `list` prints one line per note in insertion order as `<n>. [ ] <text>` with `n` starting at 1 and `[x]` for done notes, correct past 9 (`9.`, `10.`). | evidence-1 V1-3, V1-7 | V2-9 |
| P2-3 | `list` against an empty or absent store prints exactly `no notes`, exits 0, and creates neither the store file nor any parent directory. | evidence-1 V1-4 | V2-9 |
| P2-4 | The on-disk store is exactly `{"notes": [{"text": <str>, "done": <bool>}]}` — no extra top-level keys, no extra note keys, `done` a real JSON boolean. | evidence-1 V1-5 | V2-10 |
| P2-5 | A store that is not valid JSON or whose shape does not match makes **every** subcommand exit 4, name the store path on stderr, print nothing on stdout, emit no traceback, and leave the file byte-unchanged. | evidence-1 V1-6 | V2-9 |
| P2-6 | A valid `done <n>` exits 0 and is idempotent; a rejected `<n>` exits 3, names the given argument on stderr, emits no traceback and leaves the store byte-unchanged (`0`, `-1`, `abc`, `1.5`, `99`, `""`, `" "`, one past the end). | evidence-1 V1-7, V1-8 | V2-9 |
| P2-7 | Without `--color`, the output of `list` contains zero ANSI escape bytes (`0x1b`) — including when stdout is a real terminal. | evidence-1 S-R8 (`qa-1-pty.log`) | V2-5 |
| P2-8 | The package still installs editable from an unmodified `pyproject.toml`; the dependency set stays standard library plus `pytest`, with `requirements.txt` holding `pytest` and nothing else. | evidence-1 V1-10, P1-2 | V2-11 |
| P2-9 | The sources stay Python 3.9-compatible and actually run under CPython 3.9 (no `match`, no `X \| Y` annotations); every module stays under 200 lines and every function under 50. | evidence-1 V1-11 | V2-12 |
| P2-10 | `import notes` succeeds with a truthy `__version__`, `tests/test_smoke.py` still passes, the whole suite stays green with no fewer passing tests than the 25 of iteration 1, every PRD requirement has at least one test, and no test reads the real home directory. | evidence-1 V1-9, V1-12, P1-1 | V2-8, V2-12 |

# Validation requirements

All commands are run from the workspace root. Invoke the interpreter as `.venv/bin/python` —
evidence-1's Environment note records that a shell alias shadows `python`; this is the same
interpreter `. .venv/bin/activate && python` selects. Use `f=$(mktemp -u)` style temp paths and
`export NOTES_FILE=$f` so nothing touches the real home.

| id | target | kind | method (command, expected result, what to observe) |
|---|---|---|---|
| V2-1 | T2-1 | runtime | Seed a store via `notes add "Buy Milk"; notes add "call mom"; notes add "Milk run"`, then run `.venv/bin/python -m notes search milk`, `… search MILK`, `… search "uy mi"`. Expect for each: rc 0, empty stderr, stdout exactly the two lines `1. [ ] Buy Milk` and `3. [ ] Milk run` — observe that the numbers are the notes' positions in the full `list`, not `1`/`2`. Then `done 3` and repeat `search milk`: the third line must render `3. [x] Milk run`. Pipe through `cat -v` and observe no `^[`. |
| V2-2 | T2-1 | runtime | (a) With the seeded store, `.venv/bin/python -m notes search zzz` → rc 0, stderr empty, stdout exactly `no matches` (10 bytes + newline; check with `wc -c`). (b) With `NOTES_FILE` pointing at an absent path three directories deep, `… search anything` → rc 0, stdout `no matches`, and `test -e "$NOTES_FILE"` still fails and no parent directory was created. (c) `… search` (no argument) and `… search a b` → rc 2, empty stdout, usage line on stderr, no store created. |
| V2-3 | T2-1, P2-1 | runtime | `.venv/bin/python -m notes; echo rc=$?` → rc 2, stdout empty, stderr exactly one line starting `usage:` that contains all four of `add`, `list`, `done`, `search`. Repeat with `… bogus`, `… add`, `… done`, `… search`, `… list extra`, `… add a b` — all rc 2 with the same line and no traceback. Grep the emitted line for each subcommand name rather than eyeballing it. |
| V2-4 | T2-2 | runtime | Store with note 1 `plain one` not done and note 2 `done one` done. Run `.venv/bin/python -m notes list --color` piped through `cat -v` → rc 0 and exactly `1. [ ] plain one` then `2. [x] ^[[2mdone one^[[0m`; compare byte-for-byte against plain `list` and observe that only the done note's **text** gained escapes — the `2. [x] ` prefix and the whole not-done line are unchanged. Also capture raw bytes with `python -c` and assert the done line's escape bytes are `\x1b[2m` before the text and `\x1b[0m` after it. |
| V2-5 | T2-2, P2-7 | runtime | Re-run the pty harness of `qa-1-pty.log` (close the parent's slave fd before reading and keep the `isatty=True` sanity child — evidence-1's Coverage section records that two earlier harnesses returned an empty capture that could be misread as "no output"). On the pty: plain `list` must yield `ESC (0x1b) count = 0` and `CSI count = 0`; `list --color` on the **same pty** and again on a plain **pipe** must both yield a non-zero `0x1b` count — observe that the flag alone decides, never `isatty`. |
| V2-6 | T2-2 | runtime | (a) Empty/absent store: `… list --color` → rc 0, stdout exactly `no notes`, zero `0x1b` bytes. (b) `… list --colour`, `… list -c`, `… list --color extra`, `… list extra --color` and `… --color list` → each rc 2, empty stdout, usage line on stderr, no traceback, store unchanged. (c) With a corrupt store, `… list --color` → rc 4 naming the path (P2-5 must cover the new argument form too). |
| V2-7 | T2-3 | runtime | Seed 10 notes, record `shasum -a 256 "$NOTES_FILE"`, and for each of `done " 1 "`, `done "1_0"`, `done "+1"`, `done "١"`, `done "010"`: rc 3, stderr one line naming the argument as given, stdout empty, no traceback, and the sha256 unchanged. Then confirm `done 1` and `done 10` still rc 0 and mark exactly notes 1 and 10 (`list` shows `[x]` on those two lines only). Also re-check `done 0x1` and `done 1e0` still rc 3. |
| V2-8 | T2-1, T2-2, T2-3, P2-10 | code | `.venv/bin/python -m pytest -q` → green, with a passed count strictly greater than 25 (record the number; it must also match `gate-2.md`). `.venv/bin/python -m pytest -q tests/test_smoke.py` → `1 passed`. `grep -rn "R7\|R8" tests/` finds at least one test docstring for each. `grep -rn "Path.home\|expanduser\|~/.notes.json" tests/` returns nothing. |
| V2-9 | P2-1, P2-2, P2-3, P2-5, P2-6 | runtime | Re-run the black-box matrix of `qa-1-probe.sh` unchanged against the new candidate: the usage-error cases, `add`/`list` ordering including the 9/10 boundary, `no notes` with no file created, the 9 corrupt payloads × every subcommand (now including `search` and `list --color`) all rc 4 with the path named and the file byte-unchanged, and the 8 rejected `done` arguments all rc 3 with the store byte-unchanged. Any single deviation is a regression against evidence-1. |
| V2-10 | P2-4 | runtime | After `add` and `done` under the new build, print the store and assert with `python -c` + `json.load`: top-level keys exactly `['notes']`, every note's keys exactly `['done','text']`, `type(done).__name__ == 'bool'`, `type(text).__name__ == 'str'`. No escape bytes may appear in the file even after a `list --color` run. |
| V2-11 | P2-8 | code | `git diff --name-only 0cdf922c5d11c9a2e4882e842a364c355683e047..HEAD` → only files under `src/notes/` and `tests/`; the same diff restricted to `-- pyproject.toml requirements.txt` → empty; `cat requirements.txt` → `pytest` only; `grep -rn "^import \|^from " src/notes/` shows standard-library imports and intra-package imports only; `.venv/bin/pip list` shows nothing beyond pytest's own tree plus `notes`. |
| V2-12 | P2-9, P2-10 | code | For every file under `src/notes/` and `tests/`: `ast.parse(src, feature_version=(3,9))` succeeds and `grep` finds no `match ` statement or PEP 604 runtime annotation; `.venv/bin/python -m compileall -q src/notes` → rc 0; `wc -l src/notes/*.py` each under 200; longest function under 50 lines. Then repeat evidence-1's 3.9 run (`qa-1-py39run.log`): under a scratch CPython 3.9, `compileall` rc 0, the `search` and `list --color` paths give the expected rc, and the full suite passes. Nothing may be installed into the repository. |
| V2-13 | I9 / G1-4 | visual | Not automatable — QA verifies only the bytes (V2-4) and re-files the appearance as a gap. A human runs `.venv/bin/python -m notes list --color` in their own terminal on their usual background and confirms the dimmed done lines are legible. Linked to owner=`user` issue I9; never a Target. |

# Deferred

- G1-6 / I12 — unguarded `store.save` lets a `PermissionError` traceback and exit 1 reach the
  user. **Planner decision, so iteration 3 needs no further ruling:** wrap `save`'s body so
  `OSError` becomes a `StoreError`, which `main` already maps to **exit 4**. Reasoning: the PRD
  frames the exit codes as a closed public interface, `store.load` already turns a read `OSError`
  into `StoreError` → 4 (`src/notes/store.py:41-42`), and inventing a fifth code would add public
  interface the PRD does not define. Held back this iteration to keep the two functional
  requirements the only risk.
- G1-7 / I13 — `add ""` stores a blank note that lists as `1. [ ] `. **Planner decision:** treat
  empty or whitespace-only text as a usage error (exit 2 with the usage line), which is how R5
  already treats a subcommand whose argument is effectively absent, and which adds no new exit
  code. Low risk — no evidence-1 claim verifies the current rc 0 — but it is a behaviour change,
  so it waits for iteration 3.
- G1-4 / I9 — the appearance half of R8. Owner `user`, blocked until T2-2 lands; QA records it as
  a gap (V2-13) and a human closes it. Never becomes a Target.
- Iteration 3 is reserved first for repair of anything evidence-2 finds against T2-1..T2-3; I12
  and I13 are picked up only if no repair is needed.
