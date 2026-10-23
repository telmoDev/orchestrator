# orchestrator

The `orchestrator-setup` skill. It scaffolds an orchestration layer at the root of a multi-repo workspace,
for **Claude Code**, **Codex** or both, on **macOS, Linux and Windows**: one shared guide (`AGENTS.md`),
session memory with `sync-memory`, explorer/architect/developer agents, an outcome-driven flow with
test-first, model tiers by task size, and a pre-PR gate.

- `SKILL.md`: what the skill does and what it asks before writing.
- `scripts/scaffold.sh`: writes the templates into a workspace.
- `scripts/agent-to-codex.py`: renders a Claude Code agent as a Codex custom agent.
- `templates/`: the files it writes.

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

```bash
git clone https://github.com/telmoDev/orchestrator.git
cd orchestrator
bash install.sh                 # both tools; or --tools claude / --tools codex
```

It links the checkout as `~/.claude/skills/orchestrator-setup` and `~/.agents/skills/orchestrator-setup`
(a symlink on macOS and Linux, a directory junction on Windows), so `git pull` updates both.
`bash install.sh --uninstall` removes the links.

Then, in either tool, ask it to set up the orchestrator ("implementa la estructura de orquestador").
