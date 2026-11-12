defmodule MedoruWeb.LanguageSelectorComponent do
  @moduledoc """
  Top-bar language selector.

  Renders the current locale flag with a dropdown of supported locales.
  Clicking a locale persists it to the logged-in user's profile (server-side,
  applies on all devices), writes the `medoru_locale` cookie via the existing
  `phx:set_locale` JS listener, and reloads the CURRENT page via the
  `phx:reload_page` listener — so the user stays on the same page instead of
  being redirected to "/".
  """

  use MedoruWeb, :live_component

  alias Medoru.Accounts

  @supported_locales ["en", "bg", "ja"]

  @impl true
  def update(assigns, socket) do
    current_locale =
      assigns.current_scope[:locale] ||
        Gettext.get_locale(MedoruWeb.Gettext)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_locale, current_locale)}
  end

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket)
      when locale in @supported_locales do
    Gettext.put_locale(MedoruWeb.Gettext, locale)

    case socket.assigns.current_scope[:current_user] do
      %{profile: profile} when not is_nil(profile) ->
        Accounts.update_profile(profile, %{locale: locale})

      _ ->
        :ok
    end

    {:noreply,
     socket
     |> assign(:current_locale, locale)
     |> push_event("set_locale", %{locale: locale})
     |> push_event("reload_page", %{})}
  end

  def handle_event("set_locale", _params, socket), do: {:noreply, socket}

  attr :current_scope, :map, required: true
  attr :id, :string, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <li
      id={@id}
      class="dropdown dropdown-end hidden sm:block"
      data-active-locale={@current_locale}
    >
      <div
        tabindex="0"
        role="button"
        class="btn btn-ghost btn-sm sm:btn-md btn-circle touch-target"
        title={gettext("Language")}
      >
        <span class="text-lg">{flag(@current_locale)}</span>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-xl w-40 mt-2 border border-base-300"
      >
        <li class="menu-title px-3 py-2">
          <span class="text-xs text-base-content/50">{gettext("Language")}</span>
        </li>
        <%= for {code, flag, label} <- locales() do %>
          <li>
            <button
              type="button"
              phx-click="set_locale"
              phx-target={@myself}
              phx-value-locale={code}
              class={active_class(@current_locale, code)}
            >
              <span>{flag}</span> {label}
            </button>
          </li>
        <% end %>
      </ul>
    </li>
    """
  end

  defp locales do
    [
      {"en", "🇬🇧", gettext("English")},
      {"bg", "🇧🇬", gettext("Bulgarian")},
      {"ja", "🇯🇵", gettext("Japanese")}
    ]
  end

  defp flag(nil), do: "🇬🇧"
  defp flag("bg"), do: "🇧🇬"
  defp flag("ja"), do: "🇯🇵"
  defp flag(_), do: "🇬🇧"

  defp active_class(current, current),
    do: "active bg-primary/10 text-primary font-medium"

  defp active_class(_, _), do: ""
end
