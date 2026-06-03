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
      top_kanji_data = KanjiRadicals.top_kanji(character)
      frequency = KanjiRadicals.frequency(character)

      kanji_list =
        top_kanji_data
        |> Enum.map(fn %{id: id} ->
          case Content.get_kanji(id) do
            nil -> nil
            kanji -> kanji
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:noreply,
       socket
       |> assign(:radical, radical)
       |> assign(:kanji_list, kanji_list)
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
