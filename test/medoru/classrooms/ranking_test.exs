defmodule Medoru.Classrooms.RankingTest do
  @moduledoc """
  Tests for the classroom ranking system.
  
  Covers:
  - Test leaderboard rankings
  - Tie-breaker logic (same points -> more time remaining = higher rank)
  - Classroom overall leaderboard
  - Multiple students scenarios
  """
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  alias Medoru.Classrooms
  alias Medoru.Classrooms.ClassroomTestAttempt
  alias Medoru.Repo

  describe "test leaderboard rankings" do
    setup do
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Ranking Test Classroom",
          teacher_id: teacher.id
        })
      
      test_resource =
        test_fixture(%{
          title: "Ranking Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 10
        })
      
      _step =
        test_step_fixture(test_resource, %{
          question: "Q1",
          question_type: :multichoice,
          correct_answer: "A",
          options: ["A", "B", "C", "D"],
          order_index: 0
        })
      
      {:ok, classroom_test} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test_resource.id,
          teacher.id,
          %{max_attempts: 1}
        )
      
      %{
        teacher: teacher,
        classroom: classroom,
        test_resource: test_resource,
        classroom_test: classroom_test
      }
    end
    
    test "ranks by points descending", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      # Create 3 students with different scores
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      student3 = user_fixture(%{email: "student3@example.com"})
      
      # Add all as approved members
      for student <- [student1, student2, student3] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # Create attempts with different scores
      # Student1: 10 points (highest)
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 10, 100, 600)
      
      # Student2: 5 points (middle)
      create_completed_attempt(classroom.id, student2.id, test_resource.id, 5, 200, 600)
      
      # Student3: 2 points (lowest)
      create_completed_attempt(classroom.id, student3.id, test_resource.id, 2, 300, 600)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert length(leaderboard) == 3
      assert Enum.at(leaderboard, 0).rank == 1
      assert Enum.at(leaderboard, 0).user.id == student1.id
      assert Enum.at(leaderboard, 0).points_earned == 10
      
      assert Enum.at(leaderboard, 1).rank == 2
      assert Enum.at(leaderboard, 1).user.id == student2.id
      assert Enum.at(leaderboard, 1).points_earned == 5
      
      assert Enum.at(leaderboard, 2).rank == 3
      assert Enum.at(leaderboard, 2).user.id == student3.id
      assert Enum.at(leaderboard, 2).points_earned == 2
    end
    
    test "tie-breaker: same points, more time remaining ranks higher", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      # Create 2 students with same points but different time remaining
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      
      for student <- [student1, student2] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # Both get 5 points, but:
      # Student1: 100 seconds remaining (should rank higher - less time used)
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 5, 100, 600)
      
      # Student2: 50 seconds remaining (should rank lower - more time used)
      create_completed_attempt(classroom.id, student2.id, test_resource.id, 5, 50, 600)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert length(leaderboard) == 2
      
      # Student1 should rank higher (same points, more time remaining)
      assert Enum.at(leaderboard, 0).rank == 1
      assert Enum.at(leaderboard, 0).user.id == student1.id
      assert Enum.at(leaderboard, 0).time_remaining_seconds == 100
      
      # Student2 should rank lower (same points, less time remaining)
      assert Enum.at(leaderboard, 1).rank == 2
      assert Enum.at(leaderboard, 1).user.id == student2.id
      assert Enum.at(leaderboard, 1).time_remaining_seconds == 50
    end
    
    test "tie-breaker: extreme time difference with same points", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      student3 = user_fixture(%{email: "student3@example.com"})
      
      for student <- [student1, student2, student3] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # All get 5 points, different time remaining:
      # Student1: 500s remaining (fastest - rank 1)
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 5, 500, 600)
      
      # Student2: 300s remaining (middle - rank 2)
      create_completed_attempt(classroom.id, student2.id, test_resource.id, 5, 300, 600)
      
      # Student3: 10s remaining (slowest - rank 3)
      create_completed_attempt(classroom.id, student3.id, test_resource.id, 5, 10, 600)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert length(leaderboard) == 3
      assert Enum.at(leaderboard, 0).user.id == student1.id
      assert Enum.at(leaderboard, 1).user.id == student2.id
      assert Enum.at(leaderboard, 2).user.id == student3.id
    end
    
    test "mixed points and time tie-breaker", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      # Create 4 students with various points and times
      # Points should always trump time remaining
      student1 = user_fixture(%{email: "student1@example.com"}) # 10 pts, 10s left
      student2 = user_fixture(%{email: "student2@example.com"}) # 8 pts, 500s left
      student3 = user_fixture(%{email: "student3@example.com"}) # 5 pts, 500s left
      student4 = user_fixture(%{email: "student4@example.com"}) # 5 pts, 100s left
      
      for student <- [student1, student2, student3, student4] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # Student1: 10 points, 10s remaining (rank 1 - highest points)
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 10, 10, 600)
      
      # Student2: 8 points, 500s remaining (rank 2 - lower points but lots of time)
      create_completed_attempt(classroom.id, student2.id, test_resource.id, 8, 500, 600)
      
      # Student3: 5 points, 500s remaining (rank 3 - tied with student4 but more time)
      create_completed_attempt(classroom.id, student3.id, test_resource.id, 5, 500, 600)
      
      # Student4: 5 points, 100s remaining (rank 4 - tied with student3 but less time)
      create_completed_attempt(classroom.id, student4.id, test_resource.id, 5, 100, 600)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert length(leaderboard) == 4
      
      # Order should be: student1, student2, student3, student4
      assert Enum.at(leaderboard, 0).user.id == student1.id
      assert Enum.at(leaderboard, 0).points_earned == 10
      
      assert Enum.at(leaderboard, 1).user.id == student2.id
      assert Enum.at(leaderboard, 1).points_earned == 8
      
      assert Enum.at(leaderboard, 2).user.id == student3.id
      assert Enum.at(leaderboard, 2).points_earned == 5
      assert Enum.at(leaderboard, 2).time_remaining_seconds == 500
      
      assert Enum.at(leaderboard, 3).user.id == student4.id
      assert Enum.at(leaderboard, 3).points_earned == 5
      assert Enum.at(leaderboard, 3).time_remaining_seconds == 100
    end
    
    test "only completed and timed_out attempts appear on leaderboard", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      
      for student <- [student1, student2] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # Student1: completed attempt
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 10, 100, 600)
      
      # Student2: in_progress attempt (should NOT appear)
      {:ok, _} = Classrooms.start_test_attempt(classroom.id, student2.id, test_resource.id, 600, 10)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert length(leaderboard) == 1
      assert Enum.at(leaderboard, 0).user.id == student1.id
    end
    
    test "auto_submitted flag is preserved in leaderboard", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student = user_fixture(%{email: "student@example.com"})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      # Create a timed out attempt (auto-submitted)
      attempt = create_completed_attempt(classroom.id, student.id, test_resource.id, 5, 0, 600)
      
      # Update to timed_out status
      attempt
      |> Ecto.Changeset.change(status: "timed_out", auto_submitted: true)
      |> Repo.update!()
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      assert Enum.at(leaderboard, 0).auto_submitted == true
    end
    
    test "percentage is calculated correctly", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student = user_fixture(%{email: "student@example.com"})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      # 5 out of 10 points = 50%
      create_completed_attempt(classroom.id, student.id, test_resource.id, 5, 100, 600)
      
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_resource.id)
      
      entry = Enum.at(leaderboard, 0)
      assert entry.percentage == Decimal.new("50.0")
    end
  end
  
  describe "classroom overall leaderboard" do
    setup do
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Overall Ranking Classroom",
          teacher_id: teacher.id
        })
      
      %{
        teacher: teacher,
        classroom: classroom
      }
    end
    
    test "ranks by total points descending", %{
      classroom: classroom
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      student3 = user_fixture(%{email: "student3@example.com"})
      
      # Add members with different points
      for {student, points} <- [{student1, 100}, {student2, 50}, {student3, 200}] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
        {:ok, _} = Classrooms.update_member_points(membership, points)
      end
      
      leaderboard = Classrooms.get_classroom_leaderboard(classroom.id)
      
      assert length(leaderboard) == 3
      
      # Should be ordered by points: student3 (200), student1 (100), student2 (50)
      assert Enum.at(leaderboard, 0).rank == 1
      assert Enum.at(leaderboard, 0).user.id == student3.id
      assert Enum.at(leaderboard, 0).points == 200
      
      assert Enum.at(leaderboard, 1).rank == 2
      assert Enum.at(leaderboard, 1).user.id == student1.id
      assert Enum.at(leaderboard, 1).points == 100
      
      assert Enum.at(leaderboard, 2).rank == 3
      assert Enum.at(leaderboard, 2).user.id == student2.id
      assert Enum.at(leaderboard, 2).points == 50
    end
    
    test "only approved members appear on leaderboard", %{
      classroom: classroom
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      
      # Student1: approved
      {:ok, membership1} = Classrooms.apply_to_join(classroom.id, student1.id)
      {:ok, _} = Classrooms.approve_membership(membership1)
      {:ok, _} = Classrooms.update_member_points(membership1, 100)
      
      # Student2: pending (should NOT appear)
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student2.id)
      # Don't approve
      
      leaderboard = Classrooms.get_classroom_leaderboard(classroom.id)
      
      assert length(leaderboard) == 1
      assert Enum.at(leaderboard, 0).user.id == student1.id
    end
    
    test "respects limit option", %{
      classroom: classroom
    } do
      # Create 5 students
      _students = for i <- 1..5 do
        student = user_fixture(%{email: "student#{i}@example.com"})
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
        {:ok, _} = Classrooms.update_member_points(membership, i * 10)
        student
      end
      
      leaderboard = Classrooms.get_classroom_leaderboard(classroom.id, limit: 3)
      
      assert length(leaderboard) == 3
    end
  end
  
  describe "user rank lookup" do
    setup do
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "User Rank Classroom",
          teacher_id: teacher.id
        })
      
      test_resource =
        test_fixture(%{
          title: "User Rank Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 10
        })
      
      {:ok, _} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test_resource.id,
          teacher.id,
          %{max_attempts: 1}
        )
      
      %{
        teacher: teacher,
        classroom: classroom,
        test_resource: test_resource
      }
    end
    
    test "get_user_classroom_rank returns correct rank", %{
      classroom: classroom
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      student3 = user_fixture(%{email: "student3@example.com"})
      
      # Setup: student3 (300pts, rank 1), student1 (200pts, rank 2), student2 (100pts, rank 3)
      for {student, points} <- [{student1, 200}, {student2, 100}, {student3, 300}] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
        {:ok, _} = Classrooms.update_member_points(membership, points)
      end
      
      assert Classrooms.get_user_classroom_rank(classroom.id, student1.id) == 2
      assert Classrooms.get_user_classroom_rank(classroom.id, student2.id) == 3
      assert Classrooms.get_user_classroom_rank(classroom.id, student3.id) == 1
    end
    
    test "get_user_classroom_rank returns nil for non-member", %{
      classroom: classroom
    } do
      non_member = user_fixture(%{email: "nonmember@example.com"})
      
      assert Classrooms.get_user_classroom_rank(classroom.id, non_member.id) == nil
    end
    
    test "get_user_test_rank returns correct rank", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student1 = user_fixture(%{email: "student1@example.com"})
      student2 = user_fixture(%{email: "student2@example.com"})
      
      for student <- [student1, student2] do
        {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
        {:ok, _} = Classrooms.approve_membership(membership)
      end
      
      # Student1: 10 points (rank 1)
      create_completed_attempt(classroom.id, student1.id, test_resource.id, 10, 100, 600)
      
      # Student2: 5 points (rank 2)
      create_completed_attempt(classroom.id, student2.id, test_resource.id, 5, 100, 600)
      
      assert Classrooms.get_user_test_rank(classroom.id, test_resource.id, student1.id) == 1
      assert Classrooms.get_user_test_rank(classroom.id, test_resource.id, student2.id) == 2
    end
    
    test "get_user_test_rank returns nil for no attempt", %{
      classroom: classroom,
      test_resource: test_resource
    } do
      student = user_fixture(%{email: "student@example.com"})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      assert Classrooms.get_user_test_rank(classroom.id, test_resource.id, student.id) == nil
    end
  end
  
  describe "ranking_score calculation" do
    test "ranking_score includes time bonus for tie-breaking" do
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Score Calc Classroom",
          teacher_id: teacher.id
        })
      
      test_resource = test_fixture(%{title: "Score Test", created_by_id: teacher.id, status: :published})
      student = user_fixture(%{email: "student@example.com"})
      
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      # Create attempt: 5 points, 300s remaining out of 600s
      # ranking_score should be 5 + (300/600)*0.01 = 5.005
      attempt = create_completed_attempt(classroom.id, student.id, test_resource.id, 5, 300, 600)
      
      # Reload to get calculated ranking_score
      attempt = Repo.get!(ClassroomTestAttempt, attempt.id)
      
      assert Decimal.equal?(attempt.ranking_score, Decimal.new("5.005"))
    end
    
    test "ranking_score with 0 time remaining" do
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Score Calc Classroom 2",
          teacher_id: teacher.id
        })
      
      test_resource = test_fixture(%{title: "Score Test 2", created_by_id: teacher.id, status: :published})
      student = user_fixture(%{email: "student2@example.com"})
      
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      # Create attempt: 5 points, 0s remaining
      # ranking_score should be 5 + (0/600)*0.01 = 5.0
      attempt = create_completed_attempt(classroom.id, student.id, test_resource.id, 5, 0, 600)
      
      attempt = Repo.get!(ClassroomTestAttempt, attempt.id)
      
      assert Decimal.equal?(attempt.ranking_score, Decimal.new("5.0"))
    end
  end
  
  # Helper function to create a completed test attempt
  defp create_completed_attempt(classroom_id, user_id, test_id, points, time_remaining, time_limit) do
    attrs = %{
      classroom_id: classroom_id,
      user_id: user_id,
      test_id: test_id,
      time_limit_seconds: time_limit,
      max_score: 10,
      started_at: DateTime.utc_now()
    }
    
    {:ok, attempt} =
      %ClassroomTestAttempt{}
      |> ClassroomTestAttempt.create_changeset(attrs)
      |> Repo.insert()
    
    # Complete the attempt
    complete_attrs = %{
      test_session_id: nil,
      score: points,
      max_score: 10,
      points_earned: points,
      time_spent_seconds: time_limit - time_remaining,
      time_remaining_seconds: time_remaining,
      status: "completed",
      completed_at: DateTime.utc_now()
    }
    
    {:ok, completed_attempt} =
      attempt
      |> ClassroomTestAttempt.complete_changeset(complete_attrs)
      |> Repo.update()
    
    completed_attempt
  end
end
