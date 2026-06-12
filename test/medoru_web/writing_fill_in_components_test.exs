defmodule MedoruWeb.WritingFillInComponentsTest do
  use ExUnit.Case, async: true

  alias MedoruWeb.WritingFillInComponents

  describe "build_filled_sentence/2" do
    test "fills a single blank" do
      template = "あなたは___ですか。"
      answers = %{"0" => "学生"}

      assert WritingFillInComponents.build_filled_sentence(template, answers) ==
               "あなたは学生ですか。"
    end

    test "fills multiple blanks" do
      template = "___は___です。"
      answers = %{"0" => "私", "1" => "学生"}

      assert WritingFillInComponents.build_filled_sentence(template, answers) ==
               "私は学生です。"
    end

    test "leaves missing blanks empty" do
      template = "あなたは___ですか。"
      answers = %{}

      assert WritingFillInComponents.build_filled_sentence(template, answers) ==
               "あなたはですか。"
    end

    test "returns empty string for non-map answers" do
      assert WritingFillInComponents.build_filled_sentence("template", nil) == ""
    end
  end
end
