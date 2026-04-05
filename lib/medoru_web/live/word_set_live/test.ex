defmodule MedoruWeb.WordSetLive.Test do
  @moduledoc """
  LiveView for taking a practice test from a word set.
  Styled like the daily test for consistency.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordSets
  alias Medoru.Content
  alias Medoru.Tests

  @impl true
  def mount(%{"id" => word_set_id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user

    word_set = WordSets.get_word_set!(word_set_id)

    # Ensure user owns this word set
    if word_set.user_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to take this test."))
       |> push_navigate(to: ~p"/words/sets")}
    else
      # Check if there's a practice test
      if is_nil(word_set.practice_test_id) do
        {:ok,
         socket
         |> put_flash(:error, gettext("No practice test found. Create one first."))
         |> push_navigate(to: ~p"/words/sets/#{word_set_id}")}
      else
        # Abandon any existing sessions first
        abandon_existing_sessions(user.id, word_set.practice_test_id)

        # Start new test session
        case Tests.start_test_session(user.id, word_set.practice_test_id) do
          {:ok, session} ->
            session = Tests.get_test_session_with_answers(session.id)
            current_step = get_current_step(session)
            total_steps = length(Tests.get_test!(session.test_id).test_steps)

            {:ok,
             socket
             |> assign(:page_title, gettext("Practice Test"))
             |> assign(:locale, locale)
             |> assign(:word_set, word_set)
             |> assign(:session, session)
             |> assign(:current_step, current_step)
             |> assign(:total_steps, total_steps)
             |> assign(:step_number, 1)
             |> assign(:selected_answer, nil)
             |> assign(:feedback, nil)
             |> assign(:meaning_answer, "")
             |> assign(:reading_answer, "")}

          {:error, _reason} ->
            {:ok,
             socket
             |> put_flash(:error, gettext("Could not start test."))
             |> push_navigate(to: ~p"/words/sets/#{word_set_id}")}
        end
      end
    end
  end

  @impl true
  def handle_event("select_answer", %{"answer" => answer}, socket) do
    {:noreply, assign(socket, :selected_answer, answer)}
  end

  @impl true
  def handle_event("update_meaning", params, socket) do
    value = Map.get(params, "meaning_answer", params["value"] || "")
    {:noreply, assign(socket, :meaning_answer, value)}
  end

  @impl true
  def handle_event("update_reading", params, socket) do
    value = Map.get(params, "reading_answer", params["value"] || "")
    {:noreply, assign(socket, :reading_answer, value)}
  end

  @impl true
  def handle_event("submit_answer", _params, socket) do
    answer = socket.assigns.selected_answer

    if is_nil(answer) or answer == "" do
      {:noreply, socket}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Record answer - let the server validate correctness
      attrs = %{
        answer: answer,
        time_spent_seconds: 10,
        step_index: session.current_step_index
      }

      case Tests.record_step_answer(session.id, step.id, attrs, locale: socket.assigns.current_scope.locale) do
        {:ok, step_answer} ->
          feedback = if step_answer.is_correct, do: :correct, else: :incorrect
          {:noreply, assign(socket, :feedback, feedback)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
      end
    end
  end

  @impl true
  def handle_event("submit_reading_text", _params, socket) do
    meaning = String.trim(socket.assigns.meaning_answer)
    reading = String.trim(socket.assigns.reading_answer)

    if meaning == "" or reading == "" do
      {:noreply, put_flash(socket, :error, gettext("Please enter both meaning and reading"))}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Get the word for validation
      word =
        if step.word_id do
          Content.get_word!(step.word_id)
        else
          nil
        end

      if word do
        locale = socket.assigns.locale

        {:ok, validation} =
          Medoru.Tests.ReadingAnswerValidator.validate_answer(
            word,
            meaning,
            reading,
            locale
          )

        # Record the answer
        answer_text =
          Jason.encode!(%{
            meaning: meaning,
            reading: reading,
            validation: validation
          })

        attrs = %{
          answer: answer_text,
          time_spent_seconds: 15,
          step_index: session.current_step_index,
          is_correct: validation.both_correct
        }

        case Tests.record_step_answer(session.id, step.id, attrs) do
          {:ok, _step_answer} ->
            feedback = if validation.both_correct, do: :correct, else: :incorrect
            {:noreply, assign(socket, :feedback, feedback)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
        end
      else
        {:noreply, put_flash(socket, :error, gettext("Error: word not found"))}
      end
    end
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    # Kanji writing completed successfully - mark as correct
    session = socket.assigns.session
    step = socket.assigns.current_step

    attrs = %{
      answer: step.correct_answer,
      time_spent_seconds: 20,
      step_index: session.current_step_index,
      is_correct: true
    }

    case Tests.record_step_answer(session.id, step.id, attrs) do
      {:ok, _step_answer} ->
        {:noreply, assign(socket, :feedback, :correct)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
    end
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed}, socket) when completed in ["true", true] do
    # Submit button clicked when kanji is complete - treat same as kanji_complete
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed}, socket) when completed in ["false", false] do
    # User gave up or skipped - mark as incorrect
    session = socket.assigns.session
    step = socket.assigns.current_step

    attrs = %{
      answer: "",
      time_spent_seconds: 20,
      step_index: session.current_step_index,
      is_correct: false
    }

    case Tests.record_step_answer(session.id, step.id, attrs) do
      {:ok, _step_answer} ->
        {:noreply, assign(socket, :feedback, :incorrect)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
    end
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Record as skipped (incorrect with 0 points)
    attrs = %{
      answer: "",
      time_spent_seconds: 5,
      step_index: session.current_step_index,
      is_correct: false
    }

    Tests.record_step_answer(session.id, step.id, attrs)

    # Move to next step
    case get_next_step(session) do
      nil ->
        Tests.complete_session(session, 0, 0, 0)
        {:noreply, assign(socket, :test_completed, true)}

      next_step ->
        new_index = session.current_step_index + 1
        {:ok, updated_session} = Tests.progress_session(session, new_index, 10)
        updated_session = Tests.get_test_session_with_answers(updated_session.id)

        {:noreply,
         socket
         |> assign(:session, updated_session)
         |> assign(:current_step, next_step)
         |> assign(:step_number, socket.assigns.step_number + 1)
         |> assign(:selected_answer, nil)
         |> assign(:feedback, nil)
         |> assign(:meaning_answer, "")
         |> assign(:reading_answer, "")}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    session = socket.assigns.session

    case get_next_step(session) do
      nil ->
        Tests.complete_session(session, 0, 0, 0)
        
        # Calculate statistics
        stats = calculate_test_stats(session)
        
        {:noreply, 
         socket
         |> assign(:test_completed, true)
         |> assign(:stats, stats)}

      next_step ->
        new_index = session.current_step_index + 1
        {:ok, updated_session} = Tests.progress_session(session, new_index, 10)
        updated_session = Tests.get_test_session_with_answers(updated_session.id)

        {:noreply,
         socket
         |> assign(:session, updated_session)
         |> assign(:current_step, next_step)
         |> assign(:step_number, socket.assigns.step_number + 1)
         |> assign(:selected_answer, nil)
         |> assign(:feedback, nil)
         |> assign(:meaning_answer, "")
         |> assign(:reading_answer, "")}
    end
  end

  defp get_current_step(session) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index == session.current_step_index
    end)
  end

  defp get_next_step(session) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index > session.current_step_index
    end)
  end

  defp calculate_test_stats(session) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Tests.TestStepAnswer

    # Get all answers for this session
    answers = 
      TestStepAnswer
      |> where([a], a.test_session_id == ^session.id)
      |> Repo.all()

    total = length(answers)
    correct = Enum.count(answers, & &1.is_correct)
    incorrect = total - correct

    percentage = if total > 0, do: round(correct / total * 100), else: 0

    %{
      total: total,
      correct: correct,
      incorrect: incorrect,
      percentage: percentage
    }
  end

  defp abandon_existing_sessions(user_id, test_id) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Tests.TestSession

    TestSession
    |> where([ts], ts.user_id == ^user_id and ts.test_id == ^test_id and ts.status not in [:completed, :abandoned])
    |> Repo.all()
    |> Enum.each(fn session ->
      Tests.abandon_session(session, session.time_spent_seconds || 0)
    end)
  end

  # Localization helpers for multichoice options
  def localize_option(option_text, locale) when locale in ["bg", "ja"] do
    case Content.get_word_by_meaning(option_text) do
      nil -> option_text
      word -> Content.get_localized_meaning(word, locale)
    end
  end

  def localize_option(option_text, _locale), do: option_text
end
