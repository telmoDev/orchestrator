#!/usr/bin/env bash
# Cut a release: VERSION, CHANGELOG section, commit, annotated tag, push, GitHub release.
#   bash release.sh <major.minor.patch> [--dry-run]
# Needs a clean main in sync with origin, and notes under "## Unreleased" in CHANGELOG.md.
# Pushes and creates the release as RELEASE_GH_USER (default telmoDev) with that account's gh token, for
# this command only: it never changes git or gh config, and never force-pushes.
set -euo pipefail
cd "$(dirname "$0")"
new="${1:?usage: bash release.sh <major.minor.patch> [--dry-run]}"; dry=no
[ "${2:-}" = "--dry-run" ] && dry=yes
user="${RELEASE_GH_USER:-telmoDev}"
fail() { echo "release: $*" >&2; exit 1; }

[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must be major.minor.patch, got $new"
cur=$(cat VERSION 2>/dev/null || echo 0.0.0)
[ "$(printf '%s\n%s\n' "$cur" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$new" ] && [ "$cur" != "$new" ] \
  || fail "$new is not above the current $cur"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "not on main"
[ -z "$(git status --porcelain)" ] || fail "working tree not clean"
git rev-parse -q --verify "refs/tags/v$new" >/dev/null && fail "tag v$new exists"
gh auth token --user "$user" >/dev/null 2>&1 || fail "gh has no token for $user (gh auth login)"
helper="!f() { test \"\$1\" = get || exit 0; echo username=$user; echo \"password=\$(gh auth token --user $user)\"; }; f"
ggit() { git -c credential.helper= -c "credential.helper=$helper" "$@"; }
ggit fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "main differs from origin/main: pull or push first"

notes=$(awk '/^## Unreleased/{on=1; next} on && /^## /{exit} on' CHANGELOG.md | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
[ -n "$notes" ] || fail "nothing under '## Unreleased' in CHANGELOG.md"
today=$(date +%F)
if [ $dry = yes ]; then echo "would release v$new ($cur -> $new) with notes:"; echo "$notes"; exit 0; fi

awk -v v="$new" -v d="$today" '/^## Unreleased/ && !done {print; print ""; print "## v" v " — " d; done=1; next} {print}' CHANGELOG.md > CHANGELOG.md.tmp
mv CHANGELOG.md.tmp CHANGELOG.md
echo "$new" > VERSION
git add VERSION CHANGELOG.md
git commit -q -m "chore(release): v$new"
git tag -a "v$new" -m "v$new"
ggit push -q origin main "v$new"
printf '%s\n' "$notes" > .release-notes.tmp
GH_TOKEN=$(gh auth token --user "$user") gh release create "v$new" --title "v$new" --notes-file .release-notes.tmp --verify-tag
rm -f .release-notes.tmp
echo "released v$new"
