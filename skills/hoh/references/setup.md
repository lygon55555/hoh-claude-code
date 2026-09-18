# Attaching HoH to a project

The HoH core — skill, agents and gate — is project-neutral. Everything that differs between projects lives in **two files** in the workspace:

| File | Read by | Defines |
|---|---|---|
| `<workspace>/hoh/project.sh` | the gate (`gate.sh` sources it) | the build and test **commands** |
| `<workspace>/hoh/project.md` | the Developer and QA agents | layout, coding rules, commit rules, known quirks |

## 1. Create them

In Claude Code, from the workspace:

```
/hoh init <profile>
```

Profiles ship with the skill (`skills/hoh/profiles/`):

| Profile | For |
|---|---|
| `generic` | any project — fill in the TODOs |
| `node` | npm scripts, jest / vitest |
| `python` | venv + pytest (+ mypy when installed) |
| `go` | go build / vet / test |
| `rust` | cargo build / clippy / test |
| `xcode` | xcodebuild build-for-testing / test-without-building |

The files are **copied**, not linked: they belong to your project and you will edit them. Existing files are left untouched. `init` also appends `hoh/*/` to `.gitignore` so run state never gets committed, then runs a self-check gate.

Without Claude Code: `./install.sh <workspace> --profile <name>` copies the same two files.

## 2. Fill in `project.sh`

The gate sources the file and calls the functions. This is the entire contract:

```bash
HOH_REPOS_DEFAULT="."        # optional. repositories when config.md has no repos: line

hoh_build() { ... }          # required. exit 0 = success
hoh_test()  { ... }          # required. exit 0 = all tests passed
hoh_test_summary() { ... }   # optional. one-line summary on stdout
hoh_artifacts()    { ... }   # optional. artifact paths to check, one per line
```

Values exported by the gate:

| Variable | Content |
|---|---|
| `HOH_TASK` | task name |
| `HOH_T` | iteration number |
| `HOH_TASK_DIR` | `hoh/<task>` |
| `HOH_LOGS` | `hoh/<task>/logs` — extra logs written here are listed in gate-<t>.md |
| `HOH_REPOS` | target repositories, space-separated |
| `HOH_KNOWN_FAIL` | the `known_fail:` value from config.md |

Three things to watch:

- **Nothing interactive.** Watch modes, confirmation prompts and pagers hang the gate forever. Use `CI=1`, `< /dev/null`, `--no-pager` and the like.
- **The exit code is the verdict.** The summary function is for humans; it plays no part in pass/fail.
- **Same commands a human would type.** A build path only the gate knows about makes the Developer's self-check disagree with the gate.

## 3. Fill in `project.md`

The Developer and QA read it every iteration. **Project-specific rules only.** The model already knows general good practice. The test for including a line: without it, the same mistake would recur every iteration.

If `CLAUDE.md` or `AGENTS.md` already exists, do not copy it. Write "the source of truth is CLAUDE.md" and extract only what gets tripped over most.

Must-haves:

- Whether the workspace is one repository or several. If several, say "use `git -C <repo>`".
- How to run a single test. The Developer runs it repeatedly (baseline → change → retest).
- Failures specific to this environment and their workarounds. Anything broken at baseline.
- Commit message format. If trailers are required, say "append the `trailers:` value from `config.md`".

## 4. Verify

`/hoh init` runs this for you. By hand, from the workspace root:

```bash
mkdir -p hoh/_check && printf 'task: _check\n' > hoh/_check/config.md
bash <hoh>/skills/hoh/scripts/gate.sh _check 0
cat hoh/_check/gate-0.md
rm -r hoh/_check
```

`<hoh>/skills/hoh` is `.claude/skills/hoh` for a project-local install, or `~/.claude/plugins/cache/hoh/hoh/<version>/skills/hoh` for a plugin install.

`build: ok` means you are ready. Then open Claude Code in the workspace and check that `/hoh` is in the skill list.

## 5. First run

Write a PRD. Read `prd-writing.md` first — PRD quality is the ceiling of the loop.

```
/hoh start <task> <prd-path> 3
```

## FAQ

**A project with no build step?** Put `gate: none` in `config.md` and the gate is skipped. QA then builds and tests itself, which mixes deterministic checking into the evaluation role — the very thing the paper separates. Not recommended; even a linter or a type check in `hoh_build` is better.

**A project with no tests?** Leave `return 0` in `hoh_test` and state "no automated tests" in the PRD's verification-constraints section. QA then judges from runtime observation alone.

**Only some packages of a monorepo?** List their paths, space-separated, in `repos:` of `config.md`. `hoh_build` can iterate over `$HOH_REPOS`.

**Several stacks in one workspace?** Branch inside one `project.sh`. The gate asks for two functions and nothing else.
