defmodule Medoru.Content.BulgarianKatakanaTest do
  use ExUnit.Case, async: true

  alias Medoru.Content.BulgarianKatakana

  describe "list_letters/0" do
    test "returns all 30 Bulgarian letters" do
      letters = BulgarianKatakana.list_letters()
      assert length(letters) == 30

      expected =
        ~w(А Б В Г Д Е Ж З И Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ъ Ь Ю Я)

      assert Enum.map(letters, & &1.letter) == expected
    end

    test "every letter has a katakana, hiragana and latin reading" do
      for letter <- BulgarianKatakana.list_letters() do
        assert is_binary(letter.katakana) and letter.katakana != ""
        assert is_binary(letter.hiragana) and letter.hiragana != ""
        assert is_binary(letter.latin) and letter.latin != ""
      end
    end

    test "every letter has exactly 5 example words" do
      for letter <- BulgarianKatakana.list_letters() do
        assert length(letter.words) == 5

        for word <- letter.words do
          assert is_binary(word.bulgarian) and word.bulgarian != ""
          assert is_binary(word.katakana) and word.katakana != ""
          assert is_binary(word.meaning) and word.meaning != ""
        end
      end
    end
  end

  describe "get_by_letter/1" do
    test "finds a letter by uppercase Cyrillic character" do
      assert %{letter: "Б", katakana: "ブ"} = BulgarianKatakana.get_by_letter("Б")
    end

    test "finds a letter by lowercase Cyrillic character" do
      assert %{letter: "Я", katakana: "ヤ"} = BulgarianKatakana.get_by_letter("я")
    end

    test "returns nil for unknown characters" do
      assert BulgarianKatakana.get_by_letter("X") == nil
      assert BulgarianKatakana.get_by_letter("a") == nil
    end
  end

  describe "letter?/1" do
    test "returns true for Bulgarian letters" do
      assert BulgarianKatakana.letter?("М")
      assert BulgarianKatakana.letter?("м")
    end

    test "returns false for non-Bulgarian characters" do
      refute BulgarianKatakana.letter?("A")
      refute BulgarianKatakana.letter?("1")
    end
  end
end
