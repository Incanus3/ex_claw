# Architecture and Stack Handoff

Date: 2026-04-03
Related design doc: `docs/specs/2026-04-03-v0-architecture-and-stack-design.md`

## Purpose

This handoff captures the decisions from the architecture and stack brainstorming session and points future sessions to the fuller design document in its canonical `docs/specs` location.

## Confirmed Decisions

- The project should begin as a single full-stack application.
- The preferred stack is Elixir + Phoenix + LiveView.
- Persistence should exist from the start, but remain lightweight.
- SQLite via Ecto is preferred over a mandatory external Postgres dependency for v0.
- The architecture should be an API-conscious layered monolith.
- LiveView should be able to call shared application logic directly.
- A future HTTP API should call that same shared logic rather than becoming the core architecture.
- The initial execution style should be reactive and mostly synchronous.
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

## Recommended Next Discussion Topics

After reviewing the design doc, the next useful design conversations are:

1. internal layer/module boundaries
2. backend adapter interface
3. session and memory policy
4. persistence model for sessions/messages/logs
5. future task/background execution seam

## Notes For Future Sessions

If future sessions need architecture context, start with the design doc rather than this summary. This file is intentionally short and operational.