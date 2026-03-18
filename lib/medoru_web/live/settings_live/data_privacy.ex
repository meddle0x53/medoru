defmodule MedoruWeb.SettingsLive.DataPrivacy do
  @moduledoc """
  GDPR data privacy management page for users.
  Allows users to export or delete their personal data.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Classrooms

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    {:ok,
     socket
     |> assign(:page_title, gettext("Data & Privacy"))
     |> assign(:user, user)
     |> assign(:show_delete_confirm, false)
     |> assign(:export_status, nil)}
  end

  @impl true
  def handle_event("export_data", _params, socket) do
    user = socket.assigns.user

    # Gather all user data
    user_data = %{
      profile: %{
        email: user.email,
        name: user.name,
        provider: user.provider,
        type: user.type,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      },
      user_profile: serialize_profile(user.profile),
      learning_progress: list_learning_progress(user.id),
      classroom_memberships: list_classroom_data(user.id),
      test_sessions: list_test_sessions(user.id),
      badges: list_user_badges(user.id),
      notifications: list_notifications(user.id),
      exported_at: DateTime.utc_now()
    }

    # Generate JSON file
    json_data = Jason.encode!(user_data, pretty: true)

    {:noreply,
     socket
     |> assign(:export_status, :ready)
     |> push_event("download-data", %{
       filename: "medoru-data-export-#{user.id}.json",
       content: json_data
     })}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    user = socket.assigns.user

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your account has been deleted."))
         |> push_navigate(to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete account. Please contact support."))
         |> assign(:show_delete_confirm, false)}
    end
  end

  defp serialize_profile(nil), do: nil

  defp serialize_profile(profile) do
    %{
      display_name: profile.display_name,
      bio: profile.bio,
      avatar: profile.avatar,
      timezone: profile.timezone,
      daily_goal: profile.daily_goal,
      theme: profile.theme,
      featured_badge_id: profile.featured_badge_id,
      inserted_at: profile.inserted_at,
      updated_at: profile.updated_at
    }
  end

  defp list_learning_progress(user_id) do
    # Get user's learning progress
    case function_exported?(Medoru.Learning, :list_user_progress, 1) do
      true -> Medoru.Learning.list_user_progress(user_id)
      false -> []
    end
  end

  defp list_classroom_data(user_id) do
    # Simplified - get user's classroom memberships
    memberships = Classrooms.list_classroom_memberships(user_id)

    Enum.map(memberships, fn m ->
      %{
        classroom_id: m.classroom_id,
        status: m.status,
        role: m.role,
        points: m.points,
        inserted_at: m.inserted_at,
        updated_at: m.updated_at
      }
    end)
  end

  defp list_test_sessions(user_id) do
    # Get user's test attempts
    Medoru.Tests.list_test_sessions(user_id: user_id)
    |> Enum.map(fn s ->
      %{
        test_id: s.test_id,
        status: s.status,
        score: s.score,
        started_at: s.started_at,
        completed_at: s.completed_at,
        time_spent_seconds: s.time_spent_seconds
      }
    end)
  end

  defp list_user_badges(user_id) do
    Medoru.Gamification.list_user_badges(user_id)
    |> Enum.map(fn ub ->
      %{
        badge_id: ub.badge_id,
        unlocked_at: ub.unlocked_at,
        featured: ub.featured
      }
    end)
  end

  defp list_notifications(user_id) do
    # Last 100 notifications
    Medoru.Notifications.list_notifications(user_id: user_id, limit: 100)
    |> Enum.map(fn n ->
      %{
        type: n.type,
        title: n.title,
        message: n.message,
        read_at: n.read_at,
        inserted_at: n.inserted_at
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">{gettext("Data & Privacy")}</h1>

        <%!-- Data Export Section --%>
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title text-xl">
              <.icon name="hero-document-arrow-down" class="w-6 h-6" />
              {gettext("Export Your Data")}
            </h2>
            <p class="text-base-content/70">
              {gettext(
                "Download a copy of all your personal data, including your profile, learning progress, test results, and classroom memberships. This is provided in JSON format."
              )}
            </p>
            <div class="card-actions justify-end mt-4">
              <button
                phx-click="export_data"
                class="btn btn-primary"
                disabled={@export_status == :generating}
              >
                <%= if @export_status == :generating do %>
                  <span class="loading loading-spinner loading-sm"></span>
                  {gettext("Generating...")}
                <% else %>
                  <.icon name="hero-arrow-down-tray" class="w-5 h-5 mr-2" />
                  {gettext("Download My Data")}
                <% end %>
              </button>
            </div>
          </div>
        </div>

        <%!-- GDPR Rights Section --%>
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h2 class="card-title text-xl">
              <.icon name="hero-shield-check" class="w-6 h-6" />
              {gettext("Your GDPR Rights")}
            </h2>
            <div class="space-y-4 mt-4">
              <div class="flex items-start gap-3">
                <.icon name="hero-eye" class="w-5 h-5 text-primary mt-0.5" />
                <div>
                  <h3 class="font-semibold">{gettext("Right to Access")}</h3>
                  <p class="text-sm text-base-content/70">
                    {gettext(
                      "You can request a copy of all your personal data using the export button above."
                    )}
                  </p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <.icon name="hero-pencil" class="w-5 h-5 text-primary mt-0.5" />
                <div>
                  <h3 class="font-semibold">{gettext("Right to Rectification")}</h3>
                  <p class="text-sm text-base-content/70">
                    {gettext("You can update your profile information in")}
                    <.link navigate={~p"/settings/profile"} class="link link-primary">{gettext("Profile Settings")}</.link>.
                  </p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <.icon name="hero-trash" class="w-5 h-5 text-primary mt-0.5" />
                <div>
                  <h3 class="font-semibold">{gettext("Right to Erasure")}</h3>
                  <p class="text-sm text-base-content/70">
                    {gettext(
                      "You can delete your account and all associated data. See below for details."
                    )}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Delete Account Section --%>
        <div class="card bg-error/10 border-error/20 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-xl text-error">
              <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
              {gettext("Delete Account")}
            </h2>
            <p class="text-base-content/70">
              {gettext(
                "This will permanently delete your account and all associated data, including:"
              )}
            </p>
            <ul class="list-disc list-inside text-sm text-base-content/70 mt-2 space-y-1">
              <li>{gettext("Your profile and settings")}</li>
              <li>{gettext("Learning progress and statistics")}</li>
              <li>{gettext("Test scores and completion records")}</li>
              <li>{gettext("Classroom memberships")}</li>
              <li>{gettext("Badges and achievements")}</li>
            </ul>
            <p class="text-sm text-error mt-4">
              {gettext("This action cannot be undone!")}
            </p>

            <div class="card-actions justify-end mt-4">
              <%= if @show_delete_confirm do %>
                <div class="flex items-center gap-4">
                  <span class="text-sm font-semibold">{gettext("Are you sure?")}</span>
                  <button
                    phx-click="cancel_delete"
                    class="btn btn-ghost btn-sm"
                  >
                    {gettext("Cancel")}
                  </button>
                  <button
                    phx-click="delete_account"
                    class="btn btn-error btn-sm"
                  >
                    {gettext("Yes, Delete Everything")}
                  </button>
                </div>
              <% else %>
                <button
                  phx-click="confirm_delete"
                  class="btn btn-error btn-outline"
                >
                  <.icon name="hero-trash" class="w-5 h-5 mr-2" />
                  {gettext("Delete My Account")}
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
