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

## Current implementation status

As of 2026-04-06, the first two execution beads are complete and closed:

- `exc-zur.1.1` — complete
- `exc-zur.1.2` — complete

The next ready bead is:

- `exc-zur.1.3` — Assistant context lifecycle APIs

### Completed foundation work

Backend/config foundation now exists:

- `lib/ex_claw/assistant/backend.ex`
- `lib/ex_claw/assistant/backends.ex`
- `lib/ex_claw/assistant/model_catalog.ex`
- `test/support/fakes/fake_assistant_backend.ex`
- `test/ex_claw/assistant/backends/auggie_test.exs`

Important details from `exc-zur.1.1`:

- Assistant config uses `default_backend`, `backends`, `backend_options`, and `workspace_root`.
- `backend_options` replaced the earlier split `backend_defaults` / `backend_runtime` shape.
- `event.kind` intentionally remains a string per the approved design doc's open-string event kind.
- `ExClaw.Application` starts `ExClaw.Assistant.TaskSupervisor` and `ExClaw.Assistant.ModelCatalog`.

Persistence foundation now exists:

- `priv/repo/migrations/20260406115242_create_assistant_core_tables.exs`
- `lib/ex_claw/assistant/session.ex`
- `lib/ex_claw/assistant/message.ex`
- `lib/ex_claw/assistant/run.ex`
- `lib/ex_claw/assistant/run_event.ex`
- `test/support/fixtures/assistant_fixtures.ex`
- `test/ex_claw/assistant_test.exs`

Important details from `exc-zur.1.2`:

- Tables added: `assistant_sessions`, `assistant_messages`, `assistant_runs`, `assistant_run_events`.
- `assistant_messages.run_id` is a real DB foreign key on SQLite, added via a staged migration:
  create `assistant_messages` without `run_id`, create `assistant_runs`, then `alter table`
  to add `run_id references(:assistant_runs)`.
- Because of current `ecto_sqlite3` behavior, invalid `run_id` inserts may raise
  `Ecto.ConstraintError` instead of returning `{:error, changeset}` even with
  `foreign_key_constraint/3`; the DB foreign key is still enforced.
- Static `struct(Module, ...)` calls introduced during red-test setup were cleaned up back to
  direct `%Module{}` literals in tests and fixtures.

### Focused verification currently in place

- `mix test test/ex_claw/assistant/backends/auggie_test.exs` → passes
- `mix test test/ex_claw/assistant_test.exs` → passes

### Beads export status

- The beads state has been exported with `bd export -o .beads/issues.jsonl`.
- Use that command again if the JSONL export needs refreshing; do not use `bd sync` in this repo.

## How to start implementation

1. Run `bd ready`.
2. Start with the first ready execution bead in dependency order.
   - At the time of this handoff update, this should be `exc-zur.1.3`.
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
- Do not use `bd sync`; this repo's installed `bd` uses `export` for the JSONL refresh workflow.
- Do not self-commit.
- Use TDD per bead/task where practical.
- Prefer the smallest focused test command first, then expand scope only as needed.
- After all implementation is complete, the final verification gate is `mix precommit`.

## Next bead recommendation

Continue with `exc-zur.1.3`.
That bead should add the public `ExClaw.Assistant` context APIs on top of the now-complete backend
and persistence foundations without reworking the already-closed beads.
