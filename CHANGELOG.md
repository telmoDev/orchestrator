# Changelog

Versions follow [Semantic Versioning](https://semver.org/): a **patch** fixes, a **minor** adds without
breaking existing workspaces, a **major** needs a workspace migration. Before 1.0.0 a minor may still need
one; its *Workspaces* line says so. Each workspace records the version it was set up with in
`.orchestrator/orchestrator.conf` › `TEMPLATE_VERSION`.

Every entry has two parts: what changed, and **Workspaces**: what an agent must do to bring an existing
workspace up to this version ("nothing" when templates didn't change). `release.sh` turns *Unreleased*
into the new version's section.

## Unreleased

- `scripts/migrate.sh <workspace>` does the mechanical part of the v0.1.0 migration (moves, path
  rewrites, thin `CLAUDE.md`, new files, `.codex/`) and lists what an agent still edits by hand.

**Workspaces:** nothing.

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
