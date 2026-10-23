# Working with the orchestrator

For the person who works with it. Your agent can summarize this for you in your language.

## The idea

You open your agent (Claude Code or Codex) at the root of a folder that holds your repos. That session is
the **orchestrator**: it plans, briefs helper agents, checks their work and reports to you. It does not
write application code itself. Helper agents do: `explorer` looks things up, `architect` plans and
reviews, one `<repo>-dev` per repo implements.

Each task follows the same flow:

1. **Outcome first.** Before anything is built, the orchestrator writes down your goal, the observable
   result and 2–5 acceptance criteria (O1, O2…). It asks you only when a gap could change the result.
2. **Plan** (large tasks only): `architect` turns the criteria into steps and the exact contract between repos.
3. **Test first** (on by default). The dev agent writes a failing test per criterion, commits it, then the
   code that makes it pass. The gate refuses a code commit with no test commit before it.
4. **Pre-PR gate.** Nothing is pushed until the branch passes the checklist in
   `.orchestrator/pre-pr-checklist.md` and the orchestrator has rerun each criterion's test itself.
5. **Report.** You get each criterion as `passed`, `failed`, `blocked` or `pending`, with the command that
   shows it. Nothing unverified is called done.

To save tokens, each helper runs on the cheapest model that can do the job right: **trivial** (small
docs/config), **normal** (a feature with a fixed contract), **hard** (unclear bugs, security, migrations).
An agent that fails twice is replaced one tier up.

## Setting up a workspace

Open your agent at the workspace root and say "implementa la estructura de orquestador" (or "set up the
orchestrator"). It reads your repos (stack, commands, how you write commits and PR titles), asks which tools
you use, your ticket system and whether to version the orchestration files in git, then shows you its defaults (design principles and patterns, test-first,
the quality checklist) so you keep, change or drop each one. Then it writes the files and lists what's left
for you to fill in.

## It adapts to you

The defaults are a starting point that works for any stack. Your conventions win: the orchestrator follows
each repo's guide and history, and when you correct how it works or state a preference, it writes it to
*Workspace rules* in `AGENTS.md` and follows it from then on. Your own standards are skills: add one to
`.agents/skills/` and a row to *Standards*.

## Every session

| | Claude Code | Codex |
|---|---|---|
| Start | open it at the workspace root; the memory loads by itself | open it at the root; the first time, trust the project and approve the two hooks in `/hooks` |
| Ask for work | describe the task; the orchestrator does the rest | same |
| Save the session's state | `/sync-memory` before you stop or take a break | `$sync-memory` |
| See what it costs | `/usage` | `/status` |
| Between unrelated tasks | `/clear` | start a new session |

`memory/` is the handoff: a session in either tool picks up where the last one stopped (*Resume* in
`memory/NEXT_STEPS.md`). You can switch tools between sessions.

## Good to know

- Your repos are never edited to suit the orchestrator; everything lives at the workspace root.
- Agents commit only on their own branch and never push. The orchestrator pushes with
  `bash .orchestrator/scripts/push-pr.sh` after the gate, and never merges.
- When a reviewer comments something the checklist would have caught, the orchestrator adds a line to the
  checklist so it doesn't happen again.
- Update the skill: ask your agent to update the orchestrator (it moves to the latest release and tells
  you what changed). Existing workspaces keep their files and their `TEMPLATE_VERSION`; ask the agent to
  bring a workspace up to date when you want it, and it follows the *Workspaces* notes in `CHANGELOG.md`.
