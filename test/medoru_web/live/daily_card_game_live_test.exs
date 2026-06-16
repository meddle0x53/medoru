defmodule MedoruWeb.DailyCardGameLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Accounts

  describe "default mode (learning_language is not english)" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      words =
        Enum.map(1..10, fn i ->
          word =
            word_fixture(%{
              meaning: "word meaning #{i}",
              reading: "てすと/テスト"
            })

          user_progress_fixture(%{user_id: user.id, word_id: word.id})
          word
        end)

      %{conn: conn, user: user, words: words}
    end

    test "shows Japanese text and reading on flipped cards and asks for meaning", %{
      conn: conn,
      words: words
    } do
      {:ok, view, _html} = live(conn, ~p"/daily-challenges/cards")

      {pos1, pos2, word} = find_matching_pair(view, words, :text)

      render_click(view, "flip_card", %{"position" => Integer.to_string(pos1)})
      render_click(view, "flip_card", %{"position" => Integer.to_string(pos2)})

      assert has_element?(view, "#meaning-input")
      html = render(view)
      assert html =~ "Type the meaning..."
      assert html =~ word.text

      submit_answer(view, word.meaning)

      assert render(view) =~ "1 / 10"
      refute has_element?(view, "#meaning-input")
    end
  end

  describe "english mode" do
    setup %{conn: conn} do
      user = user_fixture()
      {:ok, user} = Accounts.update_learning_language(user, %{"learning_language" => "english"})
      conn = log_in_user(conn, user)

      words =
        Enum.map(1..10, fn i ->
          word =
            word_fixture(%{
              meaning: "word meaning #{i}",
              reading: "てすと/テスト"
            })

          user_progress_fixture(%{user_id: user.id, word_id: word.id})
          word
        end)

      %{conn: conn, user: user, words: words}
    end

    test "shows English meaning on flipped cards and asks for Japanese word or reading", %{
      conn: conn,
      words: words
    } do
      {:ok, view, _html} = live(conn, ~p"/daily-challenges/cards")

      {pos1, pos2, word} = find_matching_pair(view, words, :meaning)

      # Open the matching pair to bring up the input modal.
      render_click(view, "flip_card", %{"position" => Integer.to_string(pos1)})
      render_click(view, "flip_card", %{"position" => Integer.to_string(pos2)})

      assert has_element?(view, "#meaning-input")
      html = render(view)
      assert html =~ "Type the word or reading..."
      assert html =~ word.meaning
      refute html =~ word.text

      [first_reading | _] = String.split(word.reading, "/")
      submit_answer(view, first_reading)

      assert render(view) =~ "1 / 10"
      refute has_element?(view, "#meaning-input")
    end

    test "accepts the Japanese word itself as an answer", %{conn: conn, words: words} do
      {:ok, view, _html} = live(conn, ~p"/daily-challenges/cards")

      {pos1, pos2, word} = find_matching_pair(view, words, :meaning)

      render_click(view, "flip_card", %{"position" => Integer.to_string(pos1)})
      render_click(view, "flip_card", %{"position" => Integer.to_string(pos2)})

      submit_answer(view, word.text)

      assert render(view) =~ "1 / 10"
      refute has_element?(view, "#meaning-input")
    end

    test "rejects an English meaning answer in english mode", %{conn: conn, words: words} do
      {:ok, view, _html} = live(conn, ~p"/daily-challenges/cards")

      {pos1, pos2, word} = find_matching_pair(view, words, :meaning)

      render_click(view, "flip_card", %{"position" => Integer.to_string(pos1)})
      render_click(view, "flip_card", %{"position" => Integer.to_string(pos2)})

      submit_answer(view, word.meaning)

      assert render(view) =~ "Wrong meaning"
      assert has_element?(view, "#meaning-input")
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp find_matching_pair(view, words, mode) do
    # Flip each card individually to build a map of position -> displayed text.
    positions =
      Enum.map(0..19, fn pos ->
        html = render_click(view, "flip_card", %{"position" => Integer.to_string(pos)})
        text = extract_card_text(html, pos)
        send(view.pid, :close_unmatched)
        render(view)
        {pos, text}
      end)

    {pos1, pos2, displayed} =
      positions
      |> Enum.group_by(fn {_, text} -> text end)
      |> Enum.find_value(fn
        {_text, [{p1, t}, {p2, _} | _]} -> {p1, p2, t}
        _ -> nil
      end)

    assert pos1, "could not find a matching pair in the shuffled cards"

    word =
      case mode do
        :text -> Enum.find(words, fn w -> w.text == displayed end)
        :meaning -> Enum.find(words, fn w -> w.meaning == displayed end)
      end

    {pos1, pos2, word}
  end

  defp extract_card_text(html, pos) do
    case Regex.run(
           ~r/phx-value-position="#{pos}"[^>]*>.*?<span[^>]*font-bold[^>]*>([^<]+)<\/span>/s,
           html
         ) do
      [_, text] -> String.trim(text)
      _ -> "?"
    end
  end

  defp submit_answer(view, answer) do
    render_submit(view, "submit_answer", %{"meaning" => answer})
  end
end
