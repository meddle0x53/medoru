# Test with two slots
alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

sentence = "神戸へ行って、映画を見て、お茶を飲みました。"

IO.puts("Testing two te-form verb slots...")
IO.puts("Sentence: #{sentence}")

# Warm caches
IO.puts("Warming verb cache...")
ValidatorCache.warm_cache("verb")
IO.puts("Warming noun cache...")
ValidatorCache.warm_cache("noun")
IO.puts("Caches warmed!")
IO.puts("Cache stats: #{inspect(ValidatorCache.stats())}")

# Two slot pattern
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]}
]

IO.puts("\nStarting validation (two slots)...")

{time, result} =
  :timer.tc(fn ->
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
