defmodule ExClaw.Repo.Migrations.CreateAssistantCoreTables do
  use Ecto.Migration

  def change do
    create table(:assistant_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :backend, :string, null: false
      add :current_model, :string, null: false
      add :archived_at, :utc_datetime
      add :last_message_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:assistant_sessions, [:user_id])

    create index(:assistant_sessions, [:user_id, :last_message_at],
             where: "archived_at IS NULL",
             name: :assistant_sessions_active_recent_idx
           )

    create table(:assistant_messages) do
      add :session_id, references(:assistant_sessions, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:assistant_messages, [:session_id])

    create table(:assistant_runs) do
      add :session_id, references(:assistant_sessions, on_delete: :delete_all), null: false
      add :user_message_id, references(:assistant_messages, on_delete: :delete_all), null: false
      add :model, :string, null: false
      add :status, :string, null: false
      add :backend_session_id, :string
      add :backend_run_id, :string
      add :exit_code, :integer
      add :error_type, :string
      add :error_message, :string
      add :request_snapshot, :map
      add :response_snapshot, :map
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :duration_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:assistant_runs, [:session_id])
    create index(:assistant_runs, [:user_message_id])

    alter table(:assistant_messages) do
      add :run_id, references(:assistant_runs, on_delete: :delete_all)
    end

    create unique_index(:assistant_messages, [:run_id],
             where: "run_id IS NOT NULL",
             name: :assistant_messages_unique_run_id_idx
           )

    create table(:assistant_run_events) do
      add :run_id, references(:assistant_runs, on_delete: :delete_all), null: false
      add :sequence, :integer, null: false
      add :kind, :string, null: false
      add :payload, :map
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:assistant_run_events, [:run_id])

    create unique_index(:assistant_run_events, [:run_id, :sequence],
             name: :assistant_run_events_run_id_sequence_idx
           )
  end
end
