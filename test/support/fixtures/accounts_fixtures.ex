defmodule Medoru.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Accounts` context.
  """

  alias Medoru.Accounts

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a unique provider_uid.
  """
  def unique_provider_uid, do: "#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    # Ensure unique identifiers to avoid deadlocks in parallel tests
    unique_suffix = "_#{System.unique_integer([:positive])}"
    
    email = 
      case attrs[:email] || attrs["email"] do
        nil -> unique_user_email()
        e -> "#{e}#{unique_suffix}"
      end

    provider_uid = 
      case attrs[:provider_uid] || attrs["provider_uid"] do
        nil -> unique_provider_uid()
        uid -> "#{uid}#{unique_suffix}"
      end

    attrs = 
      attrs
      |> Map.drop([:email, :provider_uid, "email", "provider_uid"])
      |> Enum.into(%{
        email: email,
        provider: "google",
        provider_uid: provider_uid,
        name: "Test User",
        avatar_url: "https://example.com/avatar.jpg"
      })

    {:ok, user} = Accounts.create_user(attrs)
    user
  end

  @doc """
  Generate a user with profile and stats (full registration).
  """
  def user_fixture_with_registration(attrs \\ %{}) do
    # Ensure unique identifiers to avoid deadlocks in parallel tests
    unique_suffix = "_#{System.unique_integer([:positive])}"
    
    email = 
      case attrs[:email] || attrs["email"] do
        nil -> unique_user_email()
        e -> "#{e}#{unique_suffix}"
      end

    provider_uid = 
      case attrs[:provider_uid] || attrs["provider_uid"] do
        nil -> unique_provider_uid()
        uid -> "#{uid}#{unique_suffix}"
      end

    attrs = 
      attrs
      |> Map.drop([:email, :provider_uid, "email", "provider_uid"])
      |> Enum.into(%{
        email: email,
        provider: "google",
        provider_uid: provider_uid,
        name: "Test User",
        avatar_url: "https://example.com/avatar.jpg"
      })

    {:ok, user} = Accounts.register_user_with_oauth(attrs)
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
