defmodule MedoruWeb.GamesLive.IndexTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Classrooms
  alias Medoru.Games
  alias Medoru.Repo

  describe "Games index" do
    setup do
      user = user_fixture(%{type: "student"})
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      # Auto-approved since should_approve_memberships is false
      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, user.id)

      # Create and publish a game
      words = for _i <- 1..8, do: Medoru.ContentFixtures.word_fixture()

      {:ok, game} =
        Games.create_memory_card_game(
          classroom.id,
          teacher.id,
          %{"name" => "Test Game", "memory_card_game" => %{"board_size" => "4x4", "max_attempts" => 20}},
          Enum.map(words, &{&1.id, 10})
        )

      {:ok, _game} = Games.publish_game(game.id, teacher.id)

      %{user: user, teacher: teacher, classroom: classroom, game: game}
    end

    test "shows games from classrooms the user is a member of", %{
      conn: conn,
      user: user,
      classroom: classroom,
      game: game
    } do
      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/games")

      assert html =~ "Games"
      assert html =~ classroom.name
      assert html =~ game.name
    end

    test "shows empty state when no games available", %{conn: conn, user: user} do
      # Delete all games
      Repo.delete_all(Games.Game)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/games")

      assert html =~ "No games available"
    end

    test "teacher sees games from their own classrooms", %{
      conn: conn,
      teacher: teacher,
      classroom: classroom,
      game: game
    } do
      {:ok, _view, html} = conn |> log_in_user(teacher) |> live(~p"/games")

      assert html =~ "Games"
      assert html =~ classroom.name
      assert html =~ game.name
    end
  end
end
