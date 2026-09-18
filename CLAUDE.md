# CLAUDE.md

Guidance for Claude Code when working in this repository.

**If a file named `HANDOFF.md` exists in the repository root, read it first.** It is a local, git-ignored note that carries in-progress state and the remaining to-do list between machines. It is never committed.

## What this repository is

HoH is a Claude Code plugin implementing the Harness-of-Harness loop (Yan et al., arXiv:2609.01481): three role agents, one orchestrating skill (`/hoh`) and a deterministic build-and-test gate. It is project-neutral; per-project behavior comes from `hoh/project.sh` and `hoh/project.md` in the *user's* workspace, never from this repository.

| Path | Role |
|---|---|
| `.claude-plugin/plugin.json`, `marketplace.json` | Plugin and marketplace manifests. Versions must match. |
| `agents/hoh-{planner,developer,qa}.md` | The three role contracts. The loop's correctness lives here. |
| `skills/hoh/SKILL.md` | The `/hoh` orchestrator: `init`, `start`, `resume`, the loop, closing. |
| `skills/hoh/scripts/gate.sh` | The gate. Sources the workspace's `hoh/project.sh`; no model involved. |
| `skills/hoh/profiles/<name>/` | Starting points for `hoh/project.sh` (and `project.md` for `generic`). |
| `skills/hoh/references/` | `setup.md` (attach to a project), `prd-writing.md`. |
| `install.sh` | Project-local symlink install, the alternative to the plugin. |

## Conventions

- Everything user-facing is in English. `README.md` is canonical; `README.ko.md` is its Korean translation and the only exception — change it in the same commit whenever `README.md` changes, or leave it alone. Add no further top-level documents, no other languages, and no HTML.
- The agent files and `SKILL.md` are prompts with fixed identifier formats (`T<t>-<n>`, `P<t>-<n>`, `V<t>-<n>`, `I<n>`, `G<t>-<n>`, `S-<id>`) and a fixed file layout under `hoh/<task>/`. A change in one file usually needs a matching change in the others — grep for the identifier or field before editing.
- `gate.sh` must stay POSIX-shell portable (macOS BSD tools and GNU coreutils; note the `stat`/`date` fallbacks) and must never call a model.
- Profiles must not block on anything interactive (watch modes, prompts, pagers).
- Nothing in this repository may reference the private project it was first developed on. Keep examples generic.

## How to check a change

```bash
claude plugin validate .                     # marketplace manifest
claude plugin validate .claude-plugin/plugin.json
claude plugin validate skills && claude plugin validate agents
bash -n skills/hoh/scripts/gate.sh skills/hoh/profiles/*/project.sh install.sh
```

Gate smoke test — a throwaway repository with a trivial `hoh/project.sh`:

```bash
d=$(mktemp -d) && cd "$d" && git init -q -b main . && mkdir hoh
printf 'HOH_REPOS_DEFAULT="."\nhoh_build() { true; }\nhoh_test() { echo "1 passed"; }\nhoh_test_summary() { grep -Eo "[0-9]+ passed" "$HOH_LOGS/test-$HOH_T.log"; }\n' > hoh/project.sh
printf 'hoh/*/\n' > .gitignore && git add -A && git commit -qm init
mkdir -p hoh/t && printf 'task: t\n' > hoh/t/config.md
bash <repo>/skills/hoh/scripts/gate.sh t 0 && cat hoh/t/gate-0.md      # expect build: ok, tests: 1 passed, candidate_dirty: no
```

`.github/workflows/checks.yml` runs all of the above on every push and pull request, plus a build-failure variant of the smoke test, on Linux — the one place the gate is exercised off macOS. Keep the workflow in step when you change the commands here.

Load the plugin in a real session without installing it: `claude --plugin-dir <repo>` from any workspace, then `/hoh`. The skill is user-invocable only (`disable-model-invocation: true`), so the model will not list it among auto-invocable skills — that is expected.

## Releasing

1. Bump `version` in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
2. `claude plugin validate .` and the checks above.
3. Commit, then `claude plugin tag .` creates the `hoh--v<version>` tag; push with `--tags`.
