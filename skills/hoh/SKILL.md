---
name: hoh
description: Harness-of-Harness loop. Runs T plan → implement → QA iterations from a PRD using the hoh-planner / hoh-developer / hoh-qa subagents, feeding QA evidence back into the next plan. Runs only when the user invokes /hoh.
argument-hint: "init [profile] | start <task> <prd-path> [T=3] | resume <task> [T]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---
# /hoh

You are the **outer harness (orchestrator)** of this loop. You never write or verify code yourself. You invoke the role agents, run the gate, maintain the state files, and handle rollback and promotion.

Source paper: Yan et al., "Harness of Harness: Multi-Day Autonomous Software Development with Continual Improvement" (arXiv 2609.01481). How to write a PRD: `references/prd-writing.md`. How to attach HoH to a project: `references/setup.md`.

This skill is project-neutral. Build and test commands come from the workspace's `hoh/project.sh` (sourced by the gate); layout, coding and commit rules come from `hoh/project.md` (read by the agents).

## Locating the harness
- **Role agents**: `hoh-planner`, `hoh-developer`, `hoh-qa`. When HoH is installed as a plugin they are listed as `hoh:hoh-planner`, `hoh:hoh-developer`, `hoh:hoh-qa`. Pass whichever name appears in your list of available agents as `subagent_type`.
- **Skill directory** `HOH`: the first of these that exists —
  1. `${CLAUDE_PLUGIN_ROOT}/skills/hoh` — plugin install (Claude Code expands the placeholder)
  2. `.claude/skills/hoh` — project-local install via `install.sh`
- **Gate**: `bash "$HOH/scripts/gate.sh" <task> <t>`, always run from the workspace root.
- **Profiles**: `$HOH/profiles/<name>/`.

## Arguments: $ARGUMENTS
- `init [profile]` — prepare the workspace: copy a profile to `hoh/project.sh` and `hoh/project.md`, add the ignore rule, run a self-check gate. Default profile `generic`.
- `start <task> <prd-path> [T]` — new task. T defaults to 3.
- `resume <task> [T]` — continue an existing task. If T is given, update `T:` in config.md.

## Prerequisites (check before start and resume, every time)
Do not enter the loop if any of these is missing; tell the user instead.
- The three role agents → reinstall the plugin, or rerun `install.sh`.
- `$HOH/scripts/gate.sh` → same.
- `hoh/project.sh` and `hoh/project.md` → run `/hoh init <profile>` and edit them. See `references/setup.md`.

## State directory `hoh/<task>/` (relative to the workspace root)
| File | Written by | Content |
|---|---|---|
| prd.md | user (copied at start) | the global specification |
| config.md | orchestrator | `task:`, `repos:`, `branch:`, `T:`, `model:`, `gate:`, `known_fail:`, `trailers:` |
| plan-<t>.md | hoh-planner | development document for iteration t (never handed to the next Planner) |
| issues.md | hoh-planner | persistent issue ledger (with owner column) |
| gate-<t>.md | orchestrator (gate.sh) | deterministic build and test result |
| evidence-<t>.md | hoh-qa | evidence bundle for iteration t |
| lineage.md | orchestrator | pointers + `| t | repo | commit | state | qa | model | note |` |
| log.md | orchestrator | one line per iteration |
| logs/ | gate.sh, hoh-qa | build, test and observation logs |

`hoh/project.sh` and `hoh/project.md` are shared by all tasks, not per task. Task directories are run state and must never be committed; `/hoh init` adds `hoh/*/` to `.gitignore`.

## init procedure
1. Resolve `$HOH` (above) and the profile directory `$HOH/profiles/<profile>/`. If it does not exist, list the available profiles and stop.
2. `mkdir -p hoh`. For each of `project.sh` and `project.md`: if `hoh/<file>` exists, leave it and say so; otherwise copy it from the profile, falling back to `profiles/generic/<file>` when the profile has no such file (only `generic` ships a `project.md`). Then `chmod +x hoh/project.sh`.
3. If the workspace root is a git repository and `.gitignore` does not already contain the line `hoh/*/`, append it with a comment. Tell the user that `hoh/project.sh`, `hoh/project.md` and `.gitignore` should be committed (or listed in `.git/info/exclude` if they must stay out of the repository): a run cannot start while they are untracked.
4. List the `TODO` lines left in `hoh/project.sh` and `hoh/project.md`.
5. Self-check: `mkdir -p hoh/_check && printf 'task: _check\n' > hoh/_check/config.md`, then `bash "$HOH/scripts/gate.sh" _check 0`. Show the header of `hoh/_check/gate-0.md` and, on failure, the last lines of `hoh/_check/logs/build-0.log` or `test-0.log`. Then `rm -r hoh/_check`. `build: ok` means the project is ready.

## start procedure
1. Check the prerequisites. Create `hoh/<task>/` and `hoh/<task>/logs/`, copy the PRD to `prd.md`. Create issues.md with the header only: `| id | state | owner | summary | first seen | last updated (t) | history |`
2. Read the layout and commit sections of `hoh/project.md` to learn the options, then confirm with the user in **one** AskUserQuestion: target repositories (`.` for a single repository), branch name, and commit trailers (only if the project requires them). Record them in config.md together with `model:` (the model you are running as) and `gate: gate.sh` (`gate: none` for a task with nothing to build). Say explicitly that every later commit in this run will use these values.
3. For every repository, `git status --porcelain` must be empty. If not, stop and tell the user. Create or check out the branch and record HEAD in lineage.md as t=0, usable.
4. **Baseline gate.** With `gate: gate.sh`, run `bash "$HOH/scripts/gate.sh" <task> 0` and record the tests that fail at baseline in `known_fail:` of config.md. If it takes long, tell the user and continue. With `gate: none`, warn that deterministic checking and evaluation are now mixed into the single QA role.
5. Enter the loop.

