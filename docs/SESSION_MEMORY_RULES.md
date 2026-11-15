# SESSION MEMORY RULES (binding)

Long sessions make you forget. This file defines how you keep **written memory** so that you, a fresh session, or a different AI model can resume work with zero chat history.

**Core principle:** chat memory is unreliable; files are reliable. If it matters, write it down. If a file and your memory disagree, the file and the code win.

---

## 1. The memory layers

| Layer | File | Lifetime | Size | Purpose |
|---|---|---|---|---|
| 1. Rules | `CLAUDE.md` | permanent | short (< 100 lines) | How we work. Points to everything below. |
| 2. Vision | `docs/PROJECT_OVERVIEW.md` | long-lived | medium | What the game is, contracts, numbers, decisions. |
| 3. Durable state | `docs/PROJECT_STATE.md` | long-lived | small (< 80 lines) | What is finished, what is in flight, which branch is active, key decisions already made. |
| 4. Working memory | `docs/sessions/<branch-slug>.md` | **temporary** | medium | Everything about ONE feature branch. Deleted when the branch is done. |
| 5. Index | `docs/sessions/_ACTIVE.md` | temporary | tiny | Which session files are active. |

**One file per feature branch, not per chat.** A branch is the unit of work; the chat is just a window onto it. Each chat session appends an entry to the branch's file.

Naming: branch `features/player-rig-and-ragdoll` → `docs/sessions/features-player-rig-and-ragdoll.md` (slashes become dashes).

## 2. Start-of-session protocol (do this BEFORE any work)

1. Read, in order: `CLAUDE.md` → `docs/PROJECT_OVERVIEW.md` → `docs/PROJECT_STATE.md` → `docs/sessions/_ACTIVE.md` → the session file for the current branch.
2. Verify against reality using **read-only** git and file commands: `git branch --show-current`, `git status --short`, `git log --oneline -10`, `git diff --stat`. (Read-only git is allowed for this purpose; no writes, ever, unless the user asks.)
3. If the session file's branch does not match the current branch, or the file is missing, **stop and tell the user**. Do not guess.
4. Reply to the user with a **recap of at most 8 lines**: branch, goal, what is done, what is in progress, the exact next step, any open questions, anything in the code that contradicts the file.
5. **Stop and wait for the user's go.** Do not start building from memory.

## 3. When to write (checkpoint triggers)

Update the session file:
- after **every completed task or slice**, before moving to the next;
- after **every decision** (what + why + alternatives rejected);
- before any risky or large change (so a failed attempt is recoverable);
- whenever you learn a gotcha or find a bug and its cause;
- when the user says "checkpoint", "save state" or "wrap up";
- when the conversation has gotten long (many edits or many cards handed out), proactively tell the user: "This session is getting long. I'm writing a checkpoint. I recommend starting a fresh session after it."
- at the **end of every session**, always.

## 4. How to write (quality rules)

1. **Self-contained.** A different model must understand it with no chat. Never write "as discussed" or "the earlier approach". Name the file, function, node path, value.
2. **Specific.** Paths, function names, RPC names, constants and values, node paths. No "combat works".
3. **Label certainty:** `VERIFIED` (saw it in code or test output), `ASSUMED`, `UNVERIFIED`. Mark statuses `DONE / PARTIAL / BROKEN / UNTESTED / ABANDONED`.
4. **Current State is rewritten, not appended.** It must always describe *now*. History goes in the session log.
5. **Keep it short.** Target < 200 lines. When it grows, compress old log entries into one line each. Never delete open questions, unresolved bugs or decisions.
6. **Record the next step as an exact action**, not a theme ("Create `rig/gait_math.gd` with `stride_for_speed()` and its test", not "work on legs").
7. **No secrets, no tokens, no personal data.**
8. Record what the **user** must do and is waiting on (editor tasks, commits, test runs), separately from what you do.

## 5. Session file template

Create `docs/sessions/<branch-slug>.md` from this:

````markdown
# Session memory: <branch name>

