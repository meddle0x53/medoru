# =============================================================================
# QA Environment Seeds
# =============================================================================
# This script seeds the QA database with test users and data.
# Run with: MIX_ENV=qa mix run priv/repo/qa_seeds.exs
# =============================================================================

import Ecto.Query

alias Medoru.Repo
alias Medoru.Accounts
alias Medoru.Accounts.{User, UserProfile, UserStats}
alias Medoru.Content
alias Medoru.Learning

# =============================================================================
# Test Users Configuration
# =============================================================================

test_users = [
  # Admin users (using google provider with unique QA UIDs)
  %{
    email: "admin@qa.test",
    name: "QA Admin",
    type: "admin",
    provider: "google",
    provider_uid: "qa_google_admin_001"
  },
  %{
    email: "admin2@qa.test",
    name: "Second Admin",
    type: "admin",
    provider: "google",
    provider_uid: "qa_google_admin_002"
  },

  # Moderator user
  %{
    email: "moderator@qa.test",
    name: "QA Moderator",
    type: "student",
    moderator: true,
    provider: "google",
    provider_uid: "qa_google_moderator_001"
  },

  # Teacher users
  %{
    email: "teacher@qa.test",
    name: "QA Teacher",
    type: "teacher",
    provider: "google",
    provider_uid: "qa_google_teacher_001"
  },
  %{
    email: "teacher2@qa.test",
    name: "Second Teacher",
    type: "teacher",
    provider: "google",
    provider_uid: "qa_google_teacher_002"
  },
  %{
    email: "teachernoclasses@qa.test",
    name: "Teacher No Classes",
    type: "teacher",
    provider: "google",
    provider_uid: "qa_google_teacher_003"
  },

  # Student users - various levels
  %{
    email: "student@qa.test",
    name: "QA Student",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_student_001"
  },
  %{
    email: "student2@qa.test",
    name: "Second Student",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_student_002"
  },
  %{
    email: "studentnew@qa.test",
    name: "New Student",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_student_003"
  },
  %{
    email: "studentadvanced@qa.test",
    name: "Advanced Student",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_student_004"
  },
  %{
    email: "studentinactive@qa.test",
    name: "Inactive Student",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_student_005"
  },

  # Students for classroom testing
  %{
    email: "classroom.student1@qa.test",
    name: "Classroom Student 1",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_classroom_001"
  },
  %{
    email: "classroom.student2@qa.test",
    name: "Classroom Student 2",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_classroom_002"
  },
  %{
    email: "classroom.student3@qa.test",
    name: "Classroom Student 3",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_classroom_003"
  },
  %{
    email: "classroom.student4@qa.test",
    name: "Classroom Student 4",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_classroom_004"
  },
  %{
    email: "classroom.student5@qa.test",
    name: "Classroom Student 5",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_classroom_005"
  },

  # Edge case users
  %{
    email: "user.longname@qa.test",
    name: "User With A Very Long Name That Might Cause UI Issues",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_edge_001"
  },
  %{
    email: "user.special+chars@qa.test",
    name: "Special Chars User",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_edge_002"
  },
  %{
    email: "user.unicode@qa.test",
    name: "ユーザー テスト",
    type: "student",
    provider: "google",
    provider_uid: "qa_google_edge_003"
  }
]

# =============================================================================
# Helper Functions (using anonymous functions since .exs files can't have defp)
# =============================================================================

create_or_update_user = fn user_attrs ->
  case Accounts.get_user_by_email(user_attrs.email) do
    nil ->
      # Create new user with profile and stats
      Repo.transaction(fn ->
        with {:ok, user} <- Accounts.create_user(user_attrs),
             {:ok, _profile} <- Accounts.create_user_profile(user, %{display_name: user_attrs.name}),
             {:ok, _stats} <- Accounts.create_user_stats(user) do
          user
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)

    existing_user ->
      # Update existing user to ensure correct type and moderator flag
      Accounts.update_user_type(existing_user, user_attrs.type)
      if user_attrs[:moderator] != nil do
        Accounts.update_user_moderator(existing_user, user_attrs.moderator)
      end
      {:ok, existing_user}
  end
end

seed_lesson_progress = fn user, count ->
  # Get random lessons and create progress
  lessons = Content.list_lessons() |> Enum.take(count)

  Enum.each(lessons, fn lesson ->
    Learning.start_lesson(user.id, lesson.id)
    Learning.complete_lesson(user.id, lesson.id)
  end)
