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

      %ClassroomMembership{}
      |> ClassroomMembership.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Approves a membership application.

  ## Examples

      iex> approve_membership(membership)
      {:ok, %ClassroomMembership{}}

  """
  def approve_membership(%ClassroomMembership{} = membership) do
    membership
    |> ClassroomMembership.approve_changeset()
    |> Repo.update()
  end

  @doc """
  Rejects a membership application.

  ## Examples

      iex> reject_membership(membership)
      {:ok, %ClassroomMembership{}}

  """
  def reject_membership(%ClassroomMembership{} = membership) do
    membership
    |> ClassroomMembership.reject_changeset()
    |> Repo.update()
  end

  @doc """
  Removes a member from a classroom (by teacher).

  ## Examples

      iex> remove_member(membership)
      {:ok, %ClassroomMembership{}}

  """
  def remove_member(%ClassroomMembership{} = membership) do
    membership
    |> ClassroomMembership.remove_changeset()
    |> Repo.update()
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

  # ============================================================================
  # Private Functions
  # ============================================================================

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
