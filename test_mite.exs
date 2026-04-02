# Check if 見て is in the cache
alias Medoru.Grammar.ValidatorCache

IO.puts("Warming verb cache...")
ValidatorCache.warm_cache("verb")

IO.puts("\nLooking up 行く (dictionary)...")
result = ValidatorCache.lookup_dictionary_form("行く", "verb")
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up 行って (te-form, conjugated_form field)...")
result = ValidatorCache.lookup_conjugated_form("行って", "verb", ["te-form"], :conjugated_form)
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up 見る (dictionary)...")
result = ValidatorCache.lookup_dictionary_form("見る", "verb")
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up 見て (te-form, conjugated_form field)...")
result = ValidatorCache.lookup_conjugated_form("見て", "verb", ["te-form"], :conjugated_form)
IO.puts("Result: #{inspect(result)}")

IO.puts("\nLooking up 見て (te-form, reading field)...")
result = ValidatorCache.lookup_conjugated_form("見て", "verb", ["te-form"], :reading)
IO.puts("Result: #{inspect(result)}")

IO.puts("\nCache stats: #{inspect(ValidatorCache.stats())}")