end

seed_daily_streak = fn user, days ->
  # Update user stats with streak
  stats = Accounts.get_stats_by_user!(user.id)

  Accounts.update_stats(stats, %{
    current_streak: days,
    longest_streak: days,
    last_study_date: Date.utc_today()
  })
end

seed_xp_and_level = fn user, xp ->
  Accounts.add_xp(user, xp)
end

# =============================================================================
# Main Seeding
# =============================================================================

IO.puts("""
╔══════════════════════════════════════════════════════════════╗
║               QA Environment Database Seeder                  ║
╚══════════════════════════════════════════════════════════════╝
""")

# Verify we're in QA environment
if Application.get_env(:medoru, :env) != :qa do
  IO.puts("⚠️  Warning: Not in QA environment. Current env: #{Application.get_env(:medoru, :env)}")
  IO.puts("Please run with: MIX_ENV=qa mix run priv/repo/qa_seeds.exs")
  System.halt(1)
end

IO.puts("🌱 Seeding #{length(test_users)} test users...")

# Create all test users
Enum.each(test_users, fn user_attrs ->
  case create_or_update_user.(user_attrs) do
    {:ok, user} ->
      IO.puts("  ✅ #{user.email} (#{user.type})")

    {:error, changeset} ->
      IO.puts("  ❌ Failed to create #{user_attrs.email}")
      IO.inspect(changeset.errors, label: "Errors")
  end
end)

# Add specific data patterns for certain users
IO.puts("\n📊 Setting up user data patterns...")

# Advanced student - has progress and streak
with user <- Accounts.get_user_by_email("studentadvanced@qa.test") do
  seed_lesson_progress.(user, 50)
  seed_daily_streak.(user, 15)
  seed_xp_and_level.(user, 2500)
  IO.puts("  ✅ Advanced student: 50 lessons, 15-day streak, level 6")
end

# New student - minimal progress
with user <- Accounts.get_user_by_email("studentnew@qa.test") do
  seed_lesson_progress.(user, 3)
  IO.puts("  ✅ New student: 3 lessons completed")
end

# Inactive student - broken streak
with user <- Accounts.get_user_by_email("studentinactive@qa.test") do
  stats = Accounts.get_stats_by_user!(user.id)

  Accounts.update_stats(stats, %{
    current_streak: 0,
    longest_streak: 30,
    last_study_date: Date.add(Date.utc_today(), -5)
  })

  IO.puts("  ✅ Inactive student: 30-day best streak, inactive 5 days")
end

# Seed a few basic words for lesson/testing purposes
words_to_seed = [
  %{text: "日本", reading: "にほん", meaning: "Japan", difficulty: 5, word_type: :noun},
  %{text: "本", reading: "ほん", meaning: "book", difficulty: 5, word_type: :noun},
  %{text: "日", reading: "ひ", meaning: "day, sun", difficulty: 5, word_type: :noun}
]

Enum.each(words_to_seed, fn word_attrs ->
  case Content.create_word(word_attrs) do
    {:ok, _word} -> :ok
    {:error, %{errors: [text: {"has already been taken", _}]}} -> :ok
    {:error, changeset} ->
      IO.puts("  ⚠️  Failed to seed word #{word_attrs.text}")
      IO.inspect(changeset.errors)
  end
end)

IO.puts("  ✅ Seeded #{length(words_to_seed)} basic words for testing")

IO.puts("""

✅ QA database seeding complete!

📋 Available Test Users:

   Admins:
   • admin@qa.test
   • admin2@qa.test

   Moderators:
   • moderator@qa.test

   Teachers:
   • teacher@qa.test
   • teacher2@qa.test
   • teachernoclasses@qa.test

   Students:
   • student@qa.test (regular)
   • student2@qa.test
   • studentnew@qa.test (new, 3 lessons)
   • studentadvanced@qa.test (50 lessons, 15-day streak)
   • studentinactive@qa.test (inactive, broken streak)

   Classroom Students:
   • classroom.student1@qa.test through classroom.student5@qa.test

   Edge Cases:
   • user.longname@qa.test (long name)
   • user.special+chars@qa.test (special characters)
   • user.unicode@qa.test (unicode name)

🚀 Start the QA server:
   MIX_ENV=qa mix phx.server

🧪 Access QA bypass login:
   http://localhost:4001/qa/bypass
""")
