defmodule MedoruWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard with system statistics overview.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Content
  alias Medoru.Classrooms
  alias Medoru.SiteSettings

  embed_templates "dashboard_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {dashboard(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user_stats = Accounts.get_admin_stats()
    content_stats = Content.get_admin_stats()
    classroom_stats = Classrooms.get_admin_stats()
    settings = SiteSettings.get_settings()
    public_classrooms = Classrooms.list_public_classrooms()

    featured_classroom =
      if settings.featured_classroom_id do
        Enum.find(public_classrooms, &(&1.id == settings.featured_classroom_id))
      end

    {:ok,
     socket
     |> assign(:page_title, gettext("Admin Dashboard"))
     |> assign(:user_stats, user_stats)
     |> assign(:content_stats, content_stats)
     |> assign(:classroom_stats, classroom_stats)
     |> assign(:settings, settings)
     |> assign(:public_classrooms, public_classrooms)
     |> assign(:featured_classroom, featured_classroom)}
  end

  @impl true
  def handle_event("set_featured_classroom", %{"classroom_id" => classroom_id}, socket) do
    settings = socket.assigns.settings

    attrs =
      if classroom_id == "" do
        %{featured_classroom_id: nil}
      else
        %{featured_classroom_id: classroom_id}
      end

    case SiteSettings.update_settings(settings, attrs) do
      {:ok, updated_settings} ->
        featured_classroom =
          if updated_settings.featured_classroom_id do
            Enum.find(
              socket.assigns.public_classrooms,
              &(&1.id == updated_settings.featured_classroom_id)
            )
          end

        {:noreply,
         socket
         |> assign(:settings, updated_settings)
         |> assign(:featured_classroom, featured_classroom)
         |> put_flash(:info, gettext("Featured classroom updated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update featured classroom."))}
    end
  end
end
