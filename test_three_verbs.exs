# Test with 3 verb slots
alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

sentence = "神戸へ行って、映画を見て、お茶を飲みました。"

IO.puts("Testing three verb slots...")
IO.puts("Sentence: #{sentence}")

# Warm caches
ValidatorCache.warm_cache("verb")
ValidatorCache.warm_cache("noun")
IO.puts("Caches warmed!")

# Three verb pattern
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => []}
]

IO.puts("\nStarting validation (three verb slots)...")

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
else
  IO.puts("Error: #{inspect(result)}")
end
