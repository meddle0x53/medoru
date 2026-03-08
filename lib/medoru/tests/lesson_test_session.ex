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
      answer: answer,
      time_spent_seconds: time_spent,
      step_index: answer_counter
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
      step_queue
      |> Enum.map(&Tests.get_test_step/1)
      |> Enum.reject(&is_nil/1)

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
end
