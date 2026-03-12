defmodule Medoru.TestsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Tests` context.
  """

  alias Medoru.Tests
  alias Medoru.AccountsFixtures

  @doc """
  Generate a teacher user.
  """
  def teacher_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{user_type: "teacher"})
    |> AccountsFixtures.user_fixture_with_registration()
  end

  @doc """
  Generate a teacher test (in_progress state).
  """
  def teacher_test_fixture(teacher_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test #{System.unique_integer()}",
        description: "A test description",
        time_limit_seconds: 600,
        setup_state: "in_progress"
      })

    {:ok, test} = Tests.create_teacher_test(attrs, teacher_id)
    test
  end
end
