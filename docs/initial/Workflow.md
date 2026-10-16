# Workflow — Chimera

How a single use case is delivered, from picking it up to closing it out. The
formal, normative version of this process lives in the
[Development Workflow Document](../requirements/Development%20Workflow%20Document.md);
this document is the operational form an implementer follows step by step.

> **One use case = one branch = one issue = one pull request.**

The project-foundation issue is the sole exception to the use-case rule, but it
still uses one branch and one pull request.

## Invocation

Work starts when a use case is named by its identifier, such as `UC-03`. If the
identifier is missing or ambiguous, ask which one before doing anything else.
One pass handles exactly one use case.

## The golden rule: pause at every stage boundary

The work is reviewed before it advances. Therefore:

- The only status change made unattended is **Todo → In Progress**, immediately
  after the branch is created.
- Every other stage transition requires explicit approval. Before moving to
  **Testing**, before opening a pull request, and before moving to **Done**, stop,
  show what was completed, and ask. Do not batch these approvals.
- Never merge a pull request, self-approve it, or delete its branch. Review,
  merge, and branch deletion are human actions. An agent may prepare and push the
  pull request.

When pausing, summarize the completed stage, state what comes next, and wait for
a clear go-ahead.

## Workflow overview

```text
Load specs → Refine design and plan → approval → Branch + issue to In Progress
  → Implement → approval → issue to Testing → Test until green → approval
  → Open PR → human review, merge, and branch deletion → approval → issue to Done
```

Steps 1–2 and every approval gate are where the implementer stops.

---

## Step 1 — Load the specifications

Read the relevant requirements documents before designing anything. Pull the
specifics for this use case; do not work from memory:

- [Use Case Specification Document](../requirements/Use%20Case%20Specification%20Document.md)
  — the target use case, its actors, preconditions, postconditions, main flow,
  and every alternative flow.
- [System Requirements Document](../requirements/System%20Requirements%20Document.md)
  — the functional requirements traced to it, plus the data model, interface
  surface, and authorization rules.
- [Development Workflow Document](../requirements/Development%20Workflow%20Document.md)
  — the normative delivery process.
- [Testing Specification Document](../requirements/Testing%20Specification%20Document.md)
  — how tests are written and executed.
- [Technology Stack Document](../requirements/Technology%20Stack%20Document.md)
  — the libraries, versions, and patterns used to build it.

Then locate the corresponding GitHub issue.

## Step 2 — Refine the design and plan

The specification defines what is required; a repository-specific implementation
design defines how it fits the codebase.

1. **Design** — map the use case and its traced requirements to concrete
   components, interfaces, validation, domain behavior, and entry points. Map
   every alternative flow to an error or failure response and follow patterns
   already present in the repository.
2. **Plan** — write a step-by-step implementation plan sequenced test-first in
   accordance with the Testing Specification.

Present the refined design and plan, then wait for approval before writing code.
This is the first review gate.

## Step 3 — Branch and move the issue to In Progress

After the plan is approved, create a branch from an up-to-date `develop` branch using
the pattern `feature/uc-##-short-name`:

```bash
git switch develop
git pull
git switch -c feature/uc-03-example-use-case
```

Then make the one unattended status change: move the issue to **In Progress**.

## Step 4 — Implement

Execute the approved plan and follow the repository's established patterns.
Implement the main flow and every alternative flow from the specification. Grow
the implementation and its tests together, and commit on the branch as work
progresses.

## Step 5 — Pause for review before Testing

When implementation is code-complete, stop and ask before advancing. Summarize
what was built. Only after approval, move the issue to **Testing**.

## Step 6 — Test until green

Follow the
[Testing Specification Document](../requirements/Testing%20Specification%20Document.md),
cover the main flow and each applicable alternative flow, run the suites, fix
failures, and rerun until everything passes. The baseline command is:

```bash
flutter test
```

Target-specific functional commands are defined in the Testing Specification.
Report the passing results, then stop and ask before opening a pull request.

## Step 7 — Open the pull request after approval

Once approved, push the branch and open a pull request into `develop`, referencing
its GitHub issue so the merge closes it. The Yggdrasil branch-policy check and all
application CI checks must pass. Hand the pull request to a human for review and
merge. Do not merge it or delete the branch.

## Step 8 — Close out after the human merges

After the pull request is merged and the branch is deleted, ask before finishing.
Then move the issue to **Done** and confirm it is closed.

This completes the use case on `develop`; it does not publish a production
release. Releases use Yggdrasil's separate `release/x.y.z` to `main` promotion
flow documented in the formal Development Workflow and Operations documents.

---

## Definition of Done

- [ ] Implemented on a `feature/uc-##-short-name` branch created from `develop`.
- [ ] Main flow and every alternative flow implemented.
- [ ] Unit and functional tests cover the use case per the Testing Specification.
- [ ] The full test suite passes on every affected supported target.
- [ ] The pull request was reviewed by a human and merged.
- [ ] The branch was deleted.
- [ ] The GitHub issue is in **Done** and closed.
