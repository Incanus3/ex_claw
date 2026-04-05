# Architecture and Stack Handoff

Date: 2026-04-03
Updated: 2026-04-05
Related design doc: `docs/specs/2026-04-03-v0-architecture-and-stack-design.md`

## Purpose

This is the single current handoff doc for the project's architecture and stack direction. It summarizes the accepted design and the current repo state, and points future sessions to the fuller design doc in `docs/specs`.

## Current Project State

The repository is currently a freshly generated Phoenix application with LiveView auth scaffolding and SQLite/Ecto setup.

What exists today:
- Phoenix app scaffold
- LiveView auth scaffold
- SQLite/Ecto wiring

What does not exist yet:
- assistant-specific UI
- assistant orchestration logic
- backend adapter implementation
- session/message/log persistence model for the assistant domain

## Confirmed Decisions

- The project should proceed as a single full-stack application.
- The preferred stack is Elixir + Phoenix + LiveView.
- Persistence should exist from the start, but remain lightweight.
- SQLite via Ecto is preferred over a mandatory external Postgres dependency for v0.
- The architecture should be an API-conscious layered monolith.
- LiveView is the primary v0 entry point.
- LiveView should call shared application logic directly.
- The HTTP API is planned from the beginning and should call that same shared logic.
- The project is not API-first.
- The interaction model is hybrid in architecture but reactive and mostly synchronous in behavior.
- In this context, reactive/inline behavior means work is handled within the current user interaction rather than delegated to an independent persisted background task.
- The design should leave a clear seam for future background tasks and longer-running workflows.
- The product is single-user for now, though multiple sessions are expected.

## Why This Direction Was Chosen

This direction best matches the stated priorities:

- fast iteration
- outside-in development
- maintainability without early overengineering
- low local setup burden
- room to learn a new stack

## What Was Intentionally Deferred

- separate frontend/backend apps
- mandatory Postgres
- full job/task infrastructure
- advanced autonomy
- multi-user architecture
- using the planned HTTP API as the primary delivery surface in v0

## Immediate Next Discussion

The next discussion should define the first vertical slice from the current scaffold.

That discussion should answer:

1. what the first real page or LiveView is
2. what the first assistant interaction flow is
3. what must be persisted immediately
4. what backend adapter stub or first integration point is needed
5. what counts as done for the first usable slice

## Notes For Future Sessions

- Start with the design doc for full architectural context.
- Use this handoff as the short operational summary.
- There is only one current handoff doc; older overlapping handoffs have been consolidated.