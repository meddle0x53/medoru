defmodule Medoru.Grammar.TokenizerTest do
  use Medoru.DataCase, async: true

  alias Medoru.Grammar.Tokenizer

  test "tokenize/1 strips punctuation without mangling multibyte characters" do
    # Regression: the punctuation regexes in normalize_sentence/1 lacked the
    # `u` flag, so the character class matched raw BYTES (E3, 81, ...) and
    # corrupted every Japanese string, crashing DB lookups with invalid UTF-8.
    tokens = Tokenizer.tokenize("きのう勉強しましたか。")

    assert tokens != []
    assert Enum.map_join(tokens, & &1.text) == "きのう勉強しましたか"
    assert Enum.all?(tokens, &String.valid?(&1.text))
  end
end
