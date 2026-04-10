defmodule ExClawWeb.AssistantComponents do
  use ExClawWeb, :html

  attr :session, :map, required: true
  attr :current_session_id, :integer, default: nil

  def session_list_item(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border px-4 py-3 shadow-sm transition duration-200",
      @current_session_id == @session.id && "border-neutral-900 bg-neutral-900 text-white",
      @current_session_id != @session.id &&
        "border-base-300 bg-base-100/90 hover:border-neutral-400 hover:bg-base-100"
    ]}>
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold">{@session.title}</p>
          <p class="mt-1 truncate text-xs opacity-75">
            {String.upcase(to_string(@session.backend))} · {@session.current_model}
          </p>
        </div>
        <span :if={!is_nil(@session.archived_at)} class="rounded-full border px-2 py-0.5 text-[10px]">
          Archived
        </span>
      </div>
    </div>
    """
  end

  attr :message, :map, required: true

  def message_bubble(assigns) do
    ~H"""
    <div class={[
      "flex",
      @message.role == :assistant && "justify-start",
      @message.role == :user && "justify-end"
    ]}>
      <div class={[
        "max-w-2xl rounded-3xl px-4 py-3 shadow-sm",
        @message.role == :assistant && "bg-base-200 text-base-content",
        @message.role == :user && "bg-neutral-900 text-white"
      ]}>
        <p class="mb-1 text-[11px] font-semibold uppercase tracking-[0.2em] opacity-70">
          {message_role_label(@message.role)}
        </p>
        <p class="whitespace-pre-wrap text-sm leading-6">{@message.content}</p>
      </div>
    </div>
    """
  end

  defp message_role_label(:assistant), do: "Assistant"
  defp message_role_label(:user), do: "You"
end
