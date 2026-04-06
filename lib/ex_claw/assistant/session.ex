defmodule ExClaw.Assistant.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias ExClaw.Accounts.User
  alias ExClaw.Assistant.{Message, Run}

  schema "assistant_sessions" do
    field :title, :string
    field :backend, Ecto.Enum, values: [:auggie]
    field :current_model, :string
    field :archived_at, :utc_datetime
    field :last_message_at, :utc_datetime

    belongs_to :user, User
    has_many :messages, Message
    has_many :runs, Run

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :backend, :current_model, :archived_at, :last_message_at])
    |> validate_required([:title, :backend, :current_model])
    |> foreign_key_constraint(:user_id)
  end
end
