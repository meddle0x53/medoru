# Test noun cache
alias Medoru.Grammar.ValidatorCache

IO.puts("Warming noun cache...")
result = ValidatorCache.warm_cache("noun")
IO.puts("Warm result: #{inspect(result)}")

IO.puts("noun cached?: #{ValidatorCache.word_type_cached?("noun")}")

IO.puts("\nLooking up '映画' as noun...")
result = ValidatorCache.lookup_dictionary_form("映画", "noun")
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up '画' as noun...")
result = ValidatorCache.lookup_dictionary_form("画", "noun")
IO.puts("Result: #{inspect(result)}")

IO.puts("\nCache stats: #{inspect(ValidatorCache.stats())}")
