#!/usr/bin/env elixir
# Backfills ALL badges for existing users based on their current stats.
# Safe to run multiple times — skips badges users already have.
#
# Usage on production (via release or local mix):
#   mix run bin/backfill_all_badges.exs
# Or inside a release container:
#   /app/bin/medoru eval 'Code.eval_file("bin/backfill_all_badges.exs")'
#
require Logger

alias Medoru.Repo
alias Medoru.Accounts
alias Medoru.Learning
alias Medoru.Gamification

# Ensure badges are seeded first
badge_count = Gamification.list_badges() |> length()

if badge_count == 0 do
  Logger.error("No badges found in database. Run 'mix run bin/seed_badges.exs' first.")
  System.halt(1)
end

Logger.info("Found #{badge_count} badges in database.")

users = Accounts.User |> Repo.all()

Logger.info("Backfilling badges for #{length(users)} users...")

total_awarded =
  Enum.reduce(users, 0, fn user, acc ->
    stats = Accounts.get_or_create_user_stats(user.id)

    # Use longest_streak for streak badges (represents max achievement)
    streak = stats.longest_streak || 0
    kanji_count = stats.total_kanji_learned || 0
    words_count = stats.total_words_learned || 0
    daily_reviews = stats.total_tests_completed || 0
    level = stats.level || 0

    # lessons_completed requires a separate query
    lessons_completed =
      try do
        Learning.get_user_stats(user.id).lessons_completed
      rescue
        _ -> 0
      end

    awarded =
      []
      |> Kernel.++(Gamification.check_level_badges(user.id, level))
      |> Kernel.++(Gamification.check_streak_badges(user.id, streak))
      |> Kernel.++(Gamification.check_kanji_badges(user.id, kanji_count))
      |> Kernel.++(Gamification.check_words_badges(user.id, words_count))
      |> Kernel.++(Gamification.check_lesson_badges(user.id, lessons_completed))
      |> Kernel.++(Gamification.check_daily_reviews_badges(user.id, daily_reviews))

    if length(awarded) > 0 do
      Logger.info("  User #{user.email || user.id}: awarded #{length(awarded)} badges")
    end

    acc + length(awarded)
  end)

IO.puts("")
IO.puts("✅ Badge backfill complete!")
IO.puts("   Total badges awarded: #{total_awarded}")
