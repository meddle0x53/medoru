defmodule Medoru.LearningTest do
  use Medoru.DataCase

  alias Medoru.Learning
  alias Medoru.Learning.{UserProgress, LessonProgress}

  import Medoru.LearningFixtures

  describe "lesson_progress" do
    import Medoru.AccountsFixtures
    import Medoru.ContentFixtures

    test "list_lesson_progress/1 returns all lesson_progress for a user" do
      user = user_fixture()
      lesson = lesson_fixture()
      lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      [result] = Learning.list_lesson_progress(user.id)
      assert result.id == lesson_progress.id
      assert result.user_id == user.id
      assert result.lesson_id == lesson.id
    end

    test "get_lesson_progress/2 returns the lesson_progress for user and lesson" do
      user = user_fixture()
      lesson = lesson_fixture()
      lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      result = Learning.get_lesson_progress(user.id, lesson.id)
      assert result.id == lesson_progress.id
      assert result.user_id == user.id
      assert result.lesson_id == lesson.id
    end

    test "get_lesson_progress/2 returns nil if no progress exists" do
      user = user_fixture()
      lesson = lesson_fixture()

      assert Learning.get_lesson_progress(user.id, lesson.id) == nil
    end

    test "lesson_started?/2 returns true if user has started lesson" do
      user = user_fixture()
      lesson = lesson_fixture()
      _lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      assert Learning.lesson_started?(user.id, lesson.id) == true
    end

    test "lesson_started?/2 returns false if user has not started lesson" do
      user = user_fixture()
      lesson = lesson_fixture()

      assert Learning.lesson_started?(user.id, lesson.id) == false
    end

    test "lesson_completed?/2 returns true if user has completed lesson" do
      user = user_fixture()
      lesson = lesson_fixture()

      _lesson_progress =
        lesson_progress_fixture(
          user_id: user.id,
          lesson_id: lesson.id,
          status: :completed
        )

      assert Learning.lesson_completed?(user.id, lesson.id) == true
    end

    test "lesson_completed?/2 returns false if user has not completed lesson" do
      user = user_fixture()
      lesson = lesson_fixture()
      _lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      assert Learning.lesson_completed?(user.id, lesson.id) == false
    end

    test "start_lesson/2 creates a new lesson_progress" do
      user = user_fixture()
      lesson = lesson_fixture()

      assert {:ok, %LessonProgress{} = lesson_progress} =
               Learning.start_lesson(user.id, lesson.id)

      assert lesson_progress.user_id == user.id
      assert lesson_progress.lesson_id == lesson.id
      assert lesson_progress.status == :started
      assert lesson_progress.started_at != nil
    end

    test "start_lesson/2 returns existing progress if already started" do
      user = user_fixture()
      lesson = lesson_fixture()

      {:ok, existing} = Learning.start_lesson(user.id, lesson.id)
      {:ok, result} = Learning.start_lesson(user.id, lesson.id)
      assert result.id == existing.id
    end

    test "update_lesson_progress/3 updates the progress percentage" do
      user = user_fixture()
      lesson = lesson_fixture()
      _lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      assert {:ok, %LessonProgress{} = lesson_progress} =
               Learning.update_lesson_progress(user.id, lesson.id, 50)

      assert lesson_progress.progress_percentage == 50
    end

    test "update_lesson_progress/3 returns error if lesson not started" do
      user = user_fixture()
      lesson = lesson_fixture()

      assert {:error, :not_started} =
               Learning.update_lesson_progress(user.id, lesson.id, 50)
    end

    test "complete_lesson/2 marks lesson as completed" do
      user = user_fixture()
      lesson = lesson_fixture()
      _lesson_progress = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      assert {:ok, %LessonProgress{} = lesson_progress} =
               Learning.complete_lesson(user.id, lesson.id)

      assert lesson_progress.status == :completed
      assert lesson_progress.completed_at != nil
      assert lesson_progress.progress_percentage == 100
    end

    test "complete_lesson/2 returns error if lesson not started" do
      user = user_fixture()
      lesson = lesson_fixture()

      assert {:error, :not_started} = Learning.complete_lesson(user.id, lesson.id)
    end
  end

  describe "user_progress" do
    import Medoru.AccountsFixtures
    import Medoru.ContentFixtures

    test "list_user_progress/1 returns all user_progress for a user" do
      user = user_fixture()
      kanji = kanji_fixture()
      user_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)

      [result] = Learning.list_user_progress(user.id)
      assert result.id == user_progress.id
      assert result.user_id == user.id
    end

    test "list_kanji_progress/1 returns only kanji progress" do
      user = user_fixture()
      kanji = kanji_fixture()
      word = word_fixture()

      kanji_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)
      _word_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      result = Learning.list_kanji_progress(user.id)
      assert length(result) == 1
      assert hd(result).id == kanji_progress.id
    end

    test "list_word_progress/1 returns only word progress" do
      user = user_fixture()
      kanji = kanji_fixture()
      word = word_fixture()

      _kanji_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)
      word_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      result = Learning.list_word_progress(user.id)
      assert length(result) == 1
      assert hd(result).id == word_progress.id
    end

    test "get_kanji_progress/2 returns kanji progress for user" do
      user = user_fixture()
      kanji = kanji_fixture()
      user_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)

      result = Learning.get_kanji_progress(user.id, kanji.id)
      assert result.id == user_progress.id
      assert result.kanji_id == kanji.id
    end

    test "get_word_progress/2 returns word progress for user" do
      user = user_fixture()
      word = word_fixture()
      user_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      result = Learning.get_word_progress(user.id, word.id)
      assert result.id == user_progress.id
      assert result.word_id == word.id
    end

    test "kanji_learned?/2 returns true if kanji is learned" do
      user = user_fixture()
      kanji = kanji_fixture()
      _user_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)

      assert Learning.kanji_learned?(user.id, kanji.id) == true
    end

    test "kanji_learned?/2 returns false if kanji is not learned" do
      user = user_fixture()
      kanji = kanji_fixture()

      assert Learning.kanji_learned?(user.id, kanji.id) == false
    end

    test "word_learned?/2 returns true if word is learned" do
      user = user_fixture()
      word = word_fixture()
      _user_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      assert Learning.word_learned?(user.id, word.id) == true
    end

    test "word_learned?/2 returns false if word is not learned" do
      user = user_fixture()
      word = word_fixture()

      assert Learning.word_learned?(user.id, word.id) == false
    end

    test "track_kanji_learned/2 creates kanji progress" do
      user = user_fixture()
      kanji = kanji_fixture()

      assert {:ok, %UserProgress{} = user_progress} =
               Learning.track_kanji_learned(user.id, kanji.id)

      assert user_progress.user_id == user.id
      assert user_progress.kanji_id == kanji.id
      assert user_progress.word_id == nil
      assert user_progress.mastery_level == 1
    end

    test "track_kanji_learned/2 returns existing progress if already tracked" do
      user = user_fixture()
      kanji = kanji_fixture()

      {:ok, existing} = Learning.track_kanji_learned(user.id, kanji.id)
      {:ok, result} = Learning.track_kanji_learned(user.id, kanji.id)
      assert result.id == existing.id
    end

    test "track_word_learned/2 creates word progress" do
      user = user_fixture()
      word = word_fixture()

      assert {:ok, %UserProgress{} = user_progress} =
               Learning.track_word_learned(user.id, word.id)

      assert user_progress.user_id == user.id
      assert user_progress.word_id == word.id
      assert user_progress.kanji_id == nil
      assert user_progress.mastery_level == 1
    end

    test "track_word_learned/2 returns existing progress if already tracked" do
      user = user_fixture()
      word = word_fixture()

      {:ok, existing} = Learning.track_word_learned(user.id, word.id)
      {:ok, result} = Learning.track_word_learned(user.id, word.id)
      assert result.id == existing.id
    end

    test "update_kanji_mastery/3 updates mastery level" do
      user = user_fixture()
      kanji = kanji_fixture()
      _user_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)

      assert {:ok, %UserProgress{} = user_progress} =
               Learning.update_kanji_mastery(user.id, kanji.id, 2)

      assert user_progress.mastery_level == 2
      assert user_progress.times_reviewed == 1
      assert user_progress.last_reviewed_at != nil
    end

    test "update_kanji_mastery/3 returns error if kanji not learned" do
      user = user_fixture()
      kanji = kanji_fixture()

      assert {:error, :not_learned} = Learning.update_kanji_mastery(user.id, kanji.id, 2)
    end

    test "update_word_mastery/3 updates mastery level" do
      user = user_fixture()
      word = word_fixture()
      _user_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      assert {:ok, %UserProgress{} = user_progress} =
               Learning.update_word_mastery(user.id, word.id, 3)

      assert user_progress.mastery_level == 3
      assert user_progress.times_reviewed == 1
      assert user_progress.last_reviewed_at != nil
    end

    test "update_word_mastery/3 returns error if word not learned" do
      user = user_fixture()
      word = word_fixture()

      assert {:error, :not_learned} = Learning.update_word_mastery(user.id, word.id, 3)
    end
  end

  describe "statistics" do
    import Medoru.AccountsFixtures
    import Medoru.ContentFixtures

    test "get_user_stats/1 returns user statistics" do
      user = user_fixture()
      kanji = kanji_fixture()
      word = word_fixture()
      lesson = lesson_fixture()

      _user_progress = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)
      _word_progress = user_progress_fixture(user_id: user.id, word_id: word.id)

      _lesson_progress =
        lesson_progress_fixture(
          user_id: user.id,
          lesson_id: lesson.id,
          status: :completed
        )

      stats = Learning.get_user_stats(user.id)

      assert stats.total_kanji_learned == 1
      assert stats.total_words_learned == 1
      assert stats.lessons_started == 1
      assert stats.lessons_completed == 1
      assert stats.kanji_by_mastery == %{0 => 0, 1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
    end

    test "get_user_stats/1 returns empty stats for new user" do
      user = user_fixture()

      stats = Learning.get_user_stats(user.id)

      assert stats.total_kanji_learned == 0
      assert stats.total_words_learned == 0
      assert stats.lessons_started == 0
      assert stats.lessons_completed == 0
      assert stats.kanji_by_mastery == %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
    end
  end

  describe "user_progress changeset validations" do
    import Medoru.AccountsFixtures
    import Medoru.ContentFixtures

    test "cannot have both kanji_id and word_id" do
      user = user_fixture()
      kanji = kanji_fixture()
      word = word_fixture()

      attrs = %{
        user_id: user.id,
        kanji_id: kanji.id,
        word_id: word.id
      }

      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      assert %{kanji_id: ["cannot have both kanji_id and word_id"]} = errors_on(changeset)
    end

    test "must have at least kanji_id or word_id" do
      user = user_fixture()

      attrs = %{
        user_id: user.id
      }

      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      assert %{kanji_id: ["must have either kanji_id or word_id"]} = errors_on(changeset)
    end

    test "mastery_level must be between 0 and 5" do
      user = user_fixture()
      kanji = kanji_fixture()

      attrs = %{
        user_id: user.id,
        kanji_id: kanji.id,
        mastery_level: 6
      }

      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      assert "must be less than or equal to 5" in errors_on(changeset).mastery_level
    end

    test "cannot create duplicate kanji progress for same user" do
      user = user_fixture()
      kanji = kanji_fixture()

      _first = user_progress_fixture(user_id: user.id, kanji_id: kanji.id)

      {:error, changeset} =
        %UserProgress{}
        |> UserProgress.changeset(%{user_id: user.id, kanji_id: kanji.id})
        |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "cannot create duplicate word progress for same user" do
      user = user_fixture()
      word = word_fixture()

      _first = user_progress_fixture(user_id: user.id, word_id: word.id)

      {:error, changeset} =
        %UserProgress{}
        |> UserProgress.changeset(%{user_id: user.id, word_id: word.id})
        |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "lesson_progress changeset validations" do
    import Medoru.AccountsFixtures
    import Medoru.ContentFixtures

    test "status must be valid enum value" do
      user = user_fixture()
      lesson = lesson_fixture()

      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: :invalid_status
      }

      changeset = LessonProgress.changeset(%LessonProgress{}, attrs)
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "progress_percentage must be between 0 and 100" do
      user = user_fixture()
      lesson = lesson_fixture()

      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        progress_percentage: 150
      }

      changeset = LessonProgress.changeset(%LessonProgress{}, attrs)
      assert "must be less than or equal to 100" in errors_on(changeset).progress_percentage
    end

    test "cannot create duplicate lesson progress for same user" do
      user = user_fixture()
      lesson = lesson_fixture()

      _first = lesson_progress_fixture(user_id: user.id, lesson_id: lesson.id)

      {:error, changeset} =
        %LessonProgress{}
        |> LessonProgress.changeset(%{user_id: user.id, lesson_id: lesson.id})
        |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
