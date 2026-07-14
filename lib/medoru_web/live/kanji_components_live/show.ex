defmodule MedoruWeb.KanjiComponentsLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.KanjiComponents

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale)}
  end

  @impl true
  def handle_params(%{"character" => character}, _url, socket) do
    component = KanjiComponents.get(character)

    if component do
      kanji_list = KanjiComponents.top_kanji(character)
      frequency = KanjiComponents.frequency(character)

      {:noreply,
       socket
       |> assign(:component, component)
       |> assign(:kanji_list, kanji_list)
       |> assign(:frequency, frequency)
       |> assign(:page_title, gettext("Component: %{character}", character: character))}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Component not found"))
       |> push_navigate(to: ~p"/components")}
    end
  end
end
