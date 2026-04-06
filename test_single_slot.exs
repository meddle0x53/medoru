# Test with single slot
alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

sentence = "神戸へ行って、映画を見て、お茶を飲みました。"

IO.puts("Testing single te-form verb slot...")
IO.puts("Sentence: #{sentence}")

# Warm caches
ValidatorCache.warm_cache("verb")
ValidatorCache.warm_cache("noun")
IO.puts("Caches warmed!")

# Single slot pattern
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]}
]

IO.puts("\nStarting validation (single slot)...")

{time, result} =
  :timer.tc(fn ->
    Validator.validate_with_details(sentence, pattern)
  end)

time_ms = time / 1000
IO.puts("Completed in #{time_ms}ms")
IO.puts("Result: #{inspect(result, pretty: true)}")
