defmodule MedoruWeb.LearnedKanjiLive.Index do
  @moduledoc """
  LiveView for displaying a user's learned kanji with search, filter, and sort.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:filter_type, :all)
     |> assign(:jlpt_level, nil)
     |> assign(:school_level, nil)
     |> assign(:search_query, "")
     |> assign(:sort_by, :learned_desc)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    user_id = params["id"]
    user = Accounts.get_user!(user_id)

    search_query = String.trim(params["q"] || "")
    jlpt_level = parse_jlpt_level(params["level"])
    school_level = parse_school_level(params["sl"])
    sort_by = parse_sort(params["sort"])
    page = parse_page(params["page"])

    filter_type =
      cond do
        search_query != "" -> :search
        jlpt_level != nil -> :jlpt
        school_level != nil -> :school
        true -> :all
      end

    result =
      list_learned_kanji_paginated(user_id,
        page: page,
        search: search_query,
        jlpt_level: jlpt_level,
        school_level: school_level,
        sort_by: sort_by,
        locale: socket.assigns.locale
      )

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:page, result.page)
     |> assign(:kanji, result.kanji)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:filter_type, filter_type)
     |> assign(:jlpt_level, jlpt_level)
     |> assign(:school_level, school_level)
     |> assign(:search_query, search_query)
     |> assign(:sort_by, sort_by)
     |> assign(:page_title, gettext("%{name}'s Learned Kanji", name: user.name || user.email))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    trimmed = String.trim(query)

    url =
      if trimmed == "" do
        base_url(socket.assigns.user.id)
      else
        ~p"/users/#{socket.assigns.user.id}/kanji?q=#{trimmed}"
      end

    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: base_url(socket.assigns.user.id))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    url = build_url(socket.assigns.user.id, socket, %{"page" => page})
    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("change_sort", %{"sort" => sort}, socket) do
    sort_by = parse_sort(sort)
    url = build_url(socket.assigns.user.id, socket, %{"sort" => sort_param(sort_by)})
    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("unlearn_kanji", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id == user.id do
      case Learning.unlearn_kanji(current_user.id, id) do
        {:ok, _} ->
          result =
            list_learned_kanji_paginated(user.id,
              page: socket.assigns.page,
              search: socket.assigns.search_query,
              jlpt_level: socket.assigns.jlpt_level,
              school_level: socket.assigns.school_level,
              sort_by: socket.assigns.sort_by,
              locale: socket.assigns.locale
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
    per_page = @per_page

    result =
      Learning.list_learned_kanji_filtered(user_id,
        search: opts[:search],
        jlpt_level: opts[:jlpt_level],
        school_level: opts[:school_level],
        sort_by: opts[:sort_by],
        locale: opts[:locale],
        limit: per_page,
        offset: (page - 1) * per_page
      )

    total_pages = ceil(result.total_count / per_page)
    page = min(max(page, 1), total_pages)

    %{
      kanji: result.kanji,
      total_count: result.total_count,
      total_pages: max(1, total_pages),
      page: page
    }
  end

  defp base_url(user_id), do: ~p"/users/#{user_id}/kanji"

  defp build_url(user_id, socket, overrides) do
    params =
      %{}
      |> maybe_put_param("q", socket.assigns.search_query)
      |> maybe_put_param("level", socket.assigns.jlpt_level)
      |> maybe_put_param("sl", socket.assigns.school_level)
      |> maybe_put_param("sort", sort_param(socket.assigns.sort_by))
      |> Map.merge(overrides)

    if params == %{} do
      base_url(user_id)
    else
      ~p"/users/#{user_id}/kanji?#{params}"
    end
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, _key, ""), do: params
  defp maybe_put_param(params, key, value), do: Map.put(params, key, to_string(value))

  defp parse_jlpt_level(nil), do: nil

  defp parse_jlpt_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..5 -> n
      _ -> nil
    end
  end

  defp parse_jlpt_level(level) when is_integer(level) and level in 1..5, do: level
  defp parse_jlpt_level(_), do: nil

  defp parse_school_level(nil), do: nil

  defp parse_school_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..6 -> n
      _ -> nil
    end
  end

  defp parse_school_level(level) when is_integer(level) and level in 1..6, do: level
  defp parse_school_level(_), do: nil

  defp parse_sort(nil), do: :learned_desc
  defp parse_sort("learned_asc"), do: :learned_asc
  defp parse_sort("character_asc"), do: :character_asc
  defp parse_sort("jlpt_asc"), do: :jlpt_asc
  defp parse_sort("stroke_asc"), do: :stroke_asc
  defp parse_sort("known_score_desc"), do: :known_score_desc
  defp parse_sort("frequency_asc"), do: :frequency_asc
  defp parse_sort(_), do: :learned_desc

  defp sort_param(:learned_desc), do: "learned_desc"
  defp sort_param(:learned_asc), do: "learned_asc"
  defp sort_param(:character_asc), do: "character_asc"
  defp sort_param(:jlpt_asc), do: "jlpt_asc"
  defp sort_param(:stroke_asc), do: "stroke_asc"
  defp sort_param(:known_score_desc), do: "known_score_desc"
  defp sort_param(:frequency_asc), do: "frequency_asc"
  defp sort_param(_), do: "learned_desc"

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1
end
