defmodule MedoruWeb.WordLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Learning
  alias Medoru.Learning.WordSets

  embed_templates "show.html"

  @word_sets_per_page 10

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:add_to_word_set_modal_open, false)
     |> assign(:word_sets_page, 1)
     |> assign(:word_sets_result, nil)
     |> assign(:word_set_ids_with_word, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    %{"id" => id} = params
    word = Content.get_word_with_kanji!(id)
    locale = socket.assigns.locale
    localized_meaning = Content.get_localized_meaning(word, locale)

    # Check if user has learned this word (if authenticated)
    word_learned =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Learning.word_learned?(socket.assigns.current_scope.current_user.id, word.id)
      else
        false
      end

    # Store return URL and step for navigation back to lesson
    return_to = params["return_to"]
    step = parse_step_param(params["step"])
    practice = params["practice"] == "true"

    {:noreply,
     socket
     |> assign(:word, word)
     |> assign(:localized_meaning, localized_meaning)
     |> assign(:word_learned, word_learned)
     |> assign(:return_to, return_to)
     |> assign(:step, step)
     |> assign(:practice, practice)
     |> assign(
       :page_title,
       gettext("%{word} - %{meaning}", word: word.text, meaning: localized_meaning)
     )}
  end

  defp parse_step_param(nil), do: nil

  defp parse_step_param(step) when is_binary(step) do
    case Integer.parse(step) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_step_param(step) when is_integer(step), do: step

  @impl true
  def handle_event("mark_word_learned", _params, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      word = socket.assigns.word

      case Learning.track_word_learned(user_id, word.id) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:word_learned, true)
           |> put_flash(:info, gettext("%{word} marked as learned!", word: word.text))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not mark word as learned.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unlearn_word", _params, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      word = socket.assigns.word

      case Learning.unlearn_word(user_id, word.id) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:word_learned, false)
           |> put_flash(:info, gettext("%{word} removed from learned list.", word: word.text))}

        {:error, :not_learned} ->
          {:noreply,
           socket
           |> assign(:word_learned, false)
           |> put_flash(:error, gettext("Word was not learned."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not unlearn word."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_add_to_word_set_modal", _params, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      word_id = socket.assigns.word.id

      result = WordSets.list_user_word_sets(user_id, page: 1, per_page: @word_sets_per_page)
      word_set_ids = WordSets.list_word_set_ids_for_word(user_id, word_id)

      {:noreply,
       socket
       |> assign(:add_to_word_set_modal_open, true)
       |> assign(:word_sets_page, 1)
       |> assign(:word_sets_result, result)
       |> assign(:word_set_ids_with_word, word_set_ids)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_add_to_word_set_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:add_to_word_set_modal_open, false)
     |> assign(:word_sets_page, 1)
     |> assign(:word_sets_result, nil)
     |> assign(:word_set_ids_with_word, [])}
  end

  @impl true
  def handle_event("change_word_set_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    user_id = socket.assigns.current_scope.current_user.id

    result = WordSets.list_user_word_sets(user_id, page: page, per_page: @word_sets_per_page)

    {:noreply,
     socket
     |> assign(:word_sets_page, page)
     |> assign(:word_sets_result, result)}
  end

  @impl true
  def handle_event("add_to_word_set", %{"word_set_id" => word_set_id}, socket) do
    word = socket.assigns.word
    user_id = socket.assigns.current_scope.current_user.id

    case WordSets.get_word_set!(word_set_id) do
      word_set ->
        case WordSets.add_word_to_set(word_set, word.id) do
          {:ok, _} ->
            word_set_ids = WordSets.list_word_set_ids_for_word(user_id, word.id)

            {:noreply,
             socket
             |> assign(:add_to_word_set_modal_open, false)
             |> assign(:word_sets_result, nil)
             |> assign(:word_set_ids_with_word, word_set_ids)
             |> put_flash(:info, gettext("Added '%{word}' to word set.", word: word.text))}

          {:error, :max_words_reached} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("This word set is full (maximum %{max} words).", max: Medoru.Learning.WordSet.max_words())
             )}

          {:error, _} ->
            {:noreply,
             put_flash(socket, :error, gettext("This word is already in the word set."))}
        end
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, gettext("Word set not found."))}
  end

  # Helper functions needed for shared templates
  def page_link_params(assigns, page) do
    assigns = Map.new(assigns)

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: page,
      sort_by: Map.get(assigns, :sort_by),
      sort_order: Map.get(assigns, :sort_order)
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def sort_link_params(assigns, sort_by) do
    assigns = Map.new(assigns)
    current_sort_by = Map.get(assigns, :sort_by)
    current_sort_order = Map.get(assigns, :sort_order)

    sort_order =
      if current_sort_by == sort_by do
        toggle_order(current_sort_order)
      else
        default_order(sort_by)
      end

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: 1,
      sort_by: sort_by,
      sort_order: sort_order
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def sort_indicator(assigns, column) do
    assigns = Map.new(assigns)

    if Map.get(assigns, :sort_by) == column do
      case Map.get(assigns, :sort_order) do
        :asc -> "↑"
        :desc -> "↓"
        _ -> ""
      end
    else
      ""
    end
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  # Learning order: sort_score combines frequency + complexity (ascending)
  defp default_order(:sort_score), do: :asc
  # Most common words first (ascending frequency)
  defp default_order(:usage_frequency), do: :asc
  # JLPT: Easiest first (N5=5 -> N1=1, so descending)
  defp default_order(:difficulty), do: :desc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :asc

  # Helper for template: get localized word meaning
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end

  # Helper for template: build return path with step and practice params
  def build_return_path(return_to, step, practice) do
    path = return_to

    # Add query params
    params = []
    params = if step, do: [{"step", step} | params], else: params
    params = if practice, do: [{"practice", "true"} | params], else: params

    if params != [] do
      query_string = URI.encode_query(params)
      "#{path}?#{query_string}"
    else
      path
    end
  end
end
