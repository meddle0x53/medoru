defmodule MedoruWeb.RadicalLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Content.KanjiRadicals

  @per_page 10

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])
    query = params["q"] || ""
    counts = Content.kanji_counts_by_radical()

    all_radicals =
      KanjiRadicals.by_frequency()
      |> Enum.map(fn radical ->
        %{radical | frequency: Map.get(counts, radical.character, 0)}
      end)

    {matched_kanji, filtered_radicals} = apply_filter(all_radicals, query)
    filtered_radicals = Enum.sort_by(filtered_radicals, & &1.frequency, :desc)

    total_count = length(filtered_radicals)
    total_pages = max(1, ceil(total_count / @per_page))

    radicals =
      filtered_radicals
      |> Enum.drop((page - 1) * @per_page)
      |> Enum.take(@per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:radicals, radicals)
     |> assign(:total_count, total_count)
     |> assign(:total_pages, total_pages)
     |> assign(:query, query)
     |> assign(:matched_kanji, matched_kanji)
     |> assign(:page_title, gettext("Kanji Radicals"))}
  end

  @impl true
  def handle_event("filter", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/radicals?q=#{query}", replace: true)}
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/radicals")}
  end

  defp apply_filter(radicals, query) do
    trimmed = String.trim(query)

    cond do
      trimmed == "" ->
        {nil, radicals}

      kanji = Content.get_kanji_by_character(trimmed) ->
        {kanji, Enum.filter(radicals, &(&1.character in kanji.radicals))}

      true ->
        {nil, text_filter(radicals, trimmed)}
    end
  end

  defp text_filter(radicals, query) do
    canonical =
      case KanjiRadicals.get(query) do
        nil -> query
        %{character: character} -> character
      end

    lowered = String.downcase(query)

    Enum.filter(radicals, fn radical ->
      radical.character == canonical or
        (is_binary(radical.meaning) &&
           String.contains?(String.downcase(radical.meaning), lowered))
    end)
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    {:noreply, push_patch(socket, to: ~p"/radicals?page=#{page}")}
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
