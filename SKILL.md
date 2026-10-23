---
name: orchestrator-setup
description: Set up the orchestrator layer in a multi-repo workspace, for Claude Code, Codex or both, on macOS, Linux or Windows ("implementa la estructura de orquestador"): shared AGENTS.md guide, memory/ + sync-memory, explorer/architect/dev agents, outcome-driven flow (ODD) with test-first (TDD), model tiers by task size, pre-PR gate, token-saving settings.
---

# Set up the orchestrator structure

This sets up an orchestration layer at the root of a workspace whose application repos sit side by side
underneath it. The orchestrator plans, delegates, integrates and reports. Subagents write the application
code. One guide, `AGENTS.md`, serves both tools: Codex reads it directly and Claude Code through a
`CLAUDE.md` that imports it. Everything shared lives in `.orchestrator/` (config, checklist, scripts,
hooks), `.agents/skills/` and `memory/`; `.claude/` and `.codex/` hold only each tool's adapter.

The scaffold and the templates are in this skill's directory (`scripts/`, `templates/`). It copies them
and **never overwrites an existing file**: it reports `skip` instead. It is safe to run again. It runs on
macOS, Linux and Windows: on Windows, in Git Bash (Git for Windows), with Python 3 as `python3`, `python`
or `py -3`. It creates no symlinks.

## 1. Find the workspace and its repos

- The target is the directory the user names. If they name none, use the current working directory.
  If that directory is itself a repo inside a workspace, ask whether they meant its parent.
- Repos are the immediate subdirectories that contain `.git`. If there are none, the root itself is
  the only repo (single-repo mode, which the script detects).
- For each repo, read its `AGENTS.md`/`CLAUDE.md`/`README` if it has them, and always its manifest
  (`package.json`, `composer.json`, `pyproject.toml`, `go.mod`…) and its lint/test config. From these,
  get the stack and the commands for test, lint, format and typecheck. Many repos have no guide and no
  skills of their own. That's normal: their conventions get written at the root (step 3).
  Ask the user only for what you can't find there.
- A repo directory whose name has whitespace is refused: ask the user to rename it. Other names are
  fine: the developer agent's name is the repo name slugged (`My.API` → `my-api-dev`; `my_api_dev` in Codex).
- Ask which tools will run the orchestrator: Claude Code, Codex or both. **Default: both** (`--tools`).
- With Codex, confirm the model for each tier against what the user's account offers (`/model` in Codex).
  **Default:** trivial `gpt-6-luna`, normal `gpt-6.1-sol`, hard `gpt-6-astra` (`CODEX_TRIVIAL`,
  `CODEX_NORMAL`, `CODEX_HARD` in the environment override them).
- Ask whether the project uses a ticket system (Jira, Linear, GitHub Issues…). **Default: none.**
- Ask whether to version the orchestration layer in git. **Default: yes.** If not, pass `--no-git`.
- Ask whether the user opts into the `pre-pr-review` for large tasks (2–3 `architect` reviewers plus one
  verifier per finding; a saved workflow in Claude Code, a skill in Codex). **Default: yes.** Claude
  Code's Workflow tool needs that opt-in in the user's words, and `AGENTS.md` records it with the date.
  If not, step 3 replaces it.
- Ask whether test-first is enforced (`TDD="strict"` in `.orchestrator/orchestrator.conf`: `pre-pr-pass.sh`
  refuses a `feat`/`fix` commit with no `test` commit before it). **Default: strict.** Leave a repo with no
  test runner out of `TDD_REPOS` (all repos when empty); `off` disables the check everywhere.
- With Claude Code, ask which installed plugins and MCP servers this workspace doesn't need: they go off
  in `.claude/settings.json` › `enabledPlugins` (`"<plugin>@<marketplace>": false`). **Default: none.**
- Note which repos have CI (`.github/workflows/`, `.gitlab-ci.yml`…) and what it runs: the full suite
  stays out of local checks there.

## 2. Run the scaffold

```bash
bash <this skill's directory>/scripts/scaffold.sh [--no-git] [--tools claude,codex] <workspace-root> [repo ...]
```

With no repo arguments it uses the detected ones. It creates:

