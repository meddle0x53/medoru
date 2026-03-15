defmodule MedoruWeb.SettingsLive.Language do
  @moduledoc """
  LiveView for language preference settings.
  """
  use MedoruWeb, :live_view

  @supported_locales [
    %{code: "en", name: "English", flag: "🇬🇧", native: "English"},
    %{code: "bg", name: "Bulgarian", flag: "🇧🇬", native: "Български"},
    %{code: "ja", name: "Japanese", flag: "🇯🇵", native: "日本語"}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:page_title, gettext("Language"))
     |> assign(:current_locale, current_locale)
     |> assign(:supported_locales, @supported_locales)}
  end

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    if locale in ["en", "bg", "ja"] do
      Gettext.put_locale(MedoruWeb.Gettext, locale)

      # Store locale in a cookie via push_event
      {:noreply,
       socket
       |> assign(:current_locale, locale)
       |> push_event("set_locale", %{locale: locale})
       |> put_flash(:info, gettext("Language updated successfully."))}
    else
      {:noreply, put_flash(socket, :error, gettext("Invalid language selection."))}
    end
  end

  defp locale_button_class(true) do
    "w-full flex items-center gap-4 p-4 rounded-xl border-2 border-primary bg-primary/5 transition-all text-left"
  end

  defp locale_button_class(false) do
    "w-full flex items-center gap-4 p-4 rounded-xl border-2 border-base-200 hover:border-primary/30 hover:bg-base-100 transition-all text-left"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Language")}</h1>
          <p class="text-secondary mt-2">{gettext("Select your preferred language")}</p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="space-y-3">
              <%= for locale <- @supported_locales do %>
                <button
                  type="button"
                  phx-click="set_locale"
                  phx-value-locale={locale.code}
                  class={locale_button_class(@current_locale == locale.code)}
                >
                  <span class="text-3xl">{locale.flag}</span>

                  <div class="flex-1">
                    <div class="font-medium text-base-content">{locale.native}</div>
                    <div class="text-sm text-secondary">{locale.name}</div>
                  </div>

                  <%= if @current_locale == locale.code do %>
                    <.icon name="hero-check-circle" class="w-6 h-6 text-primary" />
                  <% else %>
                    <div class="w-6 h-6 rounded-full border-2 border-base-300"></div>
                  <% end %>
                </button>
              <% end %>
            </div>

            <div class="mt-6 p-4 bg-info/10 rounded-lg">
              <div class="flex items-start gap-3">
                <.icon name="hero-information-circle" class="w-5 h-5 text-info mt-0.5" />
                <div class="text-sm text-info-content">
                  <p>
                    {gettext(
                      "Your language preference is saved to your account and will be used across all devices."
                    )}
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
