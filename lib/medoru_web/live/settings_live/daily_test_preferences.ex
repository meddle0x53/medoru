defmodule MedoruWeb.SettingsLive.DailyTestPreferences do
  @moduledoc """
  LiveView for daily test preference settings.
  Allows users to choose which question types to include in their daily tests.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    profile = Accounts.get_user_profile(user.id) || %{daily_test_step_types: ["word_to_meaning", "word_to_reading", "reading_text"]}

    selected_types = profile.daily_test_step_types || ["word_to_meaning", "word_to_reading", "reading_text"]

    # Define step types at runtime so gettext uses the correct locale
    available_step_types = [
      %{id: "word_to_meaning", label: gettext("Word to Meaning"), icon: "hero-book-open", description: gettext("Show a Japanese word and select the English meaning")},
      %{id: "word_to_reading", label: gettext("Word to Reading"), icon: "hero-language", description: gettext("Show a Japanese word and select the hiragana reading")},
      %{id: "reading_text", label: gettext("Type Meaning & Reading"), icon: "hero-pencil", description: gettext("Type both the English meaning and hiragana reading")},
      %{id: "image_to_meaning", label: gettext("Image to Meaning"), icon: "hero-photo", description: gettext("Show a Japanese word and select from image options")}
    ]

    {:ok,
     socket
     |> assign(:page_title, gettext("Daily Test Preferences"))
     |> assign(:available_step_types, available_step_types)
     |> assign(:selected_types, selected_types)
     |> assign(:changeset, nil)}
  end

  @impl true
  def handle_event("toggle_type", %{"type" => type}, socket) do
    current_types = socket.assigns.selected_types

    new_types =
      if type in current_types do
        # Don't allow unchecking the last type
        if length(current_types) > 1 do
          List.delete(current_types, type)
        else
          current_types
        end
      else
        [type | current_types]
      end

    {:noreply, assign(socket, :selected_types, new_types)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    user = socket.assigns.current_scope.current_user
    selected_types = socket.assigns.selected_types

    case Accounts.update_user_daily_test_preferences(user.id, selected_types) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Daily test preferences updated successfully."))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, gettext("Failed to update preferences."))}
    end
  end

  defp step_type_card_class(selected) do
    if selected do
      "border-primary bg-primary/5 ring-1 ring-primary"
    else
      "border-base-300 hover:border-primary/30 hover:bg-base-100"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Daily Test Preferences")}</h1>
          <p class="text-secondary mt-2">
            {gettext("Choose which question types to include in your daily review tests.")}
          </p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <%!-- Question Type Selection --%>
            <div class="space-y-4">
              <h2 class="text-sm font-medium text-secondary uppercase tracking-wide">
                {gettext("Question Types")}
              </h2>

              <%= for step_type <- @available_step_types do %>
                <% is_selected = step_type.id in @selected_types %>
                <button
                  type="button"
                  phx-click="toggle_type"
                  phx-value-type={step_type.id}
                  class={[
                    "w-full flex items-start gap-4 p-4 rounded-xl border-2 transition-all text-left",
                    step_type_card_class(is_selected)
                  ]}
                >
                  <div class={[
                    "w-10 h-10 rounded-lg flex items-center justify-center shrink-0",
                    if(is_selected, do: "bg-primary text-primary-content", else: "bg-base-200 text-secondary")
                  ]}>
                    <.icon name={step_type.icon} class="w-5 h-5" />
                  </div>

                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="font-medium text-base-content">{step_type.label}</span>
                      <%= if is_selected do %>
                        <.icon name="hero-check-circle" class="w-5 h-5 text-primary" />
                      <% end %>
                    </div>
                    <p class="text-sm text-secondary mt-1">{step_type.description}</p>
                  </div>

                  <%= if is_selected do %>
                    <div class="w-6 h-6 rounded-full border-2 border-primary bg-primary flex items-center justify-center shrink-0">
                      <.icon name="hero-check" class="w-4 h-4 text-primary-content" />
                    </div>
                  <% else %>
                    <div class="w-6 h-6 rounded-full border-2 border-base-300 shrink-0"></div>
                  <% end %>
                </button>
              <% end %>
            </div>

            <%!-- Warning if only one selected --%>
            <%= if length(@selected_types) == 1 do %>
              <div class="mt-4 p-4 bg-warning/10 rounded-lg">
                <div class="flex items-start gap-3">
                  <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning mt-0.5" />
                  <div class="text-sm text-warning-content">
                    <p>
                      {gettext("You must have at least one question type selected.")}
                    </p>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Save Button --%>
            <div class="mt-6">
              <button
                type="button"
                phx-click="save"
                class="w-full px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-xl font-medium transition-all"
              >
                {gettext("Save Preferences")}
              </button>
            </div>

            <%!-- Info Box --%>
            <div class="mt-6 p-4 bg-info/10 rounded-lg">
              <div class="flex items-start gap-3">
                <.icon name="hero-information-circle" class="w-5 h-5 text-info mt-0.5" />
                <div class="text-sm text-info-content">
                  <p class="font-medium mb-1">{gettext("How this works:")}</p>
                  <p>
                    {gettext("Your daily test will randomly select from your chosen question types. New words will start with easier question types, while review words include more challenging ones based on your progress.")}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
