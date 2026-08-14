defmodule MedoruWeb.UserLive.Visitors do
  @moduledoc """
  LiveView for displaying a user's profile visitors.

  Only the profile owner may view this page, and only when the owner is a
  teacher, admin, or moderator-enabled user.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.Components.Helpers, only: [format_relative_time: 1]

  alias Medoru.{Accounts, Social}
  alias Medoru.Accounts.User

  @per_page 24

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale)}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.current_user

    if current_user && current_user.id == user.id && can_see_visitors?(user) do
      page = 1
      visitors = Social.list_visitors(user_id, page: page, per_page: @per_page)
      total_count = Social.count_visitors(user_id)
      total_pages = max(1, ceil(total_count / @per_page))

      {:noreply,
       socket
       |> assign(:user, user)
       |> assign(:page, page)
       |> assign(:visitors, visitors)
       |> assign(:total_count, total_count)
       |> assign(:total_pages, total_pages)
       |> assign(:page_title, gettext("Visitors"))}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("You can only view your own visitors."))
       |> push_navigate(to: ~p"/users/#{user_id}")}
    end
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    user_id = socket.assigns.user.id

    visitors = Social.list_visitors(user_id, page: page, per_page: @per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:visitors, visitors)}
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  defp can_see_visitors?(%User{} = user) do
    User.teacher?(user) or User.moderator?(user)
  end

  # Helpers for template
  def user_display_name(user) do
    (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")
  end

  def user_avatar(user) do
    (user.profile && user.profile.avatar) || user.avatar_url
  end
end
