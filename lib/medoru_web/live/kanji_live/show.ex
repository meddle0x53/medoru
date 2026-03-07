defmodule MedoruWeb.KanjiLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    kanji = Content.get_kanji_with_readings!(id)

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

    {:noreply,
     socket
     |> assign(:kanji, kanji)
     |> assign(:on_readings, on_readings)
     |> assign(:kun_readings, kun_readings)
     |> assign(:words_data, words_data)
     |> assign(:page, page)
     |> assign(:kanji_learned, kanji_learned)
     |> assign(:page_title, "#{kanji.character} - Kanji Details")}
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
           |> put_flash(:info, "#{kanji.character} marked as learned!")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not mark kanji as learned.")}
      end
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
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
end
