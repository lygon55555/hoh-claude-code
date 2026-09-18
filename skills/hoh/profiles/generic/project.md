# Project rules: <project name>

Read by the HoH Developer and QA agents every iteration. **Project-specific rules only.**
Do not write general good practice — the model already knows it. The test for
including something: without it, the same mistake would recur every iteration.

Lives at `<workspace>/hoh/project.md`. If `CLAUDE.md` or `AGENTS.md` already exists,
do not duplicate it: write "the source of truth is CLAUDE.md" and copy only the
rules that get tripped over most often.

## Layout

- Is the workspace one git repository or several? If several, say "use `git -C <repo>`".
- Directories that must never be committed (`hoh/<task>/` is always one of them).

## Build

```bash
# exactly what a human types in the terminal
```

- Environment variables, ordering constraints, arguments that are easy to forget.

## Tests

```bash
# how to run a single test (the Developer runs this repeatedly)
```

- Slow tests, tests that need isolation, tests that give false failures.

## Coding rules

- Rules that hold only in this project. Examples: a specific macro for argument checks, generated files that must not be edited by hand, which file to edit first for string resources.

## Commits

- Message format, branch rules.
- If trailers are required, say "append the `trailers:` value from `config.md` verbatim".

## Known quirks

- Failures that happen only on this machine or in this environment, and how to work around them. Anything broken at baseline.
