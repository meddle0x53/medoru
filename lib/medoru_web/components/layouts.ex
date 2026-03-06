defmodule MedoruWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MedoruWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 bg-white border-b border-base-300">
      <div class="flex-1">
        <.link navigate={~p"/"} class="flex items-center gap-2">
          <span class="text-xl font-bold text-accent">Medoru</span>
          <span class="text-sm text-secondary/70">Learn Japanese</span>
        </.link>
      </div>
      <div class="flex-none">
        <ul class="flex items-center space-x-4">
          <%= if @current_scope && @current_scope.current_user do %>
            <li>
              <.link navigate={~p"/dashboard"} class="btn btn-ghost text-secondary">
                Dashboard
              </.link>
            </li>
            <li>
              <.link navigate={~p"/lessons"} class="btn btn-ghost text-secondary">
                Lessons
              </.link>
            </li>
            <li>
              <.link navigate={~p"/kanji"} class="btn btn-ghost text-secondary">
                Kanji
              </.link>
            </li>
            <li>
              <.link navigate={~p"/words"} class="btn btn-ghost text-secondary">
                Words
              </.link>
            </li>
            <li class="flex items-center gap-2 ml-4 pl-4 border-l border-base-300">
              <%= if @current_scope.current_user.avatar_url do %>
                <img
                  src={@current_scope.current_user.avatar_url}
                  alt="Avatar"
                  class="w-8 h-8 rounded-full"
                />
              <% else %>
                <div class="w-8 h-8 rounded-full bg-accent/20 flex items-center justify-center">
                  <.icon name="hero-user" class="w-4 h-4 text-accent" />
                </div>
              <% end %>
              <span class="text-sm text-secondary hidden sm:block">
                {@current_scope.current_user.name || @current_scope.current_user.email}
              </span>
              <.link
                href={~p"/auth/logout"}
                method="delete"
                class="ml-2 text-sm text-secondary/70 hover:text-red-600"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
              </.link>
            </li>
          <% else %>
            <li>
              <.link
                href={~p"/auth/google"}
                class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-base-300 rounded-lg text-sm font-medium text-secondary hover:bg-base-200 transition-colors"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24">
                  <path
                    fill="#4285F4"
                    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                  />
                  <path
                    fill="#34A853"
                    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  />
                  <path
                    fill="#FBBC05"
                    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  />
                  <path
                    fill="#EA4335"
                    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  />
                </svg>
                Sign in with Google
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    </header>

    <main class="min-h-screen bg-base-200">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="fixed top-4 right-4 z-50 space-y-4">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
