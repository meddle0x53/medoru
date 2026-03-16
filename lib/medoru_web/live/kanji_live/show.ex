defmodule MedoruWeb.KanjiLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

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
  def handle_params(%{"id" => id} = params, _url, socket) do
    kanji = Content.get_kanji_with_readings!(id)
    locale = socket.assigns.locale

    # Parse page parameter for words pagination
    page = parse_page(params["page"])

    # Get words containing this kanji, grouped by reading
    words_data =
      Content.list_words_by_kanji_grouped_by_reading(kanji.id, page: page, per_page: 20)

    on_readings = Enum.filter(kanji.kanji_readings, &(&1.reading_type == :on))
    kun_readings = Enum.filter(kanji.kanji_readings, &(&1.reading_type == :kun))

    # Check if user has learned this kanji (if authenticated)
    kanji_learned =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Learning.kanji_learned?(socket.assigns.current_scope.current_user.id, kanji.id)
      else
        false
      end

    # Check if kanji has stroke data
    has_stroke_data =
      kanji.stroke_data != %{} and
        kanji.stroke_data != nil and
        not is_nil(kanji.stroke_data["strokes"])

    # Get localized meanings
    localized_meanings = Content.get_localized_kanji_meanings(kanji, locale)

    {:noreply,
     socket
     |> assign(:kanji, kanji)
     |> assign(:localized_meanings, localized_meanings)
     |> assign(:on_readings, on_readings)
     |> assign(:kun_readings, kun_readings)
     |> assign(:words_data, words_data)
     |> assign(:page, page)
     |> assign(:kanji_learned, kanji_learned)
     |> assign(:has_stroke_data, has_stroke_data)
     |> assign(:page_title, gettext("%{kanji} - Kanji Details", kanji: kanji.character))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    kanji = socket.assigns.kanji

    words_data =
      Content.list_words_by_kanji_grouped_by_reading(kanji.id, page: page, per_page: 20)

    {:noreply,
     socket
     |> assign(:words_data, words_data)
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("mark_kanji_learned", _params, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      kanji = socket.assigns.kanji

      case Learning.track_kanji_learned(user_id, kanji.id) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:kanji_learned, true)
           |> put_flash(:info, gettext("%{kanji} marked as learned!", kanji: kanji.character))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not mark kanji as learned.")}
      end
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("toggle_writing_practice", params, socket) do
    # Reset completed state when explicitly starting practice (not just toggling)
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
  def handle_event("kanji_complete", _params, socket) do
    # Mark writing as completed successfully
    {:noreply,
     socket
     |> assign(:writing_completed, true)
     |> put_flash(
       :info,
       gettext("Great job! You wrote %{kanji} correctly!", kanji: socket.assigns.kanji.character)
     )}
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => true}, socket) do
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", _params, socket) do
    # Not completed yet - just ignore or show hint
    {:noreply,
     put_flash(
       socket,
       :info,
       gettext("Keep going! Draw all %{count} strokes.", count: socket.assigns.kanji.stroke_count)
     )}
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helper for template: get localized word meaning
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end

  # Helper for template: get first localized kanji meaning (needed for shared templates)
  def localized_kanji_meaning(kanji, locale) do
    meanings = Content.get_localized_kanji_meanings(kanji, locale)
    List.first(meanings, "")
  end
end
