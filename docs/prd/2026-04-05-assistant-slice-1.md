# PRD: Assistant Slice 1

Date: 2026-04-05
Related design doc: `docs/plans/assistant-slice-1-design.md`

## Overview

Build the first usable assistant experience for ExClaw as an authenticated Phoenix LiveView feature.
A signed-in user should be able to open the assistant UI, land in a persisted chat session, send a
message, receive a persisted response from a real backend, and inspect enough per-turn operational
detail to debug early backend behavior.

This slice is intentionally narrow. It establishes the first real product loop and the shared
backend seam without adding long-term memory, autonomous task execution, or multiple backend
implementations.

## Goals

- Deliver the first end-to-end authenticated assistant workflow.
- Persist sessions, messages, and operational run data from day one.
- Use `auggie` as the first real backend.
- Keep the app as a LiveView-first layered monolith with shared application logic.
- Create a backend abstraction that allows `opencode` to be added later without major restructuring.
- Keep the chat transcript clean while still surfacing developer-useful debugging detail.

## Quality Gates

These commands must pass for every user story:

- `mix precommit` - project quality gate

For UI stories, also include:

- perform a lightweight manual browser sanity check relevant to the changed UI

## Execution Guidance

This PRD is written in outside-in product order, not in strict technical dependency order.

Implementation guidance:

- Implementers should read the full PRD and the related design doc before starting any individual
  story.
- Early stories may require scaffolding or temporary stubs for capabilities that are specified more
  fully in later stories.
- When adding such scaffolding or stubs, implementers should follow the contracts and invariants in
  the later stories and in the design doc's schema-semantics section rather than inventing ad hoc
  temporary shapes.
- Temporary scaffolding is acceptable when it preserves the later intended interfaces, persistence
  model, and UI direction.

Planning guidance for later implementation planning and bead creation:

- Do not assume user stories should map 1:1 to execution beads.
- The later implementation plan and bead set should add stronger operational guidance, explicit
  dependency ordering, and stub/defer instructions where useful.
- Beads should be grouped by execution dependencies and safe implementation sequence, while still
  tracing back to these user stories.

## User Stories

### US-001: Add authenticated assistant routes and landing behavior

**Description:** As an authenticated user, I want to open the assistant UI and land in a real
session so that I can start or resume a conversation immediately.

**Acceptance Criteria:**
- [ ] Add the assistant routes inside the existing authenticated Phoenix scope using the `[:browser,
  :require_authenticated_user]` pipeline and the existing `live_session :require_authenticated_user`
  block.
- [ ] The authenticated root route redirects to `/assistant`.
- [ ] Add `/assistant` as a landing route and `/assistant/:session_id` as the session-specific route.
- [ ] Visiting `/assistant` loads the current user's most recent non-archived session if one exists.
- [ ] Visiting `/assistant` creates a new session with the default backend from application
  configuration and the configured default model for that backend when no active session exists.
- [ ] After landing behavior runs, the user is navigated to `/assistant/:session_id`.
- [ ] Session access is scoped to the authenticated user via `current_scope`.
- [ ] Visiting `/assistant/:session_id` loads that specific session when it belongs to the current
  user, including when it is archived.
- [ ] If `/assistant/:session_id` refers to a missing or inaccessible session, the user is
  redirected to `/assistant` and shown a flash message explaining the redirect.
- [ ] When the loaded session is archived, the session remains viewable but the message composer is
  disabled and shows the message `This session is archived.`.

**Forward Context for Implementers:**
- Read `US-002` for the required session shape and session-list behavior.
- Read `US-004` for the backend abstraction and default backend/model expectations.
- Read the design doc's schema semantics and invariants section before implementing persistence.
- If session creation or routing is stubbed before the full backend flow exists, the stub should
  still create sessions using the documented `backend` and `current_model` contract.

### US-002: Persist assistant sessions and session management actions

**Description:** As an authenticated user, I want to manage assistant sessions so that I can
organize separate conversations over time.

**Acceptance Criteria:**
- [ ] Persist assistant sessions with at least: user ownership, title, backend, current model,
  archived timestamp, and normal timestamps.
- [ ] The assistant UI shows a lightweight session list for the current user.
- [ ] Each session list item shows the session title, selected backend, selected model, created
  timestamp, and last active timestamp.
- [ ] The UI supports creating a new session.
- [ ] The UI supports switching between sessions.
- [ ] The UI supports renaming a session.
- [ ] The UI supports archiving a session.
- [ ] Archiving the currently open session keeps the user on that session page in read-only mode
  rather than navigating away.
- [ ] New sessions start with a generic default title.
- [ ] Permanent delete is not implemented in this slice.

