# Test cache status
alias Medoru.Grammar.ValidatorCache

IO.puts("Checking cache status...")

IO.puts("verb cached?: #{ValidatorCache.word_type_cached?("verb")}")
IO.puts("noun cached?: #{ValidatorCache.word_type_cached?("noun")}")
IO.puts("expression cached?: #{ValidatorCache.word_type_cached?("expression")}")

IO.puts("\nWarming verb cache...")
ValidatorCache.warm_cache("verb")
IO.puts("verb cached?: #{ValidatorCache.word_type_cached?("verb")}")

IO.puts("\nLooking up 行く...")
result = ValidatorCache.lookup_dictionary_form("行く", "verb")
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up 行って (conjugated)...")
result = ValidatorCache.lookup_conjugated_form("行って", "verb", ["te-form"], :conjugated_form)
IO.puts("Result: #{inspect(result)}")

IO.puts("\nCache stats: #{inspect(ValidatorCache.stats())}")
