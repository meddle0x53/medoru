defmodule MedoruWeb.RadicalLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Content.KanjiRadicals

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale)}
  end

  @impl true
  def handle_params(%{"character" => character}, _url, socket) do
    radical = KanjiRadicals.get(character)

    if radical do
      all_kanji = Content.list_kanji_by_radical(radical.character)
      kanji_list = Enum.take(all_kanji, 60)
      frequency = Content.count_kanji_by_radical(radical.character)

      {:noreply,
       socket
       |> assign(:radical, radical)
       |> assign(:kanji_list, kanji_list)
       |> assign(:total_count, length(all_kanji))
       |> assign(:frequency, frequency)
       |> assign(:page_title, gettext("Radical: %{character}", character: character))}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Radical not found"))
       |> push_navigate(to: ~p"/radicals")}
    end
  end
end
