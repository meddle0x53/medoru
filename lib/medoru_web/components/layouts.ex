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

  attr :socket, :any,
    default: nil,
    doc: "the parent socket when rendering in a LiveView"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-3 sm:px-4 lg:px-8 bg-base-100 border-b border-base-300 sticky top-0 z-40 h-16">
      <div class="flex-1 flex items-center gap-2">
        <%!-- Mobile Menu Toggle --%>
        <%= if @current_scope && @current_scope.current_user do %>
          <button
            type="button"
            class="xl:hidden btn btn-ghost btn-sm btn-circle -ml-2"
            phx-click={JS.toggle(to: "#mobile-nav-drawer")}
            aria-label={gettext("Menu")}
          >
            <.icon name="hero-bars-3" class="w-6 h-6" />
          </button>
        <% end %>

        <.link navigate={~p"/"} class="flex items-center gap-2 group">
          <img src={~p"/images/medoru_logo_h.png"} alt="Medoru" class="h-8 sm:h-10 w-auto" />
        </.link>
      </div>
      <div class="flex-none">
        <ul class="flex items-center space-x-1 sm:space-x-2">
          <%= if @current_scope && @current_scope.current_user do %>
            <%!-- Main Navigation --%>
            <.nav_link
              path="/dashboard"
              icon={nil}
              label={gettext("Dashboard")}
              locale={@current_scope[:locale]}
              class="hidden lg:block"
            />
            <.nav_link
              path="/lessons"
              icon={nil}
              label={gettext("Lessons")}
              locale={@current_scope[:locale]}
              class="hidden lg:block"
            />
            <.nav_link
              path="/kanji"
              icon={nil}
              label={gettext("Kanji")}
              locale={@current_scope[:locale]}
              class="hidden xl:block"
            />
            <.nav_link
              path="/words"
              icon={nil}
              label={gettext("Words")}
              locale={@current_scope[:locale]}
              class="hidden xl:block"
            />
            <.nav_link
              path="/classrooms"
              icon="hero-academic-cap"
              label={gettext("Classrooms")}
              locale={@current_scope[:locale]}
              class="hidden xl:block"
            />

            <%= if @current_scope.current_user.type in ["teacher", "admin"] do %>
              <.nav_link
                path="/teacher/tests"
                icon="hero-clipboard-document-list"
                label={gettext("My Tests")}
                locale={@current_scope[:locale]}
                class="hidden xl:block"
              />
              <.nav_link
                path="/teacher/custom-lessons"
                icon="hero-book-open"
                label={gettext("Custom Lessons")}
                locale={@current_scope[:locale]}
                class="hidden xl:block"
              />
            <% end %>

            <%= if @current_scope.current_user.type == "admin" do %>
              <.nav_link
                path="/admin"
                icon="hero-shield-check"
                label={gettext("Admin")}
                locale={@current_scope[:locale]}
                class="hidden md:block text-error"
              />
            <% end %>

            <%!-- Mobile Navigation Drawer --%>
            <div
              id="mobile-nav-drawer"
              class="fixed inset-0 z-50 hidden"
              phx-click-away={JS.hide(to: "#mobile-nav-drawer")}
            >
              <%!-- Backdrop --%>
              <div class="absolute inset-0 bg-black/50" phx-click={JS.hide(to: "#mobile-nav-drawer")}>
              </div>

              <%!-- Drawer Panel --%>
              <nav class="absolute left-0 top-0 bottom-0 w-72 max-w-[85vw] bg-base-100 shadow-2xl flex flex-col">
                <%!-- Drawer Header --%>
                <div class="p-4 border-b border-base-300 flex items-center justify-between">
                  <.link navigate={~p"/"} class="flex items-center gap-2">
                    <img src={~p"/images/medoru_logo_h.png"} alt="Medoru" class="h-8 w-auto" />
                  </.link>
                  <button
                    type="button"
                    class="btn btn-ghost btn-sm sm:btn-md btn-circle touch-target"
                    phx-click={JS.hide(to: "#mobile-nav-drawer")}
                    aria-label={gettext("Close menu")}
                  >
                    <.icon name="hero-x-mark" class="w-6 h-6" />
                  </button>
                </div>

                <%!-- User Info in Drawer --%>
                <div class="p-4 bg-base-200/50 border-b border-base-300">
                  <div class="flex items-center gap-3">
                    <%= if (@current_scope.current_user.profile && @current_scope.current_user.profile.avatar) || @current_scope.current_user.avatar_url do %>
                      <% avatar_src =
                        (@current_scope.current_user.profile &&
                           @current_scope.current_user.profile.avatar) ||
                          @current_scope.current_user.avatar_url %>
                      <img
                        src={avatar_src}
                        alt="Avatar"
                        class="w-12 h-12 rounded-full ring-2 ring-base-300"
                      />
                    <% else %>
                      <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center ring-2 ring-base-300">
                        <.icon name="hero-user" class="w-6 h-6 text-primary" />
                      </div>
                    <% end %>
                    <div class="min-w-0 flex-1">
                      <p class="font-medium text-base-content truncate">
                        {(@current_scope.current_user.profile &&
                            @current_scope.current_user.profile.display_name) ||
                          @current_scope.current_user.name || @current_scope.current_user.email}
                      </p>
                      <p class="text-xs text-secondary capitalize">
                        {@current_scope.current_user.type}
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Navigation Links --%>
                <div class="flex-1 overflow-y-auto py-2">
                  <div class="px-4 py-2 text-xs font-semibold text-secondary uppercase tracking-wider">
                    {gettext("Learning")}
                  </div>
                  <.mobile_nav_link
                    path="/dashboard"
                    icon="hero-home"
                    label={gettext("Dashboard")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/lessons"
                    icon="hero-book-open"
                    label={gettext("Lessons")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/kanji"
                    icon="hero-language"
                    label={gettext("Kanji")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/words"
                    icon="hero-document-text"
                    label={gettext("Words")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/daily-test"
                    icon="hero-calendar"
                    label={gettext("Daily Test")}
                    locale={@current_scope[:locale]}
                  />

                  <div class="px-4 py-2 mt-2 text-xs font-semibold text-secondary uppercase tracking-wider">
                    {gettext("Social")}
                  </div>
                  <.mobile_nav_link
                    path="/classrooms"
                    icon="hero-academic-cap"
                    label={gettext("Classrooms")}
                    locale={@current_scope[:locale]}
                  />

                  <%= if @current_scope.current_user.type in ["teacher", "admin"] do %>
                    <div class="px-4 py-2 mt-2 text-xs font-semibold text-secondary uppercase tracking-wider">
                      {gettext("Teacher")}
                    </div>
                    <.mobile_nav_link
                      path="/teacher/classrooms"
                      icon="hero-users"
                      label={gettext("My Classrooms")}
                      locale={@current_scope[:locale]}
                    />
                    <.mobile_nav_link
                      path="/teacher/tests"
                      icon="hero-clipboard-document-list"
                      label={gettext("My Tests")}
                      locale={@current_scope[:locale]}
                    />
                    <.mobile_nav_link
                      path="/teacher/custom-lessons"
                      icon="hero-book-open"
                      label={gettext("Custom Lessons")}
                      locale={@current_scope[:locale]}
                    />
                  <% end %>

                  <%= if @current_scope.current_user.type == "admin" do %>
                    <div class="px-4 py-2 mt-2 text-xs font-semibold text-secondary uppercase tracking-wider">
                      {gettext("Admin")}
                    </div>
                    <.mobile_nav_link
                      path="/admin"
                      icon="hero-shield-check"
                      label={gettext("Admin Dashboard")}
                      locale={@current_scope[:locale]}
                      class="text-error"
                    />
                  <% end %>
                </div>

                <%!-- Drawer Footer --%>
                <div class="border-t border-base-300 p-4 space-y-1">
                  <.mobile_nav_link
                    path="/users/#{@current_scope.current_user.id}"
                    icon="hero-user-circle"
                    label={gettext("My Profile")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/settings/profile"
                    icon="hero-cog-6-tooth"
                    label={gettext("Settings")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/settings/language"
                    icon="hero-language"
                    label={gettext("Language")}
                    locale={@current_scope[:locale]}
                  />
                  <.mobile_nav_link
                    path="/auth/logout"
                    icon="hero-arrow-right-on-rectangle"
                    label={gettext("Sign out")}
                    locale={@current_scope[:locale]}
                    method="delete"
                    class="text-error"
                  />
                </div>
              </nav>
            </div>

            <%!-- Language Selector --%>
            <li class="dropdown dropdown-end hidden sm:block">
              <div
                tabindex="0"
                role="button"
                class="btn btn-ghost btn-sm sm:btn-md btn-circle touch-target"
                title={gettext("Language")}
              >
                <span class="text-lg">{locale_flag(@current_scope[:locale])}</span>
              </div>
              <ul
                tabindex="0"
                class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-xl w-40 mt-2 border border-base-300"
              >
                <li class="menu-title px-3 py-2">
                  <span class="text-xs text-base-content/50">{gettext("Language")}</span>
                </li>
                <li>
                  <.link
                    href={~p"/?locale=en"}
                    class={locale_active_class(@current_scope[:locale], "en")}
                  >
                    <span>🇬🇧</span> {gettext("English")}
                  </.link>
                </li>
                <li>
                  <.link
                    href={~p"/?locale=bg"}
                    class={locale_active_class(@current_scope[:locale], "bg")}
                  >
                    <span>🇧🇬</span> {gettext("Bulgarian")}
                  </.link>
                </li>
                <li>
                  <.link
                    href={~p"/?locale=ja"}
                    class={locale_active_class(@current_scope[:locale], "ja")}
                  >
                    <span>🇯🇵</span> {gettext("Japanese")}
                  </.link>
                </li>
              </ul>
            </li>

            <%!-- Notifications Dropdown --%>
            <li class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                class="btn btn-ghost btn-sm sm:btn-md btn-circle relative touch-target"
              >
                <.icon name="hero-bell" class="w-5 h-5 sm:w-6 sm:h-6 text-secondary" />
                <%= if @current_scope.unread_count > 0 do %>
                  <span class="badge badge-xs badge-error absolute -top-1 -right-1">
                    {@current_scope.unread_count}
                  </span>
                <% end %>
              </div>
              <div
                tabindex="0"
                class="dropdown-content z-[1] bg-base-100 rounded-xl w-80 mt-2 border border-base-300 shadow-lg"
              >
                <%= if @socket do %>
                  {live_render(
                    @socket,
                    MedoruWeb.NotificationDropdownLive,
                    id: "notification-dropdown",
                    session: %{"user_id" => @current_scope.current_user.id}
                  )}
                <% else %>
                  <%!-- Static fallback for controller contexts --%>
                  <div class="py-4 text-center">
                    <.link navigate={~p"/notifications"} class="text-primary hover:underline">
                      {gettext("View all")} →
                    </.link>
                  </div>
                <% end %>
              </div>
            </li>

            <%!-- User Dropdown --%>
            <li class="dropdown dropdown-end ml-2 pl-2 sm:ml-4 sm:pl-4 border-l border-base-300">
              <div
                tabindex="0"
                role="button"
                class="flex items-center gap-2 btn btn-ghost btn-sm sm:btn-md p-1 sm:p-2 h-auto touch-target"
              >
                <%= if (@current_scope.current_user.profile && @current_scope.current_user.profile.avatar) || @current_scope.current_user.avatar_url do %>
                  <% avatar_src =
                    (@current_scope.current_user.profile && @current_scope.current_user.profile.avatar) ||
                      @current_scope.current_user.avatar_url %>
                  <img
                    src={avatar_src}
                    alt="Avatar"
                    class="w-8 h-8 sm:w-9 sm:h-9 rounded-full ring-2 ring-base-200"
                  />
                <% else %>
                  <div class="w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-primary/10 flex items-center justify-center ring-2 ring-base-200">
                    <.icon name="hero-user" class="w-4 h-4 sm:w-5 sm:h-5 text-primary" />
                  </div>
                <% end %>
                <span class="text-sm text-secondary hidden lg:block max-w-[120px] truncate">
                  {(@current_scope.current_user.profile &&
                      @current_scope.current_user.profile.display_name) ||
                    @current_scope.current_user.name || @current_scope.current_user.email}
                </span>
                <.icon name="hero-chevron-down" class="w-4 h-4 text-secondary/50 hidden lg:block" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-xl w-52 mt-2 border border-base-300"
              >
                <%= if @current_scope.current_user.type == "admin" do %>
                  <li class="menu-title px-3 py-2">
                    <span class="text-xs text-base-content/50">{gettext("Administration")}</span>
                  </li>
                  <li>
                    <.link navigate={~p"/admin"} class="flex items-center gap-2 text-error">
                      <.icon name="hero-shield-check" class="w-4 h-4" /> {gettext("Admin Dashboard")}
                    </.link>
                  </li>
                  <div class="divider my-1"></div>
                <% end %>
                <li class="menu-title px-3 py-2">
                  <span class="text-xs text-base-content/50">{gettext("Account")}</span>
                </li>
                <li>
                  <.link
                    navigate={
                      ~p"/users/#{@current_scope.current_user.id}?#{locale_qs(@current_scope[:locale])}"
                    }
                    class="flex items-center gap-2"
                  >
                    <.icon name="hero-user-circle" class="w-4 h-4" /> {gettext("My Profile")}
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/settings/profile?#{locale_qs(@current_scope[:locale])}"}
                    class="flex items-center gap-2"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" /> {gettext("Settings")}
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/settings/data-privacy?#{locale_qs(@current_scope[:locale])}"}
                    class="flex items-center gap-2"
                  >
                    <.icon name="hero-shield-check" class="w-4 h-4" /> {gettext("Data & Privacy")}
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/settings/language?#{locale_qs(@current_scope[:locale])}"}
                    class="flex items-center gap-2"
                  >
                    <.icon name="hero-language" class="w-4 h-4" /> {gettext("Language")}
                  </.link>
                </li>
                <div class="divider my-1"></div>
                <li>
                  <.link
                    href={~p"/auth/logout"}
                    method="delete"
                    class="text-error hover:bg-error/10"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> {gettext(
                      "Sign out"
                    )}
                  </.link>
                </li>
              </ul>
            </li>
          <% else %>
            <li>
              <.link
                href={~p"/auth/google"}
                class="inline-flex items-center gap-2 px-4 py-2 bg-base-100 border border-base-300 rounded-xl text-sm font-medium text-secondary hover:bg-base-200 hover:border-primary/30 transition-all"
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
                <span class="hidden sm:inline">{gettext("Sign in with Google")}</span>
                <span class="sm:hidden">{gettext("Sign in")}</span>
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    </header>

    <main class="min-h-screen bg-base-200">
      {render_slot(@inner_block)}
    </main>

    <%!-- Footer with Attribution --%>
    <footer class="bg-base-100 border-t border-base-300 py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-col md:flex-row items-center justify-between gap-4">
          <div class="text-sm text-secondary">
            <span>© 2025 Medoru</span>
            <span class="mx-2">·</span>
            <.link navigate={~p"/privacy"} class="hover:text-primary transition-colors">
              {gettext("Privacy")}
            </.link>
            <span class="mx-2">·</span>
            <.link navigate={~p"/cookies"} class="hover:text-primary transition-colors">
              {gettext("Cookies")}
            </.link>
            <span class="mx-2">·</span>
            <.link navigate={~p"/attribution"} class="hover:text-primary transition-colors">
              {gettext("Data Attribution")}
            </.link>
          </div>
          <div class="text-xs text-secondary/60">
            Data from <a
              href="https://github.com/davidluzgouveia/kanji-data"
              target="_blank"
              class="hover:text-primary"
            >Kanji Data</a>, <a
              href="http://kanjivg.tagaini.net"
              target="_blank"
              class="hover:text-primary"
            >KanjiVG</a>,
            <a
              href="https://github.com/skishore/makemeahanzi"
              target="_blank"
              class="hover:text-primary"
            >
              MakeMeAHanzi
            </a>
            & <a href="https://www.edrdg.org/" target="_blank" class="hover:text-primary">EDRDG</a>
          </div>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />

    <%!-- Cookie Consent Banner --%>
    <div
      id="cookie-banner"
      class="fixed bottom-0 left-0 right-0 z-50 bg-base-200 border-t border-base-300 p-4 shadow-lg hidden"
      data-cookie-banner
    >
      <div class="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="flex-1 text-sm">
          <p class="text-base-content">
            {gettext("We use cookies to enhance your learning experience.")}
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
            id="cookie-reject"
            class="btn btn-ghost btn-sm"
          >
            {gettext("Reject")}
          </button>
          <button
            id="cookie-accept"
            class="btn btn-primary btn-sm"
          >
            {gettext("Accept All")}
          </button>
        </div>
      </div>
    </div>
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
    <div
      id={@id}
      aria-live="polite"
      class="fixed top-4 right-4 z-50 space-y-4 w-[calc(100vw-2rem)] max-w-md"
    >
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

  # Language selector helpers

  defp locale_flag(nil), do: "🇬🇧"
  defp locale_flag("en"), do: "🇬🇧"
  defp locale_flag("bg"), do: "🇧🇬"
  defp locale_flag("ja"), do: "🇯🇵"
  defp locale_flag(_), do: "🇬🇧"

  defp locale_active_class(current_locale, target_locale) when current_locale == target_locale do
    "flex items-center gap-2 active bg-primary/10 text-primary"
  end

  defp locale_active_class(_current_locale, _target_locale) do
    "flex items-center gap-2"
  end

  defp locale_qs(nil), do: ""
  defp locale_qs("en"), do: ""
  defp locale_qs(locale), do: "locale=#{locale}"

  # Navigation link with locale preservation
  attr :path, :string, required: true
  attr :label, :string, required: true
  attr :locale, :string, default: nil
  attr :icon, :any, default: nil
  attr :class, :string, default: ""

  defp nav_link(assigns) do
    locale_suffix =
      if assigns.locale && assigns.locale != "en", do: "?locale=#{assigns.locale}", else: ""

    assigns = assign(assigns, :href, assigns.path <> locale_suffix)

    ~H"""
    <li class={@class}>
      <.link navigate={@href} class="btn btn-ghost btn-sm text-secondary">
        <%= if @icon do %>
          <.icon name={@icon} class="w-4 h-4 mr-1" />
        <% end %>
        {@label}
      </.link>
    </li>
    """
  end

  # Mobile navigation link for drawer
  attr :path, :string, required: true
  attr :label, :string, required: true
  attr :locale, :string, default: nil
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :method, :string, default: nil

  defp mobile_nav_link(assigns) do
    locale_suffix =
      if assigns.locale && assigns.locale != "en", do: "?locale=#{assigns.locale}", else: ""

    assigns =
      assigns
      |> assign(:href, assigns.path <> locale_suffix)
      |> assign(:is_delete, assigns.method == "delete")

    ~H"""
    <%= if @is_delete do %>
      <.link
        href={@href}
        method="delete"
        class={[
          "flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-base-200 transition-colors",
          @class
        ]}
        phx-click={JS.hide(to: "#mobile-nav-drawer")}
      >
        <.icon name={@icon} class="w-5 h-5 opacity-70" />
        {@label}
      </.link>
    <% else %>
      <.link
        navigate={@href}
        class={[
          "flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-base-200 transition-colors",
          @class
        ]}
        phx-click={JS.hide(to: "#mobile-nav-drawer")}
      >
        <.icon name={@icon} class="w-5 h-5 opacity-70" />
        {@label}
      </.link>
    <% end %>
    """
  end
end
