defmodule ExClaw.Assistant do
  @moduledoc """
  Public assistant context APIs for sessions, messages, runs, and run events.
  """

  @run_event_sequence_retry_attempts 20

  import Ecto.Query

  alias ExClaw.Assistant.{Backends, Message, Run, RunEvent, Session}
  alias ExClaw.Repo

  def list_sessions(current_scope) do
    current_scope
    |> user_sessions_query()
    |> where([session], is_nil(session.archived_at))
    |> order_by([session], desc: session.last_message_at, desc: session.inserted_at)
    |> Repo.all()
  end

  def get_session!(current_scope, id) do
    current_scope
    |> user_sessions_query()
    |> Repo.get_by!(id: id)
  end

  def get_or_create_latest_session(current_scope) do
    case latest_active_session(current_scope) do
      nil -> create_session(current_scope)
      session -> {:ok, session}
    end
  end

  def create_session(current_scope, attrs \\ %{}) do
    attrs = session_attrs(attrs)

    %Session{user_id: current_scope.user.id}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def rename_session(current_scope, %Session{id: id}, attrs) do
    current_scope
    |> get_session!(id)
    |> Session.changeset(Map.new(attrs))
    |> Repo.update()
  end

  def archive_session(current_scope, %Session{id: id}) do
    current_scope
    |> get_session!(id)
    |> Session.changeset(%{archived_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  def update_session_model(current_scope, %Session{id: id}, model) do
    current_scope
    |> get_session!(id)
    |> Session.changeset(%{current_model: model})
    |> Repo.update()
  end

  def list_messages(current_scope, %Session{id: id}) do
    current_scope
    |> get_session!(id)
    |> Repo.preload(
      messages: from(message in Message, order_by: [asc: message.inserted_at, asc: message.id])
    )
    |> Map.get(:messages)
  end

  def create_user_message(current_scope, %Session{id: id}, attrs) do
    session = get_session!(current_scope, id)
    attrs = Map.put(Map.new(attrs), :role, :user)

    Repo.transaction(fn ->
      with {:ok, message} <- insert_message(session.id, attrs),
           {:ok, _session} <- update_last_message_at(session, message.inserted_at) do
        message
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def start_run!(session, user_message, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:model, session.current_model)
      |> Map.put_new(:status, :running)
      |> Map.put_new(:started_at, DateTime.utc_now(:second))

    %Run{session_id: session.id, user_message_id: user_message.id}
    |> Run.changeset(attrs)
    |> Repo.insert!()
  end

  def complete_run!(run, attrs) do
    {reply_text, run_attrs} = complete_run_attrs(run, attrs)

    Repo.transaction(fn ->
      persist_completed_run!(run, run_attrs, reply_text)
    end)
    |> unwrap_transaction_result!()
  end

  def fail_run!(run, attrs) do
    attrs = Map.new(attrs)
    finished_at = Map.get(attrs, :finished_at, DateTime.utc_now(:second))

    run
    |> Run.changeset(
      attrs
      |> Map.put(:status, :failed)
      |> Map.put(:finished_at, finished_at)
      |> Map.put_new(:duration_ms, duration_ms(run.started_at, finished_at))
    )
    |> Repo.update!()
  end

  def record_run_events!(run, events) do
    record_run_events!(run, events, @run_event_sequence_retry_attempts)
  end

  defp latest_active_session(current_scope) do
    current_scope
    |> user_sessions_query()
    |> where([session], is_nil(session.archived_at))
    |> order_by([session], desc: session.last_message_at, desc: session.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp user_sessions_query(current_scope) do
    from(session in Session, where: session.user_id == ^current_scope.user.id)
  end

  defp session_attrs(attrs) do
    attrs = Map.new(attrs)
    backend = Map.get(attrs, :backend, Backends.default_backend())

    %{title: "New chat", backend: backend, current_model: Backends.default_model(backend)}
    |> Map.merge(attrs)
  end

  defp insert_message(session_id, attrs) do
    %Message{session_id: session_id}
    |> Message.changeset(Map.new(attrs))
    |> Repo.insert()
  end

  defp insert_message!(session_id, attrs) do
    %Message{session_id: session_id}
    |> Message.changeset(Map.new(attrs))
    |> Repo.insert!()
  end

  defp update_last_message_at(session, occurred_at) do
    session
    |> Session.changeset(%{last_message_at: occurred_at})
    |> Repo.update()
  end

  defp update_last_message_at!(session_id, occurred_at) do
    Repo.get!(Session, session_id)
    |> Session.changeset(%{last_message_at: occurred_at})
    |> Repo.update!()
  end

  defp current_max_sequence(run_id) do
    RunEvent
    |> where([event], event.run_id == ^run_id)
    |> select([event], max(event.sequence))
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp duration_ms(started_at, finished_at) do
    DateTime.diff(finished_at, started_at, :millisecond)
  end

  defp record_run_events!(run, events, attempts_left) do
    case record_run_events_transaction(run.id, events) do
      {:ok, inserted_events} ->
        inserted_events

      {:error, changeset} ->
        retry_or_raise_run_event_conflict(run, events, attempts_left, changeset)
    end
  end

  defp record_run_events_transaction(run_id, events) do
    Repo.transaction(fn ->
      start_sequence = current_max_sequence(run_id)

      events
      |> Enum.with_index(start_sequence + 1)
      |> Enum.reduce_while([], fn {event_attrs, sequence}, inserted_events ->
        case insert_run_event(run_id, event_attrs, sequence) do
          {:ok, event} -> {:cont, [event | inserted_events]}
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
      |> Enum.reverse()
    end)
  end

  defp retry_or_raise_run_event_conflict(run, events, attempts_left, changeset)
       when attempts_left > 1 do
    if run_event_sequence_conflict?(changeset) do
      Process.sleep(run_event_retry_delay_ms(attempts_left))
      record_run_events!(run, events, attempts_left - 1)
    else
      raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
    end
  end

  defp retry_or_raise_run_event_conflict(_run, _events, _attempts_left, changeset) do
    raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
  end

  defp run_event_sequence_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:sequence, {_message, options}} -> options[:constraint] == :unique
      _other -> false
    end)
  end

  defp run_event_retry_delay_ms(attempts_left) do
    @run_event_sequence_retry_attempts - attempts_left + 1
  end

  defp complete_run_attrs(run, attrs) do
    attrs = Map.new(attrs)
    {reply_text, attrs} = Map.pop(attrs, :reply_text)
    finished_at = Map.get(attrs, :finished_at, DateTime.utc_now(:second))

    run_attrs =
      attrs
      |> Map.put(:status, :succeeded)
      |> Map.put(:finished_at, finished_at)
      |> Map.put_new(:duration_ms, duration_ms(run.started_at, finished_at))

    {reply_text, run_attrs}
  end

  defp persist_completed_run!(run, run_attrs, reply_text) do
    updated_run =
      run
      |> Run.changeset(run_attrs)
      |> Repo.update!()

    assistant_message =
      insert_message!(run.session_id, %{role: :assistant, content: reply_text, run_id: run.id})

    update_last_message_at!(run.session_id, assistant_message.inserted_at)
    updated_run
  end

  defp insert_run_event(run_id, event_attrs, sequence) do
    %RunEvent{run_id: run_id}
    |> RunEvent.changeset(run_event_attrs(event_attrs, sequence))
    |> Repo.insert()
  end

  defp run_event_attrs(event_attrs, sequence) do
    event_attrs
    |> Map.new()
    |> Map.put(:sequence, sequence)
    |> Map.put_new(:occurred_at, DateTime.utc_now(:second))
  end

  defp unwrap_transaction_result!({:ok, value}), do: value
  defp unwrap_transaction_result!({:error, reason}), do: raise(reason)
end
