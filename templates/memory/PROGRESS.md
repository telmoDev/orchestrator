# Progress

Partial tasks only, newest first, written by `/sync-memory`. A task leaves this file when it is done: its PR and the git history of `memory/` keep the record.

Entry shape:
```
## YYYY-MM-DD — <task> (<ticket or —>) — partial
Spec: <spec file> · <decision ids>
<repo>: <branch> / PR #n — <files or "none">   (one line per repo)
Outcome: O1 <criterion> — passed|failed|blocked|pending (<test or command>) · O2 …   (full text only until a PR body holds it)
Checks: <each check with its real result, or "not run">
Cost: <task-n> · <agent> · tier <tier> · attempts <n> · tokens <as reported by the Agent result, or "not reported">
Integration: <what was exercised end to end, result | not run>
Continue at: <repo, branch, file:line or step, next command>
```
