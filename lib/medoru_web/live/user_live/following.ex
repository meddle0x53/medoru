defmodule MedoruWeb.UserLive.Following do
  @moduledoc """
  LiveView for displaying a user's following list.
  Only the profile owner may view this page.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.{Accounts, Social}

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

    if current_user && current_user.id == user.id do
      page = 1
      following = Social.list_following(user_id, page: page, per_page: @per_page)
      total_count = Social.count_following(user_id)
      total_pages = max(1, ceil(total_count / @per_page))
      following_ids = Social.list_following_ids(current_user.id)

      {:noreply,
       socket
       |> assign(:user, user)
       |> assign(:page, page)
       |> assign(:following, following)
       |> assign(:total_count, total_count)
       |> assign(:total_pages, total_pages)
       |> assign(:following_ids, following_ids)
       |> assign(:page_title, gettext("Following"))}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("You can only view your own following list."))
       |> push_navigate(to: ~p"/users/#{user_id}")}
    end
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    user_id = socket.assigns.user.id

    following = Social.list_following(user_id, page: page, per_page: @per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:following, following)}
  end

  @impl true
  def handle_event("follow_user", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.current_user

    if current_user do
      case Social.follow_user(current_user.id, user_id) do
        {:ok, _} ->
          following_ids = Social.list_following_ids(current_user.id)

          {:noreply,
           socket
           |> assign(:following_ids, following_ids)
           |> put_flash(:info, gettext("Now following user."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not follow user."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unfollow_user", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.current_user

    if current_user do
      Social.unfollow_user(current_user.id, user_id)
      following_ids = Social.list_following_ids(current_user.id)

      {:noreply,
       socket
       |> assign(:following_ids, following_ids)
       |> put_flash(:info, gettext("Unfollowed user."))}
    else
      {:noreply, socket}
    end
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helpers for template
  def user_display_name(user) do
    (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")
  end

  def user_avatar(user) do
    (user.profile && user.profile.avatar) || user.avatar_url
  end
end
