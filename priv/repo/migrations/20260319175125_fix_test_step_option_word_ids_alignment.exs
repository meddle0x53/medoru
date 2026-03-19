defmodule Medoru.Repo.Migrations.FixTestStepOptionWordIdsAlignment do
  @moduledoc """
  Fixes misaligned option_word_ids in test_steps.question_data.

  The bug: options and option_word_ids were shuffled independently, causing
  the word_id at index N to not correspond to the option at index N.

  The fix: Re-shuffle options and word_ids together as pairs to maintain alignment.
  """

  use Ecto.Migration

  def up do
    # Execute the fix in Elixir code
    # Placeholder to make Ecto happy
    execute "SELECT 1"

    # Run the actual fix after the migration transaction completes
    flush()

    fix_alignment()
  end

  def down do
    # Cannot reverse this migration
    IO.puts("WARNING: Cannot reverse option_word_ids alignment fix")
  end

  defp fix_alignment do
    alias Medoru.Repo
    alias Medoru.Tests.TestStep
    import Ecto.Query

    # Find all multichoice test steps that have option_word_ids
    steps_to_fix =
      TestStep
      |> where([ts], ts.question_type == ^:multichoice)
      |> where([ts], fragment("question_data -> 'option_word_ids' IS NOT NULL"))
      |> Repo.all()

    IO.puts("Found #{length(steps_to_fix)} test steps to fix")

    fixed_count =
      Enum.reduce(steps_to_fix, 0, fn step, count ->
        question_data = step.question_data || %{}
        options = question_data["options"] || []
        option_word_ids = question_data["option_word_ids"] || []

        # Skip if lengths don't match or are empty
        if length(options) == 0 or length(option_word_ids) == 0 or
             length(options) != length(option_word_ids) do
          count
        else
          # Create pairs and shuffle together to maintain alignment
          pairs = Enum.zip(options, option_word_ids) |> Enum.shuffle()
          {new_options, new_option_word_ids} = Enum.unzip(pairs)

          # Update the step with aligned data
          new_question_data =
            Map.merge(question_data, %{
              "options" => new_options,
              "option_word_ids" => new_option_word_ids
            })

          {:ok, _} =
            step
            |> Ecto.Changeset.change(question_data: new_question_data)
            |> Repo.update()

          count + 1
        end
      end)

    IO.puts("Fixed #{fixed_count} test steps")
  end
end
