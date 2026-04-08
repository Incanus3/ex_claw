defmodule ExClaw.AssistantTest do
  use ExClaw.DataCase, async: false

  alias ExClaw.Assistant
  alias ExClaw.Assistant.{Message, Run, RunEvent, Session}

  import ExClaw.AccountsFixtures
  import ExClaw.AssistantFixtures

  describe "assistant session schema" do
    test "persists ownership, backend, current model, and archive semantics" do
      user = user_fixture()

      {:ok, session} =
        %Session{user_id: user.id}
        |> Session.changeset(%{title: "New chat", backend: :auggie, current_model: "gpt5.4"})
        |> Repo.insert()

      assert session.user_id == user.id
      assert session.backend == :auggie
      assert session.current_model == "gpt5.4"
      assert session.archived_at == nil
      assert session.last_message_at == nil

      archived_at = DateTime.utc_now(:second)

      {:ok, archived_session} =
        session
        |> Session.changeset(%{archived_at: archived_at})
        |> Repo.update()

      assert archived_session.archived_at == archived_at
    end
  end

  describe "assistant message schema" do
    test "stores user messages with nil run_id and assistant messages with run_id" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      {:ok, user_message} =
        %Message{session_id: session.id}
        |> Message.changeset(%{role: :user, content: "hello"})
        |> Repo.insert()

      assert user_message.run_id == nil
      assert user_message.role == :user

      run = ExClaw.AssistantFixtures.assistant_run_fixture(session, user_message)

      {:ok, assistant_message} =
        %Message{session_id: session.id, run_id: run.id}
        |> Message.changeset(%{role: :assistant, content: "hi"})
        |> Repo.insert()

      assert assistant_message.run_id == run.id
      assert assistant_message.role == :assistant
    end

    test "enforces run_id foreign key for assistant messages" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      assert_raise Ecto.ConstraintError, fn ->
        %Message{session_id: session.id, run_id: -1}
        |> Message.changeset(%{role: :assistant, content: "orphan"})
        |> Repo.insert()
      end
    end

    test "enforces at most one assistant message per run" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      user_message =
        ExClaw.AssistantFixtures.assistant_message_fixture(session, %{
          role: :user,
          content: "question"
        })

      run = ExClaw.AssistantFixtures.assistant_run_fixture(session, user_message)

      ExClaw.AssistantFixtures.assistant_message_fixture(session, %{
        role: :assistant,
        content: "answer",
        run_id: run.id
      })

      assert {:error, changeset} =
               %Message{session_id: session.id, run_id: run.id}
               |> Message.changeset(%{role: :assistant, content: "duplicate"})
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).run_id
    end
  end

  describe "assistant run schema" do
    test "persists mutable lifecycle fields and timestamps" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      user_message =
        ExClaw.AssistantFixtures.assistant_message_fixture(session, %{
          role: :user,
          content: "question"
        })

      started_at = DateTime.utc_now(:second)
      finished_at = DateTime.add(started_at, 2, :second)

      {:ok, run} =
        %Run{session_id: session.id, user_message_id: user_message.id}
        |> Run.changeset(%{model: "gpt5.4", status: :running, started_at: started_at})
        |> Repo.insert()

      assert run.status == :running
      assert run.started_at == started_at
      assert run.finished_at == nil
      assert run.inserted_at != nil
      assert run.updated_at != nil

      {:ok, updated_run} =
        run
        |> Run.changeset(%{status: :succeeded, finished_at: finished_at, duration_ms: 2_000})
        |> Repo.update()

      assert updated_run.status == :succeeded
      assert updated_run.finished_at == finished_at
      assert updated_run.duration_ms == 2_000
    end
  end

  describe "assistant run event schema" do
    test "stores append-only per-run ordered events" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      user_message =
        ExClaw.AssistantFixtures.assistant_message_fixture(session, %{
          role: :user,
          content: "question"
        })

      run = ExClaw.AssistantFixtures.assistant_run_fixture(session, user_message)

      event_2 =
        ExClaw.AssistantFixtures.assistant_run_event_fixture(run, %{
          sequence: 2,
          kind: "tool_result"
        })

      event_1 =
        ExClaw.AssistantFixtures.assistant_run_event_fixture(run, %{
          sequence: 1,
          kind: "tool_call"
        })

      ordered_events =
        RunEvent
        |> where([event], event.run_id == ^run.id)
        |> order_by([event], asc: event.sequence)
        |> Repo.all()

      assert Enum.map(ordered_events, & &1.sequence) == [1, 2]
      assert Enum.map(ordered_events, & &1.id) == [event_1.id, event_2.id]
      assert Enum.all?(ordered_events, &(&1.inserted_at != nil))
      refute Map.has_key?(hd(ordered_events), :updated_at)
    end
  end

  describe "assistant fixtures" do
    test "provide session, message, run, and run event helpers" do
      session = ExClaw.AssistantFixtures.assistant_session_fixture()

      message =
        ExClaw.AssistantFixtures.assistant_message_fixture(session, %{
          role: :user,
          content: "hello"
        })

      run = ExClaw.AssistantFixtures.assistant_run_fixture(session, message)
      event = ExClaw.AssistantFixtures.assistant_run_event_fixture(run)

      assert session.id
      assert message.id
      assert run.id
      assert event.id
    end
  end

  describe "assistant context session APIs" do
    test "list_sessions/1 returns the current user's active sessions ordered by recent activity" do
      current_scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      now = DateTime.utc_now(:second)

      older_session =
        assistant_session_fixture(current_scope, %{
          title: "Older session",
          last_message_at: DateTime.add(now, -60, :second)
        })

      recent_session =
        assistant_session_fixture(current_scope, %{
          title: "Recent session",
          last_message_at: now
        })

      _archived_session =
        assistant_session_fixture(current_scope, %{
          title: "Archived session",
          archived_at: now,
          last_message_at: DateTime.add(now, 60, :second)
        })

      _other_users_session =
        assistant_session_fixture(other_scope, %{
          title: "Other user's session",
          last_message_at: DateTime.add(now, 120, :second)
        })

      sessions = Assistant.list_sessions(current_scope)

      assert Enum.map(sessions, & &1.id) == [recent_session.id, older_session.id]
      assert Enum.all?(sessions, &is_nil(&1.archived_at))
      assert Enum.all?(sessions, &(&1.user_id == current_scope.user.id))
    end

    test "get_session!/2 returns an owned session even when archived" do
      current_scope = user_scope_fixture()
      archived_at = DateTime.utc_now(:second)

      session = assistant_session_fixture(current_scope, %{archived_at: archived_at})
      session_id = session.id

      assert %Session{id: ^session_id, archived_at: ^archived_at} =
               Assistant.get_session!(current_scope, session_id)
    end

    test "get_session!/2 raises for a session owned by another user" do
      current_scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      session = assistant_session_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Assistant.get_session!(current_scope, session.id)
      end
    end

    test "get_or_create_latest_session/1 returns the most recent non-archived session" do
      current_scope = user_scope_fixture()
      now = DateTime.utc_now(:second)

      older_session =
        assistant_session_fixture(current_scope, %{
          last_message_at: DateTime.add(now, -60, :second)
        })

      latest_session =
        assistant_session_fixture(current_scope, %{
          last_message_at: now
        })

      latest_session_id = latest_session.id

      assert {:ok, %Session{id: ^latest_session_id}} =
               Assistant.get_or_create_latest_session(current_scope)

      assert older_session.id != latest_session.id
    end

    test "get_or_create_latest_session/1 creates a default session when no active session exists" do
      current_scope = user_scope_fixture()

      _archived_session =
        assistant_session_fixture(current_scope, %{archived_at: DateTime.utc_now(:second)})

      assert {:ok, session} = Assistant.get_or_create_latest_session(current_scope)

      assert session.user_id == current_scope.user.id
      assert session.title == "New chat"
      assert session.backend == :auggie
      assert session.current_model == "fake-model-default"
      assert session.archived_at == nil
    end

    test "create_session/2 uses configured defaults" do
      current_scope = user_scope_fixture()

      assert {:ok, session} = Assistant.create_session(current_scope)

      assert session.user_id == current_scope.user.id
      assert session.title == "New chat"
      assert session.backend == :auggie
      assert session.current_model == "fake-model-default"
    end

    test "rename_session/3 updates the session title" do
      current_scope = user_scope_fixture()
      session = assistant_session_fixture(current_scope, %{title: "Before"})

      assert {:ok, renamed_session} =
               Assistant.rename_session(current_scope, session, %{title: "After"})

      assert renamed_session.title == "After"
    end

    test "archive_session/2 archives the session" do
      current_scope = user_scope_fixture()
      session = assistant_session_fixture(current_scope)

      assert {:ok, archived_session} = Assistant.archive_session(current_scope, session)

      assert %DateTime{} = archived_session.archived_at
    end

    test "update_session_model/3 persists the selected model for future runs" do
      current_scope = user_scope_fixture()
      session = assistant_session_fixture(current_scope)

      assert {:ok, updated_session} =
               Assistant.update_session_model(current_scope, session, "fake-model-2")

      assert updated_session.current_model == "fake-model-2"
    end
  end

  describe "assistant context lifecycle APIs" do
    test "create_user_message/3 persists a user message and updates last_message_at" do
      current_scope = user_scope_fixture()
      session = assistant_session_fixture(current_scope)

      assert {:ok, message} =
               Assistant.create_user_message(current_scope, session, %{content: "hello"})

      assert message.role == :user
      assert message.run_id == nil

      session = Repo.get!(Session, session.id)
      assert session.last_message_at == message.inserted_at
    end

    test "start_run!/3 snapshots the session model and supports retries with the same user message" do
      session = assistant_session_fixture()
      user_message = assistant_message_fixture(session, %{role: :user, content: "hello"})

      first_run = Assistant.start_run!(session, user_message)
      second_run = Assistant.start_run!(session, user_message)

      assert first_run.status == :running
      assert first_run.model == session.current_model
      assert first_run.user_message_id == user_message.id
      assert %DateTime{} = first_run.started_at

      assert second_run.id != first_run.id
      assert second_run.user_message_id == user_message.id
      assert second_run.model == session.current_model
    end

    test "complete_run!/2 marks the run succeeded, persists the assistant reply, and updates last_message_at" do
      session = assistant_session_fixture()
      user_message = assistant_message_fixture(session, %{role: :user, content: "hello"})
      run = Assistant.start_run!(session, user_message)
      finished_at = DateTime.add(run.started_at, 2, :second)

      completed_run =
        Assistant.complete_run!(run, %{
          reply_text: "Hi there",
          backend_run_id: "backend-run-1",
          response_snapshot: %{"reply" => "Hi there"},
          finished_at: finished_at
        })

      assert completed_run.status == :succeeded
      assert completed_run.finished_at == finished_at
      assert completed_run.duration_ms == 2_000
      assert completed_run.backend_run_id == "backend-run-1"

      assistant_message = Repo.get_by!(Message, run_id: run.id, role: :assistant)
      assert assistant_message.content == "Hi there"

      session = Repo.get!(Session, session.id)
      assert session.last_message_at == assistant_message.inserted_at
    end

    test "fail_run!/2 marks the run failed without creating an assistant message or changing last_message_at" do
      session = assistant_session_fixture()
      user_message = assistant_message_fixture(session, %{role: :user, content: "hello"})
      run = Assistant.start_run!(session, user_message)
      finished_at = DateTime.add(run.started_at, 3, :second)

      failed_run =
        Assistant.fail_run!(run, %{
          error_type: "backend_error",
          error_message: "something went wrong",
          finished_at: finished_at
        })

      assert failed_run.status == :failed
      assert failed_run.finished_at == finished_at
      assert failed_run.duration_ms == 3_000
      assert failed_run.error_type == "backend_error"
      assert failed_run.error_message == "something went wrong"

      assert Repo.get_by(Message, run_id: run.id, role: :assistant) == nil

      session = Repo.get!(Session, session.id)
      assert session.last_message_at == user_message.inserted_at
    end

    test "record_run_events!/2 appends ordered events without changing last_message_at" do
      session = assistant_session_fixture()
      user_message = assistant_message_fixture(session, %{role: :user, content: "hello"})
      run = Assistant.start_run!(session, user_message)
      _existing_event = assistant_run_event_fixture(run, %{sequence: 1})

      events =
        Assistant.record_run_events!(run, [
          %{kind: "lifecycle", payload: %{"status" => "started"}},
          %{kind: "stderr", payload: %{"line" => "warning"}}
        ])

      assert Enum.map(events, & &1.sequence) == [2, 3]

      session = Repo.get!(Session, session.id)
      assert session.last_message_at == user_message.inserted_at
    end

    test "record_run_events!/2 tolerates concurrent sequence allocation for the same run" do
      session = assistant_session_fixture()
      user_message = assistant_message_fixture(session, %{role: :user, content: "hello"})
      run = Assistant.start_run!(session, user_message)

      results =
        1..12
        |> Task.async_stream(
          fn index ->
            Assistant.record_run_events!(run, [
              %{kind: "note", payload: %{"index" => index}}
            ])
          end,
          max_concurrency: 12,
          ordered: false,
          timeout: :infinity
        )
        |> Enum.to_list()

      assert Enum.all?(results, &match?({:ok, [_event]}, &1))

      sequences =
        RunEvent
        |> where([event], event.run_id == ^run.id)
        |> order_by([event], asc: event.sequence)
        |> Repo.all()
        |> Enum.map(& &1.sequence)

      assert sequences == Enum.to_list(1..12)
    end
  end
end
