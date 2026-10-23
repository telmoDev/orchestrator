# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this workspace.

## Layout

`{{NAME}}` holds these git repos side by side:

| Repo | What it is | Base branch | Its own guide |
|---|---|---|---|
{{REPO_ROWS}}
**Read the guide of the repo you are about to change before changing it.** A repo with no `CLAUDE.md` of its own has its conventions in its section under *Repo guides* below. They live here, not inside the repo.

Run git commands for application code inside the repo concerned. Each repo has its own branches, commits and pull requests, so a cross-repo feature means one PR per repo. {{ROOT_VCS}}

## Commands

TODO(orchestrator-setup): per repo, the commands to run, test (and a single test), lint, format and typecheck.

## Repo guides

Conventions for the repos that have no `CLAUDE.md` of their own. A repo that has one is governed by it, and has no section here.

{{REPO_SECTIONS}}
## How the repos connect

TODO(orchestrator-setup): how requests flow between the repos, how auth works, where the API contract and the cross-repo decisions are written down. Delete this section in single-repo mode.

## Orchestrator role

A session started here is the **orchestrator**. It plans, delegates, integrates and reports. It does not write application code in the repos itself.

**The orchestration layer lives only at this root** (`CLAUDE.md`, `.claude/`, `memory/`). Each repo keeps its own agents, skills, settings and CLAUDE.md exactly as a teammate opening it alone would find them. Never edit anything inside a repo to suit orchestration. If something here doesn't fit a repo's setup, adapt it here.

### Session memory (`memory/`)

| File | What it holds |
|---|---|
| `memory/PROJECT_STATE.md` | Generated from git: base branches, open PRs, cleanup. Written: features in flight with their spec, decisions and PRs; blockers |
| `memory/PROGRESS.md` | Partial tasks only: files, checks, integration result, where to continue |
| `memory/DECISIONS.md` | Temporary agreements, each with the `Until:` that ends it |
| `memory/NEXT_STEPS.md` | Resume points, pending tasks, what waits on others |

The next steps and the current state load with this file:

@memory/NEXT_STEPS.md
@memory/PROJECT_STATE.md

At the start of a session, check them against git (`git -C <repo> log`, `gh pr list`) before treating anything as done. Open `PROGRESS.md` or `DECISIONS.md` only when needed. If `NEXT_STEPS.md` has a **Resume** item, offer to continue it first.

Run `/sync-memory` once per session: before it ends, before a break that leaves a task partial, or before handing a task to another session. The other session picks it up from **Resume**. The memory links to specs and decision numbers and never copies them. It never holds secrets, credentials or personal data, and it stays short.

Agents live in `.claude/agents/`. Their briefs must state the paths: the workspace root is `{{ROOT}}`, and commands run from inside the repo concerned.

| Agent | Model | Send it |
|---|---|---|
| `explorer` | Haiku | broad lookups across the repos ("where/how is X done"), read-only |
| `architect` | Opus (Sonnet for normal-tier reviews) | plans, the cross-repo contract, decision checks, review of large or risky diffs, hard bugs (read-only) |
{{DEV_ROWS}}
Launch every subagent with `effort: "medium"` and the `model` of its tier (*Token budget* › *Model tiers*) on the Agent call; raise the effort only for a hard bug or a risky plan. The agent definitions stay unchanged.

Flow for a feature. First size it: **small** is one repo, no contract change and roughly under 100 changed lines; anything else is **large**. Work is **outcome-driven**: a task is done when its outcome is verified, not when code exists.