| Path | Tool | What it is |
|---|---|---|
| `AGENTS.md` | both | The guide: orchestrator role, the outcome-driven flow (outcome and criteria before delegating, test-first, the orchestrator verifies each criterion as `passed`/`failed`/`blocked`/`pending`), token budget with *Model tiers* (Claude and Codex models per tier; escalate one tier after two failures), skills, *Repo guides* for repos with no guide of their own, and *Tool mapping*: what differs between the two tools, and the platform rules. Created only if absent; otherwise the template goes to `.orchestrator/AGENTS.orchestrator.md` for you to merge |
| `memory/*.md` | both | The four memory files, empty and in their entry shape |
| `.orchestrator/orchestrator.conf` | both | `REPOS`, `BASE_BRANCHES` (from `origin/HEAD`, else `main`, else `master`; `TODO` when none), `WORD_BUDGET`, `TDD`, `TDD_REPOS`, `TDD_SINCE`, `UI_REPOS`, `CODEX_ONLY_SKILLS`; optional `GIT_WRAPPER`, `TICKET_LINE`, `ADR_DIR`, `DECISION_LOG` |
| `.orchestrator/pre-pr-checklist.md` | both | The pre-PR gate: part A mechanical (owning agent), part B content. Grows one line per review comment it missed |
| `.orchestrator/scripts/` | both | `memory-state.sh` and `memory-check.py` (write the git-derived state, refuse memory git contradicts); `pre-pr-pass.sh` (stamp the commit that passed the gate; with `TDD="strict"` it refuses a `feat`/`fix` no `test` commit precedes; `TDD_EXEMPT="<reason>"` skips it once); `push-pr.sh` (push and open the PR, refusing an unstamped HEAD, a stale base, a title over 72 characters, AI attribution and, with `TICKET_LINE`, a body without the ticket); `sync-skills.sh` (copy `.agents/skills/` into `.claude/skills/`) |
| `.orchestrator/hooks/` | both | `decision-index.sh` (one line per ADR/decision in force, from `ADR_DIR`/`DECISION_LOG`; silent while they're empty) and `session-memory.sh` (prints the memory for Codex) |
| `.agents/skills/` | both | `sync-memory`, `design-patterns`, `software-principles`, and `pre-pr-review` (Codex's version of the workflow). The one copy to edit |
| `.gitattributes` | both | Keeps scripts LF, so Git for Windows doesn't break them with CRLF |
| `CLAUDE.md` | Claude | Imports `AGENTS.md` and the two memory files |
| `.claude/settings.json` | Claude | Empty attribution, the SessionStart decision index, `autoCompactWindow: 200000`, idle compaction from 120k (`env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`), `skillListingMaxDescChars: 300`, `enabledPlugins` |
| `.claude/agents/` | Claude | `explorer` (Haiku), `architect` (Opus), `<repo-slug>-dev` (Sonnet, compacts at 150k): the source the Codex agents are rendered from |
| `.claude/workflows/pre-pr-review.js` | Claude | Saved workflow: `architect` reviewers per group of checklist items, then a Sonnet `architect` that tries to refute each finding |
| `.claude/skills/` | Claude | Copies of `.agents/skills/` except `CODEX_ONLY_SKILLS` |
| `.codex/agents/*.toml` | Codex | The same agents, rendered by `scripts/agent-to-codex.py`: no model (the spawn request picks the tier's), except `explorer` on the trivial model |
| `.codex/config.toml` | Codex | `model_auto_compact_token_limit = 200000`, `[agents]` default model (normal tier) and medium effort |
| `.codex/hooks.json` | Codex | SessionStart: the memory and the decision index |
| `.gitignore` | both | Ignores the app repos, so the root versions only the orchestration layer |

It runs `git init` at the root when the root isn't a repo yet and has subrepos. It doesn't commit.

With `--no-git` it runs no `git init` and writes no root `.gitignore`. `AGENTS.md` says the layer is
unversioned, and `orchestrator.conf` gets `ROOT_GIT="no"`, so `sync-memory` skips its commit. In
single-repo mode the new files go to the repo's `.git/info/exclude`, which is local and never
committed. The app repos still need git: the memory scripts read their commits and PRs.

## 3. Tailor what the script couldn't know

Edit the generated files. Replace every `TODO(orchestrator-setup)` marker:

- **`AGENTS.md`**: the stack per repo in the repo table and the commands block. Also "How the repos
  connect": the proxy, auth, the API contract, and where cross-repo decisions are written down.
- **`AGENTS.md` › Repo guides**: one section per repo that has no `AGENTS.md`/`CLAUDE.md` of its own.
  Fill in the stack, the layout, the conventions the code actually follows and the check commands. Take
  all of them from the code, not from assumptions. Keep each section under ~15 lines. Don't create a guide
  or skills inside the repo: the root never edits inside a repo.
- **Tickets, only if the project uses them**: add a step 0 to the feature flow in `AGENTS.md`. It
  searches for or creates the ticket, puts its key in briefs and PR bodies, and moves the ticket when the
  PR opens. Set `TICKET_LINE` in `orchestrator.conf` (e.g. `'^Jira: PROJ-[0-9]+'`) so `push-pr.sh`
  enforces it. Without a ticket system, leave the flow as it is. The memory's Ticket column then takes `—`.
- **Pre-PR gate**: in `.orchestrator/pre-pr-checklist.md` item 2, the exact local checks per repo and
  what CI runs instead. Drop item 14 if no repo has a UI; otherwise list the UI repos in `UI_REPOS`, both
  in `orchestrator.conf` and in `.claude/workflows/pre-pr-review.js`. Keep the item numbers: the
  workflow and the skill group by them. If a repo has CI that runs the full suite, add a *Test suites*
  rule to `AGENTS.md` › *Workspace rules* (locally only the tests for what changed; `gh pr checks` decides).
- **Review declined** (step 1): in `AGENTS.md` step 4, replace the `pre-pr-review` clause with "for a
  large one, `architect` reviews it against part B", and delete `.claude/workflows/` and
  `.agents/skills/pre-pr-review/`.
- **Two GitHub accounts on the machine** (plain `git push` authenticates as the wrong one): write a
  wrapper `.orchestrator/scripts/gh-git.sh <repo> <git args>` that passes the org account's
  `gh auth token` as a one-shot credential helper, and set `GIT_WRAPPER` to it. Never change git or gh config.
- **Decision index**: if a repo records ADRs or a decision log, set `ADR_DIR` and `DECISION_LOG` in
  `orchestrator.conf` and run `bash .orchestrator/hooks/decision-index.sh` once: it must print one line
  per decision in force. If the format differs (status in another place), adapt the awk in the hook.
  With no decision records, delete the hook and its SessionStart entries in `.claude/settings.json` and
  `.codex/hooks.json`.
- **Agents** (`.claude/agents/<repo>-dev.md`): stack, the files to read before coding, and the exact check
  commands for that repo, including how to run a single test (test-first needs it). `architect.md`: where
  the repos record decisions (ADRs, decision log, open questions); if they keep none, "ask the user". Then
  regenerate the Codex agents from them:
  `for f in .claude/agents/*.md; do python3 <this skill's directory>/scripts/agent-to-codex.py "$f" ".codex/agents/$(basename "${f%.md}").toml" <trivial model>; done`.
- **Model tiers**: if the repos make ~30 lines a poor line for *trivial* (generated code, large fixtures),
  adjust the table in `AGENTS.md` › *Token budget*.
- If a repo already has its own agents or skills, keep them as they are. A repo with neither uses the
  root's, which is the default case. The root never edits inside a repo. To reuse a repo's agents, render
  the Codex ones from them with `agent-to-codex.py` and point `.claude/agents` at them; a symlink works on
  macOS and Linux, but on Windows copy them, and note it in `AGENTS.md` so they're re-copied when the repo
  changes them.
- If the repos already ship `design-patterns`/`software-principles`, keep the root copies anyway.
  The orchestrator and `architect` read them from the root. In briefs, point to the repo's copy
  when one exists.
- After any edit under `.agents/skills/`, run `bash .orchestrator/scripts/sync-skills.sh`.
- **Single-repo mode** (the root is the repo): delete "How the repos connect" and the sentence about
  the root being its own git repo. The orchestration files are committed in the repo itself.

Then check `grep -rn "TODO(orchestrator-setup)" AGENTS.md .orchestrator .agents .claude .codex memory`.
It should return nothing.

## 4. Verify and hand over

1. `for f in .orchestrator/scripts/*.sh .orchestrator/hooks/*.sh; do bash -n "$f"; done && python3 -m py_compile .orchestrator/scripts/memory-check.py`
   and `bash .orchestrator/scripts/sync-skills.sh --check`. With Codex, check that `.codex/config.toml` and
   `.codex/agents/*.toml` parse (`python3 -c "import tomllib,sys; [tomllib.load(open(f,'rb')) for f in sys.argv[1:]]" .codex/*.toml .codex/agents/*.toml`,
   Python 3.11+). With Claude Code and `node` installed, check the workflow wrapped in an async function
   (it uses top-level `await` and `return`): `{ echo '(async () => {'; sed 's/^export //' .claude/workflows/pre-pr-review.js; echo '})'; } > <scratch>/wf.js && node --check <scratch>/wf.js`.
2. Run `bash .orchestrator/scripts/memory-state.sh`, then `python3 .orchestrator/scripts/memory-check.py`.
   Without `gh` or a remote they warn and skip the PR part. They must not fail.
3. Unless `--no-git` was used, ask the user before the first commit at the root:
   `git add AGENTS.md CLAUDE.md .orchestrator .agents .claude .codex memory .gitignore .gitattributes && git commit -m "chore(orchestration): set up orchestrator layer"`
   (leave out what the chosen tools didn't create). Never add a remote or push unless the user asks.
4. Report: files created, files skipped (already present), the TODOs left for the user, and how to start (`USAGE.md` in this skill's directory is the person-facing version)
   in each tool. Claude Code: open it at the workspace root; `/sync-memory` once per session; `/usage` to
   see what each skill, agent and plugin costs. Codex: trust the project, open `/hooks` once to approve
   the two SessionStart hooks, then `$sync-memory` once per session and `/status` for usage. In both,
   before each push: the gate, `bash .orchestrator/scripts/pre-pr-pass.sh`, `bash .orchestrator/scripts/push-pr.sh`.
