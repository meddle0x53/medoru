defmodule Medoru.Content.TeacherAuthorizationTest do
  use Medoru.DataCase

  alias Medoru.Content
  alias Medoru.Classrooms

  import Medoru.AccountsFixtures

  describe "publish_lesson_to_classroom/4 authorization" do
    test "teacher can publish to their own classroom" do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "My Classroom",
          teacher_id: teacher.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "My Lesson",
          creator_id: teacher.id,
          status: "published"
        })

      assert {:ok, _} =
               Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)
    end

    test "teacher cannot publish to another teacher's classroom" do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Teacher2's Classroom",
          teacher_id: teacher2.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "My Lesson",
          creator_id: teacher1.id,
          status: "published"
        })

      assert {:error, :not_authorized} =
               Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher1.id)
    end

    test "student cannot publish lesson to any classroom" do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Teacher's Classroom",
          teacher_id: teacher.id
        })

      # Student tries to publish by using teacher's classroom
      {:ok, _lesson} =
        Content.create_custom_lesson(%{
          title: "My Lesson",
          creator_id: student.id,
          status: "published"
        })

      # Even if they could create a lesson, they can't publish to teacher's classroom
      assert {:error, :not_authorized} =
               Content.publish_lesson_to_classroom(
                 Ecto.UUID.generate(),
                 classroom.id,
                 student.id
               )
    end
  end

  describe "unpublish_lesson_from_classroom/2 authorization" do
    test "teacher can unpublish from their own classroom" do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "My Classroom",
          teacher_id: teacher.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "My Lesson",
          creator_id: teacher.id,
          status: "published"
        })

      {:ok, published} =
        Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      assert {:ok, _} =
               Content.unpublish_lesson_from_classroom(published, teacher.id)
    end

    test "teacher cannot unpublish from another teacher's classroom" do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Teacher2's Classroom",
          teacher_id: teacher2.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson",
          creator_id: teacher1.id,
          status: "published"
        })

      # First publish as teacher2 (owner of classroom)
      {:ok, published} =
        Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher2.id)

      # Teacher1 tries to unpublish
      assert {:error, :not_authorized} =
               Content.unpublish_lesson_from_classroom(published, teacher1.id)
    end
  end
end
