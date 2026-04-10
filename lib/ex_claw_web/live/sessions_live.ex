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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      main_class="flex min-h-0 flex-1 flex-col px-0 py-0"
      content_class="flex min-h-0 flex-1 w-full flex-col"
    >
      <section id="assistant-session-shell" class="flex min-h-0 flex-1 w-full flex-col">
        <div
          id="assistant-shell-layout"
          phx-hook=".AssistantShell"
          data-storage-key="assistant:sessions:sidebar-collapsed"
          class="relative flex min-h-0 flex-1 w-full overflow-hidden border-t border-base-300 bg-base-200/50"
        >
          <button
            id="assistant-sidebar-backdrop"
            type="button"
            data-visible="false"
            data-sidebar-backdrop
            aria-label="Close sessions sidebar"
            class="pointer-events-none fixed inset-0 z-30 bg-neutral-950/50 opacity-0 transition-opacity duration-300 data-[visible=true]:pointer-events-auto data-[visible=true]:opacity-100 lg:hidden"
          />

          <aside
            id="assistant-shell-sidebar"
            data-sidebar-collapsed="false"
            data-mobile-open="false"
            class="group fixed inset-y-0 left-0 z-40 flex w-[22rem] max-w-[85vw] -translate-x-full flex-col border-r border-base-300 bg-base-100/95 shadow-2xl transition-[transform,width] duration-300 data-[mobile-open=true]:translate-x-0 lg:static lg:z-auto lg:max-w-none lg:translate-x-0 lg:shadow-none lg:data-[sidebar-collapsed=true]:w-20"
          >
            <div
              id="assistant-sidebar-header"
              class="flex h-24 items-center justify-between gap-3 border-b border-base-300 px-4"
            >
              <div class="min-w-0 group-data-[sidebar-collapsed=true]:hidden">
                <h2 class="text-2xl font-semibold text-base-content sm:text-3xl">Sessions</h2>
              </div>

              <div class="flex items-center gap-2">
                <button
                  id="assistant-sidebar-desktop-toggle"
                  type="button"
                  data-sidebar-desktop-toggle
                  aria-controls="assistant-shell-sidebar"
                  aria-expanded="true"
                  aria-label="Collapse sessions sidebar"
                  class="hidden size-10 items-center justify-center rounded-2xl border border-base-300 bg-base-100 text-base-content transition hover:border-neutral-400 hover:bg-base-200 lg:inline-flex"
                >
                  <.icon name="hero-bars-3" class="size-5" />
                </button>

                <button
                  id="assistant-sidebar-mobile-close"
                  type="button"
                  data-sidebar-mobile-close
                  aria-label="Close sessions sidebar"
                  class="inline-flex size-10 items-center justify-center rounded-2xl border border-base-300 bg-base-100 text-base-content transition hover:border-neutral-400 hover:bg-base-200 lg:hidden"
                >
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>
            </div>

            <div class="hidden flex-col items-center gap-3 border-b border-base-300 px-3 py-3 group-data-[sidebar-collapsed=true]:flex">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-neutral-900 text-sm font-semibold tracking-[0.25em] text-white">
                AI
              </div>
              <div class="h-10 w-px bg-base-300" />
            </div>

            <div class="flex min-h-0 flex-1 flex-col px-3 py-3 group-data-[sidebar-collapsed=true]:px-2">
              <div
                id="assistant-sessions"
                phx-update="stream"
                class="space-y-3 overflow-y-auto group-data-[sidebar-collapsed=true]:hidden"
              >
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

              <div class="hidden flex-1 flex-col items-center justify-start gap-3 group-data-[sidebar-collapsed=true]:flex">
                <div class="mt-2 rounded-full border border-base-300 px-2 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-base-content/60">
                  {length(@streams.sessions.inserts)}
                </div>
                <div class="text-[10px] font-semibold uppercase tracking-[0.3em] text-base-content/50 [writing-mode:vertical-rl]">
                  Sessions
                </div>
              </div>
            </div>
          </aside>

          <section id="assistant-chat-panel" class="flex min-w-0 flex-1 flex-col bg-base-100/90">
            <div
              id="assistant-chat-header"
              class="flex h-24 items-center border-b border-base-300 bg-base-100/90 px-4 shadow-sm sm:px-6"
            >
              <div class="flex items-center gap-3">
                <button
                  id="assistant-mobile-sidebar-toggle"
                  type="button"
                  data-sidebar-mobile-toggle
                  aria-controls="assistant-shell-sidebar"
                  aria-expanded="false"
                  aria-label="Open sessions sidebar"
                  class="inline-flex size-11 shrink-0 items-center justify-center rounded-2xl border border-base-300 bg-base-100 text-base-content transition hover:border-neutral-400 hover:bg-base-200 lg:hidden"
                >
                  <.icon name="hero-bars-3" class="size-5" />
                </button>

                <div>
                  <h1
                    id="assistant-session-title"
                    class="text-2xl font-semibold text-base-content sm:text-3xl"
                  >
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
              class="flex-1 space-y-4 overflow-y-auto bg-base-200/35 px-4 py-6 sm:px-6"
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

            <div class="border-t border-base-300 bg-base-100 px-4 py-4 sm:px-6">
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
                  rows="5"
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
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".AssistantShell">
          const DESKTOP_QUERY = "(min-width: 1024px)"

          export default {
            mounted() {
              this.storageKey = this.el.dataset.storageKey || "assistant:sessions:sidebar-collapsed"
              this.sidebar = this.el.querySelector("#assistant-shell-sidebar")
              this.backdrop = this.el.querySelector("#assistant-sidebar-backdrop")
              this.desktopToggle = this.el.querySelector("[data-sidebar-desktop-toggle]")
              this.mobileToggle = this.el.querySelector("[data-sidebar-mobile-toggle]")
              this.mobileClose = this.el.querySelector("[data-sidebar-mobile-close]")
              this.mediaQuery = window.matchMedia(DESKTOP_QUERY)

              this.onDesktopToggle = () => this.toggleDesktopSidebar()
              this.onMobileOpen = () => this.setMobileOpen(true)
              this.onMobileClose = () => this.setMobileOpen(false)
              this.onMediaChange = () => this.applyStoredDesktopState()

              this.desktopToggle?.addEventListener("click", this.onDesktopToggle)
              this.mobileToggle?.addEventListener("click", this.onMobileOpen)
              this.mobileClose?.addEventListener("click", this.onMobileClose)
              this.backdrop?.addEventListener("click", this.onMobileClose)
              this.mediaQuery.addEventListener("change", this.onMediaChange)

              this.applyStoredDesktopState()
              this.setMobileOpen(false)
            },

            updated() {
              this.applyStoredDesktopState()
            },

            destroyed() {
              this.desktopToggle?.removeEventListener("click", this.onDesktopToggle)
              this.mobileToggle?.removeEventListener("click", this.onMobileOpen)
              this.mobileClose?.removeEventListener("click", this.onMobileClose)
              this.backdrop?.removeEventListener("click", this.onMobileClose)
              this.mediaQuery?.removeEventListener("change", this.onMediaChange)
              document.body.classList.remove("overflow-hidden")
            },

            toggleDesktopSidebar() {
              const collapsed = this.sidebar?.dataset.sidebarCollapsed === "true"
              this.setDesktopCollapsed(!collapsed)
            },

            applyStoredDesktopState() {
              if (!this.sidebar) return

              if (this.mediaQuery.matches) {
                this.setDesktopCollapsed(this.readStoredState())
              } else {
                this.sidebar.dataset.sidebarCollapsed = "false"
                this.syncDesktopToggle(false)
              }
            },

            setDesktopCollapsed(collapsed) {
              if (!this.sidebar) return

              this.sidebar.dataset.sidebarCollapsed = collapsed ? "true" : "false"
              this.syncDesktopToggle(collapsed)

              try {
                window.localStorage.setItem(this.storageKey, collapsed ? "true" : "false")
              } catch (_error) {
                // Ignore storage failures and keep the in-memory layout state.
              }
            },

            setMobileOpen(open) {
              if (!this.sidebar || !this.backdrop) return

              this.sidebar.dataset.mobileOpen = open ? "true" : "false"
              this.backdrop.dataset.visible = open ? "true" : "false"

              if (!this.mediaQuery.matches) {
                document.body.classList.toggle("overflow-hidden", open)
              }

              if (this.mobileToggle) {
                this.mobileToggle.setAttribute("aria-expanded", open ? "true" : "false")
              }
            },

            syncDesktopToggle(collapsed) {
              if (!this.desktopToggle) return

              this.desktopToggle.setAttribute("aria-expanded", collapsed ? "false" : "true")
              this.desktopToggle.setAttribute(
                "aria-label",
                collapsed ? "Expand sessions sidebar" : "Collapse sessions sidebar"
              )
            },

            readStoredState() {
              try {
                return window.localStorage.getItem(this.storageKey) === "true"
              } catch (_error) {
                return false
              }
            }
          }
        </script>
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