Branch: features/<name>
Goal (one sentence):
Status: IN PROGRESS | BLOCKED | READY TO RETIRE
Last updated: <date> by <model name> (session #<n>)
Base docs: PROJECT_OVERVIEW.md, PROJECT_STATE.md

## Current state (rewrite every time)
<5-10 lines: what exists and works right now, what does not.>

## Done (this branch)
- [DONE] <thing> — files: <paths> — evidence: <test name / output>

## In progress
- [PARTIAL] <thing> — files: <paths> — what is left: <exact>

## Exact next step
<one concrete action, and who does it: Claude / User>

## Waiting on the user
- <editor task N / run tests / commit / decision>

## Decisions made (with why)
| # | Decision | Why | Alternatives rejected |
|---|---|---|---|

## Open questions (do not decide these alone)
- <question> — options: <a / b> — my recommendation: <x>

## Known bugs and gotchas
- <symptom> — cause: <root cause or UNVERIFIED> — fix/workaround: <...>

## Files touched
<path — one-line purpose, grouped by feature>

## How to verify
- Run: <command>  Expect: <output>
- Playtest checklist: <items>

## Contracts to not break (links to PROJECT_OVERVIEW sections)
<only the ones relevant to this branch>

## Resume prompt (paste into a new session or a different model)
> Read CLAUDE.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md and docs/sessions/<this file>. Verify against git and the code. Recap in 8 lines. Wait for my go.

## Session log (append-only; compress old entries)
### Session 1 — <date> — <model>
- Did: <...>
- Stopped at: <...>
### Session 2 — <date> — <model>
- Did: <...>
````

`docs/sessions/_ACTIVE.md` is a list like:

```markdown
# Active session files
- features/player-rig-and-ragdoll → docs/sessions/features-player-rig-and-ragdoll.md (IN PROGRESS)
```

## 6. End-of-session protocol

1. Update the session file (current state, done, next step, decisions, bugs, waiting-on-user).
2. Update `docs/PROJECT_STATE.md` only if something durable changed (a slice finished, a decision affecting other branches).
3. Tell the user, in at most 6 lines: what was done, what to run/commit, the exact next step, and the resume prompt. Suggest a commit message.
4. If the work should stop for a fresh session, say so.

## 7. Switching models or tools

The session file must be enough for a different model. Before the user switches, make sure the file has: the resume prompt, the exact next step, all decisions with reasons, and every open question. The new model follows section 2 (start-of-session protocol) and **verifies against the code** before trusting any claim in the file.

## 8. Retirement (when the branch is finished)

A session file is temporary. When the feature is complete and merged (or abandoned):

1. **Distill before deleting.** Move anything durable into permanent docs:
   - decisions that still matter → `PROJECT_OVERVIEW.md` or `PROJECT_STATE.md`;
   - gotchas/lessons → the "Mistakes / pitfalls" section of `PROJECT_OVERVIEW.md`;
   - contracts or numbers that changed → the overview and the tuning source.
2. Set `Status: READY TO RETIRE` and tell the user what you distilled.
3. After the user confirms, **delete the session file** and its line in `_ACTIVE.md` (git history keeps a copy), or move it to `docs/sessions/_retired/` if the user prefers.
4. Update `PROJECT_STATE.md` (branch finished, what it delivered).
5. Never leave a retired branch's session file in `_ACTIVE.md`.

## 9. Keeping context healthy in long sessions

- Prefer **short sessions per slice**: finish a slice, checkpoint, commit, start fresh. A fresh session with good files beats a 6-hour session that forgot the contracts.
- Re-read the relevant overview section before touching a contract (networking, collision, tuning).
- Do not trust your recollection of exact values; open the tuning file.
- When you notice you are unsure what was decided earlier, check the session file and say so; do not improvise a contradicting decision.
- If the user says "you're forgetting things", immediately: write a checkpoint, then re-run the start-of-session protocol.

## 10. Git note

The session file lives on the feature branch and is committed by the user with the code. It is deleted in the retirement step before or right after merging. Suggest the commit; never run it yourself.
