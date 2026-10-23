# orchestrator

The `orchestrator-setup` skill: it scaffolds an orchestration layer at the root of a multi-repo workspace
(root guide, session memory with `/sync-memory`, explorer/architect/developer agents, an outcome-driven
flow with test-first, model tiers by task size, and a pre-PR gate).

- `SKILL.md` — what the skill does and how it asks before writing.
- `scripts/scaffold.sh` — writes the templates into a workspace.
- `templates/` — the files it writes (`CLAUDE.md`, `.claude/`, `memory/`).

Install for Claude Code by linking this directory as a skill:

```bash
ln -s "$PWD" ~/.claude/skills/orchestrator-setup
```

Codex support is in progress.
