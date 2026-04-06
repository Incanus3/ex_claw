defmodule ExClaw.Assistant.RunEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias ExClaw.Assistant.Run

  schema "assistant_run_events" do
    field :sequence, :integer
    field :kind, :string
    field :payload, :map
    field :occurred_at, :utc_datetime

    belongs_to :run, Run

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(run_event, attrs) do
    run_event
    |> cast(attrs, [:sequence, :kind, :payload, :occurred_at])
    |> validate_required([:sequence, :kind, :occurred_at])
    |> validate_number(:sequence, greater_than: 0)
    |> foreign_key_constraint(:run_id)
    |> unique_constraint(:sequence, name: :assistant_run_events_run_id_sequence_idx)
  end
end
