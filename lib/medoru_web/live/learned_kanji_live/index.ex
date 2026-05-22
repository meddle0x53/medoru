defmodule MedoruWeb.LearnedKanjiLive.Index do
  @moduledoc """
  LiveView for displaying a user's learned kanji.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)

    result =
      list_learned_kanji_paginated(user_id,
        page: 1,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:page, 1)
     |> assign(:kanji, result.kanji)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, gettext("%{name}'s Learned Kanji", name: user.name || user.email))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    user_id = socket.assigns.user.id

    result =
      list_learned_kanji_paginated(user_id,
        page: page,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:kanji, result.kanji)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)}
  end

  @impl true
  def handle_event("unlearn_kanji", %{"id" => kanji_id}, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id == user.id do
      case Learning.unlearn_kanji(current_user.id, kanji_id) do
        {:ok, _} ->
          # Refresh the list
          result =
            list_learned_kanji_paginated(user.id,
              page: socket.assigns.page,
              per_page: @per_page
            )

          {:noreply,
           socket
           |> assign(:kanji, result.kanji)
           |> assign(:total_count, result.total_count)
           |> assign(:total_pages, result.total_pages)
           |> put_flash(:info, gettext("Kanji removed from learned list."))}

        {:error, :not_learned} ->
          {:noreply, put_flash(socket, :error, gettext("Kanji was not learned."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not unlearn kanji."))}
      end
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  defp list_learned_kanji_paginated(user_id, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)

    total_count = Learning.count_learned_kanji(user_id)

    kanji =
      Learning.list_learned_kanji(user_id,
        limit: per_page,
        offset: (page - 1) * per_page
      )

    total_pages = ceil(total_count / per_page)

    %{
      kanji: kanji,
      total_count: total_count,
      total_pages: max(1, total_pages)
    }
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1
end
