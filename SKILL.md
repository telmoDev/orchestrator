---
name: orchestrator-setup
description: Set up the orchestrator layer in a multi-repo workspace like gfu-sis ("implementa la estructura de orquestador"): root CLAUDE.md, memory/ + /sync-memory, explorer/architect/dev agents, outcome-driven flow (ODD) with test-first (TDD), model tiers by task size, pre-PR gate (checklist, /code-review, pre-pr-review workflow, push-pr.sh), token-saving settings.
---

# Set up the orchestrator structure

This reproduces the orchestration layer of the gfu-sis workspace in any workspace. The workspace
root holds the orchestration layer (`CLAUDE.md`, `.claude/`, `memory/`) and versions it in its own
small git repo. The application repos sit side by side underneath it. The orchestrator plans,
delegates, integrates and reports. Subagents write the application code.

Templates live in `~/.claude/skills/orchestrator-setup/templates/`. The scaffold script copies them
and **never overwrites an existing file**: it reports `skip` instead. It is safe to run again.

## 1. Find the workspace and its repos

- The target is the directory the user names. If they name none, use the current working directory.
  If that directory is itself a repo inside a workspace (as `gfu-sis/sis-api` is), ask whether they
  meant its parent.
- Repos are the immediate subdirectories that contain `.git`. If there are none, the root itself is
  the only repo (single-repo mode, which the script detects).
- For each repo, read its `CLAUDE.md`/`AGENTS.md`/`README` if it has them, and always its manifest
  (`package.json`, `composer.json`, `pyproject.toml`, `go.mod`…) and its lint/test config. From these,
  get the stack and the commands for test, lint, format and typecheck. Many repos have no `CLAUDE.md`
  and no skills of their own. That's normal: their conventions get written at the root (step 3).
  Ask the user only for what you can't find there.
- A repo directory whose name has whitespace is refused: ask the user to rename it. Other names are
  fine: the developer agent's name is the repo name slugged (`Sis.API` → `sis-api-dev`).
- Ask whether the project uses a ticket system (Jira, Linear, GitHub Issues…). **Default: none.**
- Ask whether to version the orchestration layer in git. **Default: yes.** If not, pass `--no-git`.
- Ask whether the user opts into the `pre-pr-review` workflow for large tasks (it runs 2–3 `architect`
  reviewers plus one verifier per finding). **Default: yes.** The Workflow tool needs that opt-in in the
  user's words, and `CLAUDE.md` records it with the date. If not, step 3 replaces it.
- Ask whether test-first is enforced (`TDD="strict"` in `orchestrator.conf`: `pre-pr-pass.sh` refuses a `feat`/`fix`
  commit with no `test` commit before it). **Default: strict.** Leave a repo with no test runner out of `TDD_REPOS` (all repos when
  empty); `off` disables the check everywhere.
- Ask which installed plugins and MCP servers this workspace doesn't need: they go off in
  `.claude/settings.json` › `enabledPlugins` (`"<plugin>@<marketplace>": false`). **Default: none.**
- Note which repos have CI (`.github/workflows/`, `.gitlab-ci.yml`…) and what it runs: the full suite
  stays out of local checks there.

## 2. Run the scaffold

```bash
~/.claude/skills/orchestrator-setup/scripts/scaffold.sh [--no-git] <workspace-root> [repo ...]
```

With no repo arguments it uses the detected ones. It creates:

