# Assistant Slice 1 Design

Date: 2026-04-05
Status: Approved design draft
Related PRD: `docs/prd/2026-04-05-assistant-slice-1.md`

## Overview

This document defines the first usable assistant vertical slice for ExClaw.

The slice delivers an authenticated assistant interface where a signed-in user can:

- open the assistant UI
- browse or create chat sessions
- send a message in a session
- receive a persisted response from a real backend
- inspect per-turn operational details useful for debugging early development

This design is intentionally narrow. It prioritizes a real end-to-end flow over long-term memory,
advanced autonomy, or multi-channel support.

## Goals

- Ship the first real assistant workflow on top of the Phoenix auth scaffold.
- Keep the UI authenticated-only because usage costs money and conversations may be sensitive.
- Persist conversation state from day one.
- Use one real backend immediately rather than a stub.
- Create a shared backend abstraction so `opencode` can be added later without major restructuring.
- Preserve a clean separation between user-visible conversation data and backend operational detail.

## Non-Goals

This slice does not include:

- long-term memory
- background job orchestration
- autonomous task execution
- multi-user design beyond the existing auth scaffold
- Telegram or other secondary surfaces
- browser automation or a generalized tool runtime owned by ExClaw
- permanent deletion of sessions
- concurrent runs within the same session
- queued messages within the same session

## Routing and authentication

The assistant UI must be placed inside the existing authenticated Phoenix scope:

- pipeline: `[:browser, :require_authenticated_user]`
- live session: `:require_authenticated_user`

This is the correct placement because:

- backend calls consume paid tokens
- conversations may contain sensitive information
- future agent actions may have real side-effects on the machine running the assistant

The route shape for slice 1 is:

- `/` redirects authenticated users to `/assistant`
- `/assistant`
- `/assistant/:session_id`

### Landing behavior

When a user visits `/assistant`:

- load that user's most recent non-archived session if one exists
- otherwise create a new session using the default backend from application configuration and the
  configured default model for that backend
- navigate to `/assistant/:session_id`

When a user visits `/assistant/:session_id`:

- load that specific session if it belongs to the current user, even when it is archived
- if the requested session is missing or inaccessible, redirect to `/assistant`
- show a flash message explaining that the requested session was unavailable and the user was
  redirected to an active assistant session instead
- when the requested session is archived, keep it viewable but disable message submission and show
  the message `This session is archived.` inside or near the composer

All session access must be scoped through `current_scope.user`. Assistant queries and commands
should always take `current_scope` first so session access remains tied to the authenticated user.

## UI and interaction model

The slice should use a single assistant LiveView with two main areas:

1. a lightweight session list
2. the active chat session

### Session list behavior

The session list should support:

- list active sessions
- create a new chat session
- switch between sessions
- rename a session
- archive a session

Each session list item should show enough summary information to support quick navigation, including:

- session title
- selected backend
- selected model
- created timestamp
- last active timestamp

Permanent delete is intentionally deferred. Archive is the only removal-style action in slice 1.

If the currently open session is archived:

- keep the user on that archived session page
- disable message submission for that session
- show the message `This session is archived.` near the composer

### Session titles

New sessions start with a generic default title such as `New chat`.

Slice 1 supports manual rename. Automatic title generation from the first message or backend
summarization is deferred.

### Main chat area

The active session view should contain:

- a session header with title and session controls
- a per-session backend/model area
- the transcript
- an input composer

The UI should be designed so that a future simple/advanced mode can change how much operational
detail is visible without requiring a persistence redesign.

## Backend strategy

### First backend choice

The first real backend is `auggie`, the Augment CLI.

It is chosen before `opencode` because the current priorities are:

- fastest path to a reliable real integration
- lowest debugging complexity

`opencode` remains the next intended backend, but it is not part of slice 1 implementation scope.

### Shared backend abstraction

ExClaw must define a shared backend interface from day one.

Only the `auggie` adapter is implemented in slice 1, but the abstraction must be shaped so
`opencode` can later be added without major changes to:

- LiveView flows
- session/message persistence
- run logging
- failure handling
- model discovery