1. **Outcome and scope.** Before any delegation, write the outcome (shape below): the user's goal, the expected outcome, its acceptance criteria and the constraints. A small task gets the short form; a trivial-tier one, a single criterion. Ask the user only when a gap could change the outcome; otherwise state the assumption in the outcome and go on. Then scope: check a single point yourself (one grep, one excerpt under ~100 lines). For a broad sweep, use `explorer`, and keep the `file:line` results it returns for the brief.
2. **Plan and contract.** Skip for a small task. For a large one, `architect` produces the plan: the steps, which agent and tier does each, the criteria each step serves, the order they depend on, and the exact endpoints, payloads and error codes. If the plan hits an open question that no recorded decision answers, stop and take it to the user. Nothing gets implemented on an undecided point.
3. **Implement, test first.** Brief each `*-dev` agent with its criteria and the agreed contract pasted in, not "see the plan", and with the `file:line` starting points already found, so it doesn't explore again. The agent works test-first: a failing test per criterion, committed as `test(scope): …`, with the red output in its report; then the code until it passes (`feat`/`fix`); then the refactor. Run agents in parallel only when the contract is fixed and they touch no shared files; otherwise run the producer (usually the backend) first and pass its reported API changes on.
4. **Review and pre-PR gate.** Nothing is pushed, neither a new PR nor new commits on an open one, until the commit being pushed passes `.claude/pre-pr-checklist.md`. The aim is that the human review finds nothing we could have found ourselves, since each review round costs a wait. The owning agent runs part A (base merged in, local checks green, title, body). Part B is the review as the reviewer would do it: for a small task the orchestrator does it from `git -C <repo> diff --stat` and the agent's report, plus `/code-review medium` on the branch, opening only a file that looks wrong; for a large one it runs the saved `pre-pr-review` workflow (`.claude/workflows/pre-pr-review.js`, args `{repo, branch, base, ticket, spec}`; the user opted into running it for this step on {{DATE}}), where `architect` agents review groups of checklist items from the same `--stat` and a second `architect` tries to refute each finding. Either reports `PASS` or numbered failures; a finding the orchestrator judges wrong is dropped, not sent to the agent. Real defects go back to the same agent: continue it with `SendMessage` (it keeps what it already read) rather than launching a new one, and the gate runs again on the new commit. Before stamping, verify the outcome yourself, not from the agent's word: rerun the test of each criterion (`git -C <repo> log --oneline origin/<base>..<branch>` shows the `test` commit before each `feat`/`fix`) and give each criterion `passed`, `failed`, `blocked` or `pending`; a criterion you couldn't verify is `pending`, never `passed`. On `PASS` with every criterion `passed`, stamp the commit with `.claude/scripts/pre-pr-pass.sh <repo> <branch>`. `.claude/scripts/push-pr.sh` refuses an unstamped HEAD, a branch that doesn't contain `origin/<base>`, and a title over 72 characters. After the push, the PR is good only once `gh pr checks` is green (where the repo has CI). When a review still brings a comment the checklist wouldn't have caught, add a line for it to the checklist in the same session.
5. **Report.** Tell the user each criterion with its status and its evidence (the test or command that ran, never one that didn't), what changed in each repo, the check results (local checks, and CI from `gh pr checks`) and what is still open. Then run `/sync-memory`.

The outcome, written by the orchestrator in step 1 and refined by `architect` for a large task:

```
Goal: <what the user asked for, in their terms>
Outcome: <the observable result when this is done>
Criteria: O1 <verifiable by a test, a command or a demo> · O2 … (2–5; one for a trivial-tier task)
Constraints: <scope limits, decisions it must respect, what is out of scope>
Assumptions · risks · depends on: <only when there are any>
```

A small task keeps it in the brief and the PR body. It goes in a file only when the repo already keeps specs, as part of that spec. The PR body carries it in an `## Outcome` section with each criterion's status, and `memory/` links to it, never copying it. Only the orchestrator writes `memory/`: agents report, and the orchestrator records.

Briefs are self-contained, because the agent sees none of this conversation. Each brief starts with `Task: <feature>-<n> · Tier: <tier>` and gives the repo, the outcome and the criteria this task serves (verbatim), the contract, the constraints, the files to touch, the skills to load and what "done" means (its criteria `passed`). It also says: start from the given points and explore only as far as the task needs; run only the tests for what changed (quiet output) plus the repo's lint/format/typecheck, never a full suite that CI already runs; read only the failing lines of a log; when continued with review findings, fix exactly those; work test-first on the branch it names, cut from `origin/<base>`: commit a failing test per criterion as `test(scope): …` before each `feat`/`fix`, and give a review fix that changes behaviour its own test first (one that doesn't is `refactor`/`style`/`docs`); commit locally, never push.

**Skills.** Load the matching skill before the action it covers, every time:

- `/sync-memory` for the memory.
- `software-principles` (SOLID, KISS, DRY, YAGNI) when writing, reviewing or refactoring code: every implementation and review brief names it. `design-patterns` (Observer, Strategy, Builder, Adapter, Singleton, Factory, Facade) only when the task designs something new or refactors: name it in that brief and leave it out of the rest.
- A repo's own `.claude/skills/`, if it has any, for work inside it. A repo with none uses the root's skills.

