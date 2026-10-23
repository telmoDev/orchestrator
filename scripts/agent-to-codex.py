#!/usr/bin/env python3
"""Render a Claude Code agent (.claude/agents/<name>.md) as a Codex custom agent (.codex/agents/<name>.toml).

  agent-to-codex.py <agent.md> <out.toml> [trivial-model]

The body becomes developer_instructions. The name takes underscores for hyphens. The Claude model is
dropped so the spawn request picks the tier's model, except a Haiku agent (explorer), which keeps the
trivial tier's model when one is given. Claude-only keys (tools, autoCompactWindow) have no Codex
equivalent and are left out: a read-only agent stays read-only by its instructions.
"""
import re
import sys


def toml_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


src, out = sys.argv[1], sys.argv[2]
trivial = sys.argv[3] if len(sys.argv) > 3 else ""
text = open(src).read()
m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
if not m:
    sys.exit(f"agent-to-codex: {src} has no frontmatter")
meta = dict(re.findall(r"^([A-Za-z_]+):\s*(.*)$", m.group(1), re.M))
body = m.group(2).strip()
if '"""' in body:
    sys.exit(f"agent-to-codex: {src} body contains triple quotes")
lines = [
    f"# Generated from {src.split('/')[-1]} by agent-to-codex.py; change both together.",
    f"name = {toml_str(meta['name'].replace('-', '_'))}",
    f"description = {toml_str(meta['description'])}",
]
if meta.get("model") == "haiku" and trivial:
    lines.append(f"model = {toml_str(trivial)}")
lines.append('developer_instructions = """\n' + body.replace("\\", "\\\\") + '\n"""')
open(out, "w").write("\n".join(lines) + "\n")
