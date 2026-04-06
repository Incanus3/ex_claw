defmodule ExClaw.Assistant.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias ExClaw.Assistant.{Run, Session}

  schema "assistant_messages" do
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string

    belongs_to :session, Session
    belongs_to :run, Run, foreign_key: :run_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :run_id])
    |> validate_required([:role, :content])
    |> validate_role_run_consistency()
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:run_id)
    |> unique_constraint(:run_id, name: :assistant_messages_run_id_index)
  end

  defp validate_role_run_consistency(changeset) do
    case {get_field(changeset, :role), get_field(changeset, :run_id)} do
      {:user, nil} -> changeset
      {:user, _run_id} -> add_error(changeset, :run_id, "must be blank for user messages")
      {:assistant, nil} -> add_error(changeset, :run_id, "can't be blank for assistant messages")
      {:assistant, _run_id} -> changeset
      _ -> changeset
    end
  end
end