The shared backend interface should include a method or equivalent capability for retrieving the
list of available models for a backend.

`list_models/0` should return a normalized success/error result rather than raw backend-specific
CLI output. The intended shape is:

- `{:ok, [model_info, ...]}` on success
- `{:error, reason}` on failure

Each normalized model entry should include at least:

- `id`: canonical model identifier used for execution
- `display_name`: user-facing label for the UI

Optional normalized fields may include:

- `description`
- `context_window`
- `supports_tools?`
- `supports_streaming?`
- `metadata`: backend-specific extra attributes that are not yet normalized further

`list_models/0` should not embed application-level default-selection logic. Defaults belong in app
configuration and model-catalog logic, not in the backend-returned model list.

The shared backend interface should also include `run_turn/1`, which should accept one normalized
request value rather than loose keyword arguments or raw Ecto structs.

The `run_turn/1` request should include at least:

- `run_id`: local ExClaw run identifier for correlation and logging
- `session_id`: local ExClaw session identifier for correlation and logging
- `model`: exact model to use for this execution attempt
- `messages`: normalized transcript payload to send to the backend
- `backend_session_id`: optional backend-native session/conversation identifier from a previous run
- `workspace_root`: absolute workspace path the backend should operate against

The normalized `messages` payload should use ordered oldest-to-newest transcript entries with the
shape:

- `%{role: :user | :assistant, content: String.t()}`

In slice 1:

- only `:user` and `:assistant` roles should be used in this normalized payload
- the payload should include the newly submitted user message
- the payload should exclude DB identifiers, timestamps, and UI-specific metadata

Adapting the normalized payload to backend-specific JSON or CLI formats is the adapter's
responsibility.

In slice 1, `workspace_root` should come from deployment/app configuration and be shared across all
assistant sessions. Per-session workspace roots are explicitly deferred to a later slice.

For backend-native session continuation in slice 1:

- use the latest available `backend_session_id` from the same ExClaw session
- prefer the most recent run that has a non-null `backend_session_id`, regardless of whether that
  run succeeded or failed
- if no prior run has a backend session ID, pass `backend_session_id: nil`
- do not duplicate backend session IDs onto `assistant_sessions` in slice 1; derive them from prior
  runs when building the next `run_turn/1` request

Optional fields may include:

- `stream?`: future-facing execution hint
- `metadata`: extra normalized execution metadata useful for correlation or logging

The request should not require a `backend` field because the adapter module has already been chosen
before `run_turn/1` is called.

`run_turn/1` should return a tagged normalized result:

- `{:ok, success_result}` on success
- `{:error, failure_result}` on failure

`success_result` should include at least:

- `reply_text`: required assistant reply text for transcript persistence
- optional backend-native session/run identifiers
- optional request/response snapshots
- optional normalized events

`failure_result` should include at least:

- `error_type`
- `error_message`
- optional backend-native session/run identifiers
- optional request/response snapshots
- optional normalized events

Both success and failure results may carry snapshots and events for debugging. Only the success
result should drive assistant-message creation in the transcript.

### Session-scoped backend and model selection

Backend and current model are first-class session attributes from the start.

Slice 1 behavior is:

- every session stores its backend and current model
- the UI allows per-session model selection by updating the session's current model
- backend identity is persisted on the session even though only `auggie` is implemented now
- new sessions default to backend `auggie` and the configured default model for that backend
- subsequent runs in a session use that session's current model by default
- the initial configured default model for `auggie` is `gpt5.4`
- changing a session's current model while a run is active is allowed and affects only future runs
- an in-flight run always uses the `assistant_runs.model` snapshot captured when that run was created

Slice 1 does not need a persisted per-user preferences table for backend/model defaults. Application
configuration is sufficient for choosing defaults for new sessions.

The design intentionally avoids requiring full cross-backend switching semantics within an existing
conversation. Future backends can be added without pretending that one active thread can move freely
between incompatible backends.

### Model list source

Slice 1 does not need to require a fully configured model list in application config.

For `auggie`, the available model list can be loaded from the CLI, for example during server
startup or another suitable application initialization step.

