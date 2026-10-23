# orchestrator

> **Agents:** if a person gave you this link to install the orchestrator, follow [INSTALL.md](INSTALL.md) step by step.

The `orchestrator-setup` skill. It scaffolds an orchestration layer at the root of a multi-repo workspace,
for **Claude Code**, **Codex** or both, on **macOS, Linux and Windows**: one shared guide (`AGENTS.md`),
session memory with `sync-memory`, explorer/architect/developer agents, an outcome-driven flow with
test-first, model tiers by task size, and a pre-PR gate.

- `SKILL.md`: what the skill does and what it asks before writing.
- `scripts/scaffold.sh`: writes the templates into a workspace.
- `scripts/agent-to-codex.py`: renders a Claude Code agent as a Codex custom agent.
- `templates/`: the files it writes.
- `INSTALL.md`: install steps for an agent; `USAGE.md`: how a person works with the orchestrator.

## What a workspace gets

| Shared by both tools | Claude Code adapter | Codex adapter |
|---|---|---|
| `AGENTS.md` (the guide), `memory/`, `.orchestrator/` (config, checklist, scripts, hooks), `.agents/skills/` | `CLAUDE.md` (imports `AGENTS.md`), `.claude/` (settings, agents, workflow, skill copies) | `.codex/` (config, hooks, agents) |

## Requirements

- git and the GitHub CLI (`gh`), authenticated.
- bash and Python 3.8+ (3.11+ to validate the Codex TOML files).
- Windows: Git for Windows, whose Git Bash runs the scripts. For Codex, put Git's `bin` folder on `PATH`
  so `bash` resolves from its hooks. Python may be `py -3` or `python`.

## Install

Ask your agent (Claude Code or Codex), in any language:

> Install the orchestrator from https://github.com/telmoDev/orchestrator

It follows [INSTALL.md](INSTALL.md): checks your OS and prerequisites, clones the repo to
`~/orchestrator-setup`, links the skill into every tool you have (a symlink on macOS and Linux, a junction
on Windows), verifies it with `bash install.sh --check`, and explains how to work with it
([USAGE.md](USAGE.md)).

By hand:

```bash
git clone --branch v0.1.0 https://github.com/telmoDev/orchestrator.git ~/orchestrator-setup   # or the latest release
cd ~/orchestrator-setup
bash install.sh                 # both tools; or --tools claude / --tools codex
bash install.sh --check
```

Update by checking out a newer tag (`git fetch --tags && git checkout vX.Y.Z`; read `CHANGELOG.md` first);
remove with `bash install.sh --uninstall`.

## Versions

Releases follow semver and are listed in [CHANGELOG.md](CHANGELOG.md), each with what an existing
workspace needs to catch up. A workspace records its version in `.orchestrator/orchestrator.conf` ›
`TEMPLATE_VERSION`. Maintainers cut a release with `bash release.sh <version>` from a clean `main`
(notes come from *Unreleased*).
