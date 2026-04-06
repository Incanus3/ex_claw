defmodule ExClaw.AssistantFixtures do
  @moduledoc """
  Test helpers for assistant persistence records.
  """

  import Ecto.Query
  import ExClaw.AccountsFixtures

  alias ExClaw.Assistant.{Message, Run, RunEvent, Session}
  alias ExClaw.Repo

  def assistant_session_fixture(current_scope \\ user_scope_fixture(), attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "New chat",
        backend: :auggie,
        current_model: ExClaw.Assistant.Backends.default_model(:auggie)
      })

    %Session{user_id: current_scope.user.id}
    |> Session.changeset(attrs)
    |> Repo.insert!()
  end

  def assistant_message_fixture(session, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        role: :user,
        content: "Test message"
      })

    message =
      %Message{session_id: session.id}
      |> Message.changeset(attrs)
      |> Repo.insert!()

    session
    |> Ecto.Changeset.change(last_message_at: message.inserted_at)
    |> Repo.update!()

    message
  end

  def assistant_run_fixture(session, user_message, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        model: session.current_model,
        status: :running,
        started_at: DateTime.utc_now(:second)
      })

    %Run{session_id: session.id, user_message_id: user_message.id}
    |> Run.changeset(attrs)
    |> Repo.insert!()
  end

  def assistant_run_event_fixture(run, attrs \\ %{}) do
    next_sequence =
      RunEvent
      |> where([event], event.run_id == ^run.id)
      |> select([event], max(event.sequence))
      |> Repo.one()
      |> case do
        nil -> 1
        sequence -> sequence + 1
      end

    attrs =
      Enum.into(attrs, %{
        sequence: next_sequence,
        kind: "note",
        payload: %{"message" => "fixture event"},
        occurred_at: DateTime.utc_now(:second)
      })

    %RunEvent{run_id: run.id}
    |> RunEvent.changeset(attrs)
    |> Repo.insert!()
  end
end
