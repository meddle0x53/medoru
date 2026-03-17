defmodule Medoru.Content.CustomLessonTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Content
  alias Medoru.Classrooms

  describe "custom lessons" do
    setup do
      teacher = user_fixture(%{user_type: :teacher})
      student = user_fixture(%{user_type: :student})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      %{
        teacher: teacher,
        student: student,
        classroom: classroom
      }
    end

    test "create_custom_lesson/1 creates a lesson", %{teacher: teacher} do
      attrs = %{
        title: "Test Lesson",
        description: "A test lesson",
        creator_id: teacher.id,
        difficulty: 5
      }

      assert {:ok, lesson} = Content.create_custom_lesson(attrs)
      assert lesson.title == "Test Lesson"
      assert lesson.status == "draft"
      assert lesson.word_count == 0
    end

    test "list_teacher_custom_lessons/1 returns teacher's lessons", %{teacher: teacher} do
      {:ok, _} =
        Content.create_custom_lesson(%{
          title: "Lesson 1",
          creator_id: teacher.id
        })

      {:ok, _} =
        Content.create_custom_lesson(%{
          title: "Lesson 2",
          creator_id: teacher.id
        })

      lessons = Content.list_teacher_custom_lessons(teacher.id)
      assert length(lessons) == 2
    end

    test "add_word_to_lesson/3 adds a word", %{teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson with Words",
          creator_id: teacher.id
        })

      assert {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      lesson = Content.get_custom_lesson!(lesson.id)
      assert lesson.word_count == 1

      lesson_words = Content.list_lesson_words(lesson.id)
      assert length(lesson_words) == 1
      assert hd(lesson_words).word_id == word.id
    end

    test "remove_word_from_lesson/2 removes a word", %{teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson",
          creator_id: teacher.id
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})
      assert {:ok, _} = Content.remove_word_from_lesson(lesson.id, word.id)

      lesson = Content.get_custom_lesson!(lesson.id)
      assert lesson.word_count == 0
    end

    test "update_custom_lesson_word/2 updates word details", %{teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson",
          creator_id: teacher.id
        })

      {:ok, lesson_word} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      attrs = %{
        custom_meaning: "Custom meaning",
        examples: ["Example 1", "Example 2"]
      }

      assert {:ok, updated} = Content.update_custom_lesson_word(lesson_word, attrs)
      assert updated.custom_meaning == "Custom meaning"
      assert updated.examples == ["Example 1", "Example 2"]
    end

    test "publish_lesson_to_classroom/4 publishes a lesson", %{
      teacher: teacher,
      classroom: classroom
    } do
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Published Lesson",
          creator_id: teacher.id
        })

      assert {:ok, published} =
               Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      assert published.classroom_id == classroom.id
      assert published.custom_lesson_id == lesson.id
      assert published.status == "active"
    end

    test "list_classroom_custom_lessons/1 returns classroom lessons", %{
      teacher: teacher,
      classroom: classroom
    } do
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Classroom Lesson",
          creator_id: teacher.id
        })

      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      lessons = Content.list_classroom_custom_lessons(classroom.id)
      assert length(lessons) == 1
      assert hd(lessons).custom_lesson_id == lesson.id
    end

    test "complete_custom_lesson/3 awards points", %{
      classroom: classroom,
      student: student,
      teacher: teacher
    } do
      word1 = word_fixture()
      word2 = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson",
          creator_id: teacher.id
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})
      {:ok, lesson} = Content.publish_custom_lesson(lesson)

      {:ok, _} =
        Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      # Points should be: 2 words * 1 + 1 = 3
      assert {:ok, progress} =
               Classrooms.complete_custom_lesson(classroom.id, student.id, lesson.id)

      assert progress.points_earned == 3
      assert progress.status == "completed"

      # Check member points updated
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      assert membership.points == 3
    end
  end
end
