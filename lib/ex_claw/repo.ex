defmodule ExClaw.Repo do
  use Ecto.Repo,
    otp_app: :ex_claw,
    adapter: Ecto.Adapters.SQLite3
end