Application configuration should provide the default backend and per-backend default models for new
sessions, but the selectable model list should come from the backend integration when that is
practical.

Initially, the configured default model for the `auggie` backend should be `gpt5.4`.

For slice 1, deployment/runtime configuration may also provide backend-specific operational values
such as the `auggie` CLI executable path and the shared assistant workspace root. These are not
user-facing settings and are not persisted per session.

Model-catalog startup should be resilient:

- application startup should not fail merely because backend model discovery fails
- the model catalog should track per-backend availability or error state
- the assistant UI should still load even if model discovery failed for a backend
- if a backend's model list is unavailable, session creation or model selection for that backend
  should surface a clear error rather than silently guessing
- slice 1 does not require automatic background refresh of model lists
- a future explicit manual refresh API is acceptable but not required for slice 1

## Conversation ownership model

ExClaw owns the canonical transcript.

That means:

- sessions are local application records
- messages are local application records
- the UI renders from ExClaw persistence, not from backend-native history alone

The model is hybrid rather than backend-native-only, because ExClaw may also persist backend-native
identifiers when useful, such as:

- backend session ID
- backend run ID

This preserves portability while still allowing efficient continuation and better diagnostics.

## Application architecture

The assistant LiveView should not directly invoke backend integration details. Instead it should
call shared application-layer modules that handle:

- session loading and creation
- session update actions such as rename and archive
- user message persistence
- backend turn execution
- assistant message persistence on success
- run status tracking
- failure recording
- operational logging
- conversion of backend results into UI-friendly state

This keeps the LiveView thin and preserves a clean path for later reuse by HTTP endpoints.

## Persistence model

The persistence model is split into user-facing transcript records and operational records.

### Session records

Use a table such as `assistant_sessions` with fields equivalent to:

- `id`
- `user_id`
- `title`
- `backend`
- `current_model`
- `archived_at`
- `last_message_at`
- `inserted_at`
- `updated_at`

Notes:

- `archived_at` is preferred over a boolean flag because it preserves when archiving happened.
- `last_message_at` supports sorting the session list by recent activity.

### Message records

Use a table such as `assistant_messages` with fields equivalent to:

- `id`
- `session_id`
- `run_id` (nullable)
- `role` (`user` or `assistant` in slice 1)
- `content`
- `inserted_at`

Notes:

- user messages are persisted immediately when submitted
- assistant messages are persisted only on successful backend completion
- failed backend turns do not create fake successful assistant messages
- message records are append-only in slice 1, so `updated_at` is not required

### Run records

Use a table such as `assistant_runs` with fields equivalent to:

- `id`
- `session_id`
- `user_message_id`
- `model`
- `status`
- `backend_session_id` (nullable)
- `backend_run_id` (nullable)
- `exit_code` (nullable, for CLI-backed runs)
- `error_type` (nullable)
- `error_message` (nullable)
- `request_snapshot` (nullable)
- `response_snapshot` (nullable)
- `started_at`
- `finished_at` (nullable)
- `duration_ms` (nullable)
- `inserted_at`
- `updated_at`

Suggested statuses are:

- `running`
- `succeeded`
- `failed`
- `cancelled`
- `queued`

Only `running`, `succeeded`, and `failed` are required in slice 1, but keeping `queued` and
`cancelled` in the model now makes later extension easier.

### Run event records

Use a table such as `assistant_run_events` with fields equivalent to:

- `id`
- `run_id`
- `sequence`
- `kind`
- `payload`
- `occurred_at`
- `inserted_at`

Examples of `kind` values:

- `lifecycle`
- `tool_call`
- `tool_result`
- `stderr`
- `chunk`
- `note`

The event table exists so operational detail can be rich without forcing the transcript itself to
become an everything-timeline.

Run event records should be append-only in slice 1, so `updated_at` is not required there either.

## Schema semantics and invariants

This section is intended to make the persistence model implementable in a fresh session without
guessing at field meaning.

### `assistant_sessions`

- `id`: primary key for the assistant session.
- `user_id`: owner of the session. All session access must be scoped to the authenticated user.
- `title`: current display title for the session.
- `backend`: backend adapter for the session. In slice 1 this is a session-level invariant and is
  not intended to change after session creation.
