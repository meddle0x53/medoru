defmodule Medoru.Content.KanaRomajiTest do
  use ExUnit.Case, async: true

  alias Medoru.Content.KanaRomaji

  describe "to_romaji/1" do
    test "converts basic hiragana" do
      assert KanaRomaji.to_romaji("あいうえお") == "aiueo"
      assert KanaRomaji.to_romaji("かきくけこ") == "kakikukeko"
      assert KanaRomaji.to_romaji("さしすせそ") == "sashisuseso"
    end

    test "converts voiced and semi-voiced hiragana" do
      assert KanaRomaji.to_romaji("がぎぐげご") == "gagigugego"
      assert KanaRomaji.to_romaji("ぱぴぷぺぽ") == "papipupepo"
    end

    test "converts yoon digraphs" do
      assert KanaRomaji.to_romaji("きゃきゅきょ") == "kyakyukyo"
      assert KanaRomaji.to_romaji("しゃしゅしょ") == "shashusho"
      assert KanaRomaji.to_romaji("ちゃちゅちょ") == "chachucho"
      assert KanaRomaji.to_romaji("にゃにゅにょ") == "nyanyunyo"
    end

    test "handles the sokuon" do
      assert KanaRomaji.to_romaji("かった") == "katta"
      assert KanaRomaji.to_romaji("がっこう") == "gakkō"
      assert KanaRomaji.to_romaji("ざっし") == "zasshi"
      assert KanaRomaji.to_romaji("まっちゃ") == "matcha"
    end

    test "handles the prolonged sound mark" do
      assert KanaRomaji.to_romaji("コーヒー") == "kōhī"
      assert KanaRomaji.to_romaji("パーティー") == "pātī"
    end

    test "marks long vowels in hiragana" do
      assert KanaRomaji.to_romaji("とう") == "tō"
      assert KanaRomaji.to_romaji("せい") == "sē"
      assert KanaRomaji.to_romaji("おおきい") == "ōkī"
      assert KanaRomaji.to_romaji("きょう") == "kyō"
    end

    test "converts katakana" do
      assert KanaRomaji.to_romaji("テスト") == "tesuto"
      assert KanaRomaji.to_romaji("ハンバーガー") == "hanbāgā"
    end

    test "handles extended katakana combinations" do
      assert KanaRomaji.to_romaji("ティッシュ") == "tisshu"
      assert KanaRomaji.to_romaji("ファミリー") == "famirī"
    end

    test "handles multiple readings separated by slash" do
      assert KanaRomaji.to_romaji("よん/し") == "yon / shi"
    end

    test "returns empty string for empty or nil input" do
      assert KanaRomaji.to_romaji("") == ""
      assert KanaRomaji.to_romaji(nil) == ""
    end
  end
end