| Path | What it is |
|---|---|
| `CLAUDE.md` | Orchestrator role, the outcome-driven flow (outcome and criteria before delegating, test-first, the orchestrator verifies each criterion as `passed`/`failed`/`blocked`/`pending`), token budget with *Model tiers* (trivial→Haiku, normal→Sonnet, hard→Opus, passed as `model` on the Agent call; escalate one tier after two failures), skills, and a *Repo guides* section for repos with no guide of their own. Created only if absent; otherwise the template goes to `.claude/CLAUDE.orchestrator.md` for you to merge |
| `memory/*.md` | The four memory files, empty and in their entry shape |
| `.claude/orchestrator.conf` | `REPOS="…"`, the repo list the scripts read; `BASE_BRANCHES="repo=branch …"`, each repo's base branch (detected from `origin/HEAD`, else `main`, else `master`; a `TODO` when none is found); `TDD` (`strict`/`off`); optional `GIT_WRAPPER`, `TICKET_LINE`, `ADR_DIR`, `DECISION_LOG` |
| `.claude/skills/sync-memory/` | `/sync-memory` |
| `.claude/skills/design-patterns/`, `.claude/skills/software-principles/` | The two design skills, for the orchestrator and every brief |
| `.claude/scripts/memory-state.sh`, `memory-check.py` | Write the git-derived state into memory, and refuse memory that git contradicts |
| `.claude/agents/explorer.md`, `architect.md`, `<repo-slug>-dev.md` | Agents: Haiku for lookups, Opus for plans and review, Sonnet to implement in each repo (each dev agent compacts at 150k, `autoCompactWindow` in its frontmatter). `CLAUDE.md` launches them with `effort: "medium"` |
| `.claude/pre-pr-checklist.md` | The pre-PR gate: part A mechanical (owning agent), part B content (orchestrator + `/code-review medium` for small tasks, the workflow for large ones). Grows one line per review comment it missed |
| `.claude/scripts/pre-pr-pass.sh`, `push-pr.sh` | Stamp the commit that passed the gate (with `TDD="strict"`, refusing a `feat`/`fix` commit that no `test` commit precedes; `TDD_EXEMPT="<reason>"` skips it once); push and open the PR, refusing an unstamped HEAD, a stale base, a title over 72 characters, AI attribution and (with `TICKET_LINE`) a body without the ticket |
| `.claude/workflows/pre-pr-review.js` | Saved workflow: `architect` reviewers per group of checklist items (on Sonnet for `tier: "normal"`, Opus otherwise; items 15–16 check the outcome and test-first), then a Sonnet `architect` that tries to refute each finding. Shows up as `/pre-pr-review` |
| `.claude/hooks/decision-index.sh` | SessionStart hook: one line per ADR/decision in force, from `ADR_DIR`/`DECISION_LOG` in `orchestrator.conf`. Silent while they're empty |
| `.claude/settings.json` | Empty commit and PR attribution, the SessionStart hook, `autoCompactWindow: 200000`, idle compaction from 120k tokens (`env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`), `skillListingMaxDescChars: 300`, `enabledPlugins` |
| `.gitignore` | Ignores the app repos, so the root versions only the orchestration layer |

It runs `git init` at the root when the root isn't a repo yet and has subrepos. It doesn't commit.

With `--no-git` it runs no `git init` and writes no root `.gitignore`. `CLAUDE.md` says the layer is
unversioned, and `orchestrator.conf` gets `ROOT_GIT="no"`, so `/sync-memory` skips its commit. In
single-repo mode the new files go to the repo's `.git/info/exclude`, which is local and never
committed. The app repos still need git: the memory scripts read their commits and PRs.

## 3. Tailor what the script couldn't know

Edit the generated files. Replace every `TODO(orchestrator-setup)` marker:

- **`CLAUDE.md`**: the stack per repo in the repo table and the commands block. Also "How the repos
  connect": the proxy, auth, the API contract, and where cross-repo decisions are written down.
- **`CLAUDE.md` › Repo guides**: one section per repo that has no `CLAUDE.md`/`AGENTS.md` of its
  own. The scaffold creates one for each such repo. Fill in the stack, the layout, the conventions
  the code actually follows and the check commands. Take all of them from the code, not from
  assumptions. Keep each section under ~15 lines. Don't create a `CLAUDE.md` or skills inside the
  repo: the root never edits inside a repo.
- **Tickets, only if the project uses them**: add a step 0 to the feature flow in `CLAUDE.md`.
  It searches for or creates the ticket, puts its key in briefs and PR bodies, and moves the
  ticket when the PR opens. Set `TICKET_LINE` in `orchestrator.conf` (e.g. `'^Jira: KAN-[0-9]+'`)
  so `push-pr.sh` enforces it. Without a ticket system, leave the flow as it is. The memory's
  Ticket column then takes `—`.
