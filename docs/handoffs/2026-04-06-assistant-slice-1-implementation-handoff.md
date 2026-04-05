# Assistant Slice 1 Implementation Handoff

Date: 2026-04-06
Related PRD: `docs/prd/2026-04-05-assistant-slice-1.md`
Related design doc: `docs/plans/assistant-slice-1-design.md`
Related implementation plan: `docs/plans/assistant-slice-1-implementation.md`
Root bead: `exc-zur` (Assistant Slice 1)

## Purpose

This handoff is the operational starting point for agents implementing Assistant Slice 1.
After reading this file plus the referenced PRD, design doc, implementation plan, and the relevant
bead, an implementation agent should not need any additional context from the earlier chat.

## Current task source

The implementation plan has already been converted into beads.

Hierarchy:
- `exc-zur` — Assistant Slice 1
- `exc-zur.1` — Phase 1: Foundation contracts and persistence
- `exc-zur.2` — Phase 2: Authenticated shell and session UX
- `exc-zur.3` — Phase 3: Run orchestration and real auggie integration

Execution beads:
- `exc-zur.1.1` — Backend contract, defaults, model catalog, fake backend scaffold
- `exc-zur.1.2` — Persistence migration, schemas, fixtures
- `exc-zur.1.3` — Assistant context lifecycle APIs
- `exc-zur.2.1` — Authenticated routes, redirects, LiveView shell
- `exc-zur.2.2` — Session list UI, metadata, model selection, archive UX
- `exc-zur.3.1` — Async runner, transcript updates, retry flow, debug UI
- `exc-zur.3.2` — Real auggie adapter, parser fixtures, final verification

## How to start implementation

1. Run `bd ready`.
2. Start with the first ready execution bead in dependency order.
   - Initially this should be `exc-zur.1.1`.
3. Read all of:
   - this handoff
   - `docs/prd/2026-04-05-assistant-slice-1.md`
   - `docs/plans/assistant-slice-1-design.md`
   - `docs/plans/assistant-slice-1-implementation.md`
   - `bd show <bead-id>` for the bead you are executing
4. Follow the implementation plan task that matches the bead.
5. Execute only one bead at a time.
6. After finishing a bead:
   - summarize what changed
   - report what verification ran and the results
   - ask the user to review/commit
   - wait for explicit approval before starting the next bead

## Repo-specific rules that matter during execution

- Use `bd`, not `br`, in this repo.
- If the `bv` viewer needs refreshed issue data, run:
  - `bd export -o .beads/issues.jsonl`
- Do not self-commit.
- Use TDD per bead/task where practical.
- Prefer the smallest focused test command first, then expand scope only as needed.
- After all implementation is complete, the final verification gate is `mix precommit`.

## First bead recommendation

Start with `exc-zur.1.1`.
That bead establishes the backend contract, model catalog, fake backend, and runtime/default-model
foundation that all later beads depend on.
