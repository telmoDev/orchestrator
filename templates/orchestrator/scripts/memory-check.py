#!/usr/bin/env python3
"""/sync-memory step 3: refuse a memory that git contradicts.

Fails (exit 1) on: a repeated line within a section; a PR reference that does not exist; an
In flight PRs cell that calls a PR open/draft/merged/closed when GitHub disagrees; an open PR
missing from the In flight table; a commit hash in In flight; a "done" entry in PROGRESS; a
DECISIONS entry with no Until line, or whose Until PR is merged/closed or whose Until date is past;
anything that looks like a secret or an email address; the four files over the word budget.
Warns on: PR checks skipped (no gh or no remote).
Repos come from .orchestrator/orchestrator.conf.
"""
import datetime
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MEM = os.path.join(ROOT, "memory")
FILES = ["PROJECT_STATE.md", "PROGRESS.md", "DECISIONS.md", "NEXT_STEPS.md"]


def conf():
    values = {}
    with open(os.path.join(ROOT, ".orchestrator", "orchestrator.conf")) as fh:
        for line in fh:
            m = re.match(r'\s*([A-Z_]+)=["\']?(.*?)["\']?\s*$', line)
            if m:
                values[m.group(1)] = m.group(2)
    return values


CONF = conf()
REPOS = CONF.get("REPOS", ".").split()
LABEL = {r: (os.path.basename(ROOT) if r == "." else r) for r in REPOS}
WORD_BUDGET = int(CONF.get("WORD_BUDGET", "900"))
# Values, not words: "no secrets in memory" is fine, "secret: abc123" is not.
SECRET = re.compile(
    r"((password|passwd|secret|token|api[_-]?key)\s*[:=]\s*\S"
    r"|bearer\s+[A-Za-z0-9._~+/-]{16,}"
    r"|BEGIN [A-Z ]*PRIVATE KEY"
    r"|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"
    r"|\b(?=(?:[A-Za-z+/_-]*\d){4})[A-Za-z0-9+/_-]{40,}\b)",  # long token with 4+ digits; branch names have none
    re.I,
)
GENERATED = re.compile(r"<!-- state:begin.*?<!-- state:end -->", re.S)
FENCE = re.compile(r"^```.*?^```", re.S | re.M)
INLINE = re.compile(r"`[^`\n]*`")


def prose(body):
    """The file without its code blocks (entry-shape examples), line numbers kept."""
    return FENCE.sub(lambda m: "\n" * m.group(0).count("\n"), body)


def literals_out(line):
    """The line without its inline code spans (formats and examples such as `api #12 open`)."""
    return INLINE.sub(" ", line)
REPO_WORD = re.compile(r"(?<![\w-])(" + "|".join(re.escape(LABEL[r]) for r in REPOS) + r")(?![\w-])")

errors, warnings = [], []


def prs(repo):
    path = os.path.join(ROOT, repo)
    has_remote = subprocess.run(["git", "-C", path, "remote", "get-url", "origin"], capture_output=True).returncode == 0
    if not shutil.which("gh") or not has_remote:
        return None
    res = subprocess.run(
        ["gh", "pr", "list", "--state", "all", "--limit", "200", "--json", "number,state,isDraft"],
        cwd=path, capture_output=True, text=True,
    )
    if res.returncode != 0:
        return None
    return {p["number"]: p for p in json.loads(res.stdout)}


gh = {}
for r in REPOS:
    found = prs(r)
    if found is None:
        warnings.append(f"PR checks skipped for {LABEL[r]} (no gh, no remote, or gh failed)")
    else:
        gh[LABEL[r]] = found
text = {f: open(os.path.join(MEM, f)).read() for f in FILES if os.path.exists(os.path.join(MEM, f))}


def actual(pr):
    if pr["state"] == "MERGED":
        return "merged"
    if pr["state"] == "CLOSED":
        return "closed"
    return "draft" if pr["isDraft"] else "open"


# 1. Repeated lines within one section (tables' separator rows and code fences excepted).
for f, body in text.items():
    seen = {}
    for n, line in enumerate(GENERATED.sub("", body).splitlines(), 1):
        s = line.strip()
        if s.startswith("## "):
            seen = {}
        if not s or s.startswith("|---") or s.startswith("```"):
            continue
        if s in seen:
            errors.append(f"{f}:{n}: repeats line {seen[s]}: {s[:70]}")
        else:
            seen[s] = n

