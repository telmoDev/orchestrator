#!/usr/bin/env bash
# Scaffold the orchestrator layer (CLAUDE.md, memory/, .claude/) into a workspace root.
#   scaffold.sh [--no-git] <workspace-root> [repo ...]
# --no-git: don't version the orchestration layer (no git init, no .gitignore at the root; in
#           single-repo mode its files go to .git/info/exclude instead of being committed).
# Repos default to the immediate subdirectories holding .git; if none, the root itself (".").
# A repo name with whitespace is refused. Agent names are the repo name slugged (Sis.API -> sis-api-dev).
# Each repo's base branch (origin/HEAD, else main, else master) goes to BASE_BRANCHES in orchestrator.conf.
# Never overwrites: an existing file is reported as "skip".
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tpl="$here/templates"
root_git=yes
[ "${1:-}" = "--no-git" ] && { root_git=no; shift; }
root="$(cd "${1:?usage: scaffold.sh [--no-git] <workspace-root> [repo ...]}" && pwd)"; shift

if [ $# -gt 0 ]; then
  repos=("$@")
else
  repos=()
  for d in "$root"/*/; do [ -e "$d.git" ] && repos+=("$(basename "$d")"); done
  [ ${#repos[@]} -gt 0 ] || repos=(".")
fi
for r in "${repos[@]}"; do
  [ -d "$root/$r" ] || { echo "scaffold: no directory $root/$r" >&2; exit 2; }
  case "$r" in *[[:space:]]*) echo "scaffold: repo name '$r' has whitespace; rename the directory first" >&2; exit 2 ;; esac
done

agent_of() { # the developer agent's name: lowercase letters, digits and hyphens only
  [ "$1" = "." ] && { echo dev; return; }
  local s; s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
  echo "${s:-repo}-dev"
}
base_of() { # the repo's base branch, or empty when none can be found
  local d="$root/$1" b
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || return 0
  b=$(git -C "$d" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "${b#origin/}"; return; }
  for b in main master; do git -C "$d" rev-parse -q --verify "refs/heads/$b" >/dev/null && { echo "$b"; return; }; done
  return 0
}
agents=" "; bases=""
for r in "${repos[@]}"; do
  a=$(agent_of "$r")
  case "$agents" in *" $a "*) echo "scaffold: two repos map to the agent name '$a'; rename one directory" >&2; exit 2 ;; esac
  agents+="$a "
  b=$(base_of "$r"); bases+="$r=${b:-TODO(orchestrator-setup)} "
done
bases="${bases% }"
base_for() { local kv; for kv in $bases; do [ "${kv%%=*}" = "$1" ] && { echo "${kv#*=}"; return; }; done; return 0; }

name="$(basename "$root")"
repo_list="${repos[*]}"
repo_rows=""; dev_rows=""; repo_sections=""
guide_of() { # the guide a repo's agent reads: its own CLAUDE.md/AGENTS.md, or its section at the root
  local r=$1
  for g in CLAUDE.md AGENTS.md; do
    [ "$r" != "." ] && [ -f "$root/$r/$g" ] && { echo "\`$root/$r/$g\`"; return; }
  done
  echo "its section under *Repo guides* in \`$root/CLAUDE.md\` (it has no CLAUDE.md of its own)"
}
for r in "${repos[@]}"; do
  label=$([ "$r" = "." ] && echo "$name (root)" || echo "$r")
  agent=$(agent_of "$r")
  if [ "$r" != "." ] && { [ -f "$root/$r/CLAUDE.md" ] || [ -f "$root/$r/AGENTS.md" ]; }; then
    own=$([ -f "$root/$r/CLAUDE.md" ] && echo CLAUDE.md || echo AGENTS.md)
    guide="\`$r/$own\`"
  else
    guide="*Repo guides* › \`$label\` below"
    repo_sections+="### \`$label\`"$'\n\n'"- Stack: TODO(orchestrator-setup)"$'\n'"- Layout: TODO(orchestrator-setup): where routes, domain logic, UI or tests live"$'\n'"- Conventions: TODO(orchestrator-setup): naming, error handling, state, styling (only what the code shows)"$'\n'"- Checks: TODO(orchestrator-setup): test, lint, format, typecheck commands"$'\n'
  fi
  repo_rows+="| \`$label\` | TODO(orchestrator-setup): stack | \`$(base_for "$r")\` | $guide |"$'\n'
  dev_rows+="| \`$agent\` | Sonnet (Haiku or Opus by tier) | test-first implementation in \`$label\` |"$'\n'
done
[ -n "$repo_sections" ] || repo_sections="All repos have their own guide."$'\n'
if [ "$root_git" = yes ]; then
  root_vcs="The root is its own small git repo. It ignores the app repos and versions only the orchestration layer (\`CLAUDE.md\`, \`.claude/\`, \`memory/\`)."
else
  root_vcs="The orchestration layer (\`CLAUDE.md\`, \`.claude/\`, \`memory/\`) is not versioned: never run git at the root and never commit it to a repo."
fi

created=(); skipped=()
render() { # render <template> <dest> [repo]
  local src=$1 dest=$2 repo=${3:-}
  if [ -e "$dest" ] || [ -L "$dest" ]; then skipped+=("${dest#$root/}"); return; fi
  mkdir -p "$(dirname "$dest")"
  local guide="" agent="" base=""
  [ -n "$repo" ] && { guide="$(guide_of "$repo")"; agent="$(agent_of "$repo")"; base="$(base_for "$repo")"; }
  ROOT="$root" NAME="$name" REPOS="$repo_list" REPO="$repo" REPO_GUIDE="$guide" AGENT="$agent" BASE="$base" BASES="$bases" \
  REPO_ROWS="$repo_rows" DEV_ROWS="$dev_rows" REPO_SECTIONS="$repo_sections" DATE="$(date +%F)" \
  ROOT_GIT="$root_git" ROOT_VCS="$root_vcs" \
    perl -pe 's/\{\{(ROOT|NAME|REPOS|REPO_GUIDE|REPO_SECTIONS|REPO_ROWS|DEV_ROWS|REPO|AGENT|BASES|BASE|DATE|ROOT_GIT|ROOT_VCS)\}\}/$ENV{$1}/g' "$src" >"$dest"
  case "$dest" in *.sh|*.py) chmod +x "$dest" ;; esac
  created+=("${dest#$root/}")
}

# CLAUDE.md: never merged automatically.
if [ -e "$root/CLAUDE.md" ]; then
  render "$tpl/CLAUDE.md" "$root/.claude/CLAUDE.orchestrator.md"
  echo "note: CLAUDE.md exists; merge .claude/CLAUDE.orchestrator.md into it by hand"
else
  render "$tpl/CLAUDE.md" "$root/CLAUDE.md"
fi
[ "$root_git" = yes ] && render "$tpl/gitignore" "$root/.gitignore"
for f in "$tpl"/memory/*.md; do render "$f" "$root/memory/$(basename "$f")"; done
render "$tpl/claude/settings.json" "$root/.claude/settings.json"
render "$tpl/claude/orchestrator.conf" "$root/.claude/orchestrator.conf"
for s in sync-memory design-patterns software-principles; do
  render "$tpl/claude/skills/$s/SKILL.md" "$root/.claude/skills/$s/SKILL.md"
done
render "$tpl/claude/scripts/memory-state.sh" "$root/.claude/scripts/memory-state.sh"
render "$tpl/claude/scripts/memory-check.py" "$root/.claude/scripts/memory-check.py"
# Pre-PR gate (checklist, stamp, push, review workflow) and the SessionStart decision index.
render "$tpl/claude/pre-pr-checklist.md" "$root/.claude/pre-pr-checklist.md"
render "$tpl/claude/scripts/pre-pr-pass.sh" "$root/.claude/scripts/pre-pr-pass.sh"
render "$tpl/claude/scripts/push-pr.sh" "$root/.claude/scripts/push-pr.sh"
render "$tpl/claude/workflows/pre-pr-review.js" "$root/.claude/workflows/pre-pr-review.js"
render "$tpl/claude/hooks/decision-index.sh" "$root/.claude/hooks/decision-index.sh"
if [ -L "$root/.claude/agents" ]; then
  skipped+=(".claude/agents (symlink, left as is)")
else
  render "$tpl/claude/agents/explorer.md" "$root/.claude/agents/explorer.md"
  render "$tpl/claude/agents/architect.md" "$root/.claude/agents/architect.md"
  for r in "${repos[@]}"; do
    agent=$(agent_of "$r")
    render "$tpl/claude/agents/developer.md" "$root/.claude/agents/$agent.md" "$r"
  done
fi

# The root versions only the orchestration layer: ignore each subrepo.
if [ "$root_git" = no ]; then
  # Single-repo mode: keep the unversioned layer out of the repo's status, locally only.
  if [ "$repo_list" = "." ] && [ -d "$root/.git" ]; then
    ex="$root/.git/info/exclude"; mkdir -p "$(dirname "$ex")"; touch "$ex"
    for f in "${created[@]+"${created[@]}"}"; do grep -qxF "/$f" "$ex" || echo "/$f" >>"$ex"; done
    echo "excluded the new orchestration files in .git/info/exclude"
  fi
elif [ "$repo_list" != "." ] && [ -f "$root/.gitignore" ]; then
  for r in "${repos[@]}"; do grep -qxF "/$r/" "$root/.gitignore" || echo "/$r/" >>"$root/.gitignore"; done
  [ -d "$root/.git" ] || { git -C "$root" init -q && echo "git init at $root"; }
fi

echo "repos: $repo_list"
echo "base branches: $bases"
for f in "${created[@]+"${created[@]}"}"; do echo "create $f"; done
for f in "${skipped[@]+"${skipped[@]}"}"; do echo "skip   $f"; done
echo "next: replace every TODO(orchestrator-setup) marker (grep -rn 'TODO(orchestrator-setup)' $root/CLAUDE.md $root/.claude)"
