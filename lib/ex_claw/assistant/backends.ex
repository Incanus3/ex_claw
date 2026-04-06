defmodule ExClaw.Assistant.Backends do
  @moduledoc """
  Registry and configuration helpers for assistant backends.
  """

  @assistant_config ExClaw.Assistant

  def default_backend do
    config()
    |> Keyword.fetch!(:default_backend)
  end

  def default_model(backend_id) do
    backend_options(backend_id)
    |> Map.fetch!(:default_model)
  end

  def backend_options(backend_id) do
    config()
    |> Keyword.get(:backend_options, %{})
    |> Map.fetch!(backend_id)
  end

  def workspace_root do
    config()
    |> Keyword.fetch!(:workspace_root)
  end

  def registry do
    config()
    |> Keyword.get(:backends, %{})
  end

  def backend_ids do
    registry()
    |> Map.keys()
  end

  def fetch!(backend_id) do
    registry()
    |> Map.fetch!(backend_id)
  end

  def list_models(backend_id) do
    backend_id
    |> fetch!()
    |> invoke(:list_models, [])
  end

  def run_turn(backend_id, request) do
    backend_id
    |> fetch!()
    |> invoke(:run_turn, [request])
  end

  defp config do
    Application.get_env(:ex_claw, @assistant_config, [])
  end

  defp invoke(module, function_name, args) do
    apply(module, function_name, args)
  rescue
    error in [UndefinedFunctionError] ->
      {:error, {:backend_unavailable, Exception.message(error)}}
  end
end
