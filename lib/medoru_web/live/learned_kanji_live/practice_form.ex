defmodule MedoruWeb.LearnedKanjiLive.PracticeForm do
  @moduledoc """
  LiveView for selecting kanji to practice.
  Shows learned kanji with checkboxes, paginated so users can select from any page.
  User can select up to 20.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning

  @max_selection 20
  @per_page 30

  embed_templates "practice_form.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     assign(socket,
       locale: locale,
       selected_ids: [],
       max_selection: @max_selection,
       snap_correct: true,
       page: 1,
       total_count: 0,
       total_pages: 1
     )}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)
    result = list_learned_kanji_paginated(user_id, page: 1, per_page: @per_page)

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:kanji, result.kanji)
     |> assign(:page, 1)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, gettext("Practice Kanji"))}
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
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_ids
    id = String.replace_prefix(id, "select-kanji-", "")

    new_selected =
      if id in selected do
        List.delete(selected, id)
      else
        if length(selected) < @max_selection do
          [id | selected]
        else
          selected
        end
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  @impl true
  def handle_event("toggle_snap", _params, socket) do
    {:noreply, assign(socket, :snap_correct, !socket.assigns.snap_correct)}
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    selected = socket.assigns.selected_ids

    if selected == [] do
      {:noreply, put_flash(socket, :error, gettext("Please select at least one kanji."))}
    else
      ids_param = Enum.join(selected, ",")
      snap = if socket.assigns.snap_correct, do: "true", else: "false"

      {:noreply,
       push_navigate(socket,
         to:
           ~p"/users/#{socket.assigns.user.id}/kanji/practice/challenge?ids=#{ids_param}&snap=#{snap}"
       )}
    end
  end

  defp list_learned_kanji_paginated(user_id, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, @per_page)

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
