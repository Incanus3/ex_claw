defmodule ExClaw.Assistant.ModelCatalog do
  @moduledoc """
  Startup-loaded cache of backend model availability.
  """

  use GenServer

  alias ExClaw.Assistant.Backends

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    genserver_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  def backend_state(backend_id), do: backend_state(__MODULE__, backend_id)

  def backend_state(server, backend_id) do
    GenServer.call(server, {:backend_state, backend_id})
  end

  def available_models(backend_id), do: available_models(__MODULE__, backend_id)

  def available_models(server, backend_id) do
    case backend_state(server, backend_id) do
      %{status: :available, models: models} -> {:ok, models}
      %{status: :unavailable, reason: reason} -> {:error, reason}
    end
  end

  @impl true
  def init(opts) do
    backend_ids = Keyword.get(opts, :backend_ids, Backends.backend_ids())
    backends = Keyword.get(opts, :backends, Backends.registry())

    entries =
      Map.new(backend_ids, fn backend_id ->
        {backend_id, discover_backend(backend_id, Map.get(backends, backend_id))}
      end)

    {:ok, %{entries: entries}}
  end

  @impl true
  def handle_call({:backend_state, backend_id}, _from, state) do
    reply = Map.get(state.entries, backend_id, %{status: :unavailable, reason: :unknown_backend})
    {:reply, reply, state}
  end

  defp discover_backend(backend_id, nil) do
    %{status: :unavailable, reason: {:unknown_backend, backend_id}}
  end

  defp discover_backend(_backend_id, module) do
    case safe_list_models(module) do
      {:ok, models} -> %{status: :available, models: models}
      {:error, reason} -> %{status: :unavailable, reason: reason}
    end
  end

  defp safe_list_models(module) do
    apply(module, :list_models, [])
  rescue
    error in [UndefinedFunctionError] ->
      {:error, {:backend_unavailable, Exception.message(error)}}
  end
end
