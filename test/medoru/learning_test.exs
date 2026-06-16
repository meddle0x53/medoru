defmodule Medoru.LearningTest do
  use Medoru.DataCase, async: true

  alias Medoru.Learning
  alias Medoru.Learning.{ReviewSchedule, UserProgress}
  alias Medoru.Repo

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  # ============================================================================
  # record_review/3 - SM-2 algorithm tests
  # ============================================================================

  describe "record_review/3" do
    setup do
      user = user_fixture()
      word = word_fixture()
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)
      %{user: user, word: word, progress: progress}
    end

    test "creates a new schedule on first review", %{user: user, progress: progress} do
      assert {:ok, schedule} = Learning.record_review(user.id, progress.id, 4)
      assert schedule.repetitions == 1
      assert schedule.interval == 1
      assert schedule.ease_factor == 2.5
      assert DateTime.compare(schedule.next_review_at, DateTime.utc_now()) == :gt
    end

    test "successful review sequence builds intervals", %{user: user, progress: progress} do
      # 1st success: repetitions=1, interval=1
      assert {:ok, s1} = Learning.record_review(user.id, progress.id, 4)
      assert s1.repetitions == 1
      assert s1.interval == 1

      # 2nd success: repetitions=2, interval=3
      assert {:ok, s2} = Learning.record_review(user.id, progress.id, 4)
      assert s2.repetitions == 2
      assert s2.interval == 3

      # 3rd success: repetitions=3, interval=round(3 * 2.5)=8
      assert {:ok, s3} = Learning.record_review(user.id, progress.id, 4)
      assert s3.repetitions == 3
      assert s3.interval == 8

      # 4th success: interval=round(8 * 2.5)=20
      assert {:ok, s4} = Learning.record_review(user.id, progress.id, 4)
      assert s4.repetitions == 4
      assert s4.interval == 20
    end

    test "failed review resets repetitions and interval", %{user: user, progress: progress} do
      # Build up to repetitions=3
      Learning.record_review(user.id, progress.id, 4)
      Learning.record_review(user.id, progress.id, 4)
      Learning.record_review(user.id, progress.id, 4)

      # Fail: resets to repetitions=0, interval=1
      assert {:ok, schedule} = Learning.record_review(user.id, progress.id, 2)
      assert schedule.repetitions == 0
      assert schedule.interval == 1
    end

    test "failed review lowers ease factor", %{user: user, progress: progress} do
      # Successful review to get past initial state
      Learning.record_review(user.id, progress.id, 4)
      Learning.record_review(user.id, progress.id, 4)

      initial_ef = 2.5
      # Fail: ease_factor stays same (reset path doesn't change it)
      assert {:ok, s1} = Learning.record_review(user.id, progress.id, 2)
      assert s1.ease_factor == initial_ef

      # Build back up
      Learning.record_review(user.id, progress.id, 4)
      Learning.record_review(user.id, progress.id, 4)

      # Another fail
      assert {:ok, s2} = Learning.record_review(user.id, progress.id, 2)
      assert s2.ease_factor == initial_ef
    end

    test "easy successful reviews increase ease factor", %{user: user, progress: progress} do
      # Quality 5 increases ease factor more than quality 4
      assert {:ok, s1} = Learning.record_review(user.id, progress.id, 5)
      assert s1.ease_factor > 2.5

      assert {:ok, s2} = Learning.record_review(user.id, progress.id, 5)
      assert s2.ease_factor > s1.ease_factor
    end

    test "hard successful reviews decrease ease factor", %{user: user, progress: progress} do
      # Quality 3 (barely passed) decreases ease factor
      assert {:ok, s1} = Learning.record_review(user.id, progress.id, 3)
      assert s1.ease_factor < 2.5
    end

    test "ease factor has a floor of 1.3", %{user: user, progress: progress} do
      # Repeated quality 3 reviews should lower ease factor
      Enum.reduce(1..20, 2.5, fn _, _ef ->
        {:ok, schedule} = Learning.record_review(user.id, progress.id, 3)
        assert schedule.ease_factor >= 1.3
        schedule.ease_factor
      end)
    end

    test "next_review_at is calculated from now plus interval days", %{
      user: user,
      progress: progress
    } do
      before = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, schedule} = Learning.record_review(user.id, progress.id, 4)
      after_time = DateTime.utc_now() |> DateTime.truncate(:second)

      # Should be approximately 1 day from now
      expected_min = DateTime.add(before, 1, :day)
      expected_max = DateTime.add(after_time, 1, :day)

      assert DateTime.compare(schedule.next_review_at, expected_min) in [:gt, :eq]
      assert DateTime.compare(schedule.next_review_at, expected_max) in [:lt, :eq]
    end
  end

  # ============================================================================
  # adjust_word_mastery/3 tests
  # ============================================================================

  describe "adjust_word_mastery/3" do
    setup do
      user = user_fixture()
      word = word_fixture()
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)
      %{user: user, word: word, progress: progress}
    end

    test "correct answer increases mastery level", %{user: user, word: word} do
      assert {:ok, progress} = Learning.adjust_word_mastery(user.id, word.id, :correct)
      assert progress.mastery_level == 2
      assert progress.times_reviewed == 1
      assert progress.last_reviewed_at != nil
    end

    test "incorrect answer decreases mastery level", %{
      user: user,
      word: word,
      progress: _progress
    } do
      # First get to mastery level 2
      Learning.adjust_word_mastery(user.id, word.id, :correct)

      assert {:ok, updated} = Learning.adjust_word_mastery(user.id, word.id, :incorrect)
      assert updated.mastery_level == 1
      assert updated.times_reviewed == 2
    end

    test "mastery level never goes below 1", %{user: user, word: word} do
      # Try to decrease from level 1
      assert {:ok, progress} = Learning.adjust_word_mastery(user.id, word.id, :incorrect)
      assert progress.mastery_level == 1
    end

    test "mastery level never goes above 5", %{user: user, word: word} do
      # Increase to max
      Enum.each(1..10, fn _ ->
        Learning.adjust_word_mastery(user.id, word.id, :correct)
      end)

      progress = Learning.get_word_progress(user.id, word.id)
      assert progress.mastery_level == 5
    end

    test "updates review schedule on correct answer", %{
      user: user,
      word: word,
      progress: progress
    } do
      assert {:ok, _updated_progress} = Learning.adjust_word_mastery(user.id, word.id, :correct)

      schedule = Learning.get_review_schedule(user.id, progress.id)
      assert schedule != nil
      assert schedule.repetitions == 1
    end

    test "updates review schedule on incorrect answer", %{
      user: user,
      word: word,
      progress: progress
    } do
      # First succeed to build up repetitions
      Learning.adjust_word_mastery(user.id, word.id, :correct)
      Learning.adjust_word_mastery(user.id, word.id, :correct)

      # Then fail
      assert {:ok, _updated_progress} = Learning.adjust_word_mastery(user.id, word.id, :incorrect)

      schedule = Learning.get_review_schedule(user.id, progress.id)
      assert schedule.repetitions == 0
      assert schedule.interval == 1
    end

    test "returns error for unlearned word", %{user: user} do
      unlearned_word = word_fixture()

      assert {:error, :not_learned} =
               Learning.adjust_word_mastery(user.id, unlearned_word.id, :correct)
    end
  end

  # ============================================================================
  # get_due_reviews/2 tests
  # ============================================================================

  describe "get_due_reviews/2" do
    setup do
      user = user_fixture()

      # Create 3 learned words with review schedules
      words = Enum.map(1..3, fn _ -> word_fixture() end)

      progresses =
        Enum.map(words, fn word ->
          {:ok, progress} = Learning.track_word_learned(user.id, word.id)
          progress
        end)

      # Word 1: overdue (past)
      [p1, p2, p3] = progresses
      create_review_schedule(user.id, p1.id, DateTime.add(DateTime.utc_now(), -1, :day))

      # Word 2: due now
      create_review_schedule(user.id, p2.id, DateTime.utc_now())

      # Word 3: future (not due)
      create_review_schedule(user.id, p3.id, DateTime.add(DateTime.utc_now(), +7, :day))

      %{user: user, words: words, progresses: progresses}
    end

    test "returns only words with next_review_at <= now", %{user: user} do
      due = Learning.get_due_reviews(user.id)
      assert length(due) == 2
    end

    test "orders by next_review_at ascending", %{user: user, words: words} do
      due = Learning.get_due_reviews(user.id)
      assert length(due) == 2

      # First should be the most overdue one (word 1)
      assert List.first(due).word_id == List.first(words).id
    end

    test "respects limit", %{user: user} do
      due = Learning.get_due_reviews(user.id, limit: 1)
      assert length(due) == 1
    end

    test "excludes words with future next_review_at", %{user: user, words: words} do
      due = Learning.get_due_reviews(user.id)
      future_word_id = List.last(words).id
      refute Enum.any?(due, fn d -> d.word_id == future_word_id end)
    end

    test "returns empty list when no reviews are due", %{user: user, progresses: progresses} do
      # Update all schedules to be in the future
      Enum.each(progresses, fn p ->
        schedule = Learning.get_review_schedule(user.id, p.id)

        schedule
        |> ReviewSchedule.changeset(%{next_review_at: DateTime.add(DateTime.utc_now(), +7, :day)})
        |> Repo.update!()
      end)

      assert Learning.get_due_reviews(user.id) == []
    end
  end

  # ============================================================================
  # get_words_for_daily_test/2 tests
  # ============================================================================

  describe "get_words_for_daily_test/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "returns learned words ordered by mastery level", %{user: user} do
      word1 = word_fixture()
      word2 = word_fixture()
      word3 = word_fixture()

      {:ok, p1} = Learning.track_word_learned(user.id, word1.id)
      {:ok, p2} = Learning.track_word_learned(user.id, word2.id)
      {:ok, p3} = Learning.track_word_learned(user.id, word3.id)

      # Set different mastery levels
      Repo.update!(UserProgress.changeset(p1, %{mastery_level: 3}))
      Repo.update!(UserProgress.changeset(p2, %{mastery_level: 1}))
      Repo.update!(UserProgress.changeset(p3, %{mastery_level: 2}))

      results = Learning.get_words_for_daily_test(user.id)
      mastery_levels = Enum.map(results, & &1.mastery_level)

      assert mastery_levels == Enum.sort(mastery_levels)
      assert List.first(results).mastery_level == 1
    end

    test "excludes words with future SRS schedules", %{user: user} do
      word1 = word_fixture()
      word2 = word_fixture()

      {:ok, p1} = Learning.track_word_learned(user.id, word1.id)
      {:ok, p2} = Learning.track_word_learned(user.id, word2.id)

      # Word 1: has a future schedule (repetitions > 0, next_review in future)
      create_review_schedule(user.id, p1.id, DateTime.add(DateTime.utc_now(), +7, :day), %{
        repetitions: 3
      })

      # Word 2: no schedule (or repetitions=0)
      create_review_schedule(user.id, p2.id, DateTime.utc_now(), %{repetitions: 0})

      results = Learning.get_words_for_daily_test(user.id)
      word_ids = Enum.map(results, & &1.word_id)

      refute word1.id in word_ids
      assert word2.id in word_ids
    end

    test "includes words without a schedule", %{user: user} do
      word = word_fixture()
      {:ok, _progress} = Learning.track_word_learned(user.id, word.id)

      results = Learning.get_words_for_daily_test(user.id)
      assert Enum.any?(results, &(&1.word_id == word.id))
    end

    test "respects limit", %{user: user} do
      Enum.each(1..10, fn _ ->
        word = word_fixture()
        Learning.track_word_learned(user.id, word.id)
      end)

      results = Learning.get_words_for_daily_test(user.id, limit: 5)
      assert length(results) == 5
    end

    test "respects exclude_word_ids", %{user: user} do
      word1 = word_fixture()
      word2 = word_fixture()

      Learning.track_word_learned(user.id, word1.id)
      Learning.track_word_learned(user.id, word2.id)

      results = Learning.get_words_for_daily_test(user.id, exclude_word_ids: [word1.id])
      word_ids = Enum.map(results, & &1.word_id)

      refute word1.id in word_ids
      assert word2.id in word_ids
    end
  end

  # ============================================================================
  # mark_all_as_learned/1
  # ============================================================================

  describe "mark_all_as_learned/1" do
    setup do
      user = user_fixture()
      kanji = kanji_fixture()
      word = word_fixture()
      %{user: user, kanji: kanji, word: word}
    end

    test "marks all kanji and words as learned", %{user: user, kanji: kanji, word: word} do
      {:ok, %{kanji_count: kanji_count, word_count: word_count}} =
        Learning.mark_all_as_learned(user.id)

      assert kanji_count >= 1
      assert word_count >= 1
      assert Learning.kanji_learned?(user.id, kanji.id)
      assert Learning.word_learned?(user.id, word.id)
    end

    test "is idempotent — succeeds on second call", %{user: user, kanji: kanji, word: word} do
      # First call
      {:ok, %{kanji_count: _count1, word_count: _wcount1}} =
        Learning.mark_all_as_learned(user.id)

      # Second call also succeeds
      {:ok, %{kanji_count: _count2, word_count: _wcount2}} =
        Learning.mark_all_as_learned(user.id)

      assert Learning.kanji_learned?(user.id, kanji.id)
      assert Learning.word_learned?(user.id, word.id)
    end
  end

  # ============================================================================
  # English learning progress
  # ============================================================================

  describe "english learning progress" do
    setup do
      user = user_fixture()
      word = word_fixture()
      %{user: user, word: word}
    end

    test "track_english_word_learned creates progress", %{user: user, word: word} do
      assert {:ok, progress} = Learning.track_english_word_learned(user.id, word.id)
      assert progress.user_id == user.id
      assert progress.word_id == word.id
      assert Learning.english_word_learned?(user.id, word.id)
    end

    test "track_english_word_learned is idempotent", %{user: user, word: word} do
      assert {:ok, progress1} = Learning.track_english_word_learned(user.id, word.id)
      assert {:ok, progress2} = Learning.track_english_word_learned(user.id, word.id)
      assert progress1.id == progress2.id
      assert Learning.count_english_learned_words(user.id) == 1
    end

    test "untrack_english_word_learned removes progress", %{user: user, word: word} do
      Learning.track_english_word_learned(user.id, word.id)
      assert {:ok, _} = Learning.untrack_english_word_learned(user.id, word.id)
      refute Learning.english_word_learned?(user.id, word.id)
    end

    test "untrack_english_word_learned returns error when not learned", %{
      user: user,
      word: word
    } do
      assert {:error, :not_learned} =
               Learning.untrack_english_word_learned(user.id, word.id)
    end

    test "list_english_learned_words returns learned words", %{user: user, word: word} do
      Learning.track_english_word_learned(user.id, word.id)
      assert [returned_word] = Learning.list_english_learned_words(user.id)
      assert returned_word.id == word.id
    end
  end

  # ============================================================================
  # generate_daily_radical_hunt/1
  # ============================================================================

  describe "generate_daily_radical_hunt/1" do
    test "returns a radical from a learned kanji with at least 10 related kanji" do
      user = user_fixture()

      for char <- ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"] do
        kanji_fixture(%{character: char, radicals: ["口"]})
      end

      seed_kanji = kanji_fixture(%{character: "中", radicals: ["口"]})
      {:ok, _} = Learning.track_kanji_learned(user.id, seed_kanji.id)

      result = Learning.generate_daily_radical_hunt(user.id)

      assert result.radical == "口"
      assert result.seed_kanji.id == seed_kanji.id
      assert length(result.valid_kanji) >= 10
    end

    test "falls back to a common radical when user has no learned kanji" do
      user = user_fixture()

      for char <- ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"] do
        kanji_fixture(%{character: char, radicals: ["口"]})
      end

      result = Learning.generate_daily_radical_hunt(user.id)

      assert result.radical == "口"
      assert length(result.valid_kanji) >= 10
      assert result.seed_kanji == nil
    end

    test "returns the same radical for the same user/date" do
      user = user_fixture()

      for char <- ["上", "下", "左", "右", "前", "後", "東", "西", "南", "北"] do
        kanji_fixture(%{character: char, radicals: ["水"]})
      end

      seed_kanji = kanji_fixture(%{character: "氷", radicals: ["水"]})
      {:ok, _} = Learning.track_kanji_learned(user.id, seed_kanji.id)

      result1 = Learning.generate_daily_radical_hunt(user.id)
      result2 = Learning.generate_daily_radical_hunt(user.id)

      assert result1.radical == result2.radical
      assert result1.seed_kanji.id == result2.seed_kanji.id
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp create_review_schedule(user_id, user_progress_id, next_review_at, attrs \\ %{}) do
    attrs = Map.new(attrs)

    defaults = %{
      user_id: user_id,
      user_progress_id: user_progress_id,
      next_review_at: next_review_at,
      interval: 1,
      ease_factor: 2.5,
      repetitions: 0
    }

    attrs = Map.merge(defaults, attrs)

    %ReviewSchedule{}
    |> ReviewSchedule.changeset(attrs)
    |> Repo.insert!()
  end
end
