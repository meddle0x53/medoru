defmodule Medoru.Accounts.UserProfileTest do
  use Medoru.DataCase

  alias Medoru.Accounts.UserProfile

  describe "locale" do
    test "changeset accepts valid locales" do
      for locale <- ["en", "bg", "ja"] do
        changeset = UserProfile.changeset(%UserProfile{}, %{locale: locale})
        assert changeset.valid?, "expected locale #{locale} to be valid"
      end
    end

    test "changeset rejects invalid locale" do
      changeset = UserProfile.changeset(%UserProfile{}, %{locale: "fr"})
      refute changeset.valid?
      assert %{locale: ["is invalid"]} = errors_on(changeset)
    end

    test "default locale is en" do
      profile = %UserProfile{}
      assert profile.locale == "en"

      changeset = UserProfile.changeset(profile, %{})
      assert Ecto.Changeset.get_field(changeset, :locale) == "en"
    end
  end
end
