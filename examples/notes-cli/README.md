# Example run: a note-taking CLI, T=3

A complete HoH run, unedited except for one substitution: the absolute paths of the
throwaway workspace became `<workspace>`. Nothing was rewritten to look better.

The project was built for this run: a `notes` CLI (`add`, `list`, `done`, `search`, a JSON
store, `--color`) in Python with pytest, starting from a package that held nothing but
`__version__` and one smoke test. Its PRD is [prd.md](prd.md) — eight requirements, one of
them deliberately impossible for a script to settle.

## What happened

| t | gate | tests | qa_status | regressions | gaps (b/m/i/n) | ledger |
|---|---|---|---|---|---|---|
| 0 | ok | 1 passed | — | — | — | baseline |
| 1 | ok | 25 passed | fail | 0 | 0/2/2/3 | 10 open, 0 closed |
| 2 | ok | 31 passed | fail | 1 | 0/0/3/3 | 8 open, 5 closed |
| 3 | ok | 37 passed | fail | 0 | 0/0/2/3 | 5 open, 14 closed |

**`qa_status: fail` at every iteration, and the run still finished its PRD.** That is the
point of the table. R8 asks a human whether "dim" is legible on a dark background, so
`prd.md` hands QA a claim it can never mark verified — while major gaps went 2 → 0, closed
issues 0 → 14, and the suite 1 → 37 tests. Read the ledger, not the verdict.

## Where to look first

- [log.md](log.md) — the whole run in four lines.
- [issues.md](issues.md) — the ledger. Every row carries its own history, so you can watch
  one issue travel from `prd` to `closed` through the iteration that closed it.
- [evidence-2.md](evidence-2.md) — the most interesting bundle. All eight requirements pass
  black-box for the first time, and QA still files a regression against a project rule the
  gate cannot see.
- [plan-3.md](plan-3.md) — the last plan, written to close rather than to open.

## Three things the loop caught that a single agent would not

1. **A wrong note silently marked done.** Iteration 1's `done <n>` validated its argument
   with bare `int()`, so `done 1_0` marked note **10** and printed nothing. The plan's five
   required cases all behaved correctly — QA found it by probing past the plan
   ([evidence-1.md](evidence-1.md), G1-5), and iteration 2 fixed it.
2. **A traceback where an exit code was specified.** An unwritable store produced an
   eight-frame `PermissionError` and exit 1 against `project.md`'s "never let a traceback
   reach the user" (G1-6 → G2-2 → closed in iteration 3, verified by re-running the
   90-case corrupt-store matrix to show the shared exit-4 path was undisturbed).
3. **A plan that could not fail its own check.** Iteration 2's plan required "every module
   under 200 lines" but its validation command measured `src/` only, so a 303-line test
   file slipped through. QA graded against the constraint text, filed the regression, and
   said the plan was inconsistent. That became an `owner=orchestrator` issue — the harness's
   problem, not the Developer's — and iteration 3's plan aligned every constraint with the
   command that measures it.

QA also caught two of **its own** measurement harnesses producing false empties (`script -q`,
a naive `pty.openpty` read). Both would have read as "the CLI printed nothing" — that is, as
a defect in the candidate. The fix was a sanity child asserting `isatty=True` on the same
pty; the discipline is recorded in the bundles and reused in the later iterations.

## What is not here

- **The `logs/` directory** (33 files, 188K of build, test and QA probe output). The
  evidence bundles quote what mattered and name the commands to reproduce it.
- **The product code.** This is a record of the loop, not a Python sample. The final commit
  held `src/notes/{__main__,cli,store}.py` (146 lines at most, 266 in total) and nine test
  files plus a `conftest.py`.
- **A `verified-<t>` tag.** Tags need `qa_status: pass`, which this PRD makes unreachable
  by design. [lineage.md](lineage.md) records `Best verified: none` for that reason.

## What a human was left holding

Five open issues at the close: `add ""` storing a blank note (decision recorded, never
implemented), two test-hardening items, and two that need a person — running the two-minute
appearance check for R8, and deciding whether R8's "no escape sequence at all" was meant to
cover escape bytes a user stored in a note's own text.

## Cost

Three iterations, ten agent invocations (three roles × three, plus a ledger-only pass at
the close), four gate runs. The orchestrator wrote only `config.md`, `lineage.md` and
`log.md`; the plans, the ledger and the evidence are the role agents' own output.

One harness defect surfaced while setting the run up, before iteration 1: the python
profile installed `requirements.txt` only when a project had no `pyproject.toml`, so the
baseline gate called a healthy tree `tests: fail`. Fixed in the profile, not here.
