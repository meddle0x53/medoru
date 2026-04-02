# Debug test
alias Medoru.Grammar.Validator
alias Medoru.Grammar.ValidatorCache

sentence = "、映画を見て"

IO.puts("Testing: #{sentence}")

# Warm caches
ValidatorCache.warm_cache("verb")
ValidatorCache.warm_cache("noun")
IO.puts("Caches warmed!")

# Test the optimized function directly
IO.puts("\nTesting try_object_marked_verb_match_optimized...")

# This should find "を" particle and match "見て" as verb
result = Validator.try_object_marked_verb_match_optimized(sentence, ["te-form"])
IO.puts("Result: #{inspect(result)}")
