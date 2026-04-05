# AI Assistant Project Notes

Date: 2026-04-03
Updated: 2026-04-05

## Context

These notes capture the current direction for building a minimal but usable personal AI assistant inspired by the personal-assistant side of OpenClaw, explicitly excluding anything related to the retro game project with the same name.

## Current Project State

The repository is currently a freshly generated Phoenix application with LiveView auth scaffolding.

Current implementation state:
- Phoenix app scaffolded
- LiveView auth scaffolded
- SQLite/Ecto setup present
- no assistant-specific product functionality implemented yet

## What OpenClaw Means Here

OpenClaw, in the relevant sense, is a self-hosted personal AI assistant platform. The relevant inspiration is:
- personal-assistant framing rather than just a chat UI
- persistent assistant behavior
- tool use and automation
- multiple possible interaction surfaces over time

The goal here is not to reproduce its breadth, but to build a much smaller, usable version.

## High-Level Feasibility Estimate

For an experienced software developer who is new to modern LLM tooling:
- toy prototype: roughly 2-7 days
- minimal but genuinely usable MVP: roughly 2-6 weeks
- something trustworthy as a daily personal assistant: roughly 6-12 weeks
- OpenClaw-like breadth/polish: many months of ongoing work

Key point: model integration is likely the easy part. The harder parts are state, memory, autonomy, tools, safety, reliability, and long-running behavior.

## Current v0 Scope

Keep v0 narrow and intentionally boring:
- one primary surface first: LiveView web UI
- keep the architecture API-conscious so a future HTTP API can reuse the same lower-level modules
- add Telegram later as a second surface
- hosted models only
- one assistant persona
- persistent sessions
- a very small number of tools
- no voice
- no mobile apps
- no browser automation initially
- no plugin marketplace / skill registry
- no local model hosting
- no broad multi-channel support

This scope is the current chosen direction. Earlier API-first framing is superseded.

## Current Design Preferences

- breadth should stay minimal initially
- LiveView is the primary v0 entry point
- the app should be a layered monolith, not split into separate frontend/backend apps
- the HTTP API is planned from the beginning, but is not the initial primary delivery surface
- Telegram can come later
- use hosted models, not local ones
- do not necessarily integrate directly with model providers at first
- preferred backends to integrate with:
  1. opencode via its HTTP API
  2. Augment Code, likely via CLI in non-interactive mode
- these integrations may already handle some basic tool calling
- the most daunting areas are:
  - memory
  - autonomy
  - long-running task management

## Suggested Architecture for v0

A reasonable first architecture has these pieces:
- delivery layer
  - LiveView UI first
  - planned HTTP API built on the same application logic
  - Telegram adapter later
- application layer
  - session orchestration
  - conversation handling
  - agent loop
  - backend invocation
  - persistence/logging coordination
- infrastructure layer
  - repo and schemas
  - backend adapters
  - external integrations
- session store
  - conversation history
  - metadata
  - summaries
  - preferences
- tool runtime
  - only a few explicit tools at first
- persistence and observability
  - logs
  - transcripts
  - tool-call history
  - error records

## Main Technical Risks

### 1. Memory
Likely harder than expected. Questions to answer:
- what history is kept in active context?
- when is history summarized?
- what facts become long-term memory?
- how are memories stored and retrieved?
- how to avoid the assistant inventing or overusing memory?

### 2. Autonomy
This should probably be introduced carefully and in layers:
- first: reactive assistant only
- then: explicit user-created tasks/reminders
- then: scheduled follow-ups or background jobs
- much later: more independent behavior

Autonomy becomes much safer once task boundaries and permissions are explicit.

### 3. Long-Running Task Management
This looks like a product/system-design problem more than an LLM problem. It likely needs:
- explicit task records
- statuses
- ownership / source
- resumable execution
- retry policies
- audit trail
- user-visible progress

This should likely be modeled as a normal application subsystem, with the LLM helping operate it rather than replacing it.

## Recommended Development Order

1. Keep the Phoenix scaffold as the base.
2. Define the first vertical slice.
3. Build the first LiveView assistant interaction.
4. Integrate one backend first (probably whichever is easiest to drive reliably).
5. Add persistent sessions and logs.
6. Add a tiny tool surface.
7. Add basic summarizing memory.
8. Add explicit task management.
9. Add Telegram.
10. Add limited autonomy only after the above is stable.

## Working Assumption About Backends

A likely initial design is to treat opencode and Augment as interchangeable backend adapters behind a common internal interface. Even if they provide tool-calling support, the assistant still needs its own application-level state, memory policy, task model, and logging.

## Important Practical Recommendation

Do not start with full autonomy. Start with a useful reactive assistant that:
- answers well
- remembers enough
- stores sessions reliably
- can perform a few valuable actions
- has strong logs and predictable behavior

Then add memory depth, task tracking, and autonomy incrementally.

## Next Discussion: The First Vertical Slice

The next design discussion should define the first vertical slice from the current scaffold.

That discussion should answer:
- what is the first real page or LiveView?
- what is the first assistant interaction flow?
- what should be persisted immediately?
- what backend adapter stub or first integration is needed?
- what counts as done for the first usable slice?

## Follow-On Topics After That

After the first vertical slice is defined, the next high-value design work is likely:
- choosing the internal backend interface for opencode and Augment
- designing session/memory boundaries
- deciding what “task” means in the system
- defining what level of autonomy is allowed in v1
- deciding which tools are actually worth having first