- `current_model`: the model currently selected for the session. This is the default model for the
  next run in the session and may change over time.
- `archived_at`: timestamp when the session was archived. `NULL` means the session is active.
- `last_message_at`: timestamp of the most recently persisted transcript message in the session,
  whether from the user or the assistant. It should be updated when transcript messages are
  inserted, not merely when run events or diagnostics are recorded.
- `inserted_at`: when the session row was created.
- `updated_at`: when session metadata last changed, such as rename, archive, current model changes,
  or `last_message_at` updates.

Session invariants:

- Sessions belong to exactly one authenticated user.
- Archived sessions should normally be excluded from the default session list and landing-session
  lookup unless a feature explicitly asks for archived records, but direct access to an archived
  session owned by the current user remains allowed.
- The session list should sort primarily by recent activity using `last_message_at`.

### `assistant_messages`

- `id`: primary key for the transcript message.
- `session_id`: owning session for the transcript message.
- `run_id`: nullable linkage to the run that produced the message. In slice 1, user messages should
  keep this `NULL`; assistant messages produced by a successful run should point to that run.
- `role`: transcript role. In slice 1, the intended values are `user` and `assistant`.
- `content`: visible transcript body for the message.
- `inserted_at`: when the transcript message was persisted.

Message invariants:

- Messages are append-only in slice 1.
- A user message is persisted immediately on submission.
- An assistant message is persisted only for a successful run that produced a normal assistant
  reply.
- Failed runs must not create fake successful assistant messages.
- An assistant message's `session_id` must match the session of the run referenced by `run_id`.

### `assistant_runs`

- `id`: primary key for the backend execution attempt.
- `session_id`: session in which the run occurred.
- `user_message_id`: the user message that triggered this run.
- `model`: the actual model used for this execution attempt. This is a historical snapshot and may
  differ from the session's current model later.
- `status`: lifecycle state of the run. Intended values include `running`, `succeeded`, `failed`,
  and later possibly `queued` or `cancelled`.
- `backend_session_id`: backend-native conversation or session identifier, when the backend exposes
  one.
- `backend_run_id`: backend-native identifier for this specific execution attempt, when available.
- `exit_code`: process exit code for CLI-backed adapters when such a value exists.
- `error_type`: coarse machine-oriented error category for grouping or reporting.
- `error_message`: human-readable diagnostic detail for the run failure.
- `request_snapshot`: serialized record of what ExClaw sent to the backend. It may be raw,
  normalized, or a hybrid shape, and backend-specific content is allowed.
- `response_snapshot`: serialized record of what ExClaw received back from the backend. It may be
  raw, normalized, or a hybrid shape, and backend-specific content is allowed.
- `started_at`: when backend execution actually began.
- `finished_at`: when backend execution ended. `NULL` while the run is still active.
- `duration_ms`: persisted execution duration in milliseconds when known, normally derived from
  `started_at` and `finished_at`.
- `inserted_at`: when the run row was created in ExClaw.
- `updated_at`: when the run row was last mutated.

Run invariants:

- A run is one backend execution attempt, not a whole turn history.
- Retries create new run rows rather than overwriting previous failed runs.
- `user_message_id` must refer to a user message in the same session.
- In slice 1, at most one assistant message should point to a given run through
  `assistant_messages.run_id`.
- `started_at` and `inserted_at` may often be close or identical in slice 1, but they represent
  different concepts and should not be treated as synonyms.
- `finished_at` and `updated_at` may often be close or identical for terminal runs, but they also
  represent different concepts and should not be treated as synonyms.

### `assistant_run_events`

- `id`: primary key for the event row.
- `run_id`: owning run for the event.
- `sequence`: monotonic ordering key within a single run. It should be unique per run and used to
  reconstruct event order.
- `kind`: event category. This is an open string field with conventional values such as
  `lifecycle`, `tool_call`, `tool_result`, `stderr`, `chunk`, and `note`.
- `payload`: serialized event body. Backend-specific payloads are allowed so long as the UI and
  application layer can safely ignore unknown shapes.
