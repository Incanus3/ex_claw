defmodule ExClaw.TestSupport.FakeAssistantBackend do
  @behaviour ExClaw.Assistant.Backend

  alias ExClaw.Assistant.Backends

  @impl true
  def list_models do
    default_model = Backends.default_model(:auggie)

    {:ok,
     [
       %{id: default_model, display_name: "Fake Model Default"},
       %{id: "fake-model-alt", display_name: "Fake Model Alt"}
     ]}
  end

  @impl true
  def run_turn(request) do
    case get_in(request, [:metadata, :result]) do
      :error ->
        {:error,
         %{
           error_type: "fake_backend_error",
           error_message: "Forced fake backend failure",
           request_snapshot: %{messages: request.messages, model: request.model},
           events: [%{kind: "note", payload: %{message: "fake backend failure"}}]
         }}

      _ ->
        {:ok,
         %{
           reply_text: "Fake assistant reply",
           backend_session_id: Map.get(request, :backend_session_id, "fake-session-1"),
           backend_run_id: "fake-run-1",
           request_snapshot: %{messages: request.messages, model: request.model},
           response_snapshot: %{reply_text: "Fake assistant reply"},
           events: [%{kind: "note", payload: %{message: "fake backend success"}}]
         }}
    end
  end
end
