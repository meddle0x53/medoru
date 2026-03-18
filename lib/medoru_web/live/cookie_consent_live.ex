defmodule MedoruWeb.CookieConsentLive do
  @moduledoc """
  Cookie consent banner component for GDPR compliance.
  """
  use MedoruWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <%= if !@accepted do %>
      <div
        id="cookie-consent"
        class="fixed bottom-0 left-0 right-0 z-50 bg-base-200 border-t border-base-300 p-4 shadow-lg"
      >
        <div class="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div class="flex-1 text-sm">
            <p class="text-base-content">
              {gettext("We use cookies to enhance your learning experience and analyze our traffic.")}
              <.link navigate={~p"/privacy"} class="link link-primary">
                {gettext("Privacy Policy")}
              </.link>
              {gettext("and")}
              <.link navigate={~p"/cookies"} class="link link-primary">
                {gettext("Cookie Policy")}
              </.link>
            </p>
          </div>
          <div class="flex gap-2">
            <button
              phx-click="reject_cookies"
              phx-target={@myself}
              class="btn btn-ghost btn-sm"
            >
              {gettext("Reject")}
            </button>
            <button
              phx-click="accept_cookies"
              phx-target={@myself}
              class="btn btn-primary btn-sm"
            >
              {gettext("Accept All")}
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, accepted: false)}
  end

  @impl true
  def update(assigns, socket) do
    # Check cookie consent status from cookie
    accepted = get_cookie_consent(assigns)
    {:ok, assign(socket, accepted: accepted)}
  end

  @impl true
  def handle_event("accept_cookies", _params, socket) do
    # Set consent cookie (1 year expiry)
    {:noreply,
     socket
     |> push_event("set-cookie-consent", %{consent: "accepted"})
     |> assign(accepted: true)}
  end

  @impl true
  def handle_event("reject_cookies", _params, socket) do
    # Set rejection cookie (1 year expiry)
    {:noreply,
     socket
     |> push_event("set-cookie-consent", %{consent: "rejected"})
     |> assign(accepted: true)}
  end

  defp get_cookie_consent(assigns) do
    # Check if we have cookie consent from the connection
    case assigns[:cookie_consent] do
      "accepted" -> true
      "rejected" -> true
      _ -> false
    end
  end
end
