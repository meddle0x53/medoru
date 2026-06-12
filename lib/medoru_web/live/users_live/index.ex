defmodule MedoruWeb.UsersLive.Index do
  @moduledoc """
  LiveView for the public users directory.
  Displays searchable list of users with public profiles.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.{Accounts, Social}

  @per_page 24

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    all_tags = Social.list_tags()
    {:ok, assign(socket, locale: locale, selected_users: [], all_tags: all_tags)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])
    search = params["search"] || ""
    tag_id = params["tag_id"] || ""

    current_user = socket.assigns.current_scope[:current_user]
    viewer_id = current_user && current_user.id

    is_staff =
      current_user &&
        (Accounts.User.admin?(current_user) || Accounts.User.moderator?(current_user))

    only_following = current_user && !is_staff && search == ""

    following_ids =
      if viewer_id do
        Social.list_following_ids(viewer_id)
      else
        []
      end

    users =
      if search != "" do
        Social.search_users(search, viewer_id,
          page: page,
          per_page: @per_page,
          tag_id: tag_id,
          only_following: only_following
        )
      else
        Social.list_users(viewer_id,
          page: page,
          per_page: @per_page,
          tag_id: tag_id,
          only_following: only_following
        )
      end

    total_count =
      if search != "" do
        Social.count_search_users(search, viewer_id,
          tag_id: tag_id,
          only_following: only_following
        )
      else
        Social.count_users(viewer_id, tag_id: tag_id, only_following: only_following)
      end

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:search, search)
     |> assign(:tag_id, tag_id)
     |> assign(:following_ids, following_ids)
     |> assign(:users, users)
     |> assign(:total_count, total_count)
     |> assign(:total_pages, total_pages)
     |> assign(:page_title, gettext("Users"))}
  end

  @impl true
  def handle_event("search", params, socket) do
    search = params["search"] || ""
    tag_id = params["tag_id"] || ""
    {:noreply, push_patch(socket, to: ~p"/users?#{[search: search, tag_id: tag_id, page: 1]}")}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    search = socket.assigns.search
    tag_id = socket.assigns.tag_id

    {:noreply, push_patch(socket, to: ~p"/users?#{[search: search, tag_id: tag_id, page: page]}")}
  end

  @impl true
  def handle_event("toggle_select", %{"user_id" => user_id}, socket) do
    selected = socket.assigns.selected_users

    new_selected =
      if user_id in selected do
        List.delete(selected, user_id)
      else
        [user_id | selected]
      end

    {:noreply, assign(socket, :selected_users, new_selected)}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_users, [])}
  end

  @impl true
  def handle_event("follow_user", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

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
    current_user = socket.assigns.current_scope.current_user

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

  @impl true
  def handle_event("create_group", _params, socket) do
    selected = socket.assigns.selected_users

    if length(selected) >= 1 do
      {:noreply,
       push_navigate(socket, to: ~p"/messages/new-group?#{[users: Enum.join(selected, ",")]}")}
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
