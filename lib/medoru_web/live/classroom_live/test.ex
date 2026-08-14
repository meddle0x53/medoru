defmodule MedoruWeb.ClassroomLive.Test do
  @moduledoc """
  LiveView for students to take a published test from a classroom.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests
  alias Medoru.Grammar.Validator
  alias Medoru.Tests.ReadingAnswerValidator
  alias MedoruWeb.PublicAccess
  alias MedoruWeb.SlugRoutes
  alias MedoruWeb.WritingFillInComponents

  @impl true
  def mount(%{"id" => classroom_id, "test_id" => test_id}, session, socket) do
    user = socket.assigns.current_scope.current_user
    locale = session["locale"] || "en"

    socket = assign(socket, :locale, locale)

    classroom = SlugRoutes.load_classroom!(classroom_id)
    test = SlugRoutes.load_test!(test_id)

    cond do
      not is_nil(user) ->
        # Verify user is an approved member of the classroom
        case Classrooms.get_user_membership(classroom.id, user.id) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, gettext("You are not a member of this classroom."))
             |> push_navigate(to: ~p"/classrooms")}

          membership ->
            if membership.status != :approved do
              {:ok,
               socket
               |> put_flash(:error, gettext("Your membership is pending approval."))
               |> push_navigate(to: ~p"/classrooms/#{classroom.id}")}
            else
              load_test_session(socket, classroom.id, test.id, user)
            end
        end

      PublicAccess.featured_classroom?(classroom.id) ->
        load_anonymous_test_session(socket, classroom.id, test.id)

      true ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You must sign in to take this test."))
         |> push_navigate(to: ~p"/auth/google")}
    end
  end

  defp load_test_session(socket, classroom_id, test_id, user) do
    # Verify test is published to this classroom
    classroom_test = Classrooms.get_classroom_test(classroom_id, test_id)

    cond do
      is_nil(classroom_test) || classroom_test.status != :active ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This test is not available in this classroom."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}

      true ->
        # Check for existing attempt
        existing_attempt = Classrooms.get_test_attempt(classroom_id, user.id, test_id)

        cond do
          # Has an in-progress attempt - resume it
          existing_attempt && existing_attempt.status == "in_progress" ->
            resume_test_session(
              socket,
              existing_attempt,
              classroom_test,
              classroom_id,
              test_id,
              user
            )

          # Has a completed attempt and can't retake
          existing_attempt && existing_attempt.status in ["completed", "timed_out"] &&
              existing_attempt.reset_count == 0 ->
            {:ok,
             socket
             |> put_flash(:info, gettext("You have already completed this test."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}

          # Can start new attempt (no existing or was reset)
          true ->
            start_new_test_session(socket, classroom_test, classroom_id, test_id, user)
        end
    end
  end

  defp load_anonymous_test_session(socket, classroom_id, test_id) do
    classroom_test = Classrooms.get_classroom_test(classroom_id, test_id)

    cond do
      is_nil(classroom_test) || classroom_test.status != :active ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This test is not available in this classroom."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}

      true ->
        test = Tests.get_test!(test_id)
        classroom = Classrooms.get_classroom!(classroom_id)
        steps = Tests.list_test_steps(test_id)
        first_step = List.first(steps)
        time_limit = test.time_limit_seconds || 3600

        # Only persist a session once the LiveView socket is connected. The
        # initial HTTP dead-render also invokes mount and would otherwise leave
        # an abandoned session behind.
        session =
          if connected?(socket) do
            case Tests.start_test_session(nil, test_id) do
              {:ok, session} -> session
              {:error, _} -> nil
            end
          else
            nil
          end

        if connected?(socket) and is_nil(session) do
          {:ok,
           socket
           |> put_flash(:error, gettext("Failed to start test session."))
           |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
        else
          {:ok,
           socket
           |> assign(:page_title, test.title)
           |> assign(:page_description, test.description || gettext("Take this test on Medoru"))
           |> assign(:classroom, classroom)
           |> assign(:test, test)
           |> assign(:attempt, nil)
           |> assign(:is_anonymous, true)
           |> assign(:session, session)
           |> assign(:steps, steps)
           |> assign(:current_step_index, 0)
           |> assign_current_step(first_step)
           |> assign(:total_steps, length(steps))
           |> assign(:time_remaining, time_limit)
           |> assign(:answer, initial_answer_for_step(first_step))
           |> assign(:show_hint, false)
           |> assign(:writing_start_time, writing_start_time(first_step))
           |> assign(:current_wrong_strokes, 0)
           |> assign(:challenge_score, 0)
           |> assign(:meaning_answer, "")
           |> assign(:reading_answer, "")
           |> assign(:selected_answer, nil)
           |> assign(:feedback, nil)
           |> assign(:correct_meaning, nil)
           |> assign(:correct_reading, nil)
           |> assign(:meaning_error, false)
           |> assign(:reading_error, false)}
        end
    end
  end

  defp resume_test_session(socket, attempt, _classroom_test, classroom_id, test_id, user) do
    test = Tests.get_test!(test_id)
    classroom = Classrooms.get_classroom!(classroom_id)

    # Check if we have a valid session to resume
    session =
      if attempt.test_session_id do
        Tests.get_test_session(attempt.test_session_id)
      else
        nil
      end

    if is_nil(session) do
      # No session - start a new one for this reset attempt
      # First link the attempt to a new session
      case Tests.start_test_session(user.id, test_id) do
        {:ok, new_session} ->
          # Update attempt with new session
          {:ok, updated_attempt} =
            attempt
            |> Ecto.Changeset.change(test_session_id: new_session.id)
            |> Medoru.Repo.update()

          steps = Tests.list_test_steps(test_id)
          first_step = List.first(steps)

          {:ok,
           socket
           |> assign(:page_title, test.title)
           |> assign(:page_description, test.description || gettext("Take this test on Medoru"))
           |> assign(:classroom, classroom)
           |> assign(:test, test)
           |> assign(:attempt, updated_attempt)
           |> assign(:session, new_session)
           |> assign(:steps, steps)
           |> assign(:current_step_index, 0)
           |> assign_current_step(first_step)
           |> assign(:total_steps, length(steps))
           |> assign(:time_remaining, updated_attempt.time_remaining_seconds)
           |> assign(:answer, initial_answer_for_step(first_step))
           |> assign(:show_hint, false)
           |> assign(:writing_start_time, writing_start_time(first_step))
           |> assign(:current_wrong_strokes, 0)
           |> assign(:challenge_score, 0)
           |> assign(:meaning_answer, "")
           |> assign(:reading_answer, "")
           |> assign(:selected_answer, nil)
           |> assign(:feedback, nil)
           |> assign(:correct_meaning, nil)
           |> assign(:correct_reading, nil)
           |> assign(:meaning_error, false)
           |> assign(:reading_error, false)}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, gettext("Failed to start test session."))
           |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
      end
    else
      steps = Tests.list_test_steps(test_id)

      # Calculate current step index from session
      current_step_index = session.current_step_index || 0
      current_step = Enum.at(steps, current_step_index)
      {challenge_score, _max} = Tests.calculate_session_score(session.id)

      {:ok,
       socket
       |> assign(:page_title, test.title)
       |> assign(:page_description, test.description || gettext("Take this test on Medoru"))
       |> assign(:classroom, classroom)
       |> assign(:test, test)
       |> assign(:attempt, attempt)
       |> assign(:session, session)
       |> assign(:steps, steps)
       |> assign(:current_step_index, current_step_index)
       |> assign_current_step(current_step)
       |> assign(:total_steps, length(steps))
       |> assign(:time_remaining, attempt.time_remaining_seconds)
       |> assign(:answer, initial_answer_for_step(current_step))
       |> assign(:show_hint, false)
       |> assign(:writing_start_time, writing_start_time(current_step))
       |> assign(:current_wrong_strokes, 0)
       |> assign(:challenge_score, challenge_score)
       |> assign(:meaning_answer, "")
       |> assign(:reading_answer, "")
       |> assign(:selected_answer, nil)
       |> assign(:feedback, nil)
       |> assign(:correct_meaning, nil)
       |> assign(:correct_reading, nil)
       |> assign(:meaning_error, false)
       |> assign(:reading_error, false)}
    end
  end

  defp start_new_test_session(socket, _classroom_test, classroom_id, test_id, user) do
    test = Tests.get_test!(test_id)
    classroom = Classrooms.get_classroom!(classroom_id)

    # Use classroom test settings or fall back to test defaults.
    # max_attempts is the number of allowed attempts, NOT seconds.
    time_limit = test.time_limit_seconds || 3600

    # Start a new test attempt
    case Classrooms.start_test_attempt(
           classroom_id,
           user.id,
           test_id,
           time_limit,
           test.total_points
         ) do
      {:ok, attempt} ->
        # Create a test session for the attempt
        case Tests.start_test_session(user.id, test_id) do
          {:ok, session} ->
            # Link attempt to session and reload
            {:ok, updated_attempt} =
              attempt
              |> Ecto.Changeset.change(test_session_id: session.id)
              |> Medoru.Repo.update()

            steps = Tests.list_test_steps(test_id)
            first_step = List.first(steps)

            {:ok,
             socket
             |> assign(:page_title, test.title)
             |> assign(:page_description, test.description || gettext("Take this test on Medoru"))
             |> assign(:classroom, classroom)
             |> assign(:test, test)
             |> assign(:attempt, updated_attempt)
             |> assign(:session, session)
             |> assign(:steps, steps)
             |> assign(:current_step_index, 0)
             |> assign_current_step(first_step)
             |> assign(:total_steps, length(steps))
             |> assign(:time_remaining, updated_attempt.time_remaining_seconds)
             |> assign(:answer, initial_answer_for_step(first_step))
             |> assign(:show_hint, false)
             |> assign(:meaning_answer, "")
             |> assign(:reading_answer, "")
             |> assign(:selected_answer, nil)
             |> assign(:feedback, nil)
             |> assign(:correct_meaning, nil)
             |> assign(:correct_reading, nil)
             |> assign(:meaning_error, false)
             |> assign(:reading_error, false)
             |> assign(:writing_start_time, writing_start_time(first_step))
             |> assign(:current_wrong_strokes, 0)
             |> assign(:challenge_score, 0)}

          {:error, _} ->
            {:ok,
             socket
             |> put_flash(:error, gettext("Failed to start test session."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
        end

      {:error, :already_attempted} ->
        {:ok,
         socket
         |> put_flash(:info, gettext("You have already taken this test."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Failed to start test."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
    end
  end

  # Helper function to initialize answer based on step type
  defp initial_answer_for_step(nil), do: ""
  defp initial_answer_for_step(%{question_type: :fill}), do: %{"meaning" => "", "reading" => ""}
  defp initial_answer_for_step(%{question_type: :word_order}), do: []
  defp initial_answer_for_step(%{question_type: :sentence_validation}), do: ""
  defp initial_answer_for_step(%{question_type: :conjugation}), do: ""
  defp initial_answer_for_step(%{question_type: :grammar_pattern}), do: ""
  defp initial_answer_for_step(%{question_type: :writing_fill_in}), do: %{}
  defp initial_answer_for_step(%{question_type: :image_to_meaning}), do: nil

  defp initial_answer_for_step(%{question_type: :reading_text}),
    do: %{"meaning" => "", "reading" => ""}

  defp initial_answer_for_step(_), do: ""

  @impl true
  def handle_event("submit_answer", %{"answer" => "skipped"}, socket) do
    # User skipped a writing question - mark as incorrect
    submit_writing_answer(socket, false, 0.0)
  end

  @impl true
  def handle_event("show_hint", _, socket) do
    hint_used = socket.assigns.current_step.question_type == :listening

    {:noreply,
     socket
     |> assign(:show_hint, true)
     |> assign(:hint_used, hint_used)}
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
  def handle_event("submit_reading_text", params, socket) do
    handle_reading_text_answer(socket, params)
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    # User clicked skip button - mark as incorrect and move to next
    step = socket.assigns.current_step
    session = socket.assigns.session

    # Record the skipped answer as incorrect
    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => "skipped",
        "time_spent_seconds" => 10,
        "step_index" => step.order_index,
        "is_correct" => false,
        "points_earned" => 0,
        "metadata" => %{"skipped" => true}
      })

    case result do
      {:ok, _step_answer} ->
        # Update attempt progress
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: 0,
            time_spent_seconds: attempt.time_spent_seconds + 10
          }
        end)

        # Move to next step or complete
        next_index = socket.assigns.current_step_index + 1

        if next_index >= socket.assigns.total_steps do
          maybe_complete_test(socket, session.id)
        else
          Tests.update_session_progress(session.id, next_index)
          next_step = Enum.at(socket.assigns.steps, next_index)

          {:noreply,
           socket
           |> assign(:current_step_index, next_index)
           |> assign_current_step(next_step)
           |> assign(:answer, initial_answer_for_step(next_step))
           |> assign(:show_hint, false)
           |> assign(:writing_start_time, writing_start_time(next_step))
           |> assign(:current_wrong_strokes, 0)
           |> assign(:meaning_answer, "")
           |> assign(:reading_answer, "")
           |> assign(:selected_answer, nil)
           |> assign(:feedback, nil)
           |> assign(:correct_meaning, nil)
           |> assign(:correct_reading, nil)
           |> assign(:meaning_error, false)
           |> assign(:reading_error, false)}
        end

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to skip question: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to skip question. Please try again."))}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer_map}, socket) when is_map(answer_map) do
    # Handle fill question with meaning and optional reading
    step = socket.assigns.current_step
    session = socket.assigns.session

    # Extract values from form
    meaning = answer_map["meaning"]
    reading = answer_map["reading"]

    # Check if reading is required for this step
    include_reading = get_in(step.question_data, ["include_reading"]) || false

    # Validate answers
    correct_meaning = step.correct_answer
    correct_reading = get_in(step.question_data, ["reading_answer"]) || ""

    meaning_correct = validate_meaning(meaning, correct_meaning)
    reading_correct = if reading, do: validate_reading(reading, correct_reading), else: false

    # Calculate points based on include_reading flag
    # If reading is included: 2 points for meaning, 1 point for reading
    # If reading is NOT included: 2 points for meaning only
    points_earned =
      cond do
        include_reading and meaning_correct and reading_correct -> 3
        include_reading and meaning_correct -> 2
        include_reading and reading_correct -> 1
        not include_reading and meaning_correct -> 2
        true -> 0
      end

    # Record the answer
    answer_text = if include_reading and reading, do: "#{meaning} / #{reading}", else: meaning

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer_text,
        "time_spent_seconds" => 30,
        "step_index" => step.order_index,
        "is_correct" => meaning_correct and (not include_reading or reading_correct),
        "points_earned" => points_earned,
        "metadata" => %{
          "meaning" => meaning,
          "reading" => reading,
          "meaning_correct" => meaning_correct,
          "reading_correct" => reading_correct,
          "correct_meaning" => correct_meaning,
          "correct_reading" => correct_reading,
          "include_reading" => include_reading
        }
      })

    case result do
      {:ok, _step_answer} ->
        # Update attempt progress
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 30
          }
        end)

        # Move to next step or complete
        next_index = socket.assigns.current_step_index + 1

        if next_index >= socket.assigns.total_steps do
          # Complete the test
          maybe_complete_test(socket, session.id)
        else
          # Update session progress for resume functionality
          Tests.update_session_progress(session.id, next_index)

          next_step = Enum.at(socket.assigns.steps, next_index)

          {:noreply,
           socket
           |> assign(:current_step_index, next_index)
           |> assign_current_step(next_step)
           |> assign(:answer, initial_answer_for_step(next_step))
           |> assign(:show_hint, false)
           |> assign(:writing_start_time, writing_start_time(next_step))
           |> assign(:current_wrong_strokes, 0)}
        end

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"writing_fill_in_answer" => answers}, socket)
      when is_map(answers) do
    step = socket.assigns.current_step
    session = socket.assigns.session

    answer =
      WritingFillInComponents.build_filled_sentence(
        step.question_data["template"] || "",
        answers
      )

    handle_writing_fill_in_answer(socket, answer, step, session)
  end

  @impl true
  def handle_event("submit_answer", params, socket) do
    step = socket.assigns.current_step
    session = socket.assigns.session

    # Handle grammar step types with special scoring
    case step.question_type do
      :image_to_meaning ->
        handle_image_to_meaning_answer(socket)

      :sentence_validation ->
        handle_sentence_validation_answer(socket, params["answer"], step, session)

      :conjugation ->
        handle_conjugation_answer(socket, params["answer"], step, session)

      :conjugation_multichoice ->
        handle_conjugation_multichoice_answer(socket, params["answer"], step, session)

      :word_order ->
        handle_word_order_answer(socket, params["answer"], step, session)

      :grammar_pattern ->
        handle_grammar_pattern_answer(socket, params["answer"], step, session)

      _ ->
        # Standard multichoice handling
        handle_standard_answer(socket, params["answer"], step, session)
    end
  end

  @impl true
  def handle_event("update_writing_fill_in", params, socket) do
    index = params["index"]

    value =
      params["value"] ||
        get_in(params, ["writing_fill_in_answer", to_string(index)]) || ""

    answer = Map.put(socket.assigns.answer, index, value)
    {:noreply, assign(socket, :answer, answer)}
  end

  # Timer and Writing event handlers
  @impl true
  def handle_event("time_up", _, socket) do
    # Anonymous featured-classroom tests are untimed; ignore time_up.
    if socket.assigns[:is_anonymous] do
      {:noreply, socket}
    else
      # Timer ran out - auto-submit the test
      auto_submit_test(socket)
    end
  end

  @impl true
  def handle_event("sync_time", %{"time_remaining" => time_remaining}, socket) do
    # Anonymous users have no attempt record to sync.
    if socket.assigns[:is_anonymous] do
      {:noreply, socket}
    else
      # Periodic sync from client-side timer - update DB and server state.
      # The timer display is driven by the client-side JS hook, so updating
      # the assign here does not produce visible flicker.
      attempt = socket.assigns.attempt

      Task.start(fn ->
        Classrooms.update_test_progress(attempt.id, %{
          time_remaining_seconds: time_remaining
        })
      end)

      {:noreply, assign(socket, :time_remaining, time_remaining)}
    end
  end

  @impl true
  def handle_event("kanji_complete", params, socket) do
    # All strokes drawn correctly - submit as correct answer
    wrong_strokes = parse_wrong_strokes(params)
    submit_writing_answer(socket, true, 1.0, wrong_strokes)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed} = params, socket)
      when completed in ["true", true] do
    # Submit button clicked when kanji is complete - treat same as kanji_complete
    wrong_strokes = parse_wrong_strokes(params)
    submit_writing_answer(socket, true, 1.0, wrong_strokes)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => completed}, socket)
      when completed in ["false", false] do
    # User gave up or skipped - mark as incorrect
    submit_writing_answer(socket, false, 0.0, 0)
  end

  @impl true
  def handle_event("wrong_stroke", params, socket) do
    # Wrong stroke drawn - the KanjiWriting hook updates the counter client-side
    # instantly. For kanji drawing tests we also keep the count server-side so
    # step transitions don't reset the displayed score.
    if socket.assigns.test.metadata["kanji_drawing"] == true do
      count = parse_wrong_strokes(params)
      {:noreply, assign(socket, :current_wrong_strokes, count)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stroke_incorrect", _params, socket) do
    # KanjiWriter library cleared the stroke automatically
    {:noreply, put_flash(socket, :error, gettext("Try again - follow the red guide"))}
  end

  # Grammar Step Handlers
  @impl true
  def handle_event("word_order_click", %{"word" => word, "action" => "add"}, socket) do
    step = socket.assigns.current_step
    current_answer = socket.assigns.answer || []

    # Parse available words from question_data (handles newline-separated strings)
    question_data = step.question_data || %{}
    available_words = parse_word_order_words(question_data["words"])

    # Count occurrences in current answer
    used_count = Enum.count(current_answer, &(&1 == word))
    available_count = Enum.count(available_words, &(&1 == word))

    if used_count < available_count do
      new_answer = current_answer ++ [word]
      {:noreply, assign(socket, :answer, new_answer)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("word_order_remove", %{"index" => index}, socket) do
    current_answer = socket.assigns.answer || []
    index = String.to_integer(index)

    new_answer = List.delete_at(current_answer, index)
    {:noreply, assign(socket, :answer, new_answer)}
  end

  @impl true
  def handle_event("word_order_clear", _params, socket) do
    {:noreply, assign(socket, :answer, [])}
  end

  # Standard answer handler for multichoice questions
  defp handle_standard_answer(socket, answer, step, session) do
    attrs = %{
      "answer" => answer,
      "time_spent_seconds" => 30,
      "step_index" => step.order_index
    }

    attrs =
      if step.question_type == :listening && socket.assigns.hint_used do
        Map.put(attrs, "hints_used", 1)
      else
        attrs
      end

    result = Tests.record_step_answer(session.id, step.id, attrs)

    case result do
      {:ok, step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: step_answer.points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 30
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Image-to-meaning: answer is the selected option (meaning text). Validation is done
  # via option_word_ids in TestStepAnswer, so we just record the selected answer.
  defp handle_image_to_meaning_answer(socket) do
    step = socket.assigns.current_step
    session = socket.assigns.session
    answer = socket.assigns.selected_answer

    if is_nil(answer) or String.trim(answer) == "" do
      {:noreply, put_flash(socket, :error, gettext("Please select an image"))}
    else
      result =
        Tests.record_step_answer(session.id, step.id, %{
          "answer" => answer,
          "time_spent_seconds" => 30,
          "step_index" => step.order_index
        })

      case result do
        {:ok, step_answer} ->
          maybe_update_attempt_progress(socket, fn attempt ->
            %{
              score: step_answer.points_earned,
              time_spent_seconds: attempt.time_spent_seconds + 30
            }
          end)

          move_to_next_step(socket, session)

        {:error, changeset} ->
          require Logger
          Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

          {:noreply,
           put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
      end
    end
  end

  # Reading text: validate meaning and reading separately, then record.
  defp handle_reading_text_answer(socket, params) do
    step = socket.assigns.current_step
    session = socket.assigns.session
    is_kana_only = step.question_data["is_kana_only"] || false

    meaning =
      params
      |> Map.get("meaning_answer", socket.assigns.meaning_answer)
      |> to_string()
      |> String.trim()

    reading =
      params
      |> Map.get("reading_answer", socket.assigns.reading_answer)
      |> to_string()
      |> String.trim()

    if meaning == "" or (not is_kana_only and reading == "") do
      {:noreply, put_flash(socket, :error, gettext("Please enter both meaning and reading"))}
    else
      word = if step.word_id, do: Content.get_word!(step.word_id), else: nil

      if word do
        locale = socket.assigns[:locale] || "en"

        {:ok, validation} =
          ReadingAnswerValidator.validate_answer(
            word,
            meaning,
            reading,
            locale,
            skip_reading: is_kana_only
          )

        answer_text =
          Jason.encode!(%{
            meaning: meaning,
            reading: reading,
            validation: validation
          })

        result =
          Tests.record_step_answer(session.id, step.id, %{
            "answer" => answer_text,
            "time_spent_seconds" => 30,
            "step_index" => step.order_index,
            "is_correct" => validation.both_correct
          })

        case result do
          {:ok, _step_answer} ->
            if validation.both_correct do
              maybe_update_attempt_progress(socket, fn attempt ->
                %{
                  score: step.points,
                  time_spent_seconds: attempt.time_spent_seconds + 30
                }
              end)

              move_to_next_step(socket, session)
            else
              {:noreply,
               socket
               |> assign(:feedback, :incorrect)
               |> assign(:meaning_error, not validation.meaning_correct)
               |> assign(:reading_error, not validation.reading_correct)
               |> assign(:correct_meaning, word.meaning)
               |> assign(:correct_reading, word.reading)
               |> assign(:show_hint, true)}
            end

          {:error, changeset} ->
            require Logger
            Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

            {:noreply,
             put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
        end
      else
        {:noreply, put_flash(socket, :error, gettext("Error: word not found"))}
      end
    end
  end

  # Sentence validation: 10 points, -3 per wrong attempt, min 1 point
  defp handle_sentence_validation_answer(socket, answer, step, session) do
    # Get existing answer for this step (only one record exists per step due to unique constraint)
    existing_answers = Tests.list_test_step_answers(session.id, step.id)
    existing_answer = List.first(existing_answers)

    # Count previous wrong attempts from the attempts field
    previous_attempts = if existing_answer, do: existing_answer.attempts, else: 0

    # Validate against grammar pattern
    pattern = get_in(step.question_data, ["pattern"]) || []

    is_correct =
      case Validator.validate_sentence(answer, pattern) do
        {:ok, _breakdown} -> true
        {:error, _reason} -> false
      end

    # This is the current attempt number
    current_attempt = previous_attempts + 1

    # Calculate points: 10 - 3*(current_attempt-1), min 1
    points_earned =
      if is_correct do
        max(1, 10 - (current_attempt - 1) * 3)
      else
        0
      end

    # Record the answer
    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "step_index" => step.order_index,
        "time_spent_seconds" => 45,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "attempts" => current_attempt,
        "metadata" => %{
          "grammar_step" => true,
          "wrong_attempts" => previous_attempts,
          "pattern" => pattern
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 45
          }
        end)

        # Max 4 attempts total
        if is_correct or current_attempt >= 4 do
          # Correct or max attempts reached - move to next
          move_to_next_step(socket, session)
        else
          # Wrong but can retry - stay on this step
          {:noreply,
           socket
           |> put_flash(
             :error,
             gettext("Incorrect. Try again! (%{current}/4 attempts)",
               current: current_attempt
             )
           )
           |> assign(:answer, "")}
        end

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Conjugation: 3 points, single attempt, text validation
  defp handle_conjugation_answer(socket, answer, step, session) do
    question_data = step.question_data || %{}
    correct_answer = question_data["generated_answer"] || step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)
    points_earned = if is_correct, do: 3, else: 0

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 30,
        "step_index" => step.order_index,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "metadata" => %{
          "grammar_step" => true,
          "conjugation" => true,
          "correct_answer" => correct_answer
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 30
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Conjugation multichoice: 3 points, single attempt, option selection
  defp handle_conjugation_multichoice_answer(socket, answer, step, session) do
    question_data = step.question_data || %{}
    correct_answer = question_data["generated_answer"] || step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)
    points_earned = if is_correct, do: 3, else: 0

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 20,
        "step_index" => step.order_index,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "metadata" => %{
          "grammar_step" => true,
          "conjugation_multichoice" => true
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 20
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Word order: 3 points, single attempt, drag-drop validation
  defp handle_word_order_answer(socket, answer, step, session) do
    # answer is the joined string from word_order question
    correct_answer = step.correct_answer
    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)
    points_earned = if is_correct, do: 3, else: 0

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 40,
        "step_index" => step.order_index,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "metadata" => %{
          "grammar_step" => true,
          "word_order" => true,
          "word_selection" => socket.assigns.answer || []
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 40
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Grammar pattern: compare against correct_answer and alt_correct_answers
  defp handle_grammar_pattern_answer(socket, answer, step, session) do
    question_data = step.question_data || %{}
    correct_answer = step.correct_answer
    alt_answers = question_data["alt_correct_answers"] || []

    normalized = normalize_answer(answer)

    is_correct =
      normalized == normalize_answer(correct_answer) ||
        Enum.any?(alt_answers, &(normalize_answer(&1) == normalized))

    points_earned = if is_correct, do: 10, else: 0

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 40,
        "step_index" => step.order_index,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "metadata" => %{
          "grammar_step" => true,
          "grammar_pattern" => true
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 40
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  defp handle_writing_fill_in_answer(socket, answer, step, session) do
    question_data = step.question_data || %{}
    correct_answer = step.correct_answer
    alt_answers = question_data["alt_correct_answers"] || []

    normalized = normalize_answer(answer)

    is_correct =
      normalized == normalize_answer(correct_answer) ||
        Enum.any?(alt_answers, &(normalize_answer(&1) == normalized))

    points_earned = if is_correct, do: step.points, else: 0

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 40,
        "step_index" => step.order_index,
        "is_correct" => is_correct,
        "points_earned" => points_earned,
        "metadata" => %{
          "writing_fill_in" => true,
          "blank_answers" => socket.assigns.answer
        }
      })

    case result do
      {:ok, _step_answer} ->
        maybe_update_attempt_progress(socket, fn attempt ->
          %{
            score: points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 40
          }
        end)

        move_to_next_step(socket, session)

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  # Helper to move to next step or complete test
  defp move_to_next_step(socket, session) do
    next_index = socket.assigns.current_step_index + 1

    if next_index >= socket.assigns.total_steps do
      maybe_complete_test(socket, session.id)
    else
      Tests.update_session_progress(session.id, next_index)
      next_step = Enum.at(socket.assigns.steps, next_index)

      {:noreply,
       socket
       |> assign(:current_step_index, next_index)
       |> assign_current_step(next_step)
       |> assign(:answer, initial_answer_for_step(next_step))
       |> assign(:show_hint, false)
       |> assign(:writing_start_time, writing_start_time(next_step))
       |> assign(:current_wrong_strokes, 0)
       |> assign(:meaning_answer, "")
       |> assign(:reading_answer, "")
       |> assign(:selected_answer, nil)
       |> assign(:feedback, nil)
       |> assign(:correct_meaning, nil)
       |> assign(:correct_reading, nil)
       |> assign(:meaning_error, false)
       |> assign(:reading_error, false)}
    end
  end

  # Private helper functions
  defp normalize_answer(answer) when is_binary(answer) do
    answer
    |> String.trim()
    |> String.replace(~r/\s+/, "")
    |> String.replace(~r/\p{P}/u, "")
  end

  defp normalize_answer(answer), do: to_string(answer)

  defp parse_wrong_strokes(params) when is_map(params) do
    case params do
      %{"wrong_strokes" => n} when is_integer(n) -> n
      %{"wrong_strokes" => n} when is_binary(n) -> String.to_integer(n)
      %{"count" => n} when is_integer(n) -> n
      %{"count" => n} when is_binary(n) -> String.to_integer(n)
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp parse_wrong_strokes(_), do: 0

  defp submit_writing_answer(socket, correct, accuracy, wrong_strokes \\ 0) do
    step = socket.assigns.current_step
    session = socket.assigns.session
    kanji_drawing? = socket.assigns.test.metadata["kanji_drawing"] == true

    # Check if answer already exists for this step (prevent double submission)
    existing_answers = Tests.list_test_step_answers(session.id, step.id)

    if length(existing_answers) > 0 do
      # Already answered - just move to next step without error
      next_index = socket.assigns.current_step_index + 1

      if next_index >= socket.assigns.total_steps do
        maybe_complete_test(socket, session.id)
      else
        next_step = Enum.at(socket.assigns.steps, next_index)
        Tests.update_session_progress(session.id, next_index)

        {:noreply,
         socket
         |> assign(:current_step_index, next_index)
         |> assign_current_step(next_step)
         |> assign(:answer, initial_answer_for_step(next_step))
         |> assign(:show_hint, false)
         |> assign(:writing_start_time, nil)
         |> assign(:current_wrong_strokes, 0)
         |> assign(:meaning_answer, "")
         |> assign(:reading_answer, "")
         |> assign(:selected_answer, nil)
         |> assign(:feedback, nil)
         |> assign(:correct_meaning, nil)
         |> assign(:correct_reading, nil)
         |> assign(:meaning_error, false)
         |> assign(:reading_error, false)}
      end
    else
      # Calculate time spent on this writing step
      start_time = socket.assigns[:writing_start_time]

      time_spent_seconds =
        if start_time do
          DateTime.diff(DateTime.utc_now(), start_time, :second)
        else
          # Default if no start time tracked
          45
        end

      # Calculate score based on correctness and time
      points_earned =
        cond do
          kanji_drawing? and correct ->
            max(0, step.points - wrong_strokes)

          kanji_drawing? ->
            0

          correct ->
            calculate_writing_score(step, time_spent_seconds)

          true ->
            0
        end

      is_correct =
        if kanji_drawing? do
          points_earned > 0
        else
          correct
        end

      answer_text = if is_correct, do: "correct", else: "partial"

      result =
        Tests.record_step_answer(session.id, step.id, %{
          "answer" => answer_text,
          "time_spent_seconds" => time_spent_seconds,
          "step_index" => step.order_index,
          "is_correct" => is_correct,
          "points_earned" => points_earned,
          "metadata" => %{
            "accuracy" => accuracy,
            "writing" => true,
            "time_spent" => time_spent_seconds,
            "wrong_strokes" => wrong_strokes,
            "kanji_drawing" => kanji_drawing?
          }
        })

      case result do
        {:ok, _step_answer} ->
          maybe_update_attempt_progress(socket, fn attempt ->
            %{
              score: points_earned,
              time_spent_seconds: attempt.time_spent_seconds + time_spent_seconds
            }
          end)

          next_index = socket.assigns.current_step_index + 1
          Tests.update_session_progress(session.id, next_index)

          if next_index >= socket.assigns.total_steps do
            maybe_complete_test(socket, session.id)
          else
            next_step = Enum.at(socket.assigns.steps, next_index)

            {:noreply,
             socket
             |> assign(:current_step_index, next_index)
             |> assign_current_step(next_step)
             |> assign(:answer, initial_answer_for_step(next_step))
             |> assign(:show_hint, false)
             |> assign(:writing_start_time, nil)
             |> assign(:current_wrong_strokes, 0)
             |> assign(:challenge_score, socket.assigns.challenge_score + points_earned)
             |> assign(:meaning_answer, "")
             |> assign(:reading_answer, "")
             |> assign(:selected_answer, nil)
             |> assign(:feedback, nil)
             |> assign(:correct_meaning, nil)
             |> assign(:correct_reading, nil)
             |> assign(:meaning_error, false)
             |> assign(:reading_error, false)}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to submit answer."))}
      end
    end
  end

  # Calculate writing score based on time and stroke count
  # Wrong answer = 0 points
  # Correct answer = up to 5 points with gentle time decay based on stroke count
  defp calculate_writing_score(step, time_spent_seconds) do
    # Get stroke count from step data
    stroke_count = step.question_data["stroke_count"] || 4

    # Base time limits for full 5 points (generous baseline)
    # Simple kanji (1-4 strokes): 15 seconds for full points
    # Medium kanji (5-8 strokes): 25 seconds for full points
    # Complex kanji (9-12 strokes): 35 seconds for full points
    # Very complex (13-17 strokes): 45 seconds for full points
    # Extreme (18+ strokes): 60 seconds for full points
    base_time =
      cond do
        stroke_count <= 4 -> 15
        stroke_count <= 8 -> 25
        stroke_count <= 12 -> 35
        stroke_count <= 17 -> 45
        true -> 60
      end

    # Calculate score with gentle decay
    # Full points if within base_time
    # -1 point for each additional base_time period
    # Minimum 3 points for any correct answer (was 0, now ensures recognition)
    cond do
      time_spent_seconds <= base_time -> 5
      time_spent_seconds <= base_time * 2 -> 4
      time_spent_seconds <= base_time * 3 -> 3
      true -> 3
    end
  end

  defp complete_test(socket, session_id, attempt_id) do
    # Calculate final score
    {score, max_score} = Tests.calculate_session_score(session_id)

    attempt = socket.assigns.attempt

    # Kanji drawing tests are untimed, so the remaining-timer calculation
    # would always report ~0 seconds. Use the real elapsed time since the
    # attempt started for those tests.
    time_spent_seconds =
      if socket.assigns.test.metadata["kanji_drawing"] == true do
        DateTime.diff(DateTime.utc_now(), attempt.started_at, :second)
      else
        attempt.time_limit_seconds - socket.assigns.time_remaining
      end

    # If the timer hasn't been synced yet (e.g. the user finished before the
    # first periodic sync), fall back to wall-clock elapsed time so the result
    # isn't reported as 0:00.
    time_spent_seconds =
      if time_spent_seconds <= 0 do
        DateTime.diff(DateTime.utc_now(), attempt.started_at, :second)
      else
        time_spent_seconds
      end

    time_spent_seconds = min(max(time_spent_seconds, 0), attempt.time_limit_seconds)

    # Complete the classroom attempt and the underlying test session so the
    # results page can read consistent score/time data from either source.
    attrs = %{
      test_session_id: session_id,
      score: score,
      max_score: max_score,
      points_earned: score,
      time_spent_seconds: time_spent_seconds,
      time_remaining_seconds: socket.assigns.time_remaining
    }

    with {:ok, _attempt} <- Classrooms.complete_test_attempt(attempt_id, attrs),
         {:ok, _session} <-
           Tests.complete_test_session(session_id, score, max_score, time_spent_seconds) do
      {:noreply,
       socket
       |> push_navigate(
         to:
           ~p"/classrooms/#{socket.assigns.classroom.id}/tests/#{socket.assigns.test.id}/results"
       )}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to complete test."))}
    end
  end

  defp auto_submit_test(socket) do
    session = socket.assigns.session
    attempt = socket.assigns.attempt

    {score, max_score} = Tests.calculate_session_score(session.id)

    attrs = %{
      test_session_id: session.id,
      score: score,
      max_score: max_score,
      points_earned: score,
      time_spent_seconds: attempt.time_limit_seconds,
      time_remaining_seconds: 0,
      auto_submitted: true
    }

    with {:ok, _} <- Classrooms.complete_test_attempt(attempt.id, attrs),
         {:ok, _} <-
           Tests.complete_test_session(session.id, score, max_score, attempt.time_limit_seconds) do
      {:noreply,
       socket
       |> put_flash(:warning, gettext("Time's up! Your test was auto-submitted."))
       |> push_navigate(
         to:
           ~p"/classrooms/#{socket.assigns.classroom.id}/tests/#{socket.assigns.test.id}/results"
       )}
    else
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to submit test."))}
    end
  end

  # Updates the classroom test attempt progress, if the user is authenticated.
  # Anonymous users in the featured classroom do not have an attempt record.
  defp maybe_update_attempt_progress(socket, attrs_fun) when is_function(attrs_fun, 1) do
    if socket.assigns[:is_anonymous] do
      {:ok, nil}
    else
      attempt = socket.assigns.attempt
      Classrooms.update_test_progress(attempt.id, attrs_fun.(attempt))
    end
  end

  # Completes a test. For authenticated users this persists the classroom attempt;
  # for anonymous users it completes the test session and redirects with the
  # session id so the results page can display the outcome.
  defp maybe_complete_test(socket, session_id) do
    if socket.assigns[:is_anonymous] do
      complete_anonymous_test(socket, session_id)
    else
      complete_test(socket, session_id, socket.assigns.attempt.id)
    end
  end

  defp complete_anonymous_test(socket, session_id) do
    {score, max_score} = Tests.calculate_session_score(session_id)

    Tests.update_session_progress(session_id, socket.assigns.total_steps, 0)

    Tests.complete_test_session(session_id, score, max_score, 0)

    {:noreply,
     socket
     |> push_navigate(
       to:
         ~p"/classrooms/#{socket.assigns.classroom.id}/tests/#{socket.assigns.test.id}/results?session_id=#{session_id}"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8" data-theme={@classroom.theme}>
        <%!-- Header - Mobile Optimized --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4 mb-4 sm:mb-8">
          <div class="flex-1 min-w-0">
            <.link
              navigate={~p"/classrooms/#{@classroom.slug}?tab=tests"}
              class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-1 sm:mb-2 transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Tests")}
            </.link>
            <h1 class="text-xl sm:text-2xl font-bold text-base-content truncate">{@test.title}</h1>
            <p class="text-secondary text-xs sm:text-sm">{@classroom.name}</p>
          </div>

          <%!-- Timer - updated by JS hook to avoid re-rendering form --%>
          <div class="flex items-center gap-2 bg-base-200 px-3 sm:px-4 py-2 rounded-lg self-start sm:self-auto shrink-0">
            <.icon name="hero-clock" class="w-4 h-4 sm:w-5 sm:h-5 text-secondary" />
            <span
              id="timer-display"
              class="font-mono text-base sm:text-lg font-bold text-base-content"
              phx-update="ignore"
            >
              {format_time(@time_remaining)}
            </span>
          </div>
        </div>

        <%!-- Progress Bar --%>
        <div class="mb-4 sm:mb-8">
          <div class="flex justify-between text-xs sm:text-sm text-secondary mb-1 sm:mb-2">
            <span>
              {gettext("Question %{current} of %{total}",
                current: @current_step_index + 1,
                total: @total_steps
              )}
            </span>
            <span>
              {format_percentage((@current_step_index + 1) / @total_steps * 100)}%{gettext(
                " complete"
              )}
            </span>
          </div>
          <div class="h-1.5 sm:h-2 bg-base-200 rounded-full overflow-hidden">
            <div
              class="h-full bg-primary transition-all duration-300"
              style={"width: #{((@current_step_index + 1) / @total_steps) * 100}%"}
            />
          </div>
        </div>

        <%!-- Question Card --%>
        <div class="card bg-base-100 border border-base-300 shadow-lg">
          <div class="card-body p-4 sm:p-6">
            <%= if @current_step do %>
              <div class="mb-4 sm:mb-6">
                <span class="badge badge-outline badge-xs sm:badge-sm mb-2 sm:mb-4">
                  {@current_step.question_type
                  |> to_string()
                  |> String.replace("_", " ")
                  |> String.capitalize()}
                </span>

                <%= if @current_step.step_type == :vocabulary do %>
                  <p class="text-sm sm:text-base text-secondary mb-2 sm:mb-3">
                    {vocabulary_question_prompt(@current_step)}
                  </p>
                  <h2 class="text-2xl sm:text-3xl font-bold text-primary font-japanese text-center">
                    {@current_step.question_data["word_text"] || @current_step.question}
                  </h2>
                  <%= if @current_step.question_data["word_reading"] && @current_step.question_data["question_label"] != "reading" do %>
                    <p class="text-center text-secondary text-sm sm:text-base mt-2">
                      {gettext("Reading:")} {@current_step.question_data["word_reading"]}
                    </p>
                  <% end %>
                  <%= if @current_step.question_data["word_meaning"] && @current_step.question_data["question_label"] == "reading" do %>
                    <p class="text-center text-secondary text-sm sm:text-base mt-2">
                      {gettext("Meaning:")} {localize_question_data_meaning(
                        @current_step.question_data,
                        @locale
                      )}
                    </p>
                  <% end %>
                <% else %>
                  <%= if @current_step.question_type != :writing do %>
                    <h2 class="text-lg sm:text-xl font-medium text-base-content leading-relaxed">
                      {@current_step.question}
                    </h2>
                  <% end %>
                <% end %>
              </div>

              <%!-- Answer Input --%>
              <form
                phx-submit={
                  if @current_step.question_type == :reading_text,
                    do: "submit_reading_text",
                    else: "submit_answer"
                }
                class="space-y-4"
              >
                <%= case @current_step.question_type do %>
                  <% :multichoice -> %>
                    <div class="space-y-2">
                      <%= for option <- @current_step.options do %>
                        <% display_option =
                          if @current_step.question_data["question_label"] != "reading",
                            do: localize_option(option, @locale),
                            else: option %>
                        <label class="flex items-center gap-3 p-4 bg-base-200 rounded-lg cursor-pointer hover:bg-base-300 transition-colors">
                          <input
                            type="radio"
                            name="answer"
                            value={option}
                            required
                            class="radio radio-primary"
                          />
                          <span class="text-base-content">{display_option}</span>
                        </label>
                      <% end %>
                    </div>
                  <% :reading_text -> %>
                    <MedoruWeb.LessonTestLive.ReadingTextComponent.reading_text_question
                      step={@current_step}
                      meaning_answer={@meaning_answer}
                      reading_answer={@reading_answer}
                      feedback={@feedback}
                      show_hint={@show_hint}
                      meaning_error={@meaning_error}
                      reading_error={@reading_error}
                      correct_meaning={@correct_meaning}
                      correct_reading={@correct_reading}
                    />
                  <% :image_to_meaning -> %>
                    <div class="space-y-4">
                      <%= if @current_step.question_data["word_reading"] do %>
                        <p class="text-center text-secondary text-sm sm:text-base">
                          {gettext("Reading:")} {@current_step.question_data["word_reading"]}
                        </p>
                      <% end %>

                      <div class="grid grid-cols-2 gap-3 sm:gap-4">
                        <%= for {option, index} <- Enum.with_index(@current_step.options) do %>
                          <% image_data =
                            @current_step.question_data["image_options"] |> Enum.at(index) %>
                          <% is_selected = @selected_answer == option %>
                          <button
                            type="button"
                            phx-click="select_answer"
                            phx-value-answer={option}
                            class={[
                              "relative rounded-xl border-2 overflow-hidden aspect-square transition-all duration-200",
                              if is_selected do
                                "border-primary ring-2 ring-primary"
                              else
                                "border-base-200 hover:border-primary/50 hover:shadow-md"
                              end
                            ]}
                          >
                            <%= if image_data && image_data["image_path"] do %>
                              <img
                                src={image_data["image_path"]}
                                alt={option}
                                class="w-full h-full object-cover"
                                loading="lazy"
                              />
                            <% else %>
                              <div class="w-full h-full flex items-center justify-center bg-base-200">
                                <span class="text-secondary text-sm text-center px-2">
                                  {option}
                                </span>
                              </div>
                            <% end %>
                          </button>
                        <% end %>
                      </div>

                      <%= if is_nil(@selected_answer) do %>
                        <input type="hidden" name="answer" value="" />
                      <% else %>
                        <input type="hidden" name="answer" value={@selected_answer} />
                      <% end %>
                    </div>
                  <% :listening -> %>
                    <div class="space-y-4">
                      <%!-- Audio Player --%>
                      <%= if @current_step.question_data["audio_path"] do %>
                        <div class="bg-base-200 rounded-xl p-4">
                          <audio controls class="w-full" id={"listening-audio-#{@current_step.id}"}>
                            <source src={@current_step.question_data["audio_path"]} />
                            {gettext("Your browser does not support the audio element.")}
                          </audio>
                        </div>
                      <% end %>

                      <%!-- Hint --%>
                      <%= if @current_step.hints != [] do %>
                        <%= if not @show_hint do %>
                          <button
                            type="button"
                            phx-click="show_hint"
                            class="btn btn-outline btn-sm btn-info"
                          >
                            <.icon name="hero-light-bulb" class="h-4 w-4" />
                            {gettext("Show Hint")}
                          </button>
                        <% else %>
                          <div class="alert alert-info alert-soft">
                            <.icon name="hero-light-bulb" class="h-5 w-5" />
                            <span>{gettext("Hint:")} {List.first(@current_step.hints)}</span>
                          </div>
                        <% end %>
                      <% end %>

                      <%!-- Options --%>
                      <div class="space-y-2">
                        <%= for option <- @current_options do %>
                          <label class="flex items-center gap-3 p-4 bg-base-200 rounded-lg cursor-pointer hover:bg-base-300 transition-colors">
                            <input
                              type="radio"
                              name="answer"
                              value={option}
                              required
                              class="radio radio-primary"
                            />
                            <span class="text-base-content">{option}</span>
                          </label>
                        <% end %>
                      </div>
                    </div>
                  <% :writing -> %>
                    <span id="debug-wrong-strokes" class="hidden">{@current_wrong_strokes}</span>
                    <MedoruWeb.LessonTestLive.WritingComponent.writing_question
                      step={@current_step}
                      target="writing-component"
                      locale={@locale}
                      kanji_drawing={@test.metadata["kanji_drawing"] == true}
                      challenge_base={@challenge_score}
                      total_points={@test.total_points}
                      current_wrong_strokes={@current_wrong_strokes}
                    />
                    <%!-- Hidden input for form submission when skipping --%>
                    <input type="hidden" name="answer" value="skipped" />
                  <% :fill -> %>
                    <div class="space-y-4" id={"fill-inputs-#{@current_step.id}"}>
                      <%!-- Hidden field to ensure answer is always a map --%>
                      <input type="hidden" name="answer[_dummy]" value="1" />
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          {gettext("Meaning (in English):")}
                        </label>
                        <.input
                          type="text"
                          name="answer[meaning]"
                          id={"answer-meaning-#{@current_step.id}"}
                          value={@answer["meaning"] || ""}
                          placeholder={gettext("Type the meaning...")}
                          class="w-full"
                        />
                      </div>
                      <%= if @current_step.question_data && @current_step.question_data["include_reading"] do %>
                        <div>
                          <label class="block text-sm font-medium text-base-content mb-2">
                            {gettext("Reading (in Hiragana):")}
                          </label>
                          <.input
                            type="text"
                            name="answer[reading]"
                            id={"answer-reading-#{@current_step.id}"}
                            value={@answer["reading"] || ""}
                            placeholder={gettext("Type the hiragana reading...")}
                            class="w-full"
                          />
                        </div>
                      <% end %>
                    </div>
                  <% :sentence_validation -> %>
                    <MedoruWeb.ClassroomLive.GrammarComponents.sentence_validation_question
                      step={@current_step}
                      answer={@answer}
                      step_id={@current_step.id}
                    />
                  <% :conjugation -> %>
                    <MedoruWeb.ClassroomLive.GrammarComponents.conjugation_question
                      step={@current_step}
                      answer={@answer}
                      step_id={@current_step.id}
                    />
                  <% :conjugation_multichoice -> %>
                    <MedoruWeb.ClassroomLive.GrammarComponents.conjugation_multichoice_question
                      step={@current_step}
                      step_id={@current_step.id}
                    />
                  <% :word_order -> %>
                    <MedoruWeb.ClassroomLive.GrammarComponents.word_order_question
                      step={@current_step}
                      step_id={@current_step.id}
                      answer={@answer}
                    />
                  <% :grammar_pattern -> %>
                    <MedoruWeb.ClassroomLive.GrammarComponents.grammar_pattern_question
                      step={@current_step}
                      step_id={@current_step.id}
                      answer={@answer}
                    />
                  <% :writing_fill_in -> %>
                    <WritingFillInComponents.fill_in_question
                      step={@current_step}
                      answers={@answer}
                      input_event="update_writing_fill_in"
                      disabled={false}
                    />
                  <% _ -> %>
                    <.input
                      type="text"
                      name="answer"
                      value={@answer}
                      placeholder={gettext("Type your answer...")}
                      required
                      class="w-full"
                    />
                <% end %>

                <%!-- Actions --%>
                <div class="flex flex-col sm:flex-row justify-between items-stretch gap-3 pt-4 border-t border-base-200">
                  <button type="submit" class="w-full sm:w-auto btn btn-primary order-1 min-h-[48px]">
                    <%= if @current_step_index == @total_steps - 1 do %>
                      <.icon name="hero-check" class="w-4 h-4 mr-2" /> {gettext("Finish Test")}
                    <% else %>
                      <.icon name="hero-arrow-right" class="w-4 h-4 mr-2" />
                      {gettext("Next Question")}
                    <% end %>
                  </button>

                  <button
                    type="button"
                    phx-click="skip_question"
                    class="w-full sm:w-auto sm:ml-auto btn btn-outline order-2 sm:order-3 min-h-[48px]"
                  >
                    {gettext("Skip →")}
                  </button>
                </div>
              </form>
            <% else %>
              <div class="text-center py-8">
                <p class="text-secondary">{gettext("No questions available.")}</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>

    <%!-- Timer Hook - handles countdown client-side --%>
    <div
      phx-hook="Timer"
      id="test-timer"
      data-time-remaining={@time_remaining}
      data-sync-interval="10"
    />
    """
  end

  defp format_time(seconds) do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{String.pad_leading("#{mins}", 2, "0")}:#{String.pad_leading("#{secs}", 2, "0")}"
  end

  defp format_percentage(float) when is_float(float), do: trunc(float)
  defp format_percentage(int) when is_integer(int), do: int

  defp vocabulary_question_prompt(step) do
    label = step.question_data["question_label"]

    cond do
      step.question_type == :image_to_meaning ->
        gettext("Choose the picture that matches this word")

      label == "reading" ->
        gettext("How do you read this word?")

      true ->
        gettext("What is the meaning of this word?")
    end
  end

  defp localize_option(option_text, locale) when locale in ["bg", "ja"] do
    case Medoru.Content.get_word_by_meaning(option_text) do
      nil -> option_text
      word -> Medoru.Content.get_localized_meaning(word, locale)
    end
  end

  defp localize_option(option_text, _locale), do: option_text

  defp localize_question_data_meaning(question_data, locale) when locale in ["bg", "ja"] do
    word_meaning = question_data["word_meaning"]

    case Medoru.Content.get_word_by_meaning(word_meaning) do
      nil -> word_meaning
      word -> Medoru.Content.get_localized_meaning(word, locale)
    end
  end

  defp localize_question_data_meaning(question_data, _locale) do
    question_data["word_meaning"]
  end

  # Validate meaning answer (fuzzy match)
  defp validate_meaning(answer, correct) do
    answer_normalized = String.downcase(String.trim(answer))
    correct_normalized = String.downcase(String.trim(correct))

    # Exact match
    # Contains match (e.g., "blue" matches "bluish")
    answer_normalized == correct_normalized or
      String.contains?(answer_normalized, correct_normalized) or
      String.contains?(correct_normalized, answer_normalized)
  end

  # Validate reading answer (exact match with normalization)
  defp validate_reading(answer, correct) do
    answer_normalized =
      answer
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    correct_normalized =
      correct
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    answer_normalized == correct_normalized
  end

  # Return current time for writing steps, nil for other types
  defp writing_start_time(%{question_type: :writing}), do: DateTime.utc_now()
  defp writing_start_time(_), do: nil

  # Parse words for word_order questions from various formats
  defp parse_word_order_words(nil), do: []
  defp parse_word_order_words(words) when is_list(words), do: words

  defp parse_word_order_words(words) when is_binary(words) do
    words
    |> String.split(~r/[\n,]/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # Assigns the current step plus a shuffled option list for listening steps so
  # the correct answer is not always shown in the first position.
  defp assign_current_step(socket, step) do
    socket
    |> assign(:current_step, step)
    |> assign(:current_options, shuffled_options(step))
    |> assign(:show_hint, false)
    |> assign(:hint_used, false)
  end

  @doc false
  def shuffled_options(%{question_type: :listening} = step), do: Enum.shuffle(step.options)
  def shuffled_options(step), do: step.options
end
