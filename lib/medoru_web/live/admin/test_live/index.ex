defmodule MedoruWeb.Admin.TestLive.Index do
  @moduledoc """
  Admin interface for listing and managing all tests.
  """
  use MedoruWeb, :live_view

  alias Medoru.Tests

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Test Management")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("Manage all tests across the platform. Total: %{count}", count: length(@tests))}
          </p>
        </div>

        <%!-- Filters --%>
        <div class="card bg-base-100 shadow-sm border border-base-300 mb-6">
          <div class="card-body">
            <div class="flex flex-col sm:flex-row sm:items-center gap-2">
              <span class="text-sm font-medium text-base-content/70 shrink-0">
                {gettext("Filter by status:")}
              </span>
              <div class="join join-horizontal flex-wrap">
                <button
                  phx-click="filter_status"
                  phx-value-status=""
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(is_nil(@status_filter), do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("All")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="draft"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "draft", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Draft")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="published"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "published", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Published")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="archived"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "archived", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Archived")}
                </button>
              </div>
              <%= if @status_filter do %>
                <button type="button" phx-click="clear_filters" class="btn btn-sm btn-ghost">
                  {gettext("Clear")}
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Tests Table --%>
        <div class="card bg-base-100 shadow-sm border border-base-300">
          <div class="hidden md:block table-responsive">
            <table class="table table-zebra w-full">
              <thead>
                <tr class="bg-base-200/50">
                  <th class="text-base-content/70">{gettext("Title")}</th>
                  <th class="text-base-content/70">{gettext("Type")}</th>
                  <th class="text-base-content/70">{gettext("Status")}</th>
                  <th class="text-base-content/70">{gettext("Creator")}</th>
                  <th class="text-base-content/70">{gettext("Created")}</th>
                  <th class="text-base-content/70 text-right">{gettext("Actions")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for test <- @tests do %>
                  <tr class="hover:bg-base-200/50">
                    <td>
                      <div class="font-medium text-base-content">{test.title}</div>
                      <div class="text-sm text-base-content/60">{test.description}</div>
                    </td>
                    <td>
                      <span class={["badge badge-sm", type_badge_color(test.test_type)]}>
                        {String.capitalize(to_string(test.test_type))}
                      </span>
                    </td>
                    <td>
                      <span class={["badge badge-sm", status_badge_color(test.status)]}>
                        {String.capitalize(to_string(test.status))}
                      </span>
                    </td>
                    <td>
                      <%= if test.creator do %>
                        <span class="text-sm">
                          {test.creator.name || test.creator.email}
                        </span>
                      <% else %>
                        <span class="text-sm text-base-content/50">{gettext("System")}</span>
                      <% end %>
                    </td>
                    <td class="text-base-content/70">
                      {Calendar.strftime(test.inserted_at, "%b %d, %Y")}
                    </td>
                    <td class="text-right">
                      <%= if test.status != :archived do %>
                        <button
                          phx-click="archive"
                          phx-value-id={test.id}
                          data-confirm={gettext("Archive this test?")}
                          class="btn btn-sm btn-ghost"
                        >
                          <.icon name="hero-archive-box" class="w-4 h-4" /> {gettext("Archive")}
                        </button>
                      <% else %>
                        <button
                          phx-click="unarchive"
                          phx-value-id={test.id}
                          class="btn btn-sm btn-ghost"
                        >
                          <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> {gettext("Restore")}
                        </button>
                      <% end %>
                      <button
                        phx-click="delete"
                        phx-value-id={test.id}
                        data-confirm={gettext("Permanently delete this test? This cannot be undone.")}
                        class="btn btn-sm btn-ghost text-error"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Mobile Cards --%>
          <div class="md:hidden divide-y divide-base-200">
            <%= for test <- @tests do %>
              <div class="p-4 hover:bg-base-200/50">
                <div class="flex items-start gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <span class="font-medium text-base-content">{test.title}</span>
                      <span class={["badge badge-sm", status_badge_color(test.status)]}>
                        {String.capitalize(to_string(test.status))}
                      </span>
                    </div>
                    <div class="text-sm text-base-content/60">
                      {String.capitalize(to_string(test.test_type))}
                      <%= if test.creator do %>
                        • {test.creator.name || test.creator.email}
                      <% end %>
                    </div>
                    <div class="text-xs text-secondary mt-1">
                      {Calendar.strftime(test.inserted_at, "%b %d, %Y")}
                    </div>
                  </div>
                  <div class="flex-shrink-0 flex flex-col gap-1">
                    <%= if test.status != :archived do %>
                      <button
                        phx-click="archive"
                        phx-value-id={test.id}
                        data-confirm={gettext("Archive?")}
                        class="btn btn-ghost btn-xs"
                        title={gettext("Archive")}
                      >
                        <.icon name="hero-archive-box" class="w-4 h-4" />
                      </button>
                    <% else %>
                      <button
                        phx-click="unarchive"
                        phx-value-id={test.id}
                        class="btn btn-ghost btn-xs"
                        title={gettext("Restore")}
                      >
                        <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
                      </button>
                    <% end %>
                    <button
                      phx-click="delete"
                      phx-value-id={test.id}
                      data-confirm={gettext("Delete?")}
                      class="btn btn-ghost btn-xs text-error"
                      title={gettext("Delete")}
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @tests == [] do %>
            <div class="p-12 text-center">
              <.icon
                name="hero-clipboard-document-list"
                class="w-12 h-12 text-base-content/30 mx-auto mb-4"
              />
              <p class="text-base-content/50">{gettext("No tests found matching your criteria.")}</p>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status_filter = params["status"]

    opts =
      []
      |> then(&if status_filter, do: [{:status, String.to_atom(status_filter)} | &1], else: &1)

    tests = Tests.list_all_tests(opts)

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Tests"))
     |> assign(:tests, tests)
     |> assign(:status_filter, status_filter)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_param = if status in ["draft", "ready", "published", "archived"], do: status, else: nil

    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/tests?#{%{status: status_param}}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/tests")}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    test = Tests.get_test!(id)
    {:ok, _} = Tests.archive_test(test)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    tests = Tests.list_all_tests(opts)

    {:noreply,
     socket
     |> assign(:tests, tests)
     |> put_flash(:info, gettext("Test archived."))}
  end

  @impl true
  def handle_event("unarchive", %{"id" => id}, socket) do
    test = Tests.get_test!(id)
    {:ok, _} = Tests.publish_test(test)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    tests = Tests.list_all_tests(opts)

    {:noreply,
     socket
     |> assign(:tests, tests)
     |> put_flash(:info, gettext("Test restored to published."))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    test = Tests.get_test!(id)
    {:ok, _} = Tests.delete_test(test)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    tests = Tests.list_all_tests(opts)

    {:noreply,
     socket
     |> assign(:tests, tests)
     |> put_flash(:info, gettext("Test deleted permanently."))}
  end

  def status_badge_color(:draft), do: "badge-ghost"
  def status_badge_color(:ready), do: "badge-info"
  def status_badge_color(:published), do: "badge-success"
  def status_badge_color(:archived), do: "badge-neutral"
  def status_badge_color(_), do: "badge-ghost"

  def type_badge_color(:daily), do: "badge-info"
  def type_badge_color(:lesson), do: "badge-primary"
  def type_badge_color(:teacher), do: "badge-warning"
  def type_badge_color(:practice), do: "badge-secondary"
  def type_badge_color(_), do: "badge-ghost"
end
