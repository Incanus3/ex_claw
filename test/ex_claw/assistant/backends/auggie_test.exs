defmodule ExClaw.Assistant.Backends.AuggieTest do
  use ExUnit.Case, async: false

  alias ExClaw.Assistant.{Backend, Backends, ModelCatalog}

  defmodule FailingBackend do
    @behaviour Backend

    @impl true
    def list_models, do: {:error, :model_discovery_failed}

    @impl true
    def run_turn(_request) do
      {:error, %{error_type: "not_implemented", error_message: "not implemented"}}
    end
  end

  describe "assistant backend configuration" do
    test "returns configured backend defaults" do
      assert Backends.default_backend() == :auggie
      assert Backends.default_model(:auggie) == "fake-model-default"
    end

    test "resolves configured backend ids to modules" do
      assert Backends.fetch!(:auggie) == ExClaw.TestSupport.FakeAssistantBackend
    end
  end

  describe "shared backend discovery" do
    test "calls model discovery through the configured backend module" do
      assert {:ok, models} = Backends.list_models(:auggie)

      assert [first_model | _] = models
      assert first_model.id == "fake-model-default"
      assert first_model.display_name == "Fake Model Default"
    end
  end

  describe "model catalog" do
    test "returns startup-loaded models for a backend" do
      assert {:ok, models} = ModelCatalog.available_models(:auggie)
      assert Enum.any?(models, &(&1.id == "fake-model-default"))
    end

    test "captures model discovery failures as unavailable state instead of crashing startup" do
      pid =
        start_supervised!(
          {ModelCatalog, backend_ids: [:failing], backends: %{failing: FailingBackend}, name: nil}
        )

      assert %{status: :unavailable, reason: :model_discovery_failed} =
               ModelCatalog.backend_state(pid, :failing)

      assert {:error, :model_discovery_failed} = ModelCatalog.available_models(pid, :failing)
    end
  end

  describe "fake backend scaffold" do
    test "returns deterministic success and failure results for run_turn/1" do
      request = %{
        run_id: "run-1",
        session_id: "session-1",
        model: "fake-model-default",
        messages: [%{role: :user, content: "hello"}],
        workspace_root: "/tmp/ex_claw"
      }

      assert {:ok, success} = ExClaw.TestSupport.FakeAssistantBackend.run_turn(request)
      assert success.reply_text == "Fake assistant reply"
      assert success.request_snapshot.messages == request.messages

      assert {:error, failure} =
               ExClaw.TestSupport.FakeAssistantBackend.run_turn(
                 Map.put(request, :metadata, %{result: :error})
               )

      assert failure.error_type == "fake_backend_error"
      assert failure.error_message == "Forced fake backend failure"
    end
  end
end