## resume procedure
1. Read `hoh/<task>/config.md` and `lineage.md`. Stop if either is missing.
2. If T was given, update `T:` in config.md.
3. **Compare `model:` in config.md with the model you are running as.** If they differ, update `model:` to `<old> → <new> @t<next t>` and tell the user. The paper assumes the harness–model pair stays fixed for the whole run; continuing after a switch makes comparisons across iterations unreliable — say so.
4. For every repository check that the branch is the one in config.md, the working tree is clean, and HEAD equals the last usable commit in lineage. Otherwise stop and tell the user.
5. Start at t = last iteration in lineage + 1. If plan or evidence files for that t already exist, do not overwrite them; stop and tell the user.
6. Enter the loop.

## Loop (t = start .. T)
1. **Plan**: Agent tool, `subagent_type` = the planner agent, `run_in_background: false`, mode `plan`. The prompt gives the task directory, t, the absolute paths of the files to read (prd.md, evidence-<t-1>.md, issues.md, lineage.md, hoh/project.md) and the list of target repositories. Do **not** list plan-<t-1>.md. Afterwards check:
   - plan-<t>.md exists with the header fields `iteration`, `status`, `targets`
   - `targets` is at most 3 and equals the number of rows in Targets
   - id formats `T<t>-<n>`, `P<t>-<n>`, `V<t>-<n>`
   - `status: complete` → leave the loop and go to **Closing**.
2. **Dev**: Agent tool, `subagent_type` = the developer agent. The prompt gives the task directory, t, and the absolute paths of prd.md, plan-<t>.md, config.md and hoh/project.md. Record the returned status, claimed_fixed and commit hashes in lineage.md as t, pending, with the current model. If no hash was returned, read it with `git -C <repo> rev-parse HEAD`. **If a working tree is dirty, re-invoke the Developer once to commit.** A report longer than 20 lines is by itself no reason to re-invoke (the code and the commit are the deliverable). The commit at this point is the **frozen candidate**.
3. **Gate**: run `bash "$HOH/scripts/gate.sh" <task> <t>` from the workspace root to produce gate-<t>.md (build and test, no model involved). Skip with `gate: none`. On `build: fail`, do not invoke QA: write evidence-<t>.md yourself with the header only (build: fail, qa_status: fail, one gap `G<t>-1` `gate.build_fail`, blocker, owner developer, log path) and go to step 5.
4. **QA**: Agent tool, `subagent_type` = the QA agent. The prompt gives the task directory, t, the absolute paths of prd.md, plan-<t>.md, config.md and hoh/project.md, the commit hash per repository, and the path of gate-<t>.md. **Never pass the Developer's report or a summary of it.**
5. **Verdict**: read the header of evidence-<t>.md.
   - `build: fail` → mark t `unusable` in lineage and run `git reset --hard <last usable commit>` in every repository. The discarded commit stays in the reflog and in lineage.md; the next Planner sees it there and creates a blocker Target.
   - `qa_status: pass` → `git tag hoh/<task>/verified-<t>` in every repository and set "Best verified" in lineage to t.
   - otherwise → `usable`.
6. Append one line to log.md: `t | model | dev status | build | tests | qa_status | gaps(b/m/i/n) | regressions | issues open(dev/orch/user)/closed | commits`.
7. Next t.

## lineage.md format
Pointers at the top: Latest candidate, Latest warm start, Best verified, Accepted (the t the user finally accepted; default none).
Table: `| t | repo | commit | state (usable/unusable) | qa (pass/fail/-) | model | note |`

## Closing
1. Determine why the loop ended: t reached T, or the Planner returned `status: complete`.
2. **Close the ledger.** If no Planner call has read the last evidence bundle (the loop ended because t reached T), invoke the planner agent once in **ledger-only** mode so the last evidence is folded into issues.md. Skip this when the Planner ended the run with complete — the ledger is already current.
3. Append a closing line to log.md.
4. Report to the user: the per-iteration trend of gaps, regressions and issues (stating that a QA `fail` is by itself normal); the final branch, commit and verified tags per repository; the remaining issues grouped by owner (developer / orchestrator / user); whether the model changed during the run; and how to squash (loop commits are `chore: [hoh …]` WIP — `git reset --soft <t=0 commit>` and recommit with a proper message).
5. Remaining owner=orchestrator issues are **your** job, not the Developer's. `hoh/project.sh` and `hoh/project.md` in the workspace can be edited directly. The gate, the skill and the agent definitions belong to the HoH installation — under a plugin install they live in the plugin cache and are replaced on update — so propose those fixes to the user as changes to the HoH repository rather than editing them in place. Present the list and act on the user's instruction.

## Rules
- Role agents deliver files. Keep only a summary of their return text in context; never copy file contents into the main context.
- Do not interfere with how an agent works internally (tool use, debugging strategy). Check only the format of its output.
- If an output violates the format (missing header, too many targets, bad id format), re-invoke the same agent once, pointing at the format. On a second failure, stop and report to the user.
- The only question to the user is the config confirmation at start. Every other decision is logged and taken. Stop conditions (missing prerequisites, dirty tree, resume mismatch, model change) are reported immediately.
- The only files you write are config.md, lineage.md, log.md and, on a gate build failure, evidence-<t>.md. plan, issues and evidence are the role agents' outputs.
