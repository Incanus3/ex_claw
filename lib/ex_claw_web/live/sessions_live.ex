defmodule ExClawWeb.SessionsLive do
  use ExClawWeb, :live_view

  alias Ecto.NoResultsError
  alias ExClaw.Assistant
  alias ExClaw.Assistant.Session
  alias ExClawWeb.AssistantComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_session, nil)
      |> assign(:session_archived?, false)
      |> assign(:composer_form, composer_form())
      |> stream(:sessions, [])
      |> stream(:messages, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :index -> {:noreply, redirect_to_current_session(socket)}
      :show -> {:noreply, load_session(socket, params["session_id"])}
    end
  end

  @impl true
  def handle_event("send", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="assistant-session-shell" class="grid gap-6 lg:grid-cols-[20rem_minmax(0,1fr)]">
        <aside
          id="assistant-session-list"
          class="rounded-[2rem] border border-base-300 bg-base-100/90 p-5 shadow-sm"
        >
          <div class="mb-5 flex items-start justify-between gap-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.25em] text-base-content/60">
                Assistant
              </p>
              <h2 class="mt-2 text-xl font-semibold text-base-content">Sessions</h2>
              <p class="mt-1 text-sm text-base-content/70">
                Resume recent work or review archived chats.
              </p>
            </div>
            <span class="rounded-full border border-base-300 px-3 py-1 text-xs text-base-content/60">
              Authenticated
            </span>
          </div>

          <div id="assistant-sessions" phx-update="stream" class="space-y-3">
            <div
              id="assistant-sessions-empty-state"
              class="hidden rounded-2xl border border-dashed border-base-300 p-4 text-sm text-base-content/60 only:block"
            >
              No sessions yet.
            </div>

            <div :for={{dom_id, session} <- @streams.sessions} id={dom_id}>
              <.link navigate={~p"/assistant/sessions/#{session.id}"} class="block">
                <AssistantComponents.session_list_item
                  session={session}
                  current_session_id={@current_session && @current_session.id}
                />
              </.link>
            </div>
          </div>
        </aside>

        <section class="flex min-h-[36rem] flex-col overflow-hidden rounded-[2rem] border border-base-300 bg-base-100/95 shadow-sm">
          <div class="border-b border-base-300 px-6 py-5">
            <p class="text-xs font-semibold uppercase tracking-[0.25em] text-base-content/60">
              Session
            </p>
            <div class="mt-2 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <h1 id="assistant-session-title" class="text-2xl font-semibold text-base-content">
                  {session_title(@current_session)}
                </h1>
                <p class="mt-1 text-sm text-base-content/70">
                  {session_subtitle(@current_session)}
                </p>
              </div>
            </div>
          </div>

          <div
            id="assistant-transcript"
            phx-update="stream"
            class="flex-1 space-y-4 overflow-y-auto bg-base-200/40 px-6 py-6"
          >
            <div
              id="assistant-transcript-empty-state"
              class="hidden rounded-3xl border border-dashed border-base-300 bg-base-100/80 p-6 text-sm text-base-content/60 only:block"
            >
              Start a conversation in this session.
            </div>

            <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
              <AssistantComponents.message_bubble message={message} />
            </div>
          </div>

          <div class="border-t border-base-300 bg-base-100 px-6 py-5">
            <p
              :if={@session_archived?}
              id="assistant-archived-notice"
              class="mb-3 rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900"
            >
              This session is archived.
            </p>

            <.form for={@composer_form} id="assistant-composer" phx-submit="send">
              <.input
                field={@composer_form[:content]}
                type="textarea"
                id="assistant-composer-input"
                label="Message"
                placeholder="Ask the assistant anything..."
                rows="4"
                disabled={@session_archived?}
              />

              <div class="mt-4 flex justify-end">
                <.button
                  id="assistant-composer-submit"
                  type="submit"
                  variant="primary"
                  disabled={@session_archived?}
                >
                  Send
                </.button>
              </div>
            </.form>
          </div>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp redirect_to_current_session(socket) do
    case Assistant.get_or_create_latest_session(socket.assigns.current_scope) do
      {:ok, session} -> push_navigate(socket, to: ~p"/assistant/sessions/#{session.id}")
      {:error, _changeset} -> put_flash(socket, :error, "Unable to open an assistant session.")
    end
  end

  defp load_session(socket, session_id) do
    current_scope = socket.assigns.current_scope

    case fetch_session(current_scope, session_id) do
      {:ok, session} ->
        socket
        |> assign(:current_session, session)
        |> assign(:session_archived?, archived?(session))
        |> assign(:composer_form, composer_form())
        |> stream(:sessions, visible_sessions(current_scope, session), reset: true)
        |> stream(:messages, Assistant.list_messages(current_scope, session), reset: true)

      :error ->
        socket
        |> put_flash(:error, "The requested assistant session is unavailable.")
        |> push_navigate(to: ~p"/assistant/sessions")
    end
  end

  defp fetch_session(current_scope, session_id) do
    {:ok, Assistant.get_session!(current_scope, session_id)}
  rescue
    NoResultsError -> :error
  end

  defp visible_sessions(current_scope, %Session{} = current_session) do
    sessions = Assistant.list_sessions(current_scope)

    if archived?(current_session) and Enum.all?(sessions, &(&1.id != current_session.id)) do
      [current_session | sessions]
    else
      sessions
    end
  end

  defp archived?(session), do: not is_nil(session.archived_at)

  defp composer_form do
    to_form(%{"content" => ""}, as: :assistant_message)
  end

  defp session_title(nil), do: "Loading session…"
  defp session_title(session), do: session.title

  defp session_subtitle(nil), do: "Preparing your assistant workspace."

  defp session_subtitle(session) do
    "#{String.upcase(to_string(session.backend))} · #{session.current_model}"
  end
end
