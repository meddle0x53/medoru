defmodule MedoruWeb.DailyReviewLive do
  @moduledoc """
  LiveView for daily review sessions.
  Users review words due for SRS and learn new words.
  """

  use MedoruWeb, :live_view

  alias Medoru.Learning

  # Template is in daily_review_live/daily_review_live.html.heex
  embed_templates "daily_review_live/*.html"

  @impl true
  def render(assigns) do
    ~H"""
    <%= daily_review_live(assigns) %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Generate daily review
    review_data = Learning.generate_daily_review(user.id, daily_goal: 10)

    # Combine reviews and new words into a single list
    # Filter to only word-based items (kanji-only items have word_id: nil or word not loaded)
    all_items =
      (review_data.reviews ++ review_data.new_words)
      |> Enum.filter(fn item -> item.word_id != nil && item.word != nil end)

    if all_items == [] do
      {:ok,
       socket
       |> assign(:page_title, "Daily Review")
       |> assign(:items, [])
       |> assign(:current_index, 0)
       |> assign(:total_count, 0)
       |> assign(:completed, true)
       |> assign(:stats, %{
         correct: 0,
         incorrect: 0,
         total: 0
       })
       |> assign(:show_completion, false)}
    else
      # Shuffle the items for variety
      shuffled_items = Enum.shuffle(all_items)

      current_item = List.first(shuffled_items)
      {question_type, options} = generate_options(current_item)

      {:ok,
       socket
       |> assign(:page_title, "Daily Review")
       |> assign(:items, shuffled_items)
       |> assign(:current_index, 0)
       |> assign(:total_count, length(shuffled_items))
       |> assign(:completed, false)
       |> assign(:stats, %{
         correct: 0,
         incorrect: 0,
         total: 0
       })
       |> assign(:current_item, current_item)
       |> assign(:question_type, question_type)
       |> assign(:options, options)
       |> assign(:selected_answer, nil)
       |> assign(:show_result, false)
       |> assign(:is_correct, nil)
       |> assign(:show_completion, false)}
    end
  end

  @impl true
  def handle_event("select_answer", %{"answer" => answer}, socket) do
    if socket.assigns.show_result do
      {:noreply, socket}
    else
      current_item = socket.assigns.current_item
      correct_answer = get_correct_answer(current_item, socket.assigns.question_type)
      is_correct = answer == correct_answer

      # Record the review in the background
      if is_correct do
        Learning.record_review(
          socket.assigns.current_scope.current_user.id,
          current_item.id,
          4
        )
      else
        Learning.record_review(
          socket.assigns.current_scope.current_user.id,
          current_item.id,
          1
        )
      end

      new_stats =
        if is_correct do
          %{
            socket.assigns.stats
            | correct: socket.assigns.stats.correct + 1,
              total: socket.assigns.stats.total + 1
          }
        else
          %{
            socket.assigns.stats
            | incorrect: socket.assigns.stats.incorrect + 1,
              total: socket.assigns.stats.total + 1
          }
        end

      {:noreply,
       socket
       |> assign(:selected_answer, answer)
       |> assign(:show_result, true)
       |> assign(:is_correct, is_correct)
       |> assign(:stats, new_stats)}
    end
  end

  @impl true
  def handle_event("next_question", _, socket) do
    new_index = socket.assigns.current_index + 1

    if new_index >= socket.assigns.total_count do
      # Session complete
      Learning.update_streak(socket.assigns.current_scope.current_user.id)

      {:noreply,
       socket
       |> assign(:completed, true)
       |> assign(:show_completion, true)}
    else
      current_item = Enum.at(socket.assigns.items, new_index)
      {question_type, options} = generate_options(current_item)

      {:noreply,
       socket
       |> assign(:current_index, new_index)
       |> assign(:current_item, current_item)
       |> assign(:question_type, question_type)
       |> assign(:options, options)
       |> assign(:selected_answer, nil)
       |> assign(:show_result, false)
       |> assign(:is_correct, nil)}
    end
  end

  @impl true
  def handle_event("finish", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard")}
  end

  # Generate multiple choice options for the current item
  # Returns {question_type, options} where question_type is :meaning_to_reading or :reading_to_meaning
  defp generate_options(item) do
    word = item.word

    question_type = Enum.random([:meaning_to_reading, :reading_to_meaning])

    options =
      case question_type do
        :meaning_to_reading ->
          # Show meaning, select reading
          correct = word.reading
          distractors = generate_distractors(word.id, :reading)
          [correct | distractors] |> Enum.shuffle() |> Enum.map(&{&1, &1 == correct})

        :reading_to_meaning ->
          # Show reading, select meaning
          correct = word.meaning
          distractors = generate_distractors(word.id, :meaning)
          [correct | distractors] |> Enum.shuffle() |> Enum.map(&{&1, &1 == correct})
      end

    {question_type, options}
  end

  defp generate_distractors(word_id, field) do
    # Get 3 random words that aren't the current word
    import Ecto.Query

    Medoru.Content.Word
    |> where([w], w.id != ^word_id)
    |> order_by(fragment("RANDOM()"))
    |> limit(3)
    |> select([w], field(w, ^field))
    |> Medoru.Repo.all()
  end

  defp get_correct_answer(item, question_type) do
    # Returns the correct answer based on the question type
    case question_type do
      :meaning_to_reading -> item.word.reading
      :reading_to_meaning -> item.word.meaning
    end
  end

  defp progress_percentage(current, total) do
    if total == 0, do: 0, else: round(current / total * 100)
  end
end
