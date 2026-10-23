# Decisions

Temporary agreements made in sessions, each with the condition that ends it. A lasting rule for the orchestrator goes to `CLAUDE.md` › *Workspace rules*, and a domain or architecture decision goes to the repos' own decision records, never here. `memory-check.py` refuses an entry with no `Until:` line, and one whose PR is merged or closed or whose date has passed: delete it then.

Entry shape:
```
## YYYY-MM-DD — <agreement>
Until: <repo> #N merges | <ticket> closes | <open question> answered | YYYY-MM-DD
<one or two lines: what was agreed and by whom>
```
