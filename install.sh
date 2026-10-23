#!/usr/bin/env bash
# Install the orchestrator-setup skill for Claude Code (~/.claude/skills) and Codex (~/.agents/skills) by
# linking both to this checkout, so a `git pull` here updates both tools.
#   bash install.sh [--tools claude,codex] [--uninstall | --check]
# --check: report, for each tool, whether the skill is linked to this checkout (exit 1 if not), and the prerequisites.
# macOS and Linux get a symlink. Windows (Git Bash) gets a directory junction, which needs no admin rights
# or developer mode. An existing directory that is not a link is never touched.
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
tools="claude,codex" uninstall=no check=no
while [ $# -gt 0 ]; do
  case "$1" in
    --tools) tools="${2:?--tools needs claude, codex or claude,codex}"; shift 2 ;;
    --uninstall) uninstall=yes; shift ;;
    --check) check=yes; shift ;;
    *) echo "usage: bash install.sh [--tools claude,codex] [--uninstall | --check]" >&2; exit 2 ;;
  esac
done
windows=no; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) windows=yes ;; esac
winpath() { (cd "$1" && pwd -W) | sed 's#/#\\#g'; }

is_link() { # a symlink, or on Windows a junction
  [ -L "$1" ] && return 0
  [ $windows = yes ] && [ -d "$1" ] && cmd //c "fsutil reparsepoint query \"$(winpath "$1")\"" >/dev/null 2>&1
}

if [ $check = yes ]; then
  status=0
  for t in ${tools//,/ }; do
    case "$t" in claude) dst="$HOME/.claude/skills/orchestrator-setup" ;; codex) dst="$HOME/.agents/skills/orchestrator-setup" ;; *) echo "install: unknown tool $t" >&2; exit 2 ;; esac
    if is_link "$dst" && [ -f "$dst/SKILL.md" ] && [ "$(cd "$dst" && pwd -P)" = "$(cd "$src" && pwd -P)" ]; then echo "ok      $t: $dst"; else echo "missing $t: $dst"; status=1; fi
  done
  for c in git gh perl; do command -v $c >/dev/null 2>&1 && echo "ok      $c" || { echo "missing $c"; status=1; }; done
  py=""; for c in python3 python "py -3"; do $c -c 'import sys; sys.exit(sys.version_info < (3, 8))' >/dev/null 2>&1 && { py=$c; break; }; done
  [ -n "$py" ] && echo "ok      python ($py)" || { echo "missing python 3.8+"; status=1; }
  gh auth status >/dev/null 2>&1 && echo "ok      gh authenticated" || { echo "missing gh login (gh auth login)"; status=1; }
  command -v jq >/dev/null 2>&1 && echo "ok      jq" || echo "note    jq not found: hooks print plain text instead of JSON (works in both tools)"
  exit $status
fi

for t in ${tools//,/ }; do
  case "$t" in
    claude) dir="$HOME/.claude/skills" ;;
    codex) dir="$HOME/.agents/skills" ;;
    *) echo "install: unknown tool $t" >&2; exit 2 ;;
  esac
  dst="$dir/orchestrator-setup"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    is_link "$dst" || { echo "install: $dst exists and is not a link; move it away first" >&2; exit 1; }
    if [ $windows = yes ] && [ ! -L "$dst" ]; then cmd //c "rmdir \"$(winpath "$dst")\"" >/dev/null; else rm "$dst"; fi
  fi
  [ $uninstall = yes ] && { echo "removed $dst"; continue; }
  mkdir -p "$dir"
  if [ $windows = yes ]; then
    cmd //c "mklink /J \"$(winpath "$dir")\\orchestrator-setup\" \"$(winpath "$src")\"" >/dev/null
  else
    ln -s "$src" "$dst"
  fi
  echo "linked $dst -> $src"
done
