defmodule Medoru.Content.MatureContent do
  @moduledoc """
  Helpers for deciding whether mature content should be visible to a viewer.
  """

  alias Medoru.Accounts.User

  @doc """
  Returns true if a word is visible to the given viewer.
  Non-mature words are always visible. Mature words are hidden from anonymous
  users, users without an age, users under 18, and users with safety mode on.
  """
  def mature_word_visible_to_user?(%{mature: true}, nil), do: false

  def mature_word_visible_to_user?(%{mature: true}, %User{} = user) do
    not viewer_restricted_from_mature?(user)
  end

  def mature_word_visible_to_user?(_word, _viewer), do: true

  @doc """
  Returns true if the viewer should not see mature content.
  """
  def viewer_restricted_from_mature?(nil), do: true

  def viewer_restricted_from_mature?(%User{profile: %Ecto.Association.NotLoaded{}}), do: true

  def viewer_restricted_from_mature?(%User{profile: nil}), do: true

  def viewer_restricted_from_mature?(%User{profile: profile}) do
    is_nil(profile.age) or
      profile.age < 18 or
      profile.safety != false
  end
end
