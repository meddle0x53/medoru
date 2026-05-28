defmodule MedoruWeb.SettingsLive.ChatShortcuts do
  @moduledoc """
  LiveView for chat keyboard shortcut settings.
  Allows users to choose whether Enter sends messages or creates paragraphs.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user

    profile =
      Accounts.get_user_profile(user.id) ||
        %{chat_enter_sends: true}

    enter_sends = profile.chat_enter_sends != false

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:page_title, gettext("Chat Shortcuts"))
     |> assign(:enter_sends, enter_sends)}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, :enter_sends, !socket.assigns.enter_sends)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    user = socket.assigns.current_scope.current_user
    enter_sends = socket.assigns.enter_sends

    case Accounts.update_settings(user, %{chat_enter_sends: enter_sends}) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Chat shortcuts updated successfully."))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to update chat shortcuts."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Chat Shortcuts")}</h1>
          <p class="text-secondary mt-2">
            {gettext("Choose how the Enter key behaves when typing messages.")}
          </p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body space-y-6">
            <%!-- Option A: Enter sends, Shift+Enter for paragraph --%>
            <button
              type="button"
              phx-click="toggle"
              class={[
                "w-full flex items-start gap-4 p-4 rounded-xl border-2 transition-all text-left",
                if(@enter_sends,
                  do: "border-primary bg-primary/5 ring-1 ring-primary",
                  else: "border-base-300 hover:border-primary/30 hover:bg-base-100"
                )
              ]}
            >
              <div class={[
                "w-10 h-10 rounded-lg flex items-center justify-center shrink-0 font-mono text-sm",
                if(@enter_sends,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-secondary"
                )
              ]}>
                ↵
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-base-content">{gettext("Enter to send")}</span>
                  <%= if @enter_sends do %>
                    <.icon name="hero-check-circle" class="w-5 h-5 text-primary" />
                  <% end %>
                </div>
                <p class="text-sm text-secondary mt-1">
                  {gettext("Press Enter to send a message. Use Shift+Enter to add a new line.")}
                </p>
              </div>
            </button>

            <%!-- Option B: Shift+Enter sends, Enter for paragraph --%>
            <button
              type="button"
              phx-click="toggle"
              class={[
                "w-full flex items-start gap-4 p-4 rounded-xl border-2 transition-all text-left",
                if(!@enter_sends,
                  do: "border-primary bg-primary/5 ring-1 ring-primary",
                  else: "border-base-300 hover:border-primary/30 hover:bg-base-100"
                )
              ]}
            >
              <div class={[
                "w-10 h-10 rounded-lg flex items-center justify-center shrink-0 font-mono text-sm",
                if(!@enter_sends,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-secondary"
                )
              ]}>
                ⇧↵
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-base-content">{gettext("Shift+Enter to send")}</span>
                  <%= if !@enter_sends do %>
                    <.icon name="hero-check-circle" class="w-5 h-5 text-primary" />
                  <% end %>
                </div>
                <p class="text-sm text-secondary mt-1">
                  {gettext("Press Shift+Enter to send a message. Use Enter to add a new line.")}
                </p>
              </div>
            </button>

            <%!-- Save Button --%>
            <div class="pt-2">
              <button
                type="button"
                phx-click="save"
                class="w-full px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-xl font-medium transition-all"
              >
                {gettext("Save Preferences")}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
