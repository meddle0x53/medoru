defmodule MedoruWeb.ChatEmoticonsTest do
  use ExUnit.Case, async: true

  alias MedoruWeb.ChatEmoticons

  describe "replace/1" do
    test "converts basic smileys" do
      assert ChatEmoticons.replace(":)") == "😊"
      assert ChatEmoticons.replace(":(") == "😞"
      assert ChatEmoticons.replace(":D") == "😄"
      assert ChatEmoticons.replace(":P") == "😛"
      assert ChatEmoticons.replace(":p") == "😛"
    end

    test "converts nose smileys" do
      assert ChatEmoticons.replace(":-)") == "😊"
      assert ChatEmoticons.replace(":-(") == "😞"
      assert ChatEmoticons.replace(":-D") == "😄"
      assert ChatEmoticons.replace(":-P") == "😛"
      assert ChatEmoticons.replace(":-p") == "😛"
    end

    test "converts winky and special emoticons" do
      assert ChatEmoticons.replace(";)") == "😉"
      assert ChatEmoticons.replace(";-)") == "😉"
      assert ChatEmoticons.replace(":*") == "😘"
      assert ChatEmoticons.replace(":/") == "😕"
      assert ChatEmoticons.replace(":$") == "😳"
      assert ChatEmoticons.replace(":O") == "😮"
      assert ChatEmoticons.replace(":o") == "😮"
      assert ChatEmoticons.replace(":|") == "😐"
    end

    test "converts hearts and tears" do
      assert ChatEmoticons.replace("<3") == "❤️"
      assert ChatEmoticons.replace("</3") == "💔"
      assert ChatEmoticons.replace(":'-(") == "😢"
      assert ChatEmoticons.replace(":')") == "🥹"
      assert ChatEmoticons.replace(":'-)") == "😂"
    end

    test "converts cool and laugh emoticons" do
      assert ChatEmoticons.replace("B)") == "😎"
      assert ChatEmoticons.replace("8)") == "😎"
      assert ChatEmoticons.replace("XD") == "😆"
      assert ChatEmoticons.replace("xD") == "😆"
    end

    test "replaces multiple emoticons in text" do
      assert ChatEmoticons.replace("Hello :) How are you? :(") ==
               "Hello 😊 How are you? 😞"

      assert ChatEmoticons.replace("Thanks <3 You rock! B)") ==
               "Thanks ❤️ You rock! 😎"
    end

    test "handles mixed nose and plain smileys" do
      assert ChatEmoticons.replace(":-) and :)") == "😊 and 😊"
    end

    test "leaves normal text unchanged" do
      assert ChatEmoticons.replace("Hello world") == "Hello world"
      assert ChatEmoticons.replace("The cost is $5") == "The cost is $5"
      # Note: URLs are split out before emoticon replacement in actual rendering
      assert ChatEmoticons.replace("example.com") == "example.com"
    end

    test "handles nil" do
      assert ChatEmoticons.replace(nil) == nil
    end
  end
end
