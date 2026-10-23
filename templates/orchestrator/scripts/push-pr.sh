#!/usr/bin/env bash
# Push a branch an agent committed locally and open its pull request, in one deterministic step.
#   .orchestrator/scripts/push-pr.sh <repo> <branch> <base> <title> <body-file> [--draft] [--reviewer <login>]
# Refuses (AGENTS.md flow step 4, .orchestrator/pre-pr-checklist.md): a push to a base branch, AI attribution in the
# body or the commits, a body without TICKET_LINE (when orchestrator.conf sets one), a title over 72 characters,
# a branch that does not contain origin/<base>, and a HEAD the pre-PR gate has not stamped (pre-pr-pass.sh).
# Git runs through GIT_WRAPPER when orchestrator.conf sets one. If the branch already has an open PR, it only
# pushes and prints that PR's URL. It never merges and never force-pushes.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"  # the workspace root, whichever tool runs this
. "$root/.orchestrator/orchestrator.conf"
usage="usage: push-pr.sh <repo> <branch> <base> <title> <body-file> [--draft] [--reviewer <login>]"
[ $# -ge 5 ] || { echo "$usage" >&2; exit 2; }
repo=$1 branch=$2 base=$3 title=$4 body=$5; shift 5
extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --draft) extra+=(--draft); shift ;;
    --reviewer) extra+=(--reviewer "${2:?--reviewer needs a login}"); shift 2 ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done

fail() { echo "push-pr: $*" >&2; exit 1; }
rgit() { if [ -n "${GIT_WRAPPER:-}" ]; then bash "$root/$GIT_WRAPPER" "$repo" "$@"; else git -C "$root/$repo" "$@"; fi; }
case " $REPOS " in *" $repo "*) ;; *) fail "repo must be one of: $REPOS" ;; esac
for kv in ${BASE_BRANCHES:-}; do [ "${kv%%=*}" = "$repo" ] && [ "${kv#*=}" = "$branch" ] && fail "refusing to push the base branch $branch"; done
case "$branch" in main|master) fail "refusing to push $branch" ;; esac
[ -f "$body" ] || fail "body file not found: $body"
[ -z "${TICKET_LINE:-}" ] || grep -Eq "$TICKET_LINE" "$body" || fail "body has no line matching $TICKET_LINE"
grep -Eiq 'co-authored-by|generated with|claude\.ai/code|🤖' "$body" && fail "body carries AI attribution"
git -C "$root/$repo" rev-parse --verify -q "refs/heads/$branch" >/dev/null || fail "no local branch $branch in $repo"
[ ${#title} -le 72 ] || fail "title is ${#title} characters, over 72"

rgit fetch -q origin "$base"
git -C "$root/$repo" log --format=%B "origin/$base..$branch" | grep -Eiq 'co-authored-by|generated with' \
  && fail "a commit on $branch carries AI attribution"
git -C "$root/$repo" merge-base --is-ancestor "origin/$base" "$branch" \
  || fail "$branch does not contain origin/$base: merge the base in (no rebase) and re-run the gate"
stamp="$root/.orchestrator/tmp/pre-pr/${repo//\//_}--${branch//\//_}"
head=$(git -C "$root/$repo" rev-parse "refs/heads/$branch")
[ -f "$stamp" ] && [ "$(cat "$stamp")" = "$head" ] \
  || fail "the pre-PR gate has not passed on $branch at ${head:0:7} (.orchestrator/pre-pr-checklist.md, then pre-pr-pass.sh)"

rgit push -u origin "$branch"

cd "$root/$repo"
existing=$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty')
if [ -n "$existing" ]; then echo "$existing"; exit 0; fi
gh pr create --base "$base" --head "$branch" --title "$title" --body-file "$body" ${extra[@]+"${extra[@]}"}
