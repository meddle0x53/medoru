# Test script to check validator performance against medoru_dev DB - with tracing
import Ecto.Query

alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

# Simpler pattern to isolate the issue
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => []}
]

sentence = "神戸へ行って、映画を見て、お茶を飲みました。"

IO.puts("=" |> String.duplicate(60))
IO.puts("Testing SIMPLER pattern against medoru_dev database")
IO.puts("=" |> String.duplicate(60))
IO.puts("Sentence: #{sentence}")
IO.puts("Pattern: [te-form][te-form][any-form]")
IO.puts("")

# Warm caches
IO.puts("Warming caches...")
ValidatorCache.warm_cache("verb")
ValidatorCache.warm_cache("noun")
IO.puts("Caches warmed!")
IO.puts("")

IO.puts("Starting validation...")

{time, result} = :timer.tc(fn ->
  Validator.validate_with_details(sentence, pattern)
end)

time_ms = time / 1000
IO.puts("Completed in #{time_ms}ms")
IO.puts("Result.valid: #{result.valid}")

if result.valid do
  IO.puts("Breakdown:")
  Enum.each(result.breakdown, fn elem ->
    IO.puts("  - #{elem.text} (type: #{elem.type}, form: #{elem.form || "nil"})")
  end)
end
