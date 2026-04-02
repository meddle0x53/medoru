# Debug test with tracing
alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

sentence = "行って、映画を見て"

IO.puts("Testing minimal case...")
IO.puts("Sentence: #{sentence}")
IO.puts("Length: #{String.length(sentence)}")

# Warm caches
ValidatorCache.warm_cache("verb")
IO.puts("Cache warmed!")

# Pattern that should match two te-form verbs
pattern = [
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
  %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]}
]

IO.puts("\nStarting validation...")

# Set a shorter timeout to see the issue faster
task = Task.async(fn ->
  Validator.validate_with_details(sentence, pattern)
end)

case Task.yield(task, 5000) do
  nil ->
    IO.puts("❌ TIMEOUT after 5 seconds")
    Task.shutdown(task)
  {:ok, result} ->
    IO.puts("✅ Result: #{inspect(result, pretty: true)}")
end
