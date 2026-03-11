defmodule Medoru.Classrooms do
  @moduledoc """
  The Classrooms context.

  This context handles classroom management:
  - Creating and managing classrooms (by teachers)
  - Student membership applications and approvals
  - Classroom settings and configuration
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Classrooms.{Classroom, ClassroomMembership}
  alias Medoru.Notifications

  # ============================================================================
  # Classroom Management
  # ============================================================================

  @doc """
  Returns the list of classrooms for a teacher.

  ## Examples

      iex> list_teacher_classrooms(teacher_id)
      [%Classroom{}, ...]

  """
  def list_teacher_classrooms(teacher_id) do
    Classroom
    |> where([c], c.teacher_id == ^teacher_id)
    |> where([c], c.status != :archived)
    |> order_by([c], desc: c.inserted_at)
    |> preload([:teacher])
    |> Repo.all()
  end

  @doc """
  Returns the list of classrooms a student is a member of.

  ## Examples

      iex> list_student_classrooms(user_id)
      [%Classroom{}, ...]

  """
  def list_student_classrooms(user_id) do
    Classroom
    |> join(:inner, [c], m in ClassroomMembership, on: m.classroom_id == c.id)
    |> where([c, m], m.user_id == ^user_id and m.status == :approved)
    |> where([c], c.status == :active)
    |> order_by([c], desc: c.inserted_at)
    |> preload([:teacher])
    |> Repo.all()
  end

  @doc """
  Gets a single classroom by ID.

  Raises `Ecto.NoResultsError` if the Classroom does not exist.

  ## Examples

      iex> get_classroom!(123)
      %Classroom{}

      iex> get_classroom!(456)
      ** (Ecto.NoResultsError)

  """
  def get_classroom!(id) do
    Classroom
    |> Repo.get!(id)
    |> Repo.preload([:teacher, memberships: [:user]])
  end

  @doc """
  Gets a single classroom by slug.

  Returns nil if not found.

  ## Examples

      iex> get_classroom_by_slug("my-classroom")
      %Classroom{}

      iex> get_classroom_by_slug("nonexistent")
      nil

  """
  def get_classroom_by_slug(slug) do
    Classroom
    |> where([c], c.slug == ^slug)
    |> where([c], c.status == :active)
    |> preload([:teacher, memberships: [:user]])
    |> Repo.one()
  end

  @doc """
  Gets a classroom by invite code.

  Returns nil if not found.

  ## Examples

      iex> get_classroom_by_invite_code("ABC12345")
      %Classroom{}

  """
  def get_classroom_by_invite_code(code) do
    Classroom
    |> where([c], c.invite_code == ^String.upcase(code))
    |> where([c], c.status == :active)
    |> preload([:teacher])
    |> Repo.one()
  end

  @doc """
  Creates a classroom.

  ## Examples

      iex> create_classroom(%{name: "My Classroom", teacher_id: user_id})
      {:ok, %Classroom{}}

      iex> create_classroom(%{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_classroom(attrs \\ %{}) do
    # Normalize keys to atoms to prevent mixed key types
    attrs = normalize_keys(attrs)

    # Generate slug and invite code
    attrs = maybe_generate_slug(attrs)
    attrs = maybe_generate_invite_code(attrs)

    %Classroom{}
    |> Classroom.changeset(attrs)
    |> Repo.insert()
  end

  # Convert all keys to atoms, handling both atom and string keys
  defp normalize_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      atom_key =
        case key do
          k when is_binary(k) -> String.to_atom(k)
          k when is_atom(k) -> k
        end

      Map.put(acc, atom_key, value)
    end)
  end

  @doc """
  Updates a classroom.

  ## Examples

      iex> update_classroom(classroom, %{name: "New Name"})
      {:ok, %Classroom{}}

      iex> update_classroom(classroom, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_classroom(%Classroom{} = classroom, attrs) do
    classroom
    |> Classroom.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Archives a classroom (soft delete).

  ## Examples

      iex> archive_classroom(classroom)
      {:ok, %Classroom{}}

  """
  def archive_classroom(%Classroom{} = classroom) do
    classroom
    |> Classroom.changeset(%{status: :archived})
    |> Repo.update()
  end

  @doc """
  Closes a classroom (no new members).

  ## Examples

      iex> close_classroom(classroom)
      {:ok, %Classroom{}}

  """
  def close_classroom(%Classroom{} = classroom) do
    classroom
    |> Classroom.changeset(%{status: :closed})
    |> Repo.update()
  end

  @doc """
  Regenerates the invite code for a classroom.

  ## Examples

      iex> regenerate_invite_code(classroom)
      {:ok, %Classroom{}}

  """
  def regenerate_invite_code(%Classroom{} = classroom) do
    classroom
    |> Classroom.changeset(%{invite_code: Classroom.generate_invite_code()})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking classroom changes.

  ## Examples

      iex> change_classroom(classroom)
      %Ecto.Changeset{data: %Classroom{}}

  """
  def change_classroom(%Classroom{} = classroom, attrs \\ %{}) do
    Classroom.changeset(classroom, attrs)
  end

  # ============================================================================
  # Membership Management
  # ============================================================================

  @doc """
  Returns the list of memberships for a classroom.

  ## Examples

      iex> list_classroom_memberships(classroom_id)
      [%ClassroomMembership{}, ...]

  """
  def list_classroom_memberships(classroom_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id)
    |> order_by([m], desc: m.inserted_at)
    |> preload([:user, :classroom])
    |> Repo.all()
  end

  @doc """
  Returns pending membership applications for a classroom.

  ## Examples

      iex> list_pending_memberships(classroom_id)
      [%ClassroomMembership{}, ...]

  """
  def list_pending_memberships(classroom_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.status == :pending)
    |> order_by([m], asc: m.inserted_at)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Returns approved members for a classroom.

  ## Examples

      iex> list_classroom_members(classroom_id)
      [%ClassroomMembership{}, ...]

  """
  def list_classroom_members(classroom_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.status == :approved)
    |> order_by([m], desc: m.points)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Gets a single membership.

  Raises `Ecto.NoResultsError` if the membership does not exist.

  ## Examples

      iex> get_membership!(123)
      %ClassroomMembership{}

  """
  def get_membership!(id) do
    ClassroomMembership
    |> Repo.get!(id)
    |> Repo.preload([:user, :classroom])
  end

  @doc """
  Gets a membership for a user in a specific classroom.

  Returns nil if not found.

  ## Examples

      iex> get_user_membership(classroom_id, user_id)
      %ClassroomMembership{}

  """
  def get_user_membership(classroom_id, user_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
    |> preload([:user, :classroom])
    |> Repo.one()
  end

  @doc """
  Checks if a user is a member of a classroom.

  ## Examples

      iex> is_member?(classroom_id, user_id)
      true

  """
  def is_member?(classroom_id, user_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
    |> where([m], m.status in [:approved, :pending])
    |> Repo.exists?()
  end

  @doc """
  Checks if a user is an approved member of a classroom.

  ## Examples

      iex> is_approved_member?(classroom_id, user_id)
      true

  """
  def is_approved_member?(classroom_id, user_id) do
    ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
    |> where([m], m.status == :approved)
    |> Repo.exists?()
  end

  @doc """
  Creates a membership application (student requests to join).

  ## Examples

      iex> apply_to_join(classroom_id, user_id)
      {:ok, %ClassroomMembership{}}

      iex> apply_to_join(classroom_id, already_member_user_id)
      {:error, :already_member}

  """
  def apply_to_join(classroom_id, user_id) do
    if is_member?(classroom_id, user_id) do
      {:error, :already_member}
    else
      attrs = %{
        classroom_id: classroom_id,
        user_id: user_id,
        status: :pending,
        role: :student,
        points: 0
      }

      result =
        %ClassroomMembership{}
        |> ClassroomMembership.changeset(attrs)
        |> Repo.insert()

      # Notify teacher of new application
      with {:ok, _membership} <- result,
           classroom = %Classroom{} <- get_classroom!(classroom_id),
           user = %Medoru.Accounts.User{} <- Medoru.Accounts.get_user!(user_id) do
        Notifications.notify_new_application(
          classroom.teacher_id,
          user.email,
          classroom.name,
          classroom.id
        )
      end

      result
    end
  end

  @doc """
  Approves a membership application.

  ## Examples

      iex> approve_membership(membership)
      {:ok, %ClassroomMembership{}}

  """
  def approve_membership(%ClassroomMembership{} = membership) do
    result =
      membership
      |> ClassroomMembership.approve_changeset()
      |> Repo.update()

    # Notify student of approval
    with {:ok, _approved_membership} <- result,
         classroom = %Classroom{} <- get_classroom!(membership.classroom_id) do
      Notifications.notify_application_approved(
        membership.user_id,
        classroom.name,
        classroom.id
      )
    end

    result
  end

  @doc """
  Rejects a membership application.

  ## Examples

      iex> reject_membership(membership)
      {:ok, %ClassroomMembership{}}

  """
  def reject_membership(%ClassroomMembership{} = membership) do
    result =
      membership
      |> ClassroomMembership.reject_changeset()
      |> Repo.update()

    # Notify student of rejection
    with {:ok, _rejected_membership} <- result,
         classroom = %Classroom{} <- Repo.get(Classroom, membership.classroom_id) do
      Notifications.notify_application_rejected(
        membership.user_id,
        classroom.name
      )
    end

    result
  end

  @doc """
  Removes a member from a classroom (by teacher).

  ## Examples

      iex> remove_member(membership)
      {:ok, %ClassroomMembership{}}

  """
  def remove_member(%ClassroomMembership{} = membership) do
    result =
      membership
      |> ClassroomMembership.remove_changeset()
      |> Repo.update()

    # Notify student of removal
    with {:ok, _removed_membership} <- result,
         classroom = %Classroom{} <- Repo.get(Classroom, membership.classroom_id) do
      Notifications.notify_removed_from_classroom(
        membership.user_id,
        classroom.name
      )
    end

    result
  end

  @doc """
  A user leaves a classroom voluntarily.

  ## Examples

      iex> leave_classroom(membership)
      {:ok, %ClassroomMembership{}}

  """
  def leave_classroom(%ClassroomMembership{} = membership) do
    membership
    |> ClassroomMembership.leave_changeset()
    |> Repo.update()
  end

  @doc """
  Updates member points.

  ## Examples

      iex> update_member_points(membership, 100)
      {:ok, %ClassroomMembership{}}

  """
  def update_member_points(%ClassroomMembership{} = membership, points) do
    membership
    |> ClassroomMembership.changeset(%{points: points})
    |> Repo.update()
  end

  @doc """
  Adds points to a member's total.

  ## Examples

      iex> add_member_points(membership, 10)
      {:ok, %ClassroomMembership{}}

  """
  def add_member_points(%ClassroomMembership{} = membership, points_to_add) do
    new_points = membership.points + points_to_add
    update_member_points(membership, new_points)
  end

  # ============================================================================
  # Statistics
  # ============================================================================

  @doc """
  Returns statistics for a classroom.

  ## Examples

      iex> get_classroom_stats(classroom_id)
      %{
        total_members: 10,
        pending_applications: 2,
        total_points: 500
      }

  """
  def get_classroom_stats(classroom_id) do
    total_members =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.status == :approved)
      |> Repo.aggregate(:count, :id)

    pending_applications =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.status == :pending)
      |> Repo.aggregate(:count, :id)

    total_points =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.status == :approved)
      |> Repo.aggregate(:sum, :points) || 0

    %{
      total_members: total_members,
      pending_applications: pending_applications,
      total_points: total_points
    }
  end

  @doc """
  Returns statistics for multiple classrooms in a batch query.
  Much more efficient than calling get_classroom_stats/1 in a loop.

  ## Examples

      iex> get_classroom_stats_batch([classroom_id1, classroom_id2])
      %{classroom_id1 => %{total_members: 10, pending_applications: 2, total_points: 500}, ...}

  """
  def get_classroom_stats_batch(classroom_ids) when is_list(classroom_ids) do
    if classroom_ids == [] do
      %{}
    else
      # Fetch all memberships for the given classrooms
      memberships =
        ClassroomMembership
        |> where([m], m.classroom_id in ^classroom_ids)
        |> where([m], m.status in [:approved, :pending])
        |> select([m], {m.classroom_id, m.status, m.points})
        |> Repo.all()

      # Aggregate in memory
      memberships
      |> Enum.reduce(%{}, fn {classroom_id, status, points}, acc ->
        existing =
          Map.get(acc, classroom_id, %{
            total_members: 0,
            pending_applications: 0,
            total_points: 0
          })

        updated =
          case status do
            :approved ->
              %{
                existing
                | total_members: existing.total_members + 1,
                  total_points: existing.total_points + (points || 0)
              }

            :pending ->
              %{existing | pending_applications: existing.pending_applications + 1}

            _ ->
              existing
          end

        Map.put(acc, classroom_id, updated)
      end)
    end
  end

  # ============================================================================
  # Test Attempts Management
  # ============================================================================

  alias Medoru.Classrooms.{ClassroomTestAttempt, ClassroomLessonProgress}
  alias Medoru.Tests

  @doc """
  Checks if a user can take a test in a classroom.
  Returns true if:
  - User is an approved member
  - No existing attempt OR previous attempt was reset
  """
  def can_take_test?(classroom_id, user_id, test_id) do
    cond do
      not is_approved_member?(classroom_id, user_id) ->
        false

      true ->
        case get_test_attempt(classroom_id, user_id, test_id) do
          nil -> true
          attempt -> attempt.reset_count > 0 and is_nil(attempt.completed_at)
        end
    end
  end

  @doc """
  Gets a specific test attempt.
  """
  def get_test_attempt(classroom_id, user_id, test_id) do
    ClassroomTestAttempt
    |> where([a], a.classroom_id == ^classroom_id)
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.test_id == ^test_id)
    |> preload([:test, :test_session])
    |> Repo.one()
  end

  @doc """
  Gets a test attempt by ID.
  """
  def get_test_attempt!(id) do
    ClassroomTestAttempt
    |> Repo.get!(id)
    |> Repo.preload([:test, :test_session, :user, :classroom])
  end

  @doc """
  Starts a new test attempt for a user.
  """
  def start_test_attempt(classroom_id, user_id, test_id, time_limit_seconds) do
    if can_take_test?(classroom_id, user_id, test_id) do
      attrs = %{
        classroom_id: classroom_id,
        user_id: user_id,
        test_id: test_id,
        time_limit_seconds: time_limit_seconds,
        started_at: DateTime.utc_now(),
        status: "in_progress"
      }

      # If there's a reset attempt, update it; otherwise create new
      case get_test_attempt(classroom_id, user_id, test_id) do
        nil ->
          %ClassroomTestAttempt{}
          |> ClassroomTestAttempt.create_changeset(attrs)
          |> Repo.insert()

        existing_attempt when existing_attempt.reset_count > 0 ->
          # Clear the old attempt and create new
          Repo.delete(existing_attempt)

          %ClassroomTestAttempt{}
          |> ClassroomTestAttempt.create_changeset(attrs)
          |> Repo.insert()
      end
    else
      {:error, :already_attempted}
    end
  end

  @doc """
  Updates test progress (score, time) during an attempt.
  """
  def update_test_progress(attempt_id, attrs) do
    attempt = Repo.get!(ClassroomTestAttempt, attempt_id)

    attempt
    |> ClassroomTestAttempt.progress_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Completes a test attempt.
  """
  def complete_test_attempt(attempt_id, attrs) do
    attempt = Repo.get!(ClassroomTestAttempt, attempt_id)

    attrs =
      attrs
      |> Map.put(:completed_at, DateTime.utc_now())
      |> Map.put(:status, if(attrs[:auto_submitted], do: "timed_out", else: "completed"))

    result =
      attempt
      |> ClassroomTestAttempt.complete_changeset(attrs)
      |> Repo.update()

    # Update member points if successful
    with {:ok, completed_attempt} <- result,
         {:ok, _} <-
           add_points_to_member(
             completed_attempt.classroom_id,
             completed_attempt.user_id,
             completed_attempt.points_earned
           ) do
      {:ok, completed_attempt}
    else
      error -> error
    end
  end

  @doc """
  Auto-submits a test when time runs out.
  Marks remaining steps as unanswered and completes the attempt.
  """
  def auto_submit_test(attempt_id, final_score, max_score) do
    attempt = Repo.get!(ClassroomTestAttempt, attempt_id)

    # Ensure score is not negative
    points_earned = max(final_score, 0)

    attrs = %{
      score: final_score,
      max_score: max_score,
      points_earned: points_earned,
      time_spent_seconds: attempt.time_limit_seconds,
      time_remaining_seconds: 0,
      auto_submitted: true
    }

    complete_test_attempt(attempt_id, attrs)
  end

  @doc """
  Resets a test attempt for a student (teacher only).
  """
  def reset_test_attempt(attempt_id, teacher_id) do
    attempt = Repo.get!(ClassroomTestAttempt, attempt_id)

    # Verify teacher owns the classroom
    classroom = get_classroom!(attempt.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      attempt
      |> ClassroomTestAttempt.reset_changeset(%{
        reset_count: attempt.reset_count + 1,
        reset_at: DateTime.utc_now(),
        reset_by_id: teacher_id
      })
      |> Repo.update()
    end
  end

  @doc """
  Lists all test attempts for a classroom.
  """
  def list_classroom_test_attempts(classroom_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    status = Keyword.get(opts, :status)

    ClassroomTestAttempt
    |> where([a], a.classroom_id == ^classroom_id)
    |> then(fn query ->
      if status do
        where(query, [a], a.status == ^status)
      else
        query
      end
    end)
    |> order_by([a], desc: a.completed_at)
    |> preload([:user, :test])
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists test attempts for a specific user in a classroom.
  """
  def list_user_test_attempts(classroom_id, user_id) do
    ClassroomTestAttempt
    |> where([a], a.classroom_id == ^classroom_id and a.user_id == ^user_id)
    |> order_by([a], desc: a.completed_at)
    |> preload(:test)
    |> Repo.all()
  end

  # ============================================================================
  # Lesson Progress Management
  # ============================================================================

  @doc """
  Gets or creates lesson progress for a user in a classroom.
  """
  def get_or_create_lesson_progress(classroom_id, user_id, lesson_id) do
    case get_lesson_progress(classroom_id, user_id, lesson_id) do
      nil ->
        attrs = %{
          classroom_id: classroom_id,
          user_id: user_id,
          lesson_id: lesson_id,
          status: "not_started"
        }

        %ClassroomLessonProgress{}
        |> ClassroomLessonProgress.changeset(attrs)
        |> Repo.insert()

      progress ->
        {:ok, progress}
    end
  end

  @doc """
  Gets lesson progress for a specific user.
  """
  def get_lesson_progress(classroom_id, user_id, lesson_id) do
    ClassroomLessonProgress
    |> where([p], p.classroom_id == ^classroom_id)
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.lesson_id == ^lesson_id)
    |> preload([:lesson, :test_session])
    |> Repo.one()
  end

  @doc """
  Starts a lesson for a user.
  """
  def start_lesson(classroom_id, user_id, lesson_id) do
    {:ok, progress} = get_or_create_lesson_progress(classroom_id, user_id, lesson_id)

    progress
    |> ClassroomLessonProgress.start_changeset(%{})
    |> Repo.update()
  end

  @doc """
  Completes a lesson and records the test results.
  """
  def complete_lesson(classroom_id, user_id, lesson_id, test_session_id, points_earned) do
    {:ok, progress} = get_or_create_lesson_progress(classroom_id, user_id, lesson_id)

    # Get test session for score details
    _test_session = Tests.get_test_session(test_session_id)
    {score, max_score} = Tests.calculate_session_score(test_session_id)

    attrs = %{
      test_session_id: test_session_id,
      test_score: score,
      test_max_score: max_score,
      points_earned: points_earned
    }

    result =
      progress
      |> ClassroomLessonProgress.complete_changeset(attrs)
      |> Repo.update()

    # Add points to member
    with {:ok, completed_progress} <- result,
         {:ok, _} <- add_points_to_member(classroom_id, user_id, points_earned) do
      {:ok, completed_progress}
    else
      error -> error
    end
  end

  @doc """
  Lists lesson progress for a user in a classroom.
  """
  def list_user_lesson_progress(classroom_id, user_id) do
    ClassroomLessonProgress
    |> where([p], p.classroom_id == ^classroom_id and p.user_id == ^user_id)
    |> preload(:lesson)
    |> order_by([p], desc: p.completed_at)
    |> Repo.all()
  end

  @doc """
  Lists all lesson progress for a classroom.
  """
  def list_classroom_lesson_progress(classroom_id) do
    ClassroomLessonProgress
    |> where([p], p.classroom_id == ^classroom_id)
    |> preload([:user, :lesson])
    |> order_by([p], desc: p.completed_at)
    |> Repo.all()
  end

  # ============================================================================
  # Rankings and Leaderboards
  # ============================================================================

  @doc """
  Gets the overall classroom leaderboard.
  Ranked by: total_points desc, then by time spent (less is better).
  """
  def get_classroom_leaderboard(classroom_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    # Get approved members with their stats
    members =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.status == :approved)
      |> order_by([m], desc: m.points)
      |> preload(:user)
      |> limit(^limit)
      |> Repo.all()

    # Add rank
    members
    |> Enum.with_index(1)
    |> Enum.map(fn {member, rank} ->
      %{
        rank: rank,
        user: member.user,
        points: member.points,
        joined_at: member.joined_at
      }
    end)
  end

  @doc """
  Gets the leaderboard for a specific test.
  Ranked by: points desc, then time_remaining desc (tie-breaker).
  """
  def get_test_leaderboard(classroom_id, test_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    attempts =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id and a.test_id == ^test_id)
      |> where([a], a.status in ["completed", "timed_out"])
      |> order_by([a], desc: a.ranking_score)
      |> preload(:user)
      |> limit(^limit)
      |> Repo.all()

    attempts
    |> Enum.with_index(1)
    |> Enum.map(fn {attempt, rank} ->
      %{
        rank: rank,
        user: attempt.user,
        points_earned: attempt.points_earned,
        score: attempt.score,
        max_score: attempt.max_score,
        percentage: calculate_percentage(attempt.score, attempt.max_score),
        time_spent_seconds: attempt.time_spent_seconds,
        time_remaining_seconds: attempt.time_remaining_seconds,
        completed_at: attempt.completed_at,
        auto_submitted: attempt.auto_submitted
      }
    end)
  end

  @doc """
  Gets a user's rank in the classroom.
  """
  def get_user_classroom_rank(classroom_id, user_id) do
    user_points =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
      |> select([m], m.points)
      |> Repo.one()

    case user_points do
      nil ->
        nil

      points ->
        # Count how many users have more points
        higher_ranked =
          ClassroomMembership
          |> where([m], m.classroom_id == ^classroom_id and m.status == :approved)
          |> where([m], m.points > ^points)
          |> Repo.aggregate(:count, :id)

        higher_ranked + 1
    end
  end

  @doc """
  Gets a user's rank for a specific test.
  """
  def get_user_test_rank(classroom_id, test_id, user_id) do
    user_attempt =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id and a.test_id == ^test_id)
      |> where([a], a.user_id == ^user_id)
      |> where([a], a.status in ["completed", "timed_out"])
      |> select([a], a.ranking_score)
      |> Repo.one()

    case user_attempt do
      nil ->
        nil

      score ->
        higher_ranked =
          ClassroomTestAttempt
          |> where([a], a.classroom_id == ^classroom_id and a.test_id == ^test_id)
          |> where([a], a.status in ["completed", "timed_out"])
          |> where([a], a.ranking_score > ^score)
          |> Repo.aggregate(:count, :id)

        higher_ranked + 1
    end
  end

  # ============================================================================
  # Teacher Analytics
  # ============================================================================

  @doc """
  Gets comprehensive analytics for a classroom.
  """
  def get_classroom_analytics(classroom_id) do
    stats = get_classroom_stats(classroom_id)

    # Test completion stats
    test_stats = get_test_completion_stats(classroom_id)

    # Lesson completion stats
    lesson_stats = get_lesson_completion_stats(classroom_id)

    # Activity over time (last 30 days)
    activity = get_recent_activity(classroom_id, days: 30)

    # Top performers
    top_performers = get_classroom_leaderboard(classroom_id, limit: 10)

    # Recent test attempts
    recent_attempts = list_classroom_test_attempts(classroom_id, limit: 20)

    %{
      stats: stats,
      test_stats: test_stats,
      lesson_stats: lesson_stats,
      activity: activity,
      top_performers: top_performers,
      recent_attempts: recent_attempts
    }
  end

  @doc """
  Gets test completion statistics for a classroom.
  """
  def get_test_completion_stats(classroom_id) do
    total_attempts =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id)
      |> where([a], a.status in ["completed", "timed_out"])
      |> Repo.aggregate(:count, :id) || 0

    avg_score =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id)
      |> where([a], a.status in ["completed", "timed_out"])
      |> Repo.aggregate(:avg, :points_earned) || 0.0

    completed_on_time =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id and a.status == "completed")
      |> Repo.aggregate(:count, :id) || 0

    timed_out =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id and a.status == "timed_out")
      |> Repo.aggregate(:count, :id) || 0

    %{
      total_attempts: total_attempts,
      average_score: Decimal.round(Decimal.new("#{avg_score}"), 2),
      completed_on_time: completed_on_time,
      timed_out: timed_out,
      completion_rate: if(total_attempts > 0, do: completed_on_time / total_attempts, else: 0.0)
    }
  end

  @doc """
  Gets lesson completion statistics for a classroom.
  """
  def get_lesson_completion_stats(classroom_id) do
    total_completed =
      ClassroomLessonProgress
      |> where([p], p.classroom_id == ^classroom_id and p.status == "completed")
      |> Repo.aggregate(:count, :id) || 0

    in_progress =
      ClassroomLessonProgress
      |> where([p], p.classroom_id == ^classroom_id and p.status == "in_progress")
      |> Repo.aggregate(:count, :id) || 0

    avg_points =
      ClassroomLessonProgress
      |> where([p], p.classroom_id == ^classroom_id and p.status == "completed")
      |> Repo.aggregate(:avg, :points_earned) || 0.0

    %{
      total_completed: total_completed,
      in_progress: in_progress,
      average_points: Decimal.round(Decimal.new("#{avg_points}"), 2)
    }
  end

  @doc """
  Gets recent activity data for charts.
  """
  def get_recent_activity(classroom_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.add(DateTime.utc_now(), -days * 86400, :second)

    # Daily activity counts
    attempts =
      ClassroomTestAttempt
      |> where([a], a.classroom_id == ^classroom_id)
      |> where([a], a.completed_at >= ^since)
      |> Repo.all()

    # Group by date
    attempts
    |> Enum.group_by(fn a -> Date.to_iso8601(a.completed_at) end)
    |> Enum.map(fn {date, list} ->
      %{
        date: date,
        attempts: length(list),
        total_points: Enum.sum(Enum.map(list, & &1.points_earned))
      }
    end)
    |> Enum.sort_by(& &1.date)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp calculate_percentage(score, max_score) when max_score > 0 do
    Decimal.round(Decimal.mult(Decimal.div(Decimal.new(score), Decimal.new(max_score)), 100), 1)
  end

  defp calculate_percentage(_, _), do: Decimal.new(0)

  @doc """
  Adds points to a classroom member's total.
  """
  def add_points_to_member(classroom_id, user_id, points) when points > 0 do
    membership =
      ClassroomMembership
      |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
      |> Repo.one()

    case membership do
      nil ->
        {:error, :not_a_member}

      membership ->
        new_points = membership.points + points

        membership
        |> ClassroomMembership.changeset(%{points: new_points})
        |> Repo.update()
    end
  end

  def add_points_to_member(_, _, 0), do: {:ok, nil}
  def add_points_to_member(_, _, points) when points < 0, do: {:ok, nil}

  defp maybe_generate_slug(attrs) do
    name = attrs[:name]
    slug = attrs[:slug]

    if name && (is_nil(slug) || slug == "") do
      slug = Classroom.generate_slug(name)
      # Ensure uniqueness by appending random suffix if needed
      slug = ensure_unique_slug(slug)
      Map.put(attrs, :slug, slug)
    else
      attrs
    end
  end

  defp ensure_unique_slug(base_slug) do
    if Repo.exists?(where(Classroom, [c], c.slug == ^base_slug)) do
      suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower) |> binary_part(0, 6)
      "#{base_slug}-#{suffix}"
    else
      base_slug
    end
  end

  defp maybe_generate_invite_code(attrs) do
    if attrs[:invite_code] do
      attrs
    else
      Map.put(attrs, :invite_code, Classroom.generate_invite_code())
    end
  end
end
