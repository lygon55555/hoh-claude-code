# Writing a PRD for HoH

PRD quality is the ceiling of the whole loop. Evidence reorders priorities but never replaces the PRD.
The Planner splits the PRD into checkable claims; QA turns PRD requirements into claims of its own. Nothing that is missing from the PRD gets checked by anyone.

## Principle 1. State goals, not means

This is the most important one, and it went wrong in our very first real run.

The PRD said:

> R1. The control must expose the accessibility role *button*.
> R3. Mark the icon as `Image(decorative:)` so the asset name is never spoken.

The **means** prescribed by R3 nullified R1. In SwiftUI, hiding a Button's entire label subtree removes the Button node itself from the accessibility tree. The Developer followed the PRD faithfully, and the control ended up worse than the baseline. QA caught it as a blocker regression and the next iteration reverted it.

It should have read:

> R3. Assistive technology never reads the asset file name. The Developer chooses the means.

When you really must fix the means (a house convention, a compatibility constraint), write the reason next to it. That gives the Developer something to weigh when the means conflicts with another requirement.

## Principle 2. Write sentences QA can observe

QA does not accept "the implementation is in the source" as verification. Only observations reproducible through a public interface count as evidence.

| Weak | Observable |
|---|---|
| The setting must work | Changing the setting makes the service log `config reloaded` at INFO within 1 s |
| Performance must improve | Scanning 1,000 files is no slower than before (same machine, median of 3 runs) |
| The UI should feel natural | With an empty list, the hint text is visible and the button is disabled |

## Principle 3. Declare up front what cannot be verified automatically

Anything that cannot be checked from a shell on this machine belongs in a "verification constraints" section. Otherwise QA files it as a `qa.coverage_incomplete` gap every iteration, and that issue never closes.

The usual boundary:

| Automatic | Manual only |
|---|---|
| Build, unit and integration tests | Screen-reader speech |
| Presence of log strings | The installed app's actual screens, mouse hover |
| `git` state, file contents | Full keyboard navigation (Tab / Space) |
| Processes a script can launch | Anything needing sudo, permission prompts, a reboot or a physical device |

## Principle 4. Name what is out of scope

The Planner picks at most three Targets per iteration, but a broad PRD makes every iteration touch a different corner. List the files, packages and behaviors that must not change under "Out of scope (do not modify)". For shared components used elsewhere, say whether their signatures may change.

## Template

```markdown
# PRD: <one-line title> (<task name>)

Date: YYYY-MM-DD

## 1. Background
Why this is needed. Cite the documents, issues or audit reports behind it.

## 2. Scope
Target repositories: <path or .>

Target files:
- <path> (one line on its current state)

Out of scope (do not modify):
- <path or behavior>. Reason.

## 3. Functional requirements
R1. <observable sentence>
R2. ...
   - If a means must be prescribed, give the reason next to it.

## 4. Non-functional requirements
- Coding rules, no new dependencies, performance and compatibility criteria.

## 5. Verification constraints
Automatic:
- <command and expected result>

Manual only (recorded as gap + note, confirmed by a human):
- <item and why>

## 6. Definition of done
R1–Rn verified in the evidence. Manual items closed after human confirmation.
```

## Sizing

A PRD of 3–10 requirements that can finish in about three iterations is the right size. Split anything bigger into several tasks. Editing the PRD mid-run invalidates the premises of the existing evidence and plans; if you must, start over under a new task name.
