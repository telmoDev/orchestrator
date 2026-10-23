#!/usr/bin/env bash
# SessionStart for tools that can't import files into their guide (Codex): print memory/NEXT_STEPS.md and
# memory/PROJECT_STATE.md as session context. Claude Code imports them from CLAUDE.md instead.
root="$(cd "$(dirname "$0")/../.." && pwd)"  # the workspace root, whichever tool runs this
text=$(for f in NEXT_STEPS PROJECT_STATE; do
  [ -f "$root/memory/$f.md" ] && { printf '<!-- memory/%s.md -->\n' "$f"; cat "$root/memory/$f.md"; echo; }
done)
[ -n "$text" ] || exit 0
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$text" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
else
  printf '%s\n' "$text"
fi
