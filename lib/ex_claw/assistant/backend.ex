defmodule ExClaw.Assistant.Backend do
  @moduledoc """
  Shared assistant backend contract.
  """

  @type model_info :: %{
          required(:id) => String.t(),
          required(:display_name) => String.t(),
          optional(:description) => String.t(),
          optional(:context_window) => pos_integer(),
          optional(:supports_tools?) => boolean(),
          optional(:supports_streaming?) => boolean(),
          optional(:metadata) => map()
        }

  @type message :: %{required(:role) => :user | :assistant, required(:content) => String.t()}

  @type run_request :: %{
          required(:run_id) => term(),
          required(:session_id) => term(),
          required(:model) => String.t(),
          required(:messages) => [message()],
          required(:workspace_root) => String.t(),
          optional(:backend_session_id) => String.t() | nil,
          optional(:stream?) => boolean(),
          optional(:metadata) => map()
        }

  @type event :: %{
          required(:kind) => String.t(),
          optional(:payload) => map(),
          optional(:occurred_at) => DateTime.t() | NaiveDateTime.t()
        }

  @type run_success :: %{
          required(:reply_text) => String.t(),
          optional(:backend_session_id) => String.t(),
          optional(:backend_run_id) => String.t(),
          optional(:request_snapshot) => map(),
          optional(:response_snapshot) => map(),
          optional(:events) => [event()]
        }

  @type run_failure :: %{
          required(:error_type) => String.t(),
          required(:error_message) => String.t(),
          optional(:backend_session_id) => String.t(),
          optional(:backend_run_id) => String.t(),
          optional(:request_snapshot) => map(),
          optional(:response_snapshot) => map(),
          optional(:events) => [event()]
        }

  @callback list_models() :: {:ok, [model_info()]} | {:error, term()}
  @callback run_turn(run_request()) :: {:ok, run_success()} | {:error, run_failure()}
end
