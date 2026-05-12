defmodule MedoruWeb.KanaLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.Kana

  embed_templates "show.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:show_writing_practice, false)
     |> assign(:writing_completed, false)}
  end

  @impl true
  def handle_params(%{"character" => character}, _url, socket) do
    case Kana.get_by_character(character) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Kana not found"))
         |> push_navigate(to: ~p"/hiragana")}

      kana ->
        has_stroke_data =
          kana.stroke_data != %{} and
            kana.stroke_data != nil and
            not is_nil(kana.stroke_data["strokes"]) and
            length(kana.stroke_data["strokes"] || []) > 0

        list = if kana.type == :hiragana, do: Kana.list_hiragana(), else: Kana.list_katakana()
        current_index = Enum.find_index(list, &(&1.character == kana.character))

        prev_kana = if current_index && current_index > 0, do: Enum.at(list, current_index - 1)
        next_kana = if current_index && current_index < length(list) - 1, do: Enum.at(list, current_index + 1)

        {:noreply,
         socket
         |> assign(:kana, kana)
         |> assign(:has_stroke_data, has_stroke_data)
         |> assign(:prev_kana, prev_kana)
         |> assign(:next_kana, next_kana)
         |> assign(:page_title, gettext("%{character} - %{type}",
           character: kana.character,
           type: type_label(kana.type)
         ))}
    end
  end

  @impl true
  def handle_event("toggle_writing_practice", params, socket) do
    reset = params["reset"] == "true"

    socket =
      if reset or not socket.assigns.show_writing_practice do
        socket
        |> assign(:show_writing_practice, true)
        |> assign(:writing_completed, false)
      else
        assign(socket, :show_writing_practice, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => true}, socket) do
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       gettext("Keep going! Draw all %{count} strokes.", count: socket.assigns.kana.stroke_count)
     )}
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    {:noreply,
     socket
     |> assign(:writing_completed, true)
     |> put_flash(
       :info,
       gettext("Great job! You wrote %{kana} correctly!", kana: socket.assigns.kana.character)
     )}
  end

  defp type_label(:hiragana), do: gettext("Hiragana")
  defp type_label(:katakana), do: gettext("Katakana")
end
