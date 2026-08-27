defmodule MedoruWeb.ChatAIComponents do
  @moduledoc """
  Function components for the chat AI assistant modal.
  """

  use Phoenix.Component
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.CoreComponents, only: [icon: 1]

  attr :open, :boolean, required: true
  attr :prompt, :string, default: nil
  attr :response, :string, default: nil
  attr :explanation, :string, default: nil

  def ai_response_modal(assigns) do
    ~H"""
    <%= if @open do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <%!-- Backdrop --%>
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm"
          phx-click="close_ai_response_modal"
        >
        </div>

        <%!-- Modal --%>
        <div class="relative w-full max-w-lg max-h-[90vh] bg-base-100 rounded-2xl shadow-2xl flex flex-col">
          <%!-- Header --%>
          <div class="flex items-center justify-between px-4 py-3 border-b border-base-300 shrink-0">
            <h3 class="font-medium text-base-content">
              {gettext("AI suggestion")}
            </h3>
            <button
              type="button"
              phx-click="close_ai_response_modal"
              class="p-1 text-base-content/40 hover:text-base-content transition-colors"
              title={gettext("Close")}
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <%!-- Body --%>
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <div>
              <label class="block text-xs font-medium text-base-content/70 mb-1">
                {gettext("Response")}
              </label>
              <form phx-change="update_ai_response" class="block">
                <textarea
                  name="response"
                  rows="4"
                  class="w-full px-3 py-2 bg-base-200 border border-base-300 rounded-xl text-base-content placeholder:text-base-content/40 focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"
                ><%= @response %></textarea>
              </form>
            </div>

            <div>
              <label class="block text-xs font-medium text-base-content/70 mb-1">
                {gettext("Explanation")}
              </label>
              <div class="p-3 bg-base-200/70 border border-base-300 rounded-xl text-sm text-base-content/80 whitespace-pre-wrap">
                {@explanation}
              </div>
            </div>
          </div>

          <%!-- Footer --%>
          <div class="flex items-center justify-end gap-2 px-4 py-3 border-t border-base-300 shrink-0 flex-wrap">
            <button
              type="button"
              phx-click="close_ai_response_modal"
              class="btn btn-ghost btn-sm"
            >
              {gettext("Cancel")}
            </button>
            <button
              type="button"
              phx-click="regenerate_ai_response"
              phx-value-prompt={@prompt}
              class="btn btn-secondary btn-sm"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" />
              {gettext("Regenerate")}
            </button>
            <button
              type="button"
              phx-click="send_ai_response"
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-paper-airplane" class="w-4 h-4 mr-1" />
              {gettext("Send")}
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
