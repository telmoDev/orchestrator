# Pre-PR checklist

The gate of flow step 4 (`CLAUDE.md`), at any size of task. Nothing is pushed (a new PR, or new commits on an
open one) until every item below passes on the exact commit being pushed. The goal: the human review finds
nothing we could have found ourselves.

The list grows from real reviews. When a review brings a comment this list would not have caught, add one line
for it (with the PR number in brackets) in the same session that answers the review. Keep the item numbers
stable: `.claude/workflows/pre-pr-review.js` groups part B by number.

## A. Mechanical (the agent that owns the branch runs these and reports the results)

1. **Up to date with the base.** Fetch, merge `origin/<base>` into the branch, resolve conflicts keeping both
   sides. Never rebase or force-push a branch that has an open PR or a PR stacked on it. Numbered docs (ADRs,
   decision entries, open questions) still line up with what the base added.
2. **Local checks green; CI does the rest.** The tests for what changed, plus lint, format and typecheck:
   TODO(orchestrator-setup): the exact commands per repo, and which of them CI runs instead.
3. **Title and branch.** `type(scope): subject`, lower case, no period, **≤ 72 characters**, naming what lands
   after the squash. The ticket key goes in the body, not the title.
4. **Body.** Follows the repo's PR conventions: why, not what; the decision that authorises it; the ticket line
   (when the project uses tickets); one decision per PR; an `## Outcome` section with the goal, the outcome and each criterion with its status
   (`passed`, `failed`, `blocked`, `pending`) and the test that shows it. Every factual claim is true *now*. A stacked PR says
   what it is stacked on and the merge order.

## B. Content (reviewing as the reviewer would, before any push: the orchestrator for a small task, the `pre-pr-review` workflow for a large one)

5. **Code matches the contract, line by line.** For every behaviour the diff implements, open the paragraph of
   the spec or decision that states it and compare. Where they differ, the code changes, not the reading.
6. **No "interim" answer that persists data.** If an open question shapes anything stored (codes, columns, row
   shape), it cannot merge as interim: take it to the user before the PR. Anything the contract does not name
   is either written into the spec in this PR or asked.
7. **Docs move with the code, in the same PR.** New error codes, value rules and closed questions are recorded;
   stale status lines this PR makes false are fixed. Cite sections by name, not line numbers.
8. **Rules in the repo guides and skills.** Name the rule when the PR touches it. Known misses: none yet.
9. **Boundaries.** No module reaches into another's internals; cross-module access goes through the published
   interface.
10. **Failure paths.** Jobs and commands handle every error, leave a consistent state, and no log or stored
    error carries secrets, personal data or query bindings.
11. **Tests for every branch the diff adds.** Error paths, races, thresholds, skipped steps, and one test per
    should-fix found by this gate.
12. **No third copy.** A sequence the diff writes a third time is extracted into one collaborator in the same
    PR, with the existing tests unchanged.
13. **Decision records stay whole.** An amendment says who decided it, when and where; a developer only
    *proposes* a change to a decision. Logs are append-only.
14. **UI (only for repos with a user interface).** Every request that can fail has a retry path; a late async
    answer never overwrites newer data; no display string outside i18n; no business state derived on the
    client; the design system followed.

15. **Outcome met.** Every criterion of the outcome is `passed`, and its test or command was rerun by the
    orchestrator, not taken from the agent's report. No code outside the outcome's scope. A criterion that can't
    be verified is `pending`, and the PR waits or the user accepts it.
16. **Test first.** Each criterion has a test that fails without the change: the agent's report shows the red
    output, and a `test` commit comes before each `feat`/`fix` (`pre-pr-pass.sh` refuses otherwise). The tests
    assert the behaviour the criterion states, not the implementation.

## Result

The reviewer reports `PASS` or a list of failures (item number, file, one line each). Failures go back to the
agent that owns the code, and the gate runs again on the new commit. On `PASS`, the orchestrator stamps that
commit (`.claude/scripts/pre-pr-pass.sh <repo> <branch>`); `push-pr.sh` refuses to push anything else.
