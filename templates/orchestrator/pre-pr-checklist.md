# Pre-PR checklist

The gate of flow step 4 (`AGENTS.md`), at any size of task. Nothing is pushed (a new PR, or new commits on an
open one) until every item below passes on the exact commit being pushed. The goal: the human review finds
nothing we could have found ourselves.

Parts A and B are the orchestrator's flow. Part C is quality: the orchestrator's defaults, adapted by the user. The list
grows from real reviews: when a review brings a comment this list would not have caught, add one line for it to
part C (with the PR number in brackets) in the same session that answers the review. Keep the item numbers
stable: `.claude/workflows/pre-pr-review.js` and the `pre-pr-review` skill review part B and part C as groups.

## A. Mechanical (the agent that owns the branch runs these and reports the results)

1. **Up to date with the base.** Fetch and bring `origin/<base>` into the branch the way the repo does it.
   Once the branch has an open PR, merge the base in: `push-pr.sh` never force-pushes. Numbered docs still line
   up with what the base added.
2. **Local checks green; CI does the rest.** The tests for what changed, plus the repo's other local checks:
   TODO(orchestrator-setup): the exact commands per repo, and which of them CI runs instead.
3. **Title and branch.** Follow the repo's conventions, and `TITLE_PATTERN`/`TITLE_MAX` in
   `.orchestrator/orchestrator.conf` when set.
4. **Body.** Follows the repo's PR conventions: the ticket line (when the project uses tickets), and an
   `## Outcome` section with the goal, the outcome and each criterion with its status (`passed`, `failed`,
   `blocked`, `pending`) and the test or command that shows it. Every factual claim is true *now*. A stacked PR
   says what it is stacked on and the merge order.

## B. Flow (reviewing as the reviewer would, before any push: the orchestrator for a small task, the `pre-pr-review` workflow for a large one)

5. **Code matches the contract, line by line.** For every behaviour the diff implements, open the paragraph of
   the spec or decision that states it and compare. Where they differ, the code changes, not the reading.
   Anything the contract does not name is either written into the spec in this PR or asked.
6. **Repo rules and workspace standards.** The rules in the repo's guide and skills, and the standards in
   `AGENTS.md` › *Standards*. Name the rule when the PR touches it.
7. **Outcome met.** Every criterion of the outcome is `passed`, and its test or command was rerun by the
   orchestrator, not taken from the agent's report. No code outside the outcome's scope. A criterion that can't
   be verified is `pending`, and the PR waits or the user accepts it.
8. **Test first** (only with `TDD="strict"`). Each criterion has a test that fails without the change: the
   agent's report shows the red output, and a test commit comes before each code commit (`pre-pr-pass.sh`
   refuses otherwise). The tests assert the behaviour the criterion states, not the implementation.

## C. Quality (the orchestrator's defaults; the user keeps, rewrites or drops each one at setup, and adds their own)

9. **Docs move with the code, in the same PR.** New error codes, value rules and closed questions are recorded;
   stale status lines this PR makes false are fixed. Cite sections by name, not line numbers.
10. **No interim answer that persists data.** If an open question shapes anything stored, it cannot merge as
    interim: take it to the user before the PR.
11. **Boundaries.** No module reaches into another's internals; cross-module access goes through its published
    interface.
12. **Failure paths.** Every error is handled and leaves a consistent state; no log or stored error carries
    secrets or personal data.
13. **Tests for every branch the diff adds.** Error paths, races, thresholds, skipped steps, and one test per
    finding of this gate.
14. **No third copy.** A sequence the diff writes a third time is extracted into one place in the same PR, with
    the existing tests unchanged.
15. **Decision records stay whole.** An amendment says who decided it, when and where; a developer only
    proposes a change to a decision. Logs are append-only.
16. **User interface** (repos with one). Every request that can fail has a retry path; a late async answer never
    overwrites newer data; display strings follow the repo's localization rule; the repo's design system is
    followed.

Lines added from reviews go after the last item.

## Result

The reviewer reports `PASS` or a list of failures (item number, file, one line each). Failures go back to the
agent that owns the code, and the gate runs again on the new commit. On `PASS`, the orchestrator stamps that
commit (`bash .orchestrator/scripts/pre-pr-pass.sh <repo> <branch>`); `push-pr.sh` refuses to push anything else.