**Forward Context for Implementers:**
- Read `US-003` for how session state affects message submission and current-model usage.
- Read `US-004` for how backend/model defaults and model discovery influence session creation.
- Read `US-005` for the relationship between sessions, transcript records, and operational run data.
- When implementing session persistence early, preserve the documented meanings of `backend`,
  `current_model`, `archived_at`, and `last_message_at` rather than using placeholder fields that
  would need reshaping later.

### US-003: Persist chat messages and enforce one active run per session

**Description:** As an authenticated user, I want my messages to persist immediately and the session
to avoid overlapping runs so that conversation state remains predictable.

**Acceptance Criteria:**
- [ ] Persist user messages as local application records.
- [ ] Persist assistant messages as local application records on successful backend completion.
- [ ] User messages are stored immediately when submitted, before the backend finishes.
- [ ] The session allows only one active backend run at a time.
- [ ] While a run is active for a session, the composer for that session is disabled.
- [ ] The session's current model is persisted and used by default for the next run.

**Forward Context for Implementers:**
- Read `US-004` for the shared backend interface the message flow must call through.
- Read `US-005` for the run and event persistence model that should sit behind the message flow.
- Read `US-006` and `US-007` for the intended inline debug and success/failure UX that this story's
  data flow must support.
- If backend execution is temporarily stubbed while building message persistence, the stub should
  still preserve the later contract that user messages persist immediately, assistant messages are
  only persisted on successful completion, and failed runs do not create fake successful assistant
  messages.

### US-004: Implement a shared backend abstraction and the first `auggie` adapter

**Description:** As a developer, I want the first backend to run through a shared interface so that
another backend such as `opencode` can be added later without major restructuring.

**Acceptance Criteria:**
- [ ] Introduce a shared backend abstraction in the application layer.
- [ ] Implement the `auggie` adapter behind that abstraction.
- [ ] The shared backend abstraction includes a way to retrieve the available model list for a backend.
- [ ] New sessions default to backend `auggie` and a configured default model for that backend.
- [ ] The initial configured default model for the `auggie` backend is `gpt5.4`.
- [ ] The adapter uses the session's backend and current model configuration when executing a turn.
- [ ] For `auggie`, the available model list can be loaded from the CLI rather than requiring the
  full list to be statically configured in app config.
- [ ] The implementation does not require the LiveView to know backend-specific execution details.
- [ ] The abstraction shape leaves room for future backend-native identifiers such as backend
  session IDs and run IDs.

### US-005: Persist run records and operational events separately from the transcript

**Description:** As a developer, I want detailed run and event logging that is separate from the
visible transcript so that I can debug backend behavior without turning the chat into a raw event
timeline.

**Acceptance Criteria:**
- [ ] Persist run records linked to the session and relevant message/turn.
- [ ] Run records store at least: model, status, timestamps, duration, backend-native IDs when
  available, CLI exit status when relevant, and error information when present.
- [ ] Each run snapshots the actual model used for that execution even if the session's current
  model changes later.
- [ ] Persist request and response snapshots when practical.
- [ ] Persist operational event records for backend events such as lifecycle changes, tool calls,
  tool results, stderr, chunks, or notes when available.
- [ ] The transcript remains a chat-oriented view rather than a unified event timeline.

### US-006: Show developer-friendly inline per-turn operational detail

**Description:** As a developer using the prototype, I want to inspect timestamps, errors, and tool
activity inline with the conversation so that I can understand what happened for each turn.

**Acceptance Criteria:**
- [ ] Each turn can expose expandable inline operational detail tied to that turn.
- [ ] Inline detail can show useful information such as timestamps, duration, backend, model,
  backend-native identifiers, errors, and available tool-related events.
- [ ] The inline detail is derived from separate run/event persistence rather than from a special
  transcript-only data shape.
- [ ] The design keeps open a future path for simple versus advanced presentation modes.

### US-007: Handle successful and failed turns distinctly, including retry

**Description:** As a user and developer, I want successful and failed turns to be represented
differently so that conversation state is honest and failures are debuggable.

**Acceptance Criteria:**
- [ ] On a successful run, the assistant reply appears in the transcript and the run is marked
  successful.
- [ ] The assistant reply itself is the main success signal.
- [ ] Subtle success metadata can be shown in expandable per-turn detail.
- [ ] On a failed run, the user message remains persisted.
- [ ] Failed runs do not create fake successful assistant messages.
- [ ] Failed turns display a visibly distinct failure state in the conversation area.
- [ ] Success and failure states are visually distinguishable, including color treatment supported
  by non-color cues such as labels or icons.
- [ ] Failed turns support retry while preserving prior failure history.

