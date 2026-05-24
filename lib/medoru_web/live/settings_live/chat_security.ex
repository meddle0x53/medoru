defmodule MedoruWeb.SettingsLive.ChatSecurity do
  @moduledoc """
  LiveView for managing chat encryption keys.
  Allows users to export and import their private keys for cross-device access.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Encryption

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    current_user = socket.assigns.current_scope.current_user

    has_previous_keys = Encryption.user_has_previous_keys?(current_user.id)

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:page_title, gettext("Chat Security"))
     |> assign(:has_previous_keys, has_previous_keys)}
  end

  @impl true
  def handle_event("register_public_key", %{"public_key" => public_key_b64}, socket) do
    current_user = socket.assigns.current_scope.current_user
    public_key_spki = Base.decode64!(public_key_b64)

    Encryption.store_public_key(current_user.id, public_key_spki)

    {:noreply, put_flash(socket, :info, gettext("Encryption key registered successfully."))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Chat Security")}</h1>
          <p class="text-secondary mt-2">
            {gettext("Manage your end-to-end encryption keys for secure messaging.")}
          </p>
        </div>

        <div class="space-y-6">
          <%!-- Key Status Card --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-base-content text-lg">
                <.icon name="hero-shield-check" class="w-5 h-5 text-success" />
                {gettext("Encryption Key Status")}
              </h2>

              <div
                id="chat-key-manager"
                phx-hook="ChatKeyManager"
                class="mt-4 space-y-4"
              >
                <div id="chat-key-status" class="text-sm text-warning">
                  {gettext("Checking key status...")}
                </div>

                <%= if @has_previous_keys do %>
                  <div class="p-3 bg-info/10 rounded-lg border border-info/20">
                    <div class="flex items-start gap-2">
                      <.icon name="hero-information-circle" class="w-4 h-4 text-info mt-0.5 shrink-0" />
                      <p class="text-sm text-info-content">
                        {gettext(
                          "We've detected that you've used a different encryption key before. If you're on a new device, make sure to import your original key to access old messages."
                        )}
                      </p>
                    </div>
                  </div>
                <% end %>

                <%!-- Export Section --%>
                <div class="space-y-2">
                  <label class="text-sm font-medium text-base-content">
                    {gettext("Your Encryption Key")}
                  </label>
                  <textarea
                    id="chat-key-display"
                    readonly
                    rows="3"
                    class="w-full px-3 py-2 bg-base-200 border border-base-300 rounded-lg text-xs font-mono text-base-content break-all resize-none"
                  ></textarea>
                  <button
                    id="chat-key-export-btn"
                    type="button"
                    class="btn btn-outline btn-sm"
                  >
                    <.icon name="hero-clipboard-document" class="w-4 h-4 mr-1" />
                    {gettext("Copy to Clipboard")}
                  </button>
                </div>

                <%!-- Import Section --%>
                <div class="pt-2 border-t border-base-200">
                  <button
                    id="chat-key-import-btn"
                    type="button"
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-1" />
                    {gettext("Import Key from Another Device")}
                  </button>

                  <div id="chat-key-import-area" class="hidden mt-3 space-y-2">
                    <label class="text-sm font-medium text-base-content">
                      {gettext("Paste your encryption key")}
                    </label>
                    <textarea
                      id="chat-key-import-input"
                      rows="3"
                      placeholder={gettext("Paste your private key here...")}
                      class="w-full px-3 py-2 bg-base-200 border border-base-300 rounded-lg text-xs font-mono text-base-content break-all resize-none"
                    ></textarea>
                    <div class="flex gap-2">
                      <button
                        id="chat-key-import-confirm"
                        type="button"
                        class="btn btn-primary btn-sm"
                      >
                        <.icon name="hero-check" class="w-4 h-4 mr-1" />
                        {gettext("Import Key")}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Warning Card --%>
          <div class="card bg-warning/5 border border-warning/20">
            <div class="card-body">
              <h3 class="card-title text-warning text-base">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                {gettext("Important")}
              </h3>
              <div class="text-sm text-base-content/80 space-y-2 mt-2">
                <p>
                  {gettext(
                    "Your private encryption key is stored only in your browser's local storage. If you clear your browser data or switch devices, you will lose access to your encrypted messages unless you back up this key."
                  )}
                </p>
                <p>
                  {gettext(
                    "Never share your private key with anyone. Medoru staff will never ask for it."
                  )}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
