defmodule ExClaw.AssistantTest do
  use ExClaw.DataCase, async: false

  alias ExClaw.Assistant.{Message, Run, RunEvent, Session}

  import ExClaw.AccountsFixtures

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
end
