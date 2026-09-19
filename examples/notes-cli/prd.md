# PRD: a note-taking CLI with a durable JSON store (notes)

Date: 2026-09-19

## 1. Background

The repository holds an empty `notes` package and one smoke test. There is no CLI yet.
This PRD specifies the whole first version of the command-line interface. It exists to
exercise the HoH loop end to end on a project small enough to read in one sitting, so
the requirements are deliberately observable from a shell.

## 2. Scope

Target repositories: `.`

Target files:
- `src/notes/` — currently only `__init__.py` with `__version__`. The CLI lives here.
- `tests/` — currently only `tests/test_smoke.py`. New tests live here.

Out of scope (do not modify):
- `pyproject.toml` build configuration and the package name. The gate installs the
  package editable from it; changing the layout breaks the gate.
- `hoh/`. Harness files, not product code.
- `requirements.txt` beyond what a requirement here forces. No dependency may be added
  (see section 4).

## 3. Functional requirements

The command is invoked as `python -m notes <subcommand> [args]`. The store path comes
from the `NOTES_FILE` environment variable; when it is unset the path is `~/.notes.json`.

R1. `add <text>` appends a note and exits 0. A following `list` shows that text.
R2. `list` prints one line per note, in insertion order, as `<n>. [ ] <text>` with `n`
    starting at 1. A note that is done prints `[x]` in place of `[ ]`.
R3. `list` against a store with no notes prints exactly `no notes` and exits 0. It does
    not create the store file.
R4. `done <n>` marks note `n` done and exits 0. An `n` that is not a positive integer or
    is past the end of the list prints a message naming `<n>` to stderr and exits 3,
    leaving the store unchanged.
R5. No subcommand, an unknown subcommand, or a subcommand missing its argument prints a
    usage line to stderr and exits 2. The usage line names every subcommand.
R6. The store is a JSON object `{"notes": [{"text": <string>, "done": <boolean>}]}`.
    A store file that is not valid JSON, or whose shape does not match, makes every
    subcommand print a message naming the store path to stderr and exit 4 — never a
    traceback, and never a silent overwrite of the file.
R7. `search <query>` prints the matching notes in the `list` format, matching
    case-insensitively on a substring of the text. No match prints exactly `no matches`
    and exits 0.
R8. `list --color` dims the text of notes that are done, using ANSI SGR codes, and
    leaves notes that are not done unchanged. Without `--color`, no escape sequence
    appears in the output at all — including when stdout is a terminal.

## 4. Non-functional requirements

- Standard library only. `requirements.txt` keeps `pytest` as its only entry.
- Python 3.9 compatible.
- Every requirement above has at least one test in `tests/`.
- Exit codes and the text of the `no notes` / `no matches` lines are the public
  interface: a later iteration may not change them.

## 5. Verification constraints

Automatic (the gate plus commands QA can run):
- `python -m pytest -q` in the project venv is green.
- Each of R1–R8 can be checked by running `python -m notes …` with `NOTES_FILE` pointed
  at a temporary file, and comparing stdout, stderr and `$?`.
- R8's *absence* of escape sequences is checkable: `python -m notes list | cat -v` shows
  no `^[`.

Manual only (recorded as a gap plus a note, closed by a human):
- R8's dimming as it actually looks in a terminal — whether "dim" is legible on a dark
  background is a human judgement, not something a script can assert. QA is expected to
  verify the escape codes are present and correct and to leave the appearance as a gap.

## 6. Definition of done

R1–R8 verified in the evidence bundle, with the appearance half of R8 left as a manual
gap for a human to confirm. `python -m pytest -q` green at the final commit.