## Functional Requirements

- FR-1: The assistant feature must be available only to authenticated users.
- FR-2: Assistant LiveView routes must be placed in the existing authenticated Phoenix scope and
  live session.
- FR-3: The authenticated root route must redirect to `/assistant`.
- FR-4: Visiting `/assistant` must open the current user's most recent non-archived session or
  create a new one if none exists.
- FR-5: Visiting `/assistant/:session_id` must load that session when it belongs to the current
  user, including when the session is archived.
- FR-6: Missing or inaccessible `/assistant/:session_id` requests must redirect to `/assistant`
  with a flash message.
- FR-7: Archived sessions must remain viewable, but their message composer must be disabled and
  show the message `This session is archived.`.
- FR-8: The system must persist assistant sessions as user-owned records with backend and current
  model stored on the session.
- FR-9: The system must support creating, switching, renaming, and archiving sessions.
- FR-10: The system must persist user messages immediately on submission.
- FR-11: The system must persist assistant messages on successful backend completion.
- FR-12: The system must invoke the selected backend through a shared application-layer abstraction.
- FR-13: The shared backend abstraction must provide a way to retrieve the available model list for
  a backend.
- FR-14: Slice 1 must implement `auggie` as the first real backend adapter.
- FR-15: The system must store operational run records separately from chat transcript records.
- FR-16: The system must snapshot the actual model used on each run.
- FR-17: The system must store useful operational diagnostics including statuses, timings, errors,
  and backend-native identifiers when available.
- FR-18: The UI must expose expandable inline debug detail per turn.
- FR-19: The system must allow only one active run per session at a time.
- FR-20: The UI must disable new message submission for a session while a run is active in that
  session.
- FR-21: The system must represent failed turns without pretending they are normal assistant
  replies.
- FR-22: The system must support retrying a failed turn while preserving previous failed run
  history.
- FR-23: The persistence and application boundaries must support adding `opencode` later without
  major restructuring.

## Non-Goals

- Long-term memory
- Background jobs or queued turn execution
- Concurrent runs within the same session
- Multi-backend execution in slice 1
- Full cross-backend switching semantics within an existing conversation
- Per-session workspace-root selection
- Permanent delete for sessions
- Telegram or any other secondary interaction surface
- ExClaw-owned generalized tool permission UI

## Technical Considerations

- The project is a LiveView-first layered monolith; the UI should call shared application logic
  directly rather than going through an internal HTTP API.
- Because the project uses generated auth, all assistant session access should be scoped through
  `current_scope`.
- In LiveView templates, use the normal authenticated layout conventions and pass `current_scope`
  correctly.
- A clean split between transcript records and operational records is important so the product can
  later support simpler end-user presentation without losing backend diagnostics.
- Session model selection should use backend model discovery when practical, with application
  configuration providing defaults rather than necessarily the entire available model list.
- Slice 1 can use application configuration for the default backend and per-backend default models
  for new sessions rather than introducing a separate persisted user-preferences table.
- The initial configured default model for the `auggie` backend should be `gpt5.4`.
- Slice 1 should use one deployment-level assistant workspace root rather than per-session
  workspace-root configuration.
- Deployment/runtime configuration may override backend-specific operational values such as the
  `auggie` CLI executable path.
- Message records and run event records should be treated as append-only in slice 1, while run
  records remain mutable over their lifecycle.
- Key persistence invariants should be preserved during implementation:
  - `assistant_sessions.backend` is a session-level invariant in slice 1.
  - `assistant_sessions.current_model` is the default model for the next run in that session.
  - `assistant_runs.model` is the historical snapshot of the model actually used for that run.
  - `assistant_messages.run_id` should remain `NULL` for user messages in slice 1 and should point
    to the producing run for assistant messages created from successful runs.
  - `assistant_runs.user_message_id` identifies the user message that triggered the run.
  - In slice 1, at most one assistant message should reference a given run.
  - `assistant_sessions.last_message_at` should track persisted transcript message activity rather
    than generic run-event activity.
  - `assistant_run_events.sequence` is ordered within a run, not globally across all runs.

## Success Metrics

- An authenticated user can use the assistant feature end-to-end without manual database
  intervention.
- Conversation state persists across reloads.
- Backend failures are diagnosable from persisted data and the UI.
- The first backend integration is stable enough that future work can focus on product behavior
  rather than basic plumbing.
- The resulting architecture is ready for a second backend without rethinking the transcript model.

## Open Questions

- What should the first polished simple/advanced debug toggle look like when the prototype matures?
- When `opencode` is added later, should model selection remain per-session only or also support
  explicit backend selection in the same UI?
