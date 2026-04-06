# Test script to check validator performance against medoru_dev DB
import Ecto.Query

alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

# Pattern: [Verb-て-form][Expression-optional][Verb-て-form-optional][Expression-optional][Verb]
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "expression", "optional" => true},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"], "optional" => true},
  %{"type" => "word_slot", "word_type" => "expression", "optional" => true},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => []}
]

sentence = "神戸へ行って、映画を見て、お茶を飲みました。"

IO.puts("=" |> String.duplicate(60))
IO.puts("Testing against medoru_dev database")
IO.puts("=" |> String.duplicate(60))
IO.puts("Sentence: #{sentence}")
IO.puts("Sentence length: #{String.length(sentence)} chars")
IO.puts("Pattern has #{length(pattern)} elements")
IO.puts("")

# First, warm the cache for verbs and expressions
IO.puts("Warming cache for verb type...")
{time, cache_result} = :timer.tc(fn -> ValidatorCache.warm_cache("verb") end)
IO.puts("  Cache warm took #{time / 1000}ms - #{inspect(cache_result)}")

IO.puts("Warming cache for expression type...")
{time, cache_result} = :timer.tc(fn -> ValidatorCache.warm_cache("expression") end)
IO.puts("  Cache warm took #{time / 1000}ms - #{inspect(cache_result)}")

IO.puts("Warming cache for noun type...")
{time, cache_result} = :timer.tc(fn -> ValidatorCache.warm_cache("noun") end)
IO.puts("  Cache warm took #{time / 1000}ms - #{inspect(cache_result)}")

IO.puts("")
IO.puts("Starting validation with 10 second timeout...")
IO.puts("-" |> String.duplicate(60))

task =
  Task.async(fn ->
    {time, result} =
      :timer.tc(fn ->
        Validator.validate_with_details(sentence, pattern)
      end)

    {time, result}
  end)

case Task.yield(task, 10_000) do
  nil ->
    IO.puts("❌ TIMEOUT after 10 seconds!")
    IO.puts("The validator is hanging - likely due to exponential backtracking")
    Task.shutdown(task)
    System.halt(1)

  {:ok, {time_us, result}} ->
    time_ms = time_us / 1000
    IO.puts("✅ Completed in #{time_ms}ms")
    IO.puts("")
    IO.puts("Result.valid: #{result.valid}")

    if result.valid do
      IO.puts("Breakdown:")

      Enum.each(result.breakdown, fn elem ->
        IO.puts("  - #{elem.text} (type: #{elem.type}, form: #{elem.form || "nil"})")
      end)
    else
      IO.puts("Error: #{inspect(result)}")
    end

    if time_ms > 5000 do
      IO.puts("")
      IO.puts("⚠️ WARNING: Validation took > 5 seconds - still too slow!")
      System.halt(1)
    end

    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("SUCCESS: Validation is fast enough!")
    IO.puts("=" |> String.duplicate(60))
end