# 2. Every PR reference exists in a repo named on its line (in any checked repo if none is named).
# Code blocks and inline code are examples and formats, not references.
for f, body in text.items():
    for n, line in enumerate(prose(GENERATED.sub("", body)).splitlines(), 1):
        line = literals_out(line)
        named = [r for r in sorted(set(REPO_WORD.findall(line))) if r in gh]
        where = named or list(gh)
        if not where:
            continue
        for num_s in re.findall(r"#(\d+)\b", line):
            if not any(int(num_s) in gh[r] for r in where):
                errors.append(f"{f}:{n}: #{num_s} is not a PR in {' or '.join(where)}")

# 3. In flight agrees with GitHub (each `<repo> #N <state>` exists and has that state), and covers every open PR.
state = text.get("PROJECT_STATE.md", "")
m = re.search(r"^## In flight\n(.*?)(?=^## |\Z)", GENERATED.sub("", state), re.S | re.M)
listed = {r: set() for r in gh}
if m:
    rows = [l for l in m.group(1).splitlines() if l.startswith("|") and not l.startswith("|---")]
    single = LABEL[REPOS[0]] if len(REPOS) == 1 else None
    for row in rows[1:]:
        current = single
        for tok in re.finditer(REPO_WORD.pattern + r"|#(\d+)\s*(open|draft|merged|closed)?", row):
            if tok.group(1):
                current = tok.group(1)
                continue
            if not current or current not in gh:
                continue
            num, word = int(tok.group(2)), tok.group(3)
            listed[current].add(num)
            pr = gh[current].get(num)
            if not pr:  # check 2 skips inline code, and the PRs cell is often written in it
                errors.append(f"PROJECT_STATE.md In flight: {current} #{num} is not a PR")
            elif word and word != actual(pr):
                errors.append(f"PROJECT_STATE.md In flight: {current} #{num} says '{word}', GitHub says '{actual(pr)}'")
else:
    errors.append("PROJECT_STATE.md: no '## In flight' section")
for repo, found in gh.items():
    for num, pr in found.items():
        if pr["state"] == "OPEN" and num not in listed[repo]:
            errors.append(f"PROJECT_STATE.md In flight: open PR {repo} #{num} is missing")

# 3b. In flight holds no commit hashes: they go stale on the next push, and the generated block has the branches.
if m:
    for row in m.group(1).splitlines():
        if row.startswith("|") and re.search(r"\b(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b", row):
            errors.append(f"PROJECT_STATE.md In flight: drop the commit hash, it goes stale: {row.strip()[:70]}")

# 3c. PROGRESS holds only partial tasks: a done task's record is its PR and the memory's git history.
for n, line in enumerate(prose(text.get("PROGRESS.md", "")).splitlines(), 1):
    if line.startswith("## ") and re.search(r"[—-]\s*done\b", line, re.I):
        errors.append(f"PROGRESS.md:{n}: done tasks leave PROGRESS (their PR keeps the record): {line[:70]}")

# 3d. Every DECISIONS entry is temporary and says until when; an expired one is deleted.
today = datetime.date.today().isoformat()
for entry in re.split(r"^(?=## )", prose(text.get("DECISIONS.md", "")), flags=re.M):
    if not entry.startswith("## "):
        continue
    title = entry.splitlines()[0][3:73]
    until = re.search(r"^Until:\s*(.+)$", entry, re.M | re.I)
    if not until:
        errors.append(f"DECISIONS.md '{title}': no 'Until:' line. A lasting rule goes to AGENTS.md › Workspace rules")
        continue
    u = until.group(1)
    for d in re.findall(r"\b\d{4}-\d{2}-\d{2}\b", u):
        if d < today:
            errors.append(f"DECISIONS.md '{title}': Until {d} has passed, delete the entry")
    # Only a PR whose repo is certain: named on the line, or the only repo checked.
    named = [r for r in sorted(set(REPO_WORD.findall(u))) if r in gh] or (list(gh) if len(gh) == 1 else [])
    for num_s in re.findall(r"#(\d+)\b", u):
        for r in named:
            pr = gh[r].get(int(num_s))
            if pr and actual(pr) in ("merged", "closed"):
                errors.append(f"DECISIONS.md '{title}': Until {r} #{num_s}, which is {actual(pr)}, delete the entry")

# 4. Secrets and personal data.
for f, body in text.items():
    for n, line in enumerate(body.splitlines(), 1):
        if SECRET.search(line):
            errors.append(f"{f}:{n}: looks like a secret or an email: {line.strip()[:70]}")

# 5. Size.
words = sum(len(GENERATED.sub("", b).split()) for b in text.values())
if words > WORD_BUDGET:
    errors.append(f"memory is {words} words (budget {WORD_BUDGET}): trim PROGRESS first, then DECISIONS")

for w in warnings:
    print("warn:", w)
for e in errors:
    print("FAIL:", e)
print(f"memory-check: {len(errors)} error(s), {len(warnings)} warning(s), {words} words")
sys.exit(1 if errors else 0)
