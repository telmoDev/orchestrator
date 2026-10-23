#!/usr/bin/env bash
# Migrate a workspace set up before v0.1.0 (everything under .claude/) to the shared layout: AGENTS.md,
# .orchestrator/, .agents/skills/, and the thin .claude/ and .codex/ adapters (CHANGELOG.md › v0.1.0).
#   bash migrate.sh [--tools claude,codex] <workspace-root>
# Does the mechanical part only, and keeps every workspace-specific file and rule:
#   - moves .claude/{orchestrator.conf,pre-pr-checklist.md,scripts,hooks,tmp,briefs} to .orchestrator/
#   - moves the root's own skills (.claude/skills/<name>, not symlinks) to .agents/skills/, then copies them
#     back with sync-skills.sh
#   - renames CLAUDE.md to AGENTS.md (its @memory imports move to a new thin CLAUDE.md)
#   - rewrites the moved paths in the root's files, never inside an app repo or a symlinked folder
#   - adds .gitattributes, sync-skills.sh, session-memory.sh, the pre-pr-review skill, TEMPLATE_VERSION and,
#     with codex, .codex/ (agents rendered from .claude/agents)
# Then it prints what an agent still has to do by hand (tool-neutral wording, Tool mapping, checks).
# Refuses a workspace already migrated, and a root git repo with uncommitted changes. Never commits.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tpl="$here/templates"
tools="claude,codex"
[ "${1:-}" = "--tools" ] && { tools="${2:?--tools needs claude, codex or claude,codex}"; shift 2; }
root="$(cd "${1:?usage: migrate.sh [--tools claude,codex] <workspace-root>}" && pwd)"
has() { case ",$tools," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
fail() { echo "migrate: $*" >&2; exit 1; }
root_shown=$(cd "$root" && { pwd -W 2>/dev/null || pwd; })
version=$(cat "$here/VERSION" 2>/dev/null || echo unreleased)
codex_trivial="${CODEX_TRIVIAL:-gpt-6-luna}" codex_normal="${CODEX_NORMAL:-gpt-6.1-sol}"
py=""; for c in python3 python "py -3"; do $c -c 'import sys; sys.exit(sys.version_info < (3, 8))' >/dev/null 2>&1 && { py=$c; break; }; done
[ -n "$py" ] || fail "Python 3.8+ not found (python3, python or py -3)"

[ -f "$root/.claude/orchestrator.conf" ] || fail "no .claude/orchestrator.conf: not a pre-0.1.0 workspace"
[ ! -e "$root/.orchestrator" ] || fail ".orchestrator/ exists: already migrated"
git_root=no
if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1 && [ "$(git -C "$root" rev-parse --show-toplevel)" = "$(cd "$root" && pwd -P)" ]; then
  git_root=yes
  [ -z "$(git -C "$root" status --porcelain)" ] || fail "the root repo has uncommitted changes: commit or stash them first"
fi
mv_() { # move, through git when the source is tracked
  mkdir -p "$(dirname "$root/$2")"
  if [ $git_root = yes ] && [ -n "$(git -C "$root" ls-files -- "$1" | head -1)" ]; then git -C "$root" mv "$1" "$2"
  else mv "$root/$1" "$root/$2"; fi
}
done_=()

# 1. Shared files out of .claude/.
for p in orchestrator.conf pre-pr-checklist.md scripts hooks tmp briefs; do
  [ -e "$root/.claude/$p" ] && { mv_ ".claude/$p" ".orchestrator/$p"; done_+=("moved .claude/$p -> .orchestrator/$p"); }
done
moved_skills=()
if [ -d "$root/.claude/skills" ] && [ ! -L "$root/.claude/skills" ]; then
  for d in "$root"/.claude/skills/*/; do
    [ -d "$d" ] || continue; s=$(basename "$d")
    [ -L "${d%/}" ] && continue
    mv_ ".claude/skills/$s" ".agents/skills/$s"; moved_skills+=("$s"); done_+=("moved .claude/skills/$s -> .agents/skills/$s")
  done
fi

# 2. The guide: CLAUDE.md becomes AGENTS.md; the imports go to a thin CLAUDE.md.
if [ -f "$root/CLAUDE.md" ] && [ ! -e "$root/AGENTS.md" ]; then
  mv_ CLAUDE.md AGENTS.md
  $py - "$root/AGENTS.md" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"\A# CLAUDE\.md\n", "# AGENTS.md\n", s)
s = re.sub(r"^The next steps and the current state load with this file:\n\n(?:@memory/\S+\n)+",
           "`NEXT_STEPS.md` and `PROJECT_STATE.md` load at session start (Claude Code imports them from `CLAUDE.md`; "
           "Codex prints them from a SessionStart hook). If they are not in your context, read both first.\n", s, flags=re.M)
s = re.sub(r"^@memory/\S+\n", "", s, flags=re.M)
open(p, "w").write(s)
EOF
  cp "$tpl/CLAUDE.md" "$root/CLAUDE.md"; done_+=("CLAUDE.md -> AGENTS.md; new thin CLAUDE.md imports it and the memory")
fi

# 3. Rewrite the moved paths in the root's own files (never in app repos or symlinked folders).
files=()
while IFS= read -r f; do files+=("$f"); done < <(
  cd "$root"
  for p in AGENTS.md .gitignore .orchestrator .agents .claude/settings.json .claude/workflows memory; do
    [ -e "$p" ] && find "$p" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.json' -o -name '*.conf' -o -name '.gitignore' \) -not -path '.orchestrator/tmp/*'
  done
  [ -d .claude/agents ] && [ ! -L .claude/agents ] && find .claude/agents -type f -name '*.md'
)
skills_re=$(IFS='|'; echo "${moved_skills[*]:-}")
[ ${#files[@]} -gt 0 ] && (cd "$root" && ROOTP="$root_shown" ROOTR="$root" SKILLS="$skills_re" perl -pi -e '
  BEGIN { $g = q{(?<![\w.-]/)(?<![\w-])} }
  for my $r ($ENV{ROOTP}, $ENV{ROOTR}) { s{\Q$r\E/\.claude/skills/}{$ENV{ROOTP}/.agents/skills/}g; s{\Q$r\E/\.claude/(scripts|hooks|tmp|briefs|orchestrator\.conf|pre-pr-checklist\.md)}{$ENV{ROOTP}/.orchestrator/$1}g; }
  s{(\$\w+|\$\{\w+\})/\.claude/(scripts|hooks|tmp|briefs|orchestrator\.conf|pre-pr-checklist\.md)}{$1/.orchestrator/$2}g;
  s{$g\.claude/(scripts|hooks|tmp|briefs|orchestrator\.conf|pre-pr-checklist\.md)}{.orchestrator/$1}g;
  if ($ENV{SKILLS} ne "") { s{(\$\w+|\$\{\w+\})/\.claude/skills/($ENV{SKILLS})\b}{$1/.agents/skills/$2}g; s{$g\.claude/skills/($ENV{SKILLS})\b}{.agents/skills/$1}g; }
  s{\$\{CLAUDE_PROJECT_DIR:-\$\(cd "\$\(dirname "\$0"\)/\.\./\.\." && pwd\)\}}{\$(cd "\$(dirname "\$0")/../.." && pwd)}g if $ARGV =~ m{^\.orchestrator/};
  s{\$\{CLAUDE_PROJECT_DIR:-\$PWD\}}{\$(cd "\$(dirname "\$0")/../.." && pwd)}g if $ARGV =~ m{^\.orchestrator/.*\.sh$};
  s{os\.environ\.get\("CLAUDE_PROJECT_DIR"\) or }{}g;
  s{os\.path\.join\(ROOT, "\.claude", "orchestrator\.conf"\)}{os.path.join(ROOT, ".orchestrator", "orchestrator.conf")}g;
  s{then "\$root/\$GIT_WRAPPER"}{then bash "\$root/\$GIT_WRAPPER"}g;
  s{"command": "\\"(\$\{CLAUDE_PROJECT_DIR:-\$PWD\}/\.orchestrator/hooks/)}{"command": "bash \\"$1}g;
' "${files[@]}") && done_+=("rewrote the moved paths in ${#files[@]} root files")

# 4. What the old layout lacks.
add() { # add <template> <dest>: never overwrites
  [ -e "$root/$2" ] && return 0
  mkdir -p "$(dirname "$root/$2")"
  ROOT="$root_shown" CODEX_NORMAL="$codex_normal" perl -pe 's/\{\{(ROOT|CODEX_NORMAL)\}\}/$ENV{$1}/g' "$1" > "$root/$2"
  case "$2" in *.sh|*.py) chmod +x "$root/$2" ;; esac
  done_+=("added $2")
}
add "$tpl/gitattributes" .gitattributes
add "$tpl/orchestrator/scripts/sync-skills.sh" .orchestrator/scripts/sync-skills.sh
add "$tpl/orchestrator/hooks/session-memory.sh" .orchestrator/hooks/session-memory.sh
add "$tpl/skills/pre-pr-review/SKILL.md" .agents/skills/pre-pr-review/SKILL.md
conf="$root/.orchestrator/orchestrator.conf"
grep -q '^TEMPLATE_VERSION=' "$conf" || printf '%s\n' \
  "# The orchestrator-setup release this workspace was last migrated or updated with (see the skill's CHANGELOG.md)." \
  "TEMPLATE_VERSION=\"$version\"" >> "$conf"
grep -q '^CODEX_ONLY_SKILLS=' "$conf" || printf '%s\n' \
  "# Skills in .agents/skills that sync-skills.sh does not copy to .claude/skills (Claude Code has its own equivalent)." \
  'CODEX_ONLY_SKILLS="pre-pr-review"' >> "$conf"
done_+=("orchestrator.conf: TEMPLATE_VERSION=$version, CODEX_ONLY_SKILLS")
if has claude; then
  bash "$root/.orchestrator/scripts/sync-skills.sh" >/dev/null && done_+=("copied .agents/skills/ into .claude/skills/")
fi
if has codex; then
  add "$tpl/codex/config.toml" .codex/config.toml
  if [ ! -e "$root/.codex/hooks.json" ]; then
    $py - "$tpl/codex/hooks.json" "$root/.codex/hooks.json" "$([ -f "$root/.orchestrator/hooks/decision-index.sh" ] && echo yes || echo no)" <<'EOF'
import json, sys
src, dst, with_index = sys.argv[1:]
d = json.load(open(src))
if with_index != "yes":
    for group in d["hooks"]["SessionStart"]:
        group["hooks"] = [h for h in group["hooks"] if "decision-index" not in h["command"]]
open(dst, "w").write(json.dumps(d, indent=2) + "\n")
EOF
    done_+=("added .codex/hooks.json")
  fi
  for md in "$root"/.claude/agents/*.md; do
    [ -e "$md" ] || continue
    out=".codex/agents/$(basename "${md%.md}").toml"
    [ -e "$root/$out" ] && continue
    mkdir -p "$root/.codex/agents"; $py "$here/scripts/agent-to-codex.py" "$md" "$root/$out" "$codex_trivial"; done_+=("added $out")
  done
fi
if [ -f "$root/.gitignore" ] && ! grep -qxF '.orchestrator/tmp/' "$root/.gitignore"; then
  printf '%s\n' '.orchestrator/tmp/' >> "$root/.gitignore"; done_+=(".gitignore: .orchestrator/tmp/")
fi
if [ -f "$root/.gitignore" ] && ! grep -qxF '__pycache__/' "$root/.gitignore"; then printf '%s\n' '__pycache__/' >> "$root/.gitignore"; fi

for l in "${done_[@]}"; do echo "done   $l"; done
left=$(cd "$root" && grep -rlE '(^|[^\w./-])\.claude/(scripts|hooks|tmp|briefs|orchestrator\.conf|pre-pr-checklist\.md)' AGENTS.md .orchestrator .agents memory 2>/dev/null | grep -v '^\.orchestrator/tmp/' || true)
[ -z "$left" ] || { echo "check  old paths still named in:"; printf '         %s\n' $left; }
cat <<EOF
todo   AGENTS.md: make the wording tool-neutral (Agent tool, SendMessage, /code-review, /usage, model names)
       and add the *Tool mapping* section from $tpl/AGENTS.md, adapted to this workspace.
todo   .agents/skills/pre-pr-review: match its groups to .claude/workflows/pre-pr-review.js and the checklist.
todo   regenerate .codex/agents when .claude/agents change.
todo   verify (SKILL.md step 4), then commit at the root.
EOF
