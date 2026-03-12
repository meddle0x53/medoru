defmodule Medoru.Tests do
  @moduledoc """
  The Tests context.

  This context handles multi-step tests for learning assessment:
  - Test creation and management (for teachers/admins)
  - Test sessions for users taking tests
  - Step-by-step progress tracking
  - Answer recording and scoring
  - Results and statistics

  ## Key Concepts

  - **Test**: A collection of steps/questions with metadata
  - **TestStep**: Individual question within a test
  - **TestSession**: A user's attempt at a test
  - **TestStepAnswer**: User's answer to a specific step

  ## Question Types

  - `:multichoice` - Multiple choice (1 point)
  - `:fill` - Fill in the blank (2 points)
  - `:match` - Matching pairs (1-2 points)
  - `:order` - Put in correct order (2 points)

  ## Test Types

  - `:daily` - Auto-generated daily review test
  - `:lesson` - Test at the end of a lesson
  - `:teacher` - Custom test created by teachers
  - `:practice` - Self-practice test
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Tests.{Test, TestStep, TestSession, TestStepAnswer}
  alias Medoru.Learning

  # ============================================================================
  # Test Management
  # ============================================================================

  @doc """
  Returns the list of tests.

  ## Options

    * `:type` - Filter by test type (:daily, :lesson, :teacher, :practice)
    * `:status` - Filter by status (:draft, :ready, :published, :archived)
    * `:creator_id` - Filter by creator (for teacher tests)
    * `:limit` - Limit number of results
    * `:preload_steps` - Whether to preload test_steps (default: false)

  ## Examples

      iex> list_tests()
      [%Test{}, ...]

      iex> list_tests(type: :daily, status: :published)
      [%Test{}, ...]

  """
  def list_tests(opts \\ []) do
    Test
    |> maybe_filter_by_type(opts[:type])
    |> maybe_filter_by_status(opts[:status])
    |> maybe_filter_by_creator(opts[:creator_id])
    |> maybe_limit(opts[:limit])
    |> maybe_preload_steps(opts[:preload_steps])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single test.

  Returns `nil` if the Test does not exist.

  ## Options

    * `:preload_steps` - Whether to preload test_steps (default: false)

  ## Examples

      iex> get_test(123)
      %Test{}

      iex> get_test(456)
      nil

  """
  def get_test(id, opts \\ []) do
    Test
    |> maybe_preload_steps(opts[:preload_steps])
    |> Repo.get(id)
  end

  @doc """
  Gets a single test with all steps preloaded.

  Raises `Ecto.NoResultsError` if the Test does not exist.

  ## Examples

      iex> get_test!(123)
      %Test{test_steps: [%TestStep{}, ...]}

  """
  def get_test!(id) do
    Test
    |> preload(:test_steps)
    |> Repo.get!(id)
  end

  @doc """
  Creates a test.

  ## Examples

      iex> create_test(%{title: "N5 Review", test_type: :daily})
      {:ok, %Test{}}

      iex> create_test(%{title: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_test(attrs \\ %{}) do
    %Test{}
    |> Test.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a test.

  ## Examples

      iex> update_test(test, %{title: "New Title"})
      {:ok, %Test{}}

      iex> update_test(test, %{title: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_test(%Test{} = test, attrs) do
    test
    |> Test.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a test and all associated steps and sessions.

  ## Examples

      iex> delete_test(test)
      {:ok, %Test{}}

  """
  def delete_test(%Test{} = test) do
    Repo.delete(test)
  end

  @doc """
  Publishes a test, making it available for users to take.

  ## Examples

      iex> publish_test(test)
      {:ok, %Test{status: :published}}

  """
  def publish_test(%Test{} = test) do
    test
    |> Test.publish_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a test as ready for review/publishing.

  ## Examples

      iex> ready_test(test)
      {:ok, %Test{status: :ready}}

  """
  def ready_test(%Test{} = test) do
    test
    |> Test.ready_changeset()
    |> Repo.update()
  end

  @doc """
  Archives a test, removing it from active use.

  ## Examples

      iex> archive_test(test)
      {:ok, %Test{status: :archived}}

  """
  def archive_test(%Test{} = test) do
    test
    |> Test.archive_changeset()
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking test changes.

  ## Examples

      iex> change_test(test)
      %Ecto.Changeset{data: %Test{}}

  """
  def change_test(%Test{} = test, attrs \\ %{}) do
    Test.changeset(test, attrs)
  end

  @doc """
  Returns a changeset for a teacher test form.
  Only validates fields that users can edit.
  """
  def change_teacher_test(%Test{} = test, attrs \\ %{}) do
    Test.form_changeset(test, attrs)
  end

  # ============================================================================
  # Teacher Test Management
  # ============================================================================

  @doc """
  Returns the list of tests created by a teacher.

  ## Options

    * `:setup_state` - Filter by setup state ("in_progress", "ready", "published", "archived")
    * `:limit` - Limit number of results

  ## Examples

      iex> list_teacher_tests(teacher_id)
      [%Test{}, ...]

      iex> list_teacher_tests(teacher_id, setup_state: "published")
      [%Test{}, ...]

  """
  def list_teacher_tests(teacher_id, opts \\ []) do
    Test
    |> where([t], t.creator_id == ^teacher_id)
    |> where([t], t.test_type == :teacher)
    |> maybe_filter_by_setup_state(opts[:setup_state])
    |> maybe_limit(opts[:limit])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_by_setup_state(query, nil), do: query

  defp maybe_filter_by_setup_state(query, state) when is_binary(state) do
    where(query, [t], t.setup_state == ^state)
  end

  @doc """
  Creates a new teacher test.

  ## Examples

      iex> create_teacher_test(%{title: "Quiz 1", time_limit_seconds: 600}, teacher_id)
      {:ok, %Test{}}

  """
  def create_teacher_test(attrs, teacher_id) do
    # Ensure all keys are strings for consistency with form params
    attrs =
      attrs
      |> Map.put("creator_id", teacher_id)
      |> Map.put("setup_state", "in_progress")

    %Test{}
    |> Test.teacher_create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Checks if a user is the owner/creator of a test.

  ## Examples

      iex> is_test_owner?(test, user_id)
      true

  """
  def is_test_owner?(%Test{} = test, user_id) do
    test.creator_id == user_id
  end

  @doc """
  Transitions a test to a new setup state.
  Returns error if transition is invalid.

  ## Examples

      iex> transition_test_state(test, "ready")
      {:ok, %Test{setup_state: "ready"}}

  """
  def transition_test_state(%Test{} = test, new_state) do
    test
    |> Test.setup_state_changeset(new_state)
    |> Repo.update()
  end

  @doc """
  Marks a teacher test as ready for publishing.

  ## Examples

      iex> mark_test_ready(test)
      {:ok, %Test{setup_state: "ready"}}

  """
  def mark_test_ready(%Test{} = test) do
    test
    |> Test.mark_ready_changeset()
    |> Repo.update()
  end

  @doc """
  Publishes a teacher test.
  Only ready tests can be published.

  ## Examples

      iex> publish_teacher_test(test)
      {:ok, %Test{setup_state: "published"}}

  """
  def publish_teacher_test(%Test{} = test) do
    test
    |> Test.publish_teacher_changeset()
    |> Repo.update()
  end

  @doc """
  Archives a teacher test.

  ## Examples

      iex> archive_teacher_test(test)
      {:ok, %Test{setup_state: "archived"}}

  """
  def archive_teacher_test(%Test{} = test) do
    test
    |> Test.archive_teacher_changeset()
    |> Repo.update()
  end

  @doc """
  Counts steps in a test.

  ## Examples

      iex> count_test_steps(test_id)
      10

  """
  def count_test_steps(test_id) do
    TestStep
    |> where([ts], ts.test_id == ^test_id)
    |> Repo.aggregate(:count, :id)
  end

  # ============================================================================
  # Test Step Management
  # ============================================================================

  @doc """
  Returns the list of steps for a test.

  ## Examples

      iex> list_test_steps(test_id)
      [%TestStep{}, ...]

  """
  def list_test_steps(test_id) do
    TestStep
    |> where([ts], ts.test_id == ^test_id)
    |> order_by([ts], asc: ts.order_index)
    |> Repo.all()
  end

  @doc """
  Gets a single test step.

  Returns `nil` if the TestStep does not exist.

  ## Examples

      iex> get_test_step(123)
      %TestStep{}

      iex> get_test_step(456)
      nil

  """
  def get_test_step(id) when is_binary(id) or is_integer(id) do
    Repo.get(TestStep, id)
  end

  # Batch fetch for multiple test steps - used to avoid N+1 queries
  def get_test_step(ids) when is_list(ids) do
    TestStep
    |> where([ts], ts.id in ^ids)
    |> Repo.all()
  end

  @doc """
  Gets a test step by its order index within a test.

  ## Examples

      iex> get_test_step_by_index(test_id, 0)
      %TestStep{}

  """
  def get_test_step_by_index(test_id, order_index) do
    TestStep
    |> where([ts], ts.test_id == ^test_id and ts.order_index == ^order_index)
    |> Repo.one()
  end

  @doc """
  Creates a test step.

  ## Examples

      iex> create_test_step(test, %{question: "What is...", order_index: 0})
      {:ok, %TestStep{}}

  """
  def create_test_step(%Test{} = test, attrs \\ %{}) do
    # Ensure all keys are strings for consistency
    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()
      |> Map.put("test_id", test.id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:step, fn _changes ->
      %TestStep{}
      |> TestStep.changeset(attrs)
    end)
    |> Ecto.Multi.update(:test, fn %{step: step} ->
      update_test_total_points(test, step.points)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{step: step}} -> {:ok, step}
      {:error, :step, changeset, _changes} -> {:error, changeset}
      {:error, :test, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Creates multiple test steps in a batch.

  ## Examples

      iex> create_test_steps(test, [%{question: "..."}, %{question: "..."}])
      {:ok, [%TestStep{}, %TestStep{}]}

  """
  def create_test_steps(%Test{} = test, steps_attrs) when is_list(steps_attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    steps =
      Enum.with_index(steps_attrs, fn attrs, index ->
        %{
          id: Ecto.UUID.generate(),
          test_id: test.id,
          order_index: index,
          step_type: attrs[:step_type] || :vocabulary,
          question_type: attrs[:question_type] || :multichoice,
          question: attrs[:question],
          question_data: attrs[:question_data] || %{},
          correct_answer: attrs[:correct_answer],
          options: attrs[:options] || [],
          points:
            attrs[:points] || TestStep.default_points(attrs[:question_type] || :multichoice),
          hints: attrs[:hints] || [],
          explanation: attrs[:explanation],
          time_limit_seconds: attrs[:time_limit_seconds],
          kanji_id: attrs[:kanji_id],
          word_id: attrs[:word_id],
          inserted_at: now,
          updated_at: now
        }
      end)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:steps, TestStep, steps, returning: true)
    |> Ecto.Multi.update(:test, fn %{steps: {_, inserted_steps}} ->
      total_points = Enum.reduce(inserted_steps, 0, &(&1.points + &2))
      update_test_total_points(test, total_points)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{steps: {_, inserted_steps}}} -> {:ok, inserted_steps}
      {:error, :steps, changeset, _changes} -> {:error, changeset}
      {:error, :test, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Updates a test step.

  ## Examples

      iex> update_test_step(test_step, %{question: "New question"})
      {:ok, %TestStep{}}

  """
  def update_test_step(%TestStep{} = test_step, attrs) do
    old_points = test_step.points

    result =
      test_step
      |> TestStep.changeset(attrs)
      |> Repo.update()

    with {:ok, updated_step} <- result,
         true <- old_points != updated_step.points do
      # Recalculate total points
      recalculate_test_total_points(test_step.test_id)
    end

    result
  end

  @doc """
  Deletes a test step.

  ## Examples

      iex> delete_test_step(test_step)
      {:ok, %TestStep{}}

  """
  def delete_test_step(%TestStep{} = test_step) do
    result = Repo.delete(test_step)

    with {:ok, _step} <- result do
      recalculate_test_total_points(test_step.test_id)
      reorder_test_steps(test_step.test_id)
    end

    result
  end

  @doc """
  Reorders test steps by updating their order_index values.

  ## Examples

      iex> reorder_steps(test_id, [step_id_3, step_id_1, step_id_2])
      :ok

  """
  def reorder_steps(test_id, step_ids) when is_list(step_ids) do
    Repo.transaction(fn ->
      # First, set all steps to temporary high indices to avoid unique constraint conflicts
      # Use 1000 + original index as temporary index
      TestStep
      |> where([ts], ts.test_id == ^test_id)
      |> Repo.update_all(inc: [order_index: 1000])

      # Now set the correct order indices
      Enum.with_index(step_ids, fn step_id, index ->
        TestStep
        |> where([ts], ts.id == ^step_id and ts.test_id == ^test_id)
        |> Repo.update_all(set: [order_index: index])
      end)
    end)

    :ok
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking test step changes.

  ## Examples

      iex> change_test_step(test_step)
      %Ecto.Changeset{data: %TestStep{}}

  """
  def change_test_step(%TestStep{} = test_step, attrs \\ %{}) do
    TestStep.changeset(test_step, attrs)
  end

  defp update_test_total_points(test, additional_points) do
    Ecto.Changeset.change(test, total_points: test.total_points + additional_points)
  end

  defp recalculate_test_total_points(test_id) do
    total =
      TestStep
      |> where([ts], ts.test_id == ^test_id)
      |> Repo.aggregate(:sum, :points) || 0

    Test
    |> where([t], t.id == ^test_id)
    |> Repo.update_all(set: [total_points: total])

    :ok
  end

  defp reorder_test_steps(test_id) do
    steps =
      TestStep
      |> where([ts], ts.test_id == ^test_id)
      |> order_by([ts], asc: ts.inserted_at)
      |> Repo.all()

    Enum.with_index(steps, fn step, index ->
      step
      |> Ecto.Changeset.change(order_index: index)
      |> Repo.update!()
    end)

    :ok
  end

  # ============================================================================
  # Test Session Management
  # ============================================================================

  @doc """
  Returns the list of test sessions for a user.

  ## Options

    * `:status` - Filter by status
    * `:test_id` - Filter by specific test
    * `:limit` - Limit number of results
    * `:preload` - List of associations to preload [:test, :test_step_answers]

  ## Examples

      iex> list_test_sessions(user_id)
      [%TestSession{}, ...]

  """
  def list_test_sessions(user_id, opts \\ []) do
    TestSession
    |> where([ts], ts.user_id == ^user_id)
    |> maybe_filter_by_session_status(opts[:status])
    |> maybe_filter_by_test(opts[:test_id])
    |> maybe_limit(opts[:limit])
    |> maybe_preload_session_associations(opts[:preload])
    |> order_by([ts], desc: ts.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single test session.

  Returns `nil` if the TestSession does not exist.

  ## Examples

      iex> get_test_session(123)
      %TestSession{}

      iex> get_test_session(456)
      nil

  """
  def get_test_session(id) do
    Repo.get(TestSession, id)
  end

  @doc """
  Gets a test session with preloaded associations.

  ## Examples

      iex> get_test_session_with_answers(session_id)
      %TestSession{test_step_answers: [...]}

  """
  def get_test_session_with_answers(id) do
    TestSession
    |> preload([:test, test_step_answers: :test_step])
    |> Repo.get(id)
  end

  @doc """
  Gets the active (incomplete) test session for a user on a specific test.

  ## Examples

      iex> get_active_session(user_id, test_id)
      %TestSession{status: :in_progress}

      iex> get_active_session(user_id, test_id)
      nil

  """
  def get_active_session(user_id, test_id) do
    TestSession
    |> where(
      [ts],
      ts.user_id == ^user_id and ts.test_id == ^test_id and
        ts.status in [:started, :in_progress]
    )
    |> preload([:test, test_step_answers: :test_step])
    |> Repo.one()
  end

  @doc """
  Checks if a user has an active session for a test.

  ## Examples

      iex> has_active_session?(user_id, test_id)
      true

  """
  def has_active_session?(user_id, test_id) do
    TestSession
    |> where(
      [ts],
      ts.user_id == ^user_id and ts.test_id == ^test_id and
        ts.status in [:started, :in_progress]
    )
    |> Repo.exists?()
  end

  @doc """
  Starts a new test session for a user.

  If an active session already exists, returns that session.

  ## Examples

      iex> start_test_session(user_id, test_id)
      {:ok, %TestSession{}}

  """
  def start_test_session(user_id, test_id) do
    # Check for existing active session
    case get_active_session(user_id, test_id) do
      nil ->
        test = get_test!(test_id)

        attrs = %{
          user_id: user_id,
          test_id: test_id,
          total_possible: test.total_points,
          current_step_index: 0
        }

        %TestSession{}
        |> TestSession.start_changeset(attrs)
        |> Repo.insert()

      existing_session ->
        {:ok, existing_session}
    end
  end

  @doc """
  Records progress in a test session (moving to a new step).

  ## Examples

      iex> progress_session(session, 5, 120)
      {:ok, %TestSession{current_step_index: 5, time_spent_seconds: 120}}

  """
  def progress_session(%TestSession{} = session, current_step_index, time_spent_seconds) do
    session
    |> TestSession.progress_changeset(current_step_index, time_spent_seconds)
    |> Repo.update()
  end

  @doc """
  Completes a test session and calculates final score.

  ## Examples

      iex> complete_session(session, 85, 100, 300)
      {:ok, %TestSession{status: :completed, score: 85, percentage: 85.0}}

  """
  def complete_session(%TestSession{} = session, score, total_possible, time_spent_seconds) do
    result =
      session
      |> TestSession.complete_changeset(score, total_possible, time_spent_seconds)
      |> Repo.update()

    # Update streak if completed successfully
    with {:ok, completed_session} <- result do
      Learning.update_streak(session.user_id)
      {:ok, completed_session}
    end
  end

  @doc """
  Abandons a test session.

  ## Examples

      iex> abandon_session(session, 180)
      {:ok, %TestSession{status: :abandoned}}

  """
  def abandon_session(%TestSession{} = session, time_spent_seconds) do
    session
    |> TestSession.abandon_changeset(time_spent_seconds)
    |> Repo.update()
  end

  @doc """
  Times out a test session.

  ## Examples

      iex> timeout_session(session, 45, 100, 600)
      {:ok, %TestSession{status: :timed_out}}

  """
  def timeout_session(%TestSession{} = session, score, total_possible, time_spent_seconds) do
    session
    |> TestSession.timeout_changeset(score, total_possible, time_spent_seconds)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking test session changes.

  ## Examples

      iex> change_test_session(session)
      %Ecto.Changeset{data: %TestSession{}}

  """
  def change_test_session(%TestSession{} = session, attrs \\ %{}) do
    TestSession.changeset(session, attrs)
  end

  # ============================================================================
  # Test Step Answer Management
  # ============================================================================

  @doc """
  Returns the list of answers for a test session.

  ## Examples

      iex> list_step_answers(session_id)
      [%TestStepAnswer{}, ...]

  """
  def list_step_answers(session_id) do
    TestStepAnswer
    |> where([sa], sa.test_session_id == ^session_id)
    |> order_by([sa], asc: sa.step_index)
    |> preload(:test_step)
    |> Repo.all()
  end

  @doc """
  Gets a single step answer.

  ## Examples

      iex> get_step_answer(123)
      %TestStepAnswer{}

  """
  def get_step_answer(id) do
    Repo.get(TestStepAnswer, id)
  end

  @doc """
  Records an answer to a test step.

  Automatically determines if the answer is correct and calculates points.
  For writing steps, pass `is_correct` directly.

  ## Examples

      iex> record_step_answer(session_id, step_id, %{answer: "にほん", time_spent_seconds: 30})
      {:ok, %TestStepAnswer{is_correct: true, points_earned: 2}}

  """
  def record_step_answer(session_id, step_id, attrs) do
    step = get_test_step(step_id)

    attrs =
      attrs
      |> Map.put("test_session_id", session_id)
      |> Map.put("test_step_id", step_id)

    # For writing steps, is_correct is passed directly
    changeset =
      if attrs["is_correct"] != nil do
        %TestStepAnswer{}
        |> TestStepAnswer.changeset(%{
          answer: attrs["answer"],
          is_correct: attrs["is_correct"],
          points_earned: if(attrs["is_correct"], do: step.points, else: 0),
          time_spent_seconds: attrs["time_spent_seconds"],
          step_index: attrs["step_index"],
          test_session_id: session_id,
          test_step_id: step_id
        })
      else
        %TestStepAnswer{}
        |> TestStepAnswer.answer_changeset(attrs, step.correct_answer, step.points)
      end

    changeset |> Repo.insert()
  end

  @doc """
  Updates a step answer (e.g., for manual grading or corrections).

  ## Examples

      iex> update_step_answer(answer, %{points_earned: 1, is_correct: true})
      {:ok, %TestStepAnswer{}}

  """
  def update_step_answer(%TestStepAnswer{} = answer, attrs) do
    answer
    |> TestStepAnswer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Calculates the total score for a test session based on answers.

  ## Examples

      iex> calculate_session_score(session_id)
      {85, 100}

  """
  def calculate_session_score(session_id) do
    answers = list_step_answers(session_id)

    score = Enum.reduce(answers, 0, &(&1.points_earned + &2))
    total_possible = Enum.reduce(answers, 0, &(&1.test_step.points + &2))

    {score, total_possible}
  end

  @doc """
  Checks if all steps in a test have been answered in a session.

  ## Examples

      iex> all_steps_answered?(session)
      true

  """
  def all_steps_answered?(%TestSession{} = session) do
    test = get_test!(session.test_id)
    total_steps = length(test.test_steps)

    answered_count =
      TestStepAnswer
      |> where([sa], sa.test_session_id == ^session.id)
      |> Repo.aggregate(:count, :id)

    answered_count >= total_steps
  end

  # ============================================================================
  # Statistics and Reporting
  # ============================================================================

  @doc """
  Gets statistics for a user's test performance.

  ## Examples

      iex> get_user_test_stats(user_id)
      %{
        total_tests_taken: 15,
        tests_completed: 12,
        tests_abandoned: 2,
        tests_timed_out: 1,
        average_score: 78.5,
        total_points_earned: 450,
        total_time_spent_seconds: 7200
      }

  """
  def get_user_test_stats(user_id) do
    sessions = list_test_sessions(user_id)

    completed = Enum.filter(sessions, &(&1.status == :completed))

    %{
      total_tests_taken: length(sessions),
      tests_completed: length(completed),
      tests_abandoned: Enum.count(sessions, &(&1.status == :abandoned)),
      tests_timed_out: Enum.count(sessions, &(&1.status == :timed_out)),
      average_score:
        if length(completed) > 0 do
          avg = Enum.reduce(completed, 0.0, &(&1.percentage + &2)) / length(completed)
          Float.round(avg, 2)
        else
          0.0
        end,
      total_points_earned: Enum.reduce(sessions, 0, &(&1.score + &2)),
      total_time_spent_seconds: Enum.reduce(sessions, 0, &(&1.time_spent_seconds + &2))
    }
  end

  @doc """
  Gets statistics for a specific test.

  ## Examples

      iex> get_test_stats(test_id)
      %{
        total_sessions: 45,
        completion_rate: 85.5,
        average_score: 72.3,
        average_time_seconds: 420
      }

  """
  def get_test_stats(test_id) do
    sessions =
      TestSession
      |> where([ts], ts.test_id == ^test_id)
      |> Repo.all()

    completed = Enum.filter(sessions, &(&1.status == :completed))

    %{
      total_sessions: length(sessions),
      completion_rate:
        if length(sessions) > 0 do
          Float.round(length(completed) / length(sessions) * 100, 2)
        else
          0.0
        end,
      average_score:
        if length(completed) > 0 do
          avg = Enum.reduce(completed, 0.0, &(&1.percentage + &2)) / length(completed)
          Float.round(avg, 2)
        else
          0.0
        end,
      average_time_seconds:
        if length(sessions) > 0 do
          avg = Enum.reduce(sessions, 0, &(&1.time_spent_seconds + &2)) / length(sessions)
          round(avg)
        else
          0
        end
    }
  end

  # ============================================================================
  # Lesson Tests
  # ============================================================================

  @doc """
  Gets the test for a lesson, generating one if needed.

  ## Examples

      iex> get_lesson_test(lesson_id)
      {:ok, %Test{}}

  """
  def get_lesson_test(lesson_id) do
    Medoru.Tests.LessonTestGenerator.get_or_create_lesson_test(lesson_id)
  end

  @doc """
  Generates a new test for a lesson based on its words.

  ## Options
    * `:steps_per_word` - Number of steps per word (default: 3)
    * `:distractor_count` - Number of wrong options (default: 3)

  ## Examples

      iex> generate_lesson_test(lesson_id)
      {:ok, %Test{}}

  """
  def generate_lesson_test(lesson_id, opts \\ []) do
    Medoru.Tests.LessonTestGenerator.generate_lesson_test(lesson_id, opts)
  end

  @doc """
  Starts a lesson test session with adaptive retry logic.

  ## Examples

      iex> start_lesson_test_session(user_id, test_id)
      {:ok, %{session: %TestSession{}, current_step: %TestStep{}, remaining_steps: [...]}}

  """
  def start_lesson_test_session(user_id, test_id) do
    Medoru.Tests.LessonTestSession.start_lesson_test(user_id, test_id)
  end

  @doc """
  Submits an answer for a lesson test step.

  Returns `{:correct, ...}`, `{:incorrect, ...}`, or `{:completed, ...}`.

  ## Examples

      iex> submit_lesson_test_answer(session_id, step_id, "answer")
      {:correct, %{next_step: %TestStep{}, remaining_count: 5}}

  """
  def submit_lesson_test_answer(session_id, step_id, answer, opts \\ []) do
    Medoru.Tests.LessonTestSession.submit_answer(session_id, step_id, answer, opts)
  end

  @doc """
  Gets the current state of a lesson test session.

  ## Examples

      iex> get_lesson_test_session_state(session_id)
      %{current_step: %TestStep{}, progress: 50.0, remaining_steps: [...]}

  """
  def get_lesson_test_session_state(session_id) do
    Medoru.Tests.LessonTestSession.get_session_state(session_id)
  end

  @doc """
  Skips the current step in a lesson test (adds to end of queue).

  ## Examples

      iex> skip_lesson_test_step(session_id, step_id)
      {:ok, %{next_step: %TestStep{}, remaining_count: 5}}

  """
  def skip_lesson_test_step(session_id, step_id) do
    Medoru.Tests.LessonTestSession.skip_step(session_id, step_id)
  end

  @doc """
  Abandons a lesson test session.

  ## Examples

      iex> abandon_lesson_test(session_id)
      {:ok, %TestSession{status: :abandoned}}

  """
  def abandon_lesson_test(session_id) do
    Medoru.Tests.LessonTestSession.abandon_lesson_test(session_id)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp maybe_filter_by_type(query, nil), do: query
  defp maybe_filter_by_type(query, type), do: where(query, [t], t.test_type == ^type)

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [t], t.status == ^status)

  defp maybe_filter_by_creator(query, nil), do: query

  defp maybe_filter_by_creator(query, creator_id),
    do: where(query, [t], t.creator_id == ^creator_id)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp maybe_preload_steps(query, true), do: preload(query, :test_steps)
  defp maybe_preload_steps(query, _), do: query

  defp maybe_filter_by_session_status(query, nil), do: query

  defp maybe_filter_by_session_status(query, status),
    do: where(query, [ts], ts.status == ^status)

  defp maybe_filter_by_test(query, nil), do: query
  defp maybe_filter_by_test(query, test_id), do: where(query, [ts], ts.test_id == ^test_id)

  defp maybe_preload_session_associations(query, nil), do: query

  defp maybe_preload_session_associations(query, preloads) do
    Enum.reduce(preloads, query, fn
      :test, q -> preload(q, :test)
      :test_step_answers, q -> preload(q, :test_step_answers)
      _, q -> q
    end)
  end
end
