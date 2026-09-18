# HoH — Harness-of-Harness for Claude Code

An implementation of the Harness-of-Harness loop from Yan et al., *Harness of Harness: Multi-Day Autonomous Software Development with Continual Improvement* ([arXiv:2609.01481](https://arxiv.org/abs/2609.01481)), packaged as a Claude Code plugin: three role agents (Planner, Developer, QA), one orchestrating skill (`/hoh`) and a deterministic build-and-test gate.

It is project-neutral. You describe how to build and test your project in two small files; the loop does the rest.

## Why

Hand an agent a feature and the first pass looks fine. Say "keep going" a few times and it starts re-fixing the same spot, breaking things that used to work, and reporting unfinished work as done — because the party that implemented the change is also the one judging whether it is complete.

HoH splits every iteration into three independent invocations of the same model:

| Role | May write | Produces |
|---|---|---|
| **Planner** | `plan-<t>.md`, `issues.md` | This iteration's development document: at most three targets, the behaviors that must not break, and how QA should check each one |
| **Developer** | Code, commits | Code changes committed on the task branch — the *frozen candidate* |
| **QA** | `evidence-<t>.md`, logs | Per-claim `verified` / `gap` evidence from its own observations. It never sees the Developer's report |

Two state channels connect iterations: code (the committed artifact) flows to the next Developer, evidence flows to the next Planner. The development document is **not** carried over — the Planner rewrites it every iteration from the specification and the latest evidence. In the paper's ablation, removing plan rewriting, evidence feedback or artifact warm-start each cost 6–8 points on their benchmark; this loop keeps all three.

Between Developer and QA sits the gate: a shell script that builds and tests the frozen commit with no model involved, records the commit hash and the results, and hands them to QA as the only trusted starting point. In our first real run, QA used it to catch a regression the Developer had reported as complete, and the next iteration reverted it.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 2.1 or later (subagents, skills, plugins).
- A project that builds and tests from the shell without interaction, under git.
- Budget. One iteration is three agent invocations plus a full build and test. Expect one to two hours and several times the tokens of a single-shot task for T=3.

The Developer agent has full tool access: it edits files, runs shell commands and commits. Run HoH on a branch, in a repository you can reset.

## Install

### As a plugin (recommended)

In Claude Code:

```
/plugin marketplace add lygon55555/hoh-claude-code
/plugin install hoh@hoh
```

Restart Claude Code. `/hoh` appears in the skill list and the agents are listed as `hoh:hoh-planner`, `hoh:hoh-developer` and `hoh:hoh-qa`.

To try a local checkout without publishing anything:

```bash
claude --plugin-dir /path/to/hoh
```

### Project-local (symlinks)

For a harness that lives inside one workspace instead of the plugin cache:

```bash
git clone https://github.com/lygon55555/hoh-claude-code.git
./hoh-claude-code/install.sh /path/to/your/workspace --profile node
```

`install.sh` symlinks `skills/hoh` and the three agents into `<workspace>/.claude/` and copies the profile into `<workspace>/hoh/`. Rerunning it is safe.

## Set up your project

HoH needs two files in your workspace:

| File | Read by | Contains |
|---|---|---|
| `hoh/project.sh` | the gate | `hoh_build()` and `hoh_test()` — the exact commands a human would type |
| `hoh/project.md` | Developer and QA | Project-specific rules only: layout, how to run one test, coding and commit conventions, known quirks of the environment |

Create them from a profile, then edit:

```
/hoh init python
```

Profiles: `generic`, `node`, `python`, `go`, `rust`, `xcode`. All but `generic` are starting points that assume the stack's defaults — check the commands against your project. Running `/hoh init` again performs a self-check gate and reports `build: ok` when the two files work.

`hoh/project.sh` and `hoh/project.md` belong in your repository. Run state under `hoh/<task>/` does not; `/hoh init` adds `hoh/*/` to `.gitignore`.

The full contract and the pitfalls (watch modes, pagers, prompts that hang the gate): [skills/hoh/references/setup.md](skills/hoh/references/setup.md).

## Run

### 1. Write a PRD

PRD quality is the ceiling of the whole loop. Read [prd-writing.md](skills/hoh/references/prd-writing.md) first. In short:

- State **goals, not means**. A PRD that prescribes an implementation can silently contradict its own other requirements.
- Write sentences QA can **observe** through a public interface — not "works correctly" but "logs `config reloaded` at INFO within 1 s".
- Declare up front what **cannot be verified automatically** (screen-reader speech, sudo, a physical device). Otherwise QA files it as a coverage gap every iteration.
- Name what is **out of scope**.

### 2. Start

```
/hoh start <task> <path/to/prd.md> [T=3]
```

You are asked exactly once: target repositories, branch name, and commit trailers if your project requires them. Every other decision is taken by the loop and written to the log. To continue an interrupted run:

```
/hoh resume <task> [T]
```

### 3. Read the results

Everything lands in `hoh/<task>/`:

| File | Why you look at it |
|---|---|
| `log.md` | One line per iteration. Start here |
| `issues.md` | Persistent ledger. **Progress is the open/closed trend here**, not `qa_status` |
| `evidence-<t>.md` | What QA observed, how, and which claims are gaps |
| `plan-<t>.md` | What the iteration set out to do and why |
| `lineage.md` | Commit per iteration, usable/unusable, verified tags |

**QA returning `fail` is normal.** A single manual-only item is enough to prevent `pass`. Watch the ledger shrink instead.

Every issue has an owner:

| owner | Who acts |
|---|---|
| `developer` | The loop, in the next iteration |
| `orchestrator` | A harness problem — the gate, your `project.sh`, or this repository |
| `user` | A human: manual verification, PRD wording, environment |

### 4. Finish

Loop commits are WIP (`chore: [hoh <task>] iter <t> …`). To keep the work, squash them:

```bash
git reset --soft <t=0 commit>    # the hash is in lineage.md
git commit
```

To discard it, delete the branch. Iterations that passed QA are tagged `hoh/<task>/verified-<t>`.

## How an iteration runs

```
for t in 1..T:
  plan-t      = Planner(prd, evidence-(t-1), issues, lineage, project.md)   # never sees plan-(t-1)
  if plan-t.status == complete: break
  candidate-t = Developer(prd, plan-t, project.md)                          # commits; tree must be clean
  gate-t      = gate.sh(candidate-t)                                        # build + test, no model
  evidence-t  = QA(prd, plan-t, gate-t, candidate-t)                        # never sees the Developer's report

  build failed  -> reset to the last usable commit
  qa_status pass -> tag hoh/<task>/verified-t
```

A regression does not roll back automatically. It is filed as `regressed` and becomes the next iteration's top priority after build blockers. Only a build failure rolls back.

## Repository layout

```
.claude-plugin/          plugin and marketplace manifests
agents/                  hoh-planner.md, hoh-developer.md, hoh-qa.md
skills/hoh/SKILL.md      the /hoh orchestrator
skills/hoh/scripts/      gate.sh
skills/hoh/profiles/     generic, node, python, go, rust, xcode
skills/hoh/references/   setup.md, prd-writing.md
install.sh               project-local install (alternative to the plugin)
```

## Limits

- No unattended multi-day runs yet. The loop runs T iterations inside one Claude Code session; `/hoh resume` continues across sessions.
- The gate checks only what a shell can run. Visual, audio and permission-gated behavior ends up as gaps for a human.
- A `project.sh` that blocks on a watch mode, a prompt or a pager hangs the gate. See the pitfalls in setup.md.
- Switching models mid-run is recorded and reported, but the paper assumes a fixed harness–model pair; comparisons across such a switch are unreliable.
- Tested on macOS with Claude Code 2.1. The gate script uses only POSIX tools plus git and should run on Linux; Windows is untested.

## Acknowledgements

The loop, the role split and the two-channel state design follow Yan et al., *Harness of Harness: Multi-Day Autonomous Software Development with Continual Improvement*, arXiv:2609.01481 (2026). This is an independent implementation and is not affiliated with the authors.

## License

[MIT](LICENSE)