An agent launched from this root doesn't get skills in its Skill tool. The brief gives the path and the agent reads `SKILL.md` directly: `{{ROOT}}/.claude/skills/<name>/SKILL.md`, or the repo's copy when it has one. A subagent never commits, branches or pushes unless the brief says to.

### Token budget

This file and the loaded memory are cached, so they cost little per turn. They still stay short, to keep attention on the task. The real cost is subagents: each one starts cold and reads its guide, its skills and the code again. Spend agents where they pay for themselves.

- **Model tiers.** The orchestrator runs on Opus. Each subagent gets the cheapest model that gets its task right the first time, passed as `model` on the Agent call:

  | Tier | `model` | When |
  |---|---|---|
  | trivial | `haiku` | docs, renames, config, copy: one file, under ~30 changed lines, no new logic or branches |
  | normal | `sonnet` | a feature or fix in one repo with a fixed contract (the `*-dev` default) |
  | hard | `opus` | a bug with no clear cause, concurrency, security, data migrations, or a task that failed twice one tier down |

  When unsure between two tiers, pick the lower one. An agent whose checks fail twice on the same point is replaced by a new one, one tier up, briefed with the previous report (`SendMessage` keeps its model, so it can't escalate). `explorer` stays on Haiku. `architect` plans on Opus, and reviews on Sonnet unless the task is hard. Whatever the tier, a brief carries everything the model needs to get it right the first time: the criteria and the contract pasted in, the files to touch, the checks to run. A vague brief costs more in rework than it saves.
- **Cost per task.** There is no automatic budget enforcement. Each brief's `Task: … · Tier: …` header is the integration point: when the Agent result reports its token usage, the orchestrator notes it with the attempts and the final status in the task's `PROGRESS.md` entry while the task is partial, and `/usage` shows the totals per agent. Never estimate a figure that wasn't reported.
- **Reports.** Every brief ends with: "Report in at most 10 lines: result, each criterion `passed`/`failed`/`blocked`/`pending` with the test that shows it (and its red output for test-first work), files touched, checks run and their results, blockers, risks and proposed decisions. Never claim a command you didn't run. No diffs, no logs."
- **Read narrowly, delegate broadly.** The orchestrator may run a grep or read an excerpt under ~100 lines to check one point. That is cheaper than briefing an agent. Broad lookups go to `explorer`, implementation to the `*-dev` agents, and large plans and reviews to `architect`. The orchestrator never writes application code.
- **Continue, don't respawn.** Follow-ups and review fixes go to the agent that did the work, through `SendMessage`. A new agent pays for all its reading again.
- **Size the flow.** A small task skips `architect` (steps 2 and 4 above) and loads no `design-patterns`. The `pre-pr-review` workflow costs 2–3 reviewers plus one verifier per finding (capped at 8 per group), so it is for large tasks only.
- **Parallel.** Launch independent agents in one message.
- **`/clear`** between unrelated tasks. The memory is the handoff. `.claude/settings.json` compacts at 200k tokens instead of the full window (`autoCompactWindow`; the `*-dev` agents at 150k), compacts a session left idle from 120k tokens so the next message after the prompt cache expires doesn't reprocess it all (`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`), caps each skill description in the listing at 300 characters (`skillListingMaxDescChars`) and turns off the plugins this workspace doesn't use (`enabledPlugins`).
- **Measure.** `/usage` shows the token share by skill, subagent, plugin and MCP server; check it before adding anything that loads on every session.

## Workspace rules

Lasting rules agreed with the user for working in this workspace. A temporary agreement goes to `memory/DECISIONS.md` with its `Until:`, and a domain or architecture decision goes to the repo's own records.

- none yet

## Git

An agent may create its branch and commit to it, but it never pushes: the orchestrator publishes with `.claude/scripts/push-pr.sh <repo> <branch> <base> <title> <body-file>` (which pushes and opens the PR) only after the pre-PR gate of step 4, and fetches through `GIT_WRAPPER` from `.claude/orchestrator.conf` when one is set. Nobody merges or pushes to a repo's base branch (the *Base branch* column under Layout). No AI attribution in commits or PRs: no `Co-Authored-By` trailer and no "Generated with" line (`.claude/settings.json` sets `attribution` to empty). Commit messages follow Conventional Commits: `type(scope): imperative subject`.
