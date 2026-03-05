defmodule Medoru.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Accounts` context.
  """

  alias Medoru.Accounts

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  @doc """
  Generate a unique provider_uid.
  """
  def unique_provider_uid, do: "#{System.unique_integer()}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        provider: "google",
        provider_uid: unique_provider_uid(),
        name: "Test User",
        avatar_url: "https://example.com/avatar.jpg"
      })
      |> Accounts.create_user()

    user
  end

  @doc """
  Generate a user with profile and stats (full registration).
  """
  def user_fixture_with_registration(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: unique_user_email(),
        provider: "google",
        provider_uid: unique_provider_uid(),
        name: "Test User",
        avatar_url: "https://example.com/avatar.jpg"
      })
      |> Accounts.register_user_with_oauth()

    user
  end

  @doc """
  Generate a user with profile.
  """
  def user_fixture_with_profile(attrs \\ %{}) do
    user_fixture_with_registration(attrs)
  end

  @doc """
  Generate a user with stats.
  """
  def user_fixture_with_stats(attrs \\ %{}) do
    user_fixture_with_registration(attrs)
  end

  @doc """
  Generate profile attributes.
  """
  def profile_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      display_name: "Test Display Name",
      avatar: "https://example.com/custom-avatar.jpg",
      timezone: "UTC",
      daily_goal: 10,
      theme: "light"
    })
  end

  @doc """
  Generate stats attributes.
  """
  def stats_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      total_kanji_learned: 0,
      total_words_learned: 0,
      current_streak: 0,
      longest_streak: 0,
      total_tests_completed: 0,
      total_duels_played: 0,
      total_duels_won: 0,
      xp: 0,
      level: 1
    })
  end
end