- `occurred_at`: when the event occurred, or when it was observed if the backend does not provide a
  more exact event time.
- `inserted_at`: when the event row was stored in ExClaw.

Run event invariants:

- Run events are append-only in slice 1.
- Events are ordered per run by `sequence`, not globally across all runs.
- Event persistence exists to preserve operational detail without forcing the transcript itself to
  become a unified event timeline.

## Turn model and runtime flow

A turn in slice 1 is:

- one persisted user message
- zero or one successful assistant message
- one or more backend runs if retries happen

### Normal successful turn

1. user submits a message in a session
2. app persists the user message immediately
3. app creates a run record with status `running`
4. app invokes the selected backend for that session
5. while the run is active, the input for that session is disabled
6. on success:
   - app persists the assistant message
   - app updates the run to `succeeded`
   - app stores useful identifiers, snapshots, and events

### Failed turn

1. user message remains persisted
2. the failed run is updated to `failed`
3. useful error and diagnostic information is persisted
4. no successful assistant message is created for that run
5. the UI offers retry

### Retry behavior

Retry should create a new run associated with the same original user message while preserving the
previous failed run history.

In slice 1:

- retry should reuse the existing `user_message_id`
- retry should create a new `assistant_runs` row
- retry should not create a duplicate user transcript message
- the transcript should stay focused on the original user turn plus the eventual success or repeated
  failure state linked to that turn

## Concurrency model

Slice 1 allows only one active run per session.

That means:

- if a session has a running backend call, the composer for that session is disabled
- concurrent runs in the same session are out of scope
- queued follow-up messages in the same session are out of scope

However, the run model should preserve a clean path to future queueing by keeping run status
explicit and by not assuming there can only ever be one run record per user turn.

## Success, failure, and debug visibility

### Success state

The main success signal is the assistant reply appearing in the conversation.

Additional success detail should be subtle and available on demand, such as:

- completion time
- duration
- backend and model used

### Failure state

Failures must not be presented as if they were normal assistant replies.

Instead:

- the transcript remains chat-oriented
- failure state is represented through run status and debug information
- detailed diagnostics remain available inline for prototype debugging

### Debug presentation

Operational detail should be shown as inline expandable detail associated with the relevant turn
rather than in a fully separate inspector panel.

The inline detail may show:

- timestamps
- duration
- backend and model
- backend-native identifiers
- errors
- tool calls
- tool results
- other run events

This keeps operational context tied to the turn that produced it while still keeping transcript and
logs as separate stored concepts.

### Visual differentiation

Success and failure states should be visually distinguishable.

Use color coding and supporting UI cues such as icons or labels so the distinction is not conveyed
by color alone.

## Safety posture

Slice 1 does not add extra app-level permission gating on top of the chosen backend.

The safety stance for this slice is:

- capability is backend-dependent
- ExClaw relies on the backend and tool runtime permission model for now
- ExClaw does not yet implement per-session or per-action approval UI

This is acceptable for the first internal prototype but should be revisited before broader use.

## Quality gate

The required project quality gate is:

- `mix precommit`

For UI work, lightweight manual browser sanity checks should also be performed when relevant.

## Definition of done

Assistant slice 1 is done when all of the following are true:

- authenticated assistant routes exist under the existing authenticated LiveView scope
- the authenticated root route redirects to `/assistant`
- `/assistant` lands the user in the most recent session or creates one and navigates to it
- `/assistant/:session_id` renders a persisted session-specific assistant view
- sessions are scoped to the authenticated user through `current_scope`
- the UI supports create, switch, rename, and archive session actions
- new sessions persist default backend and current model values
- per-session model selection is supported
- runs snapshot the actual model used for each execution
- user messages persist immediately on submit
- `auggie` is integrated behind a shared backend abstraction
- successful runs persist assistant replies
- failed runs persist useful diagnostics without creating fake successful assistant messages
- per-turn inline debug detail is available in the UI
- success and failure states are visually distinguishable
- only one active run is allowed per session
- the persistence and application boundaries make a future `opencode` adapter addable without major
  restructuring
- `mix precommit` passes
