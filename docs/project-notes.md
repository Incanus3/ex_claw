# AI Assistant Project Notes

Date: 2026-04-03

## Context

These notes capture the discussion about building a minimal but usable personal AI assistant inspired by the personal-assistant side of OpenClaw, explicitly excluding anything related to the retro game project with the same name.

## What OpenClaw Means Here

OpenClaw, in the relevant sense, is a self-hosted personal AI assistant platform. Its notable ideas include:
- personal-assistant framing rather than just a chat UI
- local/self-hosted control plane
- multiple messaging/device channels
- tool use and automation
- persistent, always-available assistant behavior

The goal here is not to reproduce its breadth, but to build a much smaller, usable version.

## High-Level Feasibility Estimate

For an experienced software developer who is new to modern LLM tooling:
- toy prototype: roughly 2-7 days
- minimal but genuinely usable MVP: roughly 2-6 weeks
- something trustworthy as a daily personal assistant: roughly 6-12 weeks
- OpenClaw-like breadth/polish: many months of ongoing work

Key point: model/API integration is likely the easy part. The harder parts are state, memory, autonomy, tools, safety, reliability, and long-running behavior.

## Recommended Initial Scope

Keep v0 narrow and intentionally boring:
- one primary surface first: HTTP API + simple web UI
- add Telegram later as the second surface
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

This scope was explicitly agreed as the right direction: start small and only add breadth where needed.

## Your Stated Preferences

- breadth should stay minimal initially
- web + Telegram is enough
- start with an HTTP API and simple web UI
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

A reasonable first architecture would have these pieces:
- channel layer
  - HTTP API first
  - web UI on top of the API
  - Telegram adapter later
- session store
  - conversation history
  - metadata
  - summaries
  - preferences
- agent loop
  - takes user input + relevant context
  - calls selected backend
  - handles backend responses and tool results
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

1. Create the project skeleton.
2. Build the HTTP API.
3. Build a minimal web UI.
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

## Next Topics to Analyze

Before implementation, the most valuable design work is likely:
- choosing the internal backend interface for opencode and Augment
- designing session/memory boundaries
- deciding what “task” means in the system
- defining what level of autonomy is allowed in v1
- deciding which tools are actually worth having first
