defmodule MedoruWeb.GameLiveTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures

  alias Medoru.Repo
  alias MedoruWeb.GameLive

  defp set_display_name(user, name) do
    user.profile
    |> Medoru.Accounts.UserProfile.changeset(%{display_name: name})
    |> Repo.update!()
  end

  test "build_game_data/3 uses the profile display_name (nickname) when set" do
    user = user_fixture_with_registration(%{name: "OAuth Name"})
    set_display_name(user, "ShadowNeko")

    # force: true — the fixture user already has its profile association
    # loaded, and a plain preload would return the stale struct.
    data = GameLive.build_game_data(Repo.preload(user, :profile, force: true), %{"locale" => "en"})

    assert data.name == "ShadowNeko"
  end

  test "build_game_data/3 falls back to the OAuth name without a display_name" do
    user = user_fixture_with_registration(%{name: "OAuth Name"})

    data = GameLive.build_game_data(Repo.preload(user, :profile), %{"locale" => "en"})

    assert data.name == "OAuth Name"
  end
end
