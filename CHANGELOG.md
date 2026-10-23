# Changelog

Versions follow [Semantic Versioning](https://semver.org/): a **patch** fixes, a **minor** adds without
breaking existing workspaces, a **major** needs a workspace migration. Before 1.0.0 a minor may still need
one; its *Workspaces* line says so. Each workspace records the version it was set up with in
`.orchestrator/orchestrator.conf` › `TEMPLATE_VERSION`.

Every entry has two parts: what changed, and **Workspaces**: what an agent must do to bring an existing
workspace up to this version ("nothing" when templates didn't change). `release.sh` turns *Unreleased*
into the new version's section.

## Unreleased

- Standards that agents actually apply: transcripts showed dev agents told to "read software-principles"
  never opened it. The `architect` and `*-dev` definitions now carry a short *Standards digest*; the full
  skills are opened for plans and design reviews, and agents report which skills they read.
- A leaner orchestrator, which ran on the priciest model and processed half of all tokens: one read per
  question (a second one goes to `explorer`), never a whole file, diff or log; past ~100k tokens of context it
  delegates every lookup and clears after the task's PR. Compaction at 150k (was 200k) in both tools, idle
  compaction from 100k (was 120k).

**Workspaces:** optional. Add the *Standards digest* block to `.claude/agents/architect.md` and each
`*-dev.md` (as in `templates/agents/`) and regenerate `.codex/agents/` with `agent-to-codex.py`; copy the
*Read narrowly* and *Delegate by context size* bullets and the *Compaction* row into `AGENTS.md`; set
`autoCompactWindow` to 150000 and `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` to "100000" in
`.claude/settings.json`, and `model_auto_compact_token_limit = 150000` in `.codex/config.toml`.

## v0.4.0 — 2026-10-23

- Update notice: a SessionStart hook, `.orchestrator/hooks/update-check.sh`, says when a newer orchestrator
  release is out (looked up in the background, at most once a day, so the session never waits on the
  network) and when the workspace's `TEMPLATE_VERSION` is behind the installed skill. The session tells the
  user and asks; it updates only after the user explicitly accepts, and so does `INSTALL.md`, which now
  waits for a yes before moving the clone to a new release (and a separate yes per workspace). `UPDATE_CHECK="off"` silences it; setup asks (`scaffold.sh --no-update-check`).

**Workspaces:** optional. Copy `templates/orchestrator/hooks/update-check.sh` to `.orchestrator/hooks/`, add
`UPDATE_CHECK="on"` to `orchestrator.conf`, add the hook to SessionStart in `.claude/settings.json` and
`.codex/hooks.json` (as in the templates), and the *Update notice* row and the line after *Resume* to
`AGENTS.md`. Then set `TEMPLATE_VERSION` to this version.

## v0.3.0 — 2026-10-23

- Whether to version a workspace's orchestration layer is the user's call: setup always asks, with no
  default, and `scaffold.sh` refuses to run without `--git` or `--no-git`.

**Workspaces:** nothing.

## v0.2.0 — 2026-10-23

- `scripts/migrate.sh <workspace>` does the mechanical part of the v0.1.0 migration (moves, path
  rewrites, thin `CLAUDE.md`, new files, `.codex/`) and lists what an agent still edits by hand.
- `memory-check.py` no longer reads code blocks or inline code as PR references: the example
  `api #12 open, web #7 draft` in `PROJECT_STATE.md` failed the check in any repo with a remote.
  The In flight table now checks itself that each PR it lists exists, backticks or not.

- Examples no longer name real projects: `My.API` → `my-api-dev` for agent names, `'^Jira: PROJ-[0-9]+'`
  for `TICKET_LINE`.
- Good-practice defaults, adapted to the user. The orchestrator keeps its own way of working (outcome-driven
  flow, test-first, `software-principles`, `design-patterns`, the quality checklist), which holds for any
  stack; setup reads each repo's conventions from its history and asks which defaults to keep, rewrite or
  drop. New `AGENTS.md` › *Standards* lists the skills briefs name; *Workspace rules* records the user's
  corrections and preferences as they come.
- What belongs to the user's team is no longer imposed: commit and PR title format, attribution and the way
  the base is brought in follow each repo's convention. `push-pr.sh` enforces only what `orchestrator.conf`
  sets (`TITLE_PATTERN`, `TITLE_MAX`, `ATTRIBUTION="refuse"`, `TICKET_LINE`); the template's
  `.claude/settings.json` no longer empties attribution.
- `pre-pr-pass.sh` tells test commits from code commits with `TDD_TEST_COMMIT` and `TDD_CODE_COMMIT`
  (defaults: Conventional Commits) instead of hard-coded `test`/`feat`/`fix`.
- The checklist has three parts: A mechanical (1–5), B the flow's review (6–9), C quality (10–17, the
  defaults the user adapts, where lines from reviews also go). The review workflow and skill group by part,
  so `UI_REPOS` is gone: the UI item names the repos it covers.
- Git and PR defaults, for repos with no convention of their own: Conventional Commits and `<type>/<topic>`
  branches; one logical change per commit, no secrets, `.env`, build output or local config, no rewriting
  history pushed for review; one small topic per PR (stacked when large), the repo's PR template, why rather
  than what, `Closes #N`, a draft while a criterion is `pending`, reviewers from the repo's own rules. New
  checklist item 3 (clean diff).
- The guide, agents and checklist speak of contracts, interfaces and data shapes, not endpoints and payloads.

**Workspaces:** copy `templates/orchestrator/scripts/memory-check.py` over `.orchestrator/scripts/memory-check.py`.
The rest is optional; a workspace keeps working with its current files. To adopt it, copy `pre-pr-pass.sh`
and `push-pr.sh` together with these lines in `orchestrator.conf`: `TDD_TEST_COMMIT='^test(\(|:|!)'`,
`TDD_CODE_COMMIT='^(feat|fix)(\(|:|!)'`, and, to keep the old checks, `TITLE_MAX=72` and `ATTRIBUTION="refuse"`.
Copy the checklist, `.claude/workflows/pre-pr-review.js` and `.agents/skills/pre-pr-review/` together (they
share the numbering), moving the workspace's own review lines into part C. Add the *Standards* section to
`AGENTS.md` listing the standard skills the workspace already has.

## v0.1.0 — 2026-10-23

First release. The skill, until now kept in `~/.claude/skills/orchestrator-setup`, is shared by Claude
Code and Codex and runs on macOS, Linux and Windows.

- One guide, `AGENTS.md`, read by Codex directly and by Claude Code through `CLAUDE.md`. Shared files in
  `.orchestrator/` (config, checklist, scripts, hooks), `.agents/skills/` and `memory/`; `.claude/` and
  `.codex/` are thin adapters, and `AGENTS.md` › *Tool mapping* lists what differs.
- Outcome-driven flow (goal, outcome, criteria O1… verified by the orchestrator as
  `passed`/`failed`/`blocked`/`pending`), test-first enforced by `pre-pr-pass.sh` (`TDD`, `TDD_REPOS`,
  `TDD_SINCE`, `TDD_EXEMPT`), and model tiers (trivial/normal/hard) per tool.
- Codex: custom agents rendered from the Claude ones (`scripts/agent-to-codex.py`), `$pre-pr-review`
  skill mirroring the Claude workflow, SessionStart hooks for the memory and the decision index,
  `.codex/config.toml` with compaction and subagent defaults.
- Cross-platform: no symlinks in a workspace (`sync-skills.sh` copies skills), scripts called as
  `bash`/`python3`, `.gitattributes` keeps them LF, native `C:/` paths under Git Bash.
- `TDD_SINCE` with a bare date now means its midnight (git read it as that day at the current time, so
  the check skipped every commit made earlier that day); `HH:MM` accepted.
- `pre-pr-review` reviewers use the normal-tier model for any tier but hard.
- Briefs spell out the test-first commits; `WORD_BUDGET` 900 → 1200 to fit outcome and cost lines.
- Install by an agent from the repo link (`INSTALL.md`), `install.sh` with `--check` and
  `--uninstall` (symlink on macOS/Linux, junction on Windows), and `USAGE.md` for the person.

**Workspaces:** a workspace set up before this release has everything under `.claude/` (no
`TEMPLATE_VERSION`). To migrate: run `bash scripts/migrate.sh <workspace>` (from v0.1.1 on), or by hand: move `.claude/orchestrator.conf`, `pre-pr-checklist.md`, `scripts/` and
`hooks/` to `.orchestrator/`; move the root skills to `.agents/skills/` and run `sync-skills.sh`; turn
`CLAUDE.md` into `AGENTS.md` plus the thin `CLAUDE.md` (keep the workspace's own sections); update the
paths in settings, workflow, checklist and skills; add `.gitattributes`, `TEMPLATE_VERSION="0.1.0"`, and
`.codex/` if the workspace will use Codex. Check with step 4 of `SKILL.md`.