- **Pre-PR gate**: in `.claude/pre-pr-checklist.md` item 2, the exact local checks per repo and
  what CI runs instead. Drop item 14 if no repo has a UI; otherwise list the UI repos in
  `UI_REPOS` in `.claude/workflows/pre-pr-review.js`. Keep the item numbers: the workflow groups
  by them. If the repo has CI that runs the full suite, add a *Test suites* rule to `CLAUDE.md` ›
  *Workspace rules* (locally only the tests for what changed; `gh pr checks` decides).
- **Workflow declined** (step 1): in `CLAUDE.md` step 4, replace the workflow clause with "for a
  large one, `architect` reviews it against part B", and delete `.claude/workflows/`.
- **Two GitHub accounts on the machine** (plain `git push` authenticates as the wrong one): write a
  wrapper `.claude/scripts/gh-git.sh <repo> <git args>` that passes the org account's `gh auth token`
  as a one-shot credential helper, and set `GIT_WRAPPER` to it. Never change git or gh config.
- **Decision index**: if a repo records ADRs or a decision log, set `ADR_DIR` and `DECISION_LOG` in
  `orchestrator.conf` and run `.claude/hooks/decision-index.sh` once: it must print one line per
  decision in force. If the format differs (status in another place), adapt the awk in the hook.
  With no decision records, delete the hook and its `SessionStart` entry in `settings.json`.
- **`.claude/agents/<repo>-dev.md`**: stack, the files to read before coding, and the exact check
  commands for that repo, including how to run a single test (test-first needs it).
- **Model tiers**: if the repos make ~30 lines a poor line for *trivial* (generated code, large fixtures),
  adjust the table in `CLAUDE.md` › *Token budget*.
- **`.claude/agents/architect.md`**: where the repos record decisions (ADRs, decision log, open
  questions). If they keep none, say "ask the user".
- If a repo already has its own `.claude/agents/` or `.claude/skills/`, keep them as they are.
  A repo with neither uses the root's agents and skills, which is the default case. The
  root never edits inside a repo. Prefer symlinking `.claude/agents` to the repo's own agents over
  duplicating them, and delete the generated ones in that case.
- If the repos already ship `design-patterns`/`software-principles`, keep the root copies anyway.
  The orchestrator and `architect` read them from the root. In briefs, point to the repo's copy
  when one exists.

- **Single-repo mode** (the root is the repo): delete "How the repos connect" and the sentence about
  the root being its own git repo. The orchestration files are committed in the repo itself.

Then check `grep -rn "TODO(orchestrator-setup)" CLAUDE.md .claude memory`. It should return nothing.

## 4. Verify and hand over

1. `for f in .claude/scripts/*.sh .claude/hooks/*.sh; do bash -n "$f"; done && python3 -m py_compile .claude/scripts/memory-check.py`,
   and, if `node` is installed, check the workflow wrapped in an async function (it uses top-level
   `await` and `return`): `{ echo '(async () => {'; sed 's/^export //' .claude/workflows/pre-pr-review.js; echo '})'; } > <scratch>/wf.js && node --check <scratch>/wf.js`.
2. Run `.claude/scripts/memory-state.sh`, then `.claude/scripts/memory-check.py`. Without `gh` or a
   remote they warn and skip the PR part. They must not fail.
3. Unless `--no-git` was used, ask the user before the first commit at the root:
   `git add CLAUDE.md .claude memory .gitignore && git commit -m "chore(orchestration): set up orchestrator layer"`.
   Never add a remote or push unless the user asks.
4. Report: files created, files skipped (already present), the TODOs left for the user, and how to
   start: open Claude Code at the workspace root, then run `/sync-memory` once per session; before
   each push, the gate (`/code-review medium` or `/pre-pr-review`), `pre-pr-pass.sh`, `push-pr.sh`;
   and `/usage` to see what each skill, agent and plugin costs.
