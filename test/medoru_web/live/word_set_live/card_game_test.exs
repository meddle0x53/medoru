defmodule MedoruWeb.WordSetLive.CardGameTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Repo
  alias Medoru.Learning.WordSets

  defp set_with_game(conn, n \\ 4) do
    user = user_fixture()
    word_set = word_set_fixture(%{user_id: user.id})

    words =
      1..n
      |> Enum.map_reduce(word_set, fn i, set ->
        word = word_fixture(%{meaning: "meaning #{i}"})
        {:ok, updated_set} = WordSets.add_word_to_set(set, word.id)
        {word, updated_set}
      end)
      |> elem(0)

    word_set = Repo.get!(Medoru.Learning.WordSet, word_set.id)
    {:ok, game} = WordSets.create_card_game_for_set(word_set, user)

    %{conn: log_in_user(conn, user), user: user, word_set: word_set, words: words, game: game}
  end

  describe "mount" do
    test "owner can play and win the game", %{conn: conn} do
      %{conn: conn, word_set: word_set, words: words, game: game} = set_with_game(conn)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/cards")

      assert render(view) =~ word_set.name

      # Collect every pair.
      Enum.each(words, fn _word ->
        {pos1, pos2, text} = find_pair_positions(view, game)
        word = Enum.find(words, fn w -> w.text == text end)

        render_click(view, "flip_card", %{"position" => Integer.to_string(pos1)})
        render_click(view, "flip_card", %{"position" => Integer.to_string(pos2)})

        assert has_element?(view, "#meaning-input")
        render_submit(view, "submit_answer", %{"meaning" => word.meaning})
      end)

      html = render(view)
      assert html =~ "You Win!"
      assert html =~ "Back to Word Set"

      # Play again resets the board.
      render_click(view, "play_again")
      assert render(view) =~ "Attempts"
    end

    test "non-owner is redirected to the word sets page", %{conn: conn} do
      %{word_set: word_set} = set_with_game(conn)
      other = user_fixture()
      conn = log_in_user(build_conn(), other)

      {:error, {:live_redirect, %{to: "/words/sets", flash: flash}}} =
        live(conn, ~p"/words/sets/#{word_set.id}/cards")

      assert flash["error"] =~ "permission"
    end

    test "redirects with flash when no game exists", %{conn: conn} do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id})
      conn = log_in_user(conn, user)

      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/words/sets/#{word_set.id}/cards")

      assert to == ~p"/words/sets/#{word_set.id}"
      assert flash["error"] =~ "Create a game first"
    end
  end

  describe "show page card game card" do
    test "create button navigates to the game", %{conn: conn} do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id})

      1..4
      |> Enum.reduce(word_set, fn i, set ->
        word = word_fixture(%{meaning: "meaning #{i}"})
        {:ok, updated} = WordSets.add_word_to_set(set, word.id)
        updated
      end)

      word_set = Repo.get!(Medoru.Learning.WordSet, word_set.id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")
      assert render(view) =~ "Create Game"

      {:ok, _view, html} =
        view
        |> element("button", "Create Game")
        |> render_click()
        |> follow_redirect(conn, ~p"/words/sets/#{word_set.id}/cards")

      assert html =~ word_set.name
    end

    test "create shows an error when the set has fewer than 4 words", %{conn: conn} do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      view
      |> element("button", "Create Game")
      |> render_click()

      assert render(view) =~ "at least 4 words"
    end

    test "delete removes the game and shows the create button again", %{conn: conn} do
      %{conn: conn, word_set: word_set} = set_with_game(conn)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")
      assert render(view) =~ "Memory Game"

      view
      |> element("button", "Delete")
      |> render_click()

      html = render(view)
      assert html =~ "Memory game deleted"
      assert html =~ "Create Game"
      assert WordSets.get_card_game_for_set(word_set.id) == nil
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  # Finds two positions that hold the same word by flipping each card
  # individually (single flips never match and never cost an attempt).
  defp find_pair_positions(view, game) do
    positions =
      Enum.map(0..(length(game.words) * 2 - 1), fn pos ->
        html = render_click(view, "flip_card", %{"position" => Integer.to_string(pos)})
        text = extract_card_text(html, pos)
        send(view.pid, :close_unmatched)
        render(view)
        {pos, text}
      end)

    {pos1, pos2, _text} =
      positions
      |> Enum.reject(fn {_, text} -> is_nil(text) end)
      |> Enum.group_by(fn {_, text} -> text end)
      |> Enum.find_value(fn
        {text, [{p1, _}, {p2, _} | _]} -> {p1, p2, text}
        _ -> nil
      end) ||
        raise "could not find a matching pair"

    {pos1, pos2, _text}
  end

  defp extract_card_text(html, pos) do
    case Regex.run(
           ~r/phx-value-position="#{pos}"[^>]*>.*?<span[^>]*font-bold[^>]*>([^<]+)<\/span>/s,
           html
         ) do
      [_, text] -> String.trim(text)
      _ -> nil
    end
  end
end
