defmodule Medoru.Repo.Migrations.FixTestStepOptionWordIdsAlignment do
  @moduledoc """
  Fixes misaligned option_word_ids in test_steps.question_data.

  The bug: options and option_word_ids were shuffled independently, causing
  the word_id at index N to not correspond to the option at index N.

  The fix: Re-shuffle options and word_ids together as pairs to maintain alignment.
  """

  use Ecto.Migration

  def up do
    execute "SELECT 1"
    flush()
    fix_alignment()
  end

  def down do
    IO.puts("WARNING: Cannot reverse option_word_ids alignment fix")
  end

  defp fix_alignment do
    alias Medoru.Repo

    {:ok, result} =
      Repo.query("""
      SELECT id, question_data
      FROM test_steps
      WHERE question_type = 'multichoice'
        AND question_data -> 'option_word_ids' IS NOT NULL
      """)

    steps_to_fix = result.rows
    IO.puts("Found #{length(steps_to_fix)} test steps to fix")

    fixed_count =
      Enum.reduce(steps_to_fix, 0, fn [id, question_data_json], count ->
        question_data =
          case Jason.decode(question_data_json) do
            {:ok, map} -> map
            _ -> %{}
          end

        options = question_data["options"] || []
        option_word_ids = question_data["option_word_ids"] || []

        if length(options) == 0 or length(option_word_ids) == 0 or
             length(options) != length(option_word_ids) do
          count
        else
          pairs = Enum.zip(options, option_word_ids) |> Enum.shuffle()
          {new_options, new_option_word_ids} = Enum.unzip(pairs)

          new_question_data =
            Map.merge(question_data, %{
              "options" => new_options,
              "option_word_ids" => new_option_word_ids
            })

          {:ok, _} =
            Repo.query(
              "UPDATE test_steps SET question_data = $1::jsonb WHERE id = $2",
              [Jason.encode!(new_question_data), id]
            )

          count + 1
        end
      end)

    IO.puts("Fixed #{fixed_count} test steps")
  end
end
