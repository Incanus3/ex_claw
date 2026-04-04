# Initial V0 Handoff

Date: 2026-04-03
Project root: `~/Projects/ai/assistant`

## Project Goal

Build a minimal but usable personal AI assistant inspired by the personal-assistant side of OpenClaw, while staying intentionally narrow in scope.

## What This Project Is Not

This project is not:
- related to the retro-game OpenClaw project
- trying to match OpenClaw's breadth
- trying to support many channels early
- trying to use local/self-hosted models in v0
- trying to implement broad autonomy from the start

## Agreed V0 Direction

Start small and only add breadth where needed.

Initial direction:
- start with an HTTP API
- build a simple web UI on top of it
- add Telegram later as the second surface
- use hosted models only
- keep one assistant persona initially
- keep the tool surface very small
- persist sessions and logs from the beginning

## Preferred Model Backends

The user does not currently want to integrate directly with model providers first.

Preferred backends to explore:
1. `opencode` via its HTTP API
2. `Augment Code` via CLI in non-interactive mode

Working assumption:
- these backends may already handle some basic tool calling
- the assistant still needs its own application-level orchestration, state, memory policy, logging, and task model

## Expected Core Subsystems

Likely v0 subsystems:
- HTTP API
- simple web UI
- backend adapter layer
- session store
- agent loop
- small tool runtime
- persistence/logging

## Major Risks / Unknowns

### Memory
This is expected to be one of the hardest parts.
Open questions include:
- what stays in immediate conversation context?
- when should history be summarized?
- what becomes longer-term memory?
- how should memory be stored and retrieved?

### Autonomy
This is also expected to be difficult and should be introduced gradually.
Recommended progression:
- reactive assistant first
- explicit user-created tasks/reminders next
- scheduled follow-ups after that
- broader autonomy much later, if ever

### Long-Running Task Management
This should likely be designed as a normal application subsystem, not as “just prompting.”
It will likely need:
- explicit task records
- status tracking
- resumability
- retries
- audit history
- user-visible progress

## Recommended Development Order

1. create project skeleton
2. implement HTTP API
3. implement simple web UI
4. integrate one backend first
5. add persistent sessions and logs
6. add a very small tool surface
7. add basic summarizing memory
8. add explicit task management
9. add Telegram
10. add limited autonomy only after the above is stable

## Current Design Bias

Preferred early design choices:
- narrow scope
- boring persistence
- strong logs/observability
- one backend first, adapters for more later
- no full autonomy in the beginning
- reliability over cleverness

## Immediate Next Design Topics

The next high-value design work is likely:
1. define the internal backend adapter interface
2. define session boundaries and memory policy
3. define the task model
4. define the allowed autonomy level for v1
5. decide which initial tools are actually worth having

## Existing Notes

Longer conversation notes are in:
- `project-notes.md`

This handoff is intended to be the short operational summary for future sessions.
