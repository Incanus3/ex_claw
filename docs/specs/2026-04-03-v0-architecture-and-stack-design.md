# V0 Architecture and Stack Design

Date: 2026-04-03
Status: Drafted from brainstorming session; awaiting user review

## Goal

Define the overall shape of the project before subsystem design. The intent is to optimize for fast iteration, outside-in development, and maintainability without overengineering v0.

## Design Summary

The project should start as a single Phoenix application using LiveView as the primary user interface. The architecture should be an API-conscious layered monolith: the LiveView UI can call application logic directly, and a future HTTP API should call the same lower-level modules rather than duplicating behavior.

Persistence should exist from the start, but should remain lightweight. For v0, that means Ecto with SQLite rather than a mandatory external Postgres dependency.

The initial execution model should be mostly synchronous and reactive. Normal chat interactions should happen inline within the current user flow. The architecture should preserve a clear seam for later promotion of selected actions into persisted background tasks.

## Key Product Assumptions

- v0 optimizes for fast iteration and visible progress
- development should support an outside-in workflow
- maintainability matters, but v0 should not be overengineered
- the project is single-user for now, though possibly multi-session
- multi-user support should not be a design goal for v0
- learning new technology is a valid secondary goal

## Chosen Stack

- Language: Elixir
- Web framework: Phoenix
- UI approach: Phoenix LiveView
- Persistence: Ecto + SQLite
- App shape: single full-stack application

## Rejected Baselines

### Separate frontend and backend apps
Rejected for v0 because it adds ceremony and slows iteration without enough immediate benefit.

### Mandatory external Postgres from day one
Rejected for v0 because it adds setup and operational dependency cost that is not justified for a single-user early-stage product.

### Task-oriented execution for everything from the start
Rejected for v0 because it adds complexity before the user-facing workflow and assistant behavior are understood.

## Architectural Style

The preferred architecture is an API-conscious layered monolith.

That means:

- one deployable Phoenix app
- LiveView is the first real interface
- core application logic does not depend on LiveView or JSON controllers
- future API endpoints should call the same application layer as the UI
- persistence and backend orchestration live below the delivery layer

This preserves the development feel of a LiveView-first product while keeping the codebase ready for a later HTTP API and additional interaction surfaces.

## Runtime Entry Points

### Primary v0 entry point
- LiveView web UI

### Planned secondary entry point
- HTTP API built on top of the same application logic

The UI should not be forced to go through the API internally. Instead, both the UI and API should depend on shared lower-level modules.

## Interaction Model

The initial interaction model is hybrid in architecture but reactive in behavior.

- normal assistant chat should execute synchronously in the current interaction
- UI updates should be visible quickly and support iterative development
- the code should keep a seam where selected actions can later become persisted background tasks

This should feel like approach C in architecture, with an implementation that initially behaves much like approach A.

## Persistence Direction

Persistence should be present from the beginning because the project expects sessions and logs to matter early.

For v0, prefer SQLite because it:

- avoids an external database dependency
- supports fast local iteration
- is sufficient for a single-user application with multiple sessions

The code should still use normal Ecto boundaries so that moving to Postgres later remains possible if the product grows beyond SQLite's comfort zone.

## High-Level Layering

The project should roughly follow this dependency direction:

1. Delivery layer
   - LiveView UI
   - future HTTP controllers / API endpoints
2. Application layer
   - session orchestration
   - conversation handling
   - backend invocation
   - logging and persistence coordination
3. Infrastructure layer
   - Ecto repos and schemas
   - backend adapters
   - external integrations

Lower layers should not depend on LiveView.

## Development Style Implications

The chosen architecture should support outside-in development:

- start with a simple UI flow
- connect it to application-layer actions
- stub or simplify deeper integrations temporarily when useful
- replace those stubs with real persistence and backend behavior incrementally

This allows visible progress early without letting the UI become the only architectural boundary.

## Explicit Deferrals

The following should be deliberately deferred until the product proves it needs them:

- separate frontend/backend runtimes
- full background job infrastructure
- long-running task engine
- advanced autonomy and scheduling
- generalized multi-user architecture
- overly generic backend abstraction layers

## Immediate Follow-On Design Topics

Once this document is accepted, the next high-value design topics are:

1. define the internal application-layer boundaries and responsibilities
2. define the backend adapter interface
3. define session boundaries and memory policy
4. define the initial persistence model for sessions, messages, and logs
5. define how future background tasks plug into the reactive-first architecture

## Decision Summary

- use Elixir + Phoenix + LiveView for the initial app
- keep the project as a single full-stack application
- use Ecto + SQLite for early persistence
- build a LiveView-first product with a shared core that can also serve a future API
- treat chat as synchronous/reactive first
- preserve a seam for background tasks later
- optimize for fast iteration and maintainability, not early operational complexity