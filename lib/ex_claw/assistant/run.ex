defmodule ExClaw.Assistant.Run do
  use Ecto.Schema
  import Ecto.Changeset

  alias ExClaw.Assistant.{Message, RunEvent, Session}

  schema "assistant_runs" do
    field :model, :string
    field :status, Ecto.Enum, values: [:queued, :running, :succeeded, :failed, :cancelled]
    field :backend_session_id, :string
    field :backend_run_id, :string
    field :exit_code, :integer
    field :error_type, :string
    field :error_message, :string
    field :request_snapshot, :map
    field :response_snapshot, :map
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :duration_ms, :integer

    belongs_to :session, Session
    belongs_to :user_message, Message
    has_many :events, RunEvent
    has_one :assistant_message, Message, foreign_key: :run_id

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :model,
      :status,
      :backend_session_id,
      :backend_run_id,
      :exit_code,
      :error_type,
      :error_message,
      :request_snapshot,
      :response_snapshot,
      :started_at,
      :finished_at,
      :duration_ms
    ])
    |> validate_required([:model, :status, :started_at])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_message_id)
  end
end
