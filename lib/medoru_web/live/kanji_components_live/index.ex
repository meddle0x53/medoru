defmodule MedoruWeb.KanjiComponentsLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.KanjiComponents

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
    all_components = KanjiComponents.by_frequency()
    total_count = length(all_components)
    total_pages = max(1, ceil(total_count / @per_page))

    components =
      all_components
      |> Enum.drop((page - 1) * @per_page)
      |> Enum.take(@per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:components, components)
     |> assign(:total_count, total_count)
     |> assign(:total_pages, total_pages)
     |> assign(:page_title, gettext("Kanji Components"))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    {:noreply, push_patch(socket, to: ~p"/components?page=#{page}")}
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
