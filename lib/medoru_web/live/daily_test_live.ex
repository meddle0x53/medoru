defmodule MedoruWeb.DailyTestLive do
  @moduledoc """
  LiveView for taking daily review tests.

  Daily tests are auto-generated and combine:
  - SRS-based review items (words due for review)
  - New words (up to 5, if available)

  Each user can have only one daily test per day.
  Completing the daily test updates the user's streak.
  """

  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Tests

  embed_templates "daily_test_live/*.html"

  @impl true
  def render(assigns) do
    daily_test_live(assigns)
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Get or create daily test
    case Learning.get_or_create_daily_test(user.id) do
      {:ok, test} ->
        # Check if already completed
        if Learning.daily_test_completed_today?(user.id) do
          {:ok,
           socket
           |> assign(:page_title, gettext("Daily Review Complete"))
           |> assign(:already_completed, true)
           |> assign(:test, test)
           |> assign(:session, nil)
           |> assign(:current_step, nil)
           |> assign(:session_state, nil)}
        else
          {:ok,
           socket
           |> assign(:page_title, gettext("Daily Review"))
           |> assign(:already_completed, false)
           |> assign(:test, test)
           |> assign(:session, nil)
           |> assign(:current_step, nil)
           |> assign(:session_state, nil)
           |> assign(:selected_answer, nil)
           |> assign(:meaning_answer, "")
           |> assign(:reading_answer, "")
           |> assign(:feedback, nil)
           |> assign(:show_hint, false)
           |> assign(:error_message, nil)
           |> assign(:meaning_error, false)
           |> assign(:reading_error, false)
           |> assign(:correct_meaning, nil)
           |> assign(:correct_reading, nil)}
        end

      {:error, :no_items_available} ->
        # No words learned yet - redirect to lessons page
        {:ok,
         socket
         |> put_flash(
           :info,
           gettext(
             "Start a lesson to begin learning Japanese! Your daily review will be available once you've learned some words."
           )
         )
         |> push_navigate(to: ~p"/lessons")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    if socket.assigns.already_completed || socket.assigns[:no_items] do
      {:noreply, socket}
    else
      # Start or resume test session
      user = socket.assigns.current_scope.current_user
      test = socket.assigns.test

      case Tests.start_test_session(user.id, test.id) do
        {:ok, session} ->
          # Load session with answers
          session = Tests.get_test_session_with_answers(session.id)

          # Get current step
          current_step = get_current_step(session)

          socket =
            socket
            |> assign(:session, session)
            |> assign(:current_step, current_step)
            |> assign(:session_state, calculate_session_state(session))
            |> assign(:selected_answer, nil)
            |> assign(:meaning_answer, "")
            |> assign(:reading_answer, "")
            |> assign(:feedback, nil)
            |> assign(:show_hint, false)
            |> assign(:meaning_error, false)
            |> assign(:reading_error, false)
            |> assign(:correct_meaning, nil)
            |> assign(:correct_reading, nil)

          {:noreply, socket}

        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("Could not start daily test"))
           |> push_navigate(to: ~p"/dashboard")}
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

    if is_nil(answer) do
      {:noreply, put_flash(socket, :error, gettext("Please select an answer"))}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Record answer
      attrs = %{
        answer: answer,
        time_spent_seconds: 10,
        step_index: session.current_step_index
      }

      case Tests.record_step_answer(session.id, step.id, attrs) do
        {:ok, step_answer} ->
          if step_answer.is_correct do
            handle_correct_answer(socket, step)
          else
            handle_incorrect_answer(socket, step)
          end

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

      # Validate using ReadingAnswerValidator
      word =
        if step.word_id do
          Medoru.Content.get_word!(step.word_id)
        else
          nil
        end

      if word do
        {:ok, validation} =
          Medoru.Tests.ReadingAnswerValidator.validate_answer(
            word,
            meaning,
            reading
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
            if validation.both_correct do
              handle_correct_answer(socket, step)
            else
              handle_incorrect_reading_text(socket, step, validation, word)
            end

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Error recording answer")}
        end
      else
        {:noreply, put_flash(socket, :error, gettext("Error: word not found"))}
      end
    end
  end

  @impl true
  def handle_event("show_hint", _params, socket) do
    {:noreply, assign(socket, :show_hint, true)}
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Move to next step without recording (counts as wrong)
    attrs = %{
      answer: "skipped",
      time_spent_seconds: 5,
      step_index: session.current_step_index,
      is_correct: false,
      points_earned: 0
    }

    Tests.record_step_answer(session.id, step.id, attrs)

    next_step = get_next_step(session, step)

    if next_step do
      # Update session progress
      {:ok, updated_session} =
        Tests.progress_session(
          session,
          session.current_step_index + 1,
          session.time_spent_seconds + 5
        )

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:current_step, next_step)
        |> assign(:session_state, calculate_session_state(updated_session))
        |> assign(:selected_answer, nil)
        |> assign(:meaning_answer, "")
        |> assign(:reading_answer, "")
        |> assign(:show_hint, false)
        |> assign(:feedback, nil)
        |> assign(:meaning_error, false)
        |> assign(:reading_error, false)
        |> assign(:correct_meaning, nil)
        |> assign(:correct_reading, nil)

      {:noreply, socket}
    else
      # Complete test
      complete_test(socket)
    end
  end

  @impl true
  def handle_event("clear_feedback", _params, socket) do
    {:noreply, assign(socket, :feedback, nil)}
  end

  @impl true
  def handle_event("finish", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("start_new_test", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/daily-test")}
  end

  # Private functions

  defp handle_correct_answer(socket, _step) do
    session = socket.assigns.session

    # Calculate score so far
    {_score, _total} = Tests.calculate_session_score(session.id)

    # Update session progress
    progress_index = session.current_step_index + 1

    {:ok, updated_session} =
      Tests.progress_session(
        session,
        progress_index,
        session.time_spent_seconds + 10
      )

    # Get next step
    next_step = get_next_step(updated_session, socket.assigns.current_step)

    if next_step do
      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:current_step, next_step)
        |> assign(:session_state, calculate_session_state(updated_session))
        |> assign(:selected_answer, nil)
        |> assign(:meaning_answer, "")
        |> assign(:reading_answer, "")
        |> assign(:show_hint, false)
        |> assign(:feedback, :correct)
        |> assign(:meaning_error, false)
        |> assign(:reading_error, false)
        |> assign(:correct_meaning, nil)
        |> assign(:correct_reading, nil)

      {:noreply, socket}
    else
      # Complete test
      complete_test(socket)
    end
  end

  defp handle_incorrect_reading_text(socket, step, validation, word) do
    session = socket.assigns.session

    # Still advance to next step (daily test doesn't have adaptive retry)
    next_step = get_next_step(session, step)

    if next_step do
      {:ok, updated_session} =
        Tests.progress_session(
          session,
          session.current_step_index + 1,
          session.time_spent_seconds + 15
        )

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:current_step, next_step)
        |> assign(:session_state, calculate_session_state(updated_session))
        |> assign(:selected_answer, nil)
        |> assign(:meaning_answer, "")
        |> assign(:reading_answer, "")
        |> assign(:show_hint, false)
        |> assign(:feedback, :incorrect)
        |> assign(:meaning_error, !validation.meaning_correct)
        |> assign(:reading_error, !validation.reading_correct)
        |> assign(:correct_meaning, word.meaning)
        |> assign(:correct_reading, word.reading)

      {:noreply, socket}
    else
      # Complete test even with incorrect last answer
      complete_test(socket)
    end
  end

  defp handle_incorrect_answer(socket, step) do
    session = socket.assigns.session

    # Still advance to next step
    next_step = get_next_step(session, step)

    if next_step do
      {:ok, updated_session} =
        Tests.progress_session(
          session,
          session.current_step_index + 1,
          session.time_spent_seconds + 10
        )

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:current_step, next_step)
        |> assign(:session_state, calculate_session_state(updated_session))
        |> assign(:selected_answer, nil)
        |> assign(:show_hint, false)
        |> assign(:feedback, :incorrect)

      {:noreply, socket}
    else
      # Complete test even with incorrect last answer
      complete_test(socket)
    end
  end

  defp complete_test(socket) do
    session = socket.assigns.session
    test = socket.assigns.test
    user = socket.assigns.current_scope.current_user

    # Calculate final score
    {score, total_possible} = Tests.calculate_session_score(session.id)

    # Complete session
    {:ok, completed_session} =
      Tests.complete_session(
        session,
        score,
        total_possible,
        session.time_spent_seconds + 10
      )

    # Update streak
    Learning.update_streak(user.id)

    # Track learned words from the test
    track_test_words(user.id, test.id)

    # Navigate to completion page
    {:noreply,
     socket
     |> assign(:session, completed_session)
     |> push_navigate(to: ~p"/daily-test/complete")}
  end

  # Track all words from the test as learned
  defp track_test_words(user_id, test_id) do
    test = Tests.get_test!(test_id)

    test.test_steps
    |> Enum.map(& &1.word_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.each(fn word_id ->
      # Track word as learned (will create UserProgress if not exists)
      Learning.track_word_learned(user_id, word_id)

      # Get or create review schedule
      progress = Learning.get_word_progress(user_id, word_id)

      if progress do
        Learning.get_or_create_review_schedule(user_id, progress.id)
      end
    end)
  end

  defp get_current_step(session) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index == session.current_step_index
    end)
  end

  defp get_next_step(session, current_step) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index > current_step.order_index
    end)
  end

  defp calculate_session_state(session) do
    test = Tests.get_test!(session.test_id)
    total_steps = length(test.test_steps)
    completed_steps = session.current_step_index

    progress =
      if total_steps > 0 do
        round(completed_steps / total_steps * 100)
      else
        0
      end

    %{
      total_steps: total_steps,
      completed_steps: completed_steps,
      remaining_steps: total_steps - completed_steps,
      progress: progress
    }
  end

  # Translate question messages from the database
  def translate_question(nil), do: ""

  def translate_question(question) when is_binary(question) do
    cond do
      String.starts_with?(question, "__MSG_WHAT_DOES_WORD_MEAN__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("What does '%{word}' mean?", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_HOW_DO_YOU_READ__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("How do you read '%{word}'?", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_TYPE_MEANING_READING__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("Type the meaning and reading for '%{word}'", word: word)
          _ -> question
        end

      true ->
        question
    end
  end

  # Translate hint messages
  def translate_hint(nil), do: nil

  def translate_hint(hint) when is_binary(hint) do
    case hint do
      "__MSG_TYPE_ENGLISH_HIRAGANA__" ->
        gettext("Type the English meaning and hiragana reading")

      "Take your time and think about the word" ->
        gettext("Take your time and think about the word")

      _ ->
        hint
    end
  end

  # Translate explanation messages
  def translate_explanation(nil), do: nil

  def translate_explanation(explanation) when is_binary(explanation) do
    case String.split(explanation, "|") do
      ["__MSG_WORD_MEANS_READING__", word, meaning, reading] ->
        gettext("%{word} means '%{meaning}' and is read as '%{reading}'",
          word: word,
          meaning: meaning,
          reading: reading
        )

      _ ->
        explanation
    end
  end
end
