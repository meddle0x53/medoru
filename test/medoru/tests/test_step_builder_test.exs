defmodule Medoru.Tests.TestStepBuilderTest do
  use ExUnit.Case, async: true

  alias Medoru.Tests.TestStepBuilder

  defp word(id, text, reading) do
    %{id: id, text: text, reading: reading, meaning: "meaning #{id}"}
  end

  defp pool do
    for i <- 1..6, do: word("w#{i}", "text#{i}", "reading#{i}")
  end

  describe "add_distractors/5" do
    test "default behavior uses raw field values" do
      correct = word("w0", "text0", "reading0")
      step = %{correct_answer: "text0", question_data: %{}}

      step = TestStepBuilder.add_distractors(step, correct, 2, pool(), field: :text)

      assert length(step.options) == 3
      assert "text0" in step.options
      assert Enum.all?(step.options, &(&1 in ["text0" | Enum.map(pool(), fn w -> w.text end)]))

      assert step.question_data.option_word_ids
             |> Enum.zip(step.options)
             |> Enum.all?(fn
               {"w0", "text0"} -> true
               {nil, _} -> true
               _ -> false
             end)
    end

    test "format_option formats distractor options while correct answer stays pre-formatted" do
      correct = word("w0", "text0", "reading0")
      format = fn w -> "#{w.text} / #{w.reading}" end
      step = %{correct_answer: format.(correct), question_data: %{}}

      step =
        TestStepBuilder.add_distractors(step, correct, 2, pool(),
          field: :text,
          format_option: format
        )

      assert length(step.options) == 3

      assert Enum.all?(step.options, fn option ->
               [t, r] = String.split(option, " / ")

               t in ["text0" | Enum.map(pool(), & &1.text)] and
                 r in ["reading0" | Enum.map(pool(), & &1.reading)]
             end)

      correct_index = Enum.find_index(step.options, &(&1 == step.correct_answer))
      assert correct_index != nil
      assert Enum.at(step.question_data.option_word_ids, correct_index) == "w0"

      Enum.with_index(step.question_data.option_word_ids, fn wid, i ->
        if wid != "w0", do: assert(Enum.at(step.question_data.option_word_ids, i) == nil)
      end)
    end

    test "format_option also filters distractors equal to the pre-formatted correct answer" do
      correct = word("w0", "text0", "reading0")
      format = fn w -> "#{w.text} / #{w.reading}" end
      # Duplicate of the correct word in the pool (different id, same text/reading)
      duplicate = word("w9", "text0", "reading0")
      step = %{correct_answer: format.(correct), question_data: %{}}

      step =
        TestStepBuilder.add_distractors(step, correct, 2, [duplicate | pool()],
          field: :text,
          format_option: format
        )

      assert Enum.count(step.options, &(&1 == step.correct_answer)) == 1
    end
  end
end
