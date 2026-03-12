defmodule Medoru.Tests.LessonTestSession do
  @moduledoc """
  Manages lesson test sessions with adaptive retry logic.

  Key behavior: When a user answers a step incorrectly, that step is
  added to the end of the remaining steps queue. The test continues
  until all steps are answered correctly.

  This ensures mastery - users must correctly answer every question.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Tests
  alias Medoru.Tests.{Test, TestSession}
  alias Medoru.Tests.TestStep

  @doc """
  Starts a new lesson test session for a user.

  Creates a test session and builds the initial step queue from the test steps.
  Steps are shuffled for random order.

  ## Examples

      iex> start_lesson_test(user_id, lesson_test_id)
      {:ok, %{session: %TestSession{}, remaining_steps: [%TestStep{}, ...]}}

  """
  def start_lesson_test(user_id, test_id) do
    # Get test with steps
    test =
      Test
      |> where([t], t.id == ^test_id)
      |> preload(:test_steps)
      |> Repo.one!()

    # Check for existing active session
    case Tests.get_active_session(user_id, test_id) do
      nil ->
        # Create new session
        with {:ok, session} <- Tests.start_test_session(user_id, test_id) do
          # Build initial step queue (shuffled)
          remaining_steps = Enum.shuffle(test.test_steps)

          # Store initial queue in session metadata
          updated_session =
            session
            |> Ecto.Changeset.change(
              metadata: %{
                step_queue: Enum.map(remaining_steps, & &1.id),
                current_step_id: List.first(remaining_steps) |> then(&(&1 && &1.id)),
                total_steps: length(remaining_steps),
                wrong_answer_count: 0,
                answer_counter: 0
              }
            )
            |> Repo.update!()

          {:ok,
           %{
             session: updated_session,
             remaining_steps: remaining_steps,
             current_step: List.first(remaining_steps)
           }}
        end

      existing_session ->
        # Resume existing session
        resume_session(existing_session)
    end
  end

  @doc """
  Submits a reading text answer for validation.

  ## Parameters
    * `meaning_answer` - User's English meaning answer
    * `reading_answer` - User's hiragana reading answer
    * `opts` - Additional options

  ## Examples

      iex> submit_reading_text_answer(session_id, step_id, "to eat", "たべる")
      {:correct, %{meaning_correct: true, reading_correct: true}}

  """
  def submit_reading_text_answer(session_id, step_id, meaning_answer, reading_answer, opts \\ []) do
    time_spent = Keyword.get(opts, :time_spent_seconds, 0)

    session =
      TestSession
      |> where([ts], ts.id == ^session_id)
      |> preload(:test)
      |> Repo.one!()

    step = Repo.get!(TestStep, step_id)

    # Load the word for validation
    word =
      if step.word_id do
        Medoru.Content.get_word!(step.word_id)
      else
        nil
      end

    # Validate the answers
    {is_correct, validation_result} =
      if word do
        {:ok, result} =
          Medoru.Tests.ReadingAnswerValidator.validate_answer(
            word,
            meaning_answer,
            reading_answer
          )

        {result.both_correct, result}
      else
        # Fallback if no word associated
        {false, %{meaning_correct: false, reading_correct: false}}
      end

    # Get current metadata
    metadata = session.metadata || %{}
    answer_counter = metadata["answer_counter"] || 0
    step_queue = metadata["step_queue"] || []

    # Record the answer
    answer_text =
      Jason.encode!(%{
        meaning: meaning_answer,
        reading: reading_answer,
        validation: validation_result
      })

    attrs = %{
      "answer" => answer_text,
      "time_spent_seconds" => time_spent,
      "step_index" => answer_counter,
      "is_correct" => is_correct
    }

    {:ok, _step_answer} = Tests.record_step_answer(session_id, step_id, attrs)

    # Update queue based on result
    new_queue =
      if is_correct do
        List.delete(step_queue, step_id)
      else
        # Move to end
        List.delete(step_queue, step_id) ++ [step_id]
      end

    wrong_count =
      if is_correct do
        metadata["wrong_answer_count"] || 0
      else
        (metadata["wrong_answer_count"] || 0) + 1
      end

    next_step_id = List.first(new_queue)

    new_metadata = %{
      metadata
      | "step_queue" => new_queue,
        "wrong_answer_count" => wrong_count,
        "current_step_id" => next_step_id,
        "answer_counter" => answer_counter + 1
    }

    # Update session
    total_steps = metadata["total_steps"] || length(step_queue)
    progress_index = total_steps - length(new_queue)

    updated_session =
      if is_correct do
        session
        |> TestSession.progress_changeset(progress_index, session.time_spent_seconds + time_spent)
        |> Ecto.Changeset.put_change(:metadata, new_metadata)
        |> Repo.update!()
      else
        session
        |> Ecto.Changeset.change(
          metadata: new_metadata,
          current_step_index: session.current_step_index + 1
        )
        |> Repo.update!()
      end

    # Return result
    if is_correct do
      if new_queue == [] do
        complete_lesson_test(updated_session, total_steps)
      else
        next_step = Repo.get!(TestStep, hd(new_queue))

        {:correct,
         %{
           session: updated_session,
           next_step: next_step,
           remaining_count: length(new_queue),
           total_steps: total_steps,
           completed_steps: progress_index,
           validation: validation_result
         }}
      end
    else
      next_step = Repo.get!(TestStep, next_step_id || step_id)

      {:incorrect,
       %{
         session: updated_session,
         next_step: next_step,
         remaining_count: length(new_queue),
         wrong_answer: validation_result,
         retry_position: length(new_queue),
         correct_meaning: word && word.meaning,
         correct_reading: word && word.reading
       }}
    end
  end

  @doc """
  Submits a writing step answer for validation.

  ## Parameters
    * `strokes` - List of strokes, each as list of {x, y} points
    * `opts` - Additional options

  ## Examples

      iex> submit_writing_answer(session_id, step_id, [[{10, 10}, {50, 50}], [{60, 10}, {60, 50}]])
      {:correct, %{accuracy: 0.85}}

  """
  def submit_writing_answer(session_id, step_id, strokes, opts \\ []) do
    time_spent = Keyword.get(opts, :time_spent_seconds, 0)
    # Allow overriding is_correct (used when client validates via kanji_complete)
    is_correct_override = Keyword.get(opts, :is_correct)

    # Parse strokes if sent as JSON string from JavaScript
    # Convert %{"x" => x, "y" => y} format to {x, y} tuples
    parsed_strokes =
      cond do
        is_binary(strokes) ->
          case Jason.decode(strokes) do
            {:ok, decoded} -> convert_stroke_format(decoded)
            {:error, _} -> []
          end

        is_list(strokes) ->
          strokes

        true ->
          []
      end

    session =
      TestSession
      |> where([ts], ts.id == ^session_id)
      |> preload(:test)
      |> Repo.one!()

    step = Repo.get!(TestStep, step_id)

    # Determine if correct (use override if provided, otherwise validate)
    {is_correct, accuracy} =
      if is_correct_override != nil do
        {is_correct_override, 1.0}
      else
        # Get kanji stroke data for validation
        kanji =
          if step.kanji_id do
            Medoru.Content.get_kanji!(step.kanji_id)
          else
            nil
          end

        # Validate the writing
        result =
          if kanji && kanji.stroke_data do
            Medoru.Tests.WritingValidator.validate_writing(
              step.correct_answer,
              parsed_strokes,
              kanji.stroke_data
            )
          else
            # Fallback: just check stroke count
            if length(parsed_strokes) > 0, do: {:ok, 0.8}, else: {:error, :no_strokes}
          end

        # Determine if correct from validation result
        correct = match?({:ok, _}, result)
        acc = if correct, do: elem(result, 1), else: 0.0
        {correct, acc}
      end

    # Get current metadata
    metadata = session.metadata || %{}
    answer_counter = metadata["answer_counter"] || 0
    step_queue = metadata["step_queue"] || []

    # Record the answer with validation result
    answer_text = if is_correct, do: "Correct (#{round(accuracy * 100)}%)", else: "Incorrect"

    attrs = %{
      "answer" => answer_text,
      "time_spent_seconds" => time_spent,
      "step_index" => answer_counter,
      "is_correct" => is_correct
    }

    {:ok, _step_answer} = Tests.record_step_answer(session_id, step_id, attrs)

    # Update queue based on result
    new_queue =
      if is_correct do
        List.delete(step_queue, step_id)
      else
        # Move to end
        List.delete(step_queue, step_id) ++ [step_id]
      end

    wrong_count =
      if is_correct do
        metadata["wrong_answer_count"] || 0
      else
        (metadata["wrong_answer_count"] || 0) + 1
      end

    next_step_id = List.first(new_queue)

    new_metadata = %{
      metadata
      | "step_queue" => new_queue,
        "wrong_answer_count" => wrong_count,
        "current_step_id" => next_step_id,
        "answer_counter" => answer_counter + 1
    }

    # Update session
    total_steps = metadata["total_steps"] || length(step_queue)
    progress_index = total_steps - length(new_queue)

    updated_session =
      if is_correct do
        session
        |> TestSession.progress_changeset(progress_index, session.time_spent_seconds + time_spent)
        |> Ecto.Changeset.put_change(:metadata, new_metadata)
        |> Repo.update!()
      else
        session
        |> Ecto.Changeset.change(
          metadata: new_metadata,
          current_step_index: session.current_step_index + 1
        )
        |> Repo.update!()
      end

    # Return result
    if is_correct do
      if new_queue == [] do
        complete_lesson_test(updated_session, total_steps)
      else
        next_step = Repo.get!(TestStep, hd(new_queue))

        {:correct,
         %{
           session: updated_session,
           next_step: next_step,
           remaining_count: length(new_queue),
           total_steps: total_steps,
           completed_steps: progress_index,
           accuracy: accuracy
         }}
      end
    else
      next_step = Repo.get!(TestStep, next_step_id || step_id)

      {:incorrect,
       %{
         session: updated_session,
         next_step: next_step,
         remaining_count: length(new_queue),
         wrong_answer: %{accuracy: accuracy},
         retry_position: length(new_queue),
         show_stroke_preview: true
       }}
    end
  end

  @doc """
  Submits an answer for the current step in a lesson test.

  If correct: removes step from queue, moves to next step
  If incorrect: adds step to end of queue for retry

  Returns the result with updated session state.

  ## Examples

      iex> submit_answer(session_id, step_id, "answer")
      {:correct, %{session: %TestSession{}, next_step: %TestStep{}, remaining_count: 5}}

      iex> submit_answer(session_id, step_id, "wrong")
      {:incorrect, %{session: %TestSession{}, next_step: %TestStep{}, remaining_count: 6}}

  """
  def submit_answer(session_id, step_id, answer, opts \\ []) do
    time_spent = Keyword.get(opts, :time_spent_seconds, 0)

    session =
      TestSession
      |> where([ts], ts.id == ^session_id)
      |> preload(:test)
      |> Repo.one!()

    # Get current metadata
    metadata = session.metadata || %{}
    # Use a separate counter for answer index to ensure uniqueness
    answer_counter = metadata["answer_counter"] || 0

    # Record the answer
    _step = Repo.get!(TestStep, step_id)

    attrs = %{
      "answer" => answer,
      "time_spent_seconds" => time_spent,
      "step_index" => answer_counter
    }

    {:ok, step_answer} = Tests.record_step_answer(session_id, step_id, attrs)

    # Get current queue from metadata
    metadata = session.metadata || %{}
    step_queue = metadata["step_queue"] || []

    if step_answer.is_correct do
      # Remove from queue
      new_queue = List.delete(step_queue, step_id)

      # Update session - increment answer counter for next answer
      new_metadata = %{
        metadata
        | "step_queue" => new_queue,
          "current_step_id" => List.first(new_queue),
          "answer_counter" => answer_counter + 1
      }

      # Update progress
      total_steps = metadata["total_steps"] || length(step_queue)
      progress_index = total_steps - length(new_queue)

      updated_session =
        session
        |> TestSession.progress_changeset(progress_index, session.time_spent_seconds + time_spent)
        |> Ecto.Changeset.put_change(:metadata, new_metadata)
        |> Repo.update!()

      # Check if complete
      if new_queue == [] do
        complete_lesson_test(updated_session, total_steps)
      else
        next_step = Repo.get!(TestStep, hd(new_queue))

        {:correct,
         %{
           session: updated_session,
           next_step: next_step,
           remaining_count: length(new_queue),
           total_steps: total_steps,
           completed_steps: progress_index
         }}
      end
    else
      # Add to end of queue (adaptive retry)
      # First remove from current position, then add to end
      new_queue = List.delete(step_queue, step_id) ++ [step_id]
      wrong_count = (metadata["wrong_answer_count"] || 0) + 1

      # Get next step - it's the first item in the new queue
      # After moving current to end, the next question is at index 0
      next_step_id = List.first(new_queue)

      new_metadata = %{
        metadata
        | "step_queue" => new_queue,
          "wrong_answer_count" => wrong_count,
          "current_step_id" => next_step_id,
          "answer_counter" => answer_counter + 1
      }

      # Update session
      updated_session =
        session
        |> Ecto.Changeset.change(
          metadata: new_metadata,
          current_step_index: session.current_step_index + 1
        )
        |> Repo.update!()

      next_step = Repo.get!(TestStep, next_step_id)

      {:incorrect,
       %{
         session: updated_session,
         next_step: next_step,
         remaining_count: length(new_queue),
         wrong_answer: step_answer,
         retry_position: length(new_queue)
       }}
    end
  end

  @doc """
  Gets the current state of a lesson test session.

  ## Examples

      iex> get_session_state(session_id)
      %{current_step: %TestStep{}, remaining_steps: [%TestStep{}, ...], progress: 0.5}

  """
  def get_session_state(session_id) do
    session =
      TestSession
      |> where([ts], ts.id == ^session_id)
      |> preload([:test, test_step_answers: :test_step])
      |> Repo.one!()

    metadata = session.metadata || %{}
    step_queue = metadata["step_queue"] || []
    total_steps = metadata["total_steps"] || length(step_queue)

    current_step =
      case metadata["current_step_id"] do
        nil ->
          case step_queue do
            [current_id | _] -> Repo.get!(TestStep, current_id)
            [] -> nil
          end

        current_id ->
          Repo.get!(TestStep, current_id)
      end

    remaining_steps =
      if step_queue == [] do
        []
      else
        step_queue
        |> Tests.get_test_step()
        |> Enum.sort_by(fn step -> Enum.find_index(step_queue, &(&1 == step.id)) end)
      end

    completed_steps = total_steps - length(step_queue)

    progress =
      if total_steps > 0,
        do: completed_steps / total_steps,
        else: 0.0

    %{
      session: session,
      current_step: current_step,
      remaining_steps: remaining_steps,
      completed_steps: completed_steps,
      total_steps: total_steps,
      progress: Float.round(progress * 100, 1),
      status: session.status,
      wrong_answer_count: metadata["wrong_answer_count"] || 0
    }
  end

  @doc """
  Skips the current step (adds to end of queue without penalty).
  Useful for "I don't know" functionality.

  ## Examples

      iex> skip_step(session_id, step_id)
      {:ok, %{next_step: %TestStep{}, remaining_count: 5}}

  """
  def skip_step(session_id, step_id) do
    session = Repo.get!(TestSession, session_id)
    metadata = session.metadata || %{}
    step_queue = metadata["step_queue"] || []

    # Move current step to end
    new_queue = List.delete(step_queue, step_id) ++ [step_id]

    new_metadata = %{metadata | "step_queue" => new_queue}

    session
    |> Ecto.Changeset.change(metadata: new_metadata)
    |> Repo.update!()

    next_step_id = hd(new_queue)
    next_step = Repo.get!(TestStep, next_step_id)

    {:ok,
     %{
       next_step: next_step,
       remaining_count: length(new_queue)
     }}
  end

  @doc """
  Abandons a lesson test session.

  ## Examples

      iex> abandon_lesson_test(session_id)
      {:ok, %TestSession{status: :abandoned}}

  """
  def abandon_lesson_test(session_id) do
    session = Repo.get!(TestSession, session_id)
    Tests.abandon_session(session, session.time_spent_seconds)
  end

  # Private functions

  defp resume_session(session) do
    state = get_session_state(session.id)

    {:ok,
     %{
       session: session,
       remaining_steps: state.remaining_steps,
       current_step: state.current_step
     }}
  end

  defp complete_lesson_test(session, total_steps) do
    # Calculate final score (all correct = 100%)
    score = total_steps
    total_possible = total_steps
    time_spent = session.time_spent_seconds

    {:ok, completed_session} =
      Tests.complete_session(session, score, total_possible, time_spent)

    # Mark lesson as completed
    test = Repo.get!(Test, session.test_id)

    if test.lesson_id do
      Medoru.Learning.complete_lesson(session.user_id, test.lesson_id)
    end

    {:completed,
     %{
       session: completed_session,
       score: score,
       total_possible: total_possible,
       percentage: 100.0,
       wrong_answer_count: session.metadata["wrong_answer_count"] || 0
     }}
  end

  # Convert strokes from JSON format %{"x" => x, "y" => y} to tuple format {x, y}
  defp convert_stroke_format(strokes) when is_list(strokes) do
    Enum.map(strokes, fn stroke ->
      Enum.map(stroke, fn
        %{"x" => x, "y" => y} -> {x, y}
        [x, y] -> {x, y}
        {x, y} -> {x, y}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  defp convert_stroke_format(_), do: []
end
