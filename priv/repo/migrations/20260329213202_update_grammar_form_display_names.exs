defmodule Medoru.Repo.Migrations.UpdateGrammarFormDisplayNames do
  use Ecto.Migration

  def up do
    # Update verb forms - remove "形" from display names
    execute(
      "UPDATE grammar_forms SET display_name = 'ない' WHERE name = 'nai-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'なくて' WHERE name = 'nakute-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'なかった' WHERE name = 'nakatta-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'ます' WHERE name = 'masu-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'て' WHERE name = 'te-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'た' WHERE name = 'ta-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = '条件形 (れば)' WHERE name = 'conditional' AND word_type = 'verb'"
    )

    # Update adjective forms - remove "形" from display names  
    execute("UPDATE grammar_forms SET display_name = 'ない' WHERE name = 'kunai-form'")
    execute("UPDATE grammar_forms SET display_name = 'なかった' WHERE name = 'kunakatta-form'")
    execute("UPDATE grammar_forms SET display_name = 'くて' WHERE name = 'kute-form'")
    execute("UPDATE grammar_forms SET display_name = 'く' WHERE name = 'ku-form'")
    execute("UPDATE grammar_forms SET display_name = 'かった' WHERE name = 'katta-form'")
    execute("UPDATE grammar_forms SET display_name = 'な' WHERE name = 'na-form'")
    execute("UPDATE grammar_forms SET display_name = 'で' WHERE name = 'de-form'")
    execute("UPDATE grammar_forms SET display_name = 'でした' WHERE name = 'deshita-form'")
    execute("UPDATE grammar_forms SET display_name = 'ではない' WHERE name = 'dewa-nai-form'")
    execute("UPDATE grammar_forms SET display_name = 'ではなかった' WHERE name = 'dewa-nakatta-form'")
  end

  def down do
    # Revert to original names with "形"
    execute(
      "UPDATE grammar_forms SET display_name = 'ない形' WHERE name = 'nai-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'なくて形' WHERE name = 'nakute-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'なかった形' WHERE name = 'nakatta-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'ます形' WHERE name = 'masu-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'て形' WHERE name = 'te-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = 'た形' WHERE name = 'ta-form' AND word_type = 'verb'"
    )

    execute(
      "UPDATE grammar_forms SET display_name = '条件形' WHERE name = 'conditional' AND word_type = 'verb'"
    )

    execute("UPDATE grammar_forms SET display_name = 'くない形' WHERE name = 'kunai-form'")
    execute("UPDATE grammar_forms SET display_name = 'くなかった形' WHERE name = 'kunakatta-form'")
    execute("UPDATE grammar_forms SET display_name = 'くて形' WHERE name = 'kute-form'")
    execute("UPDATE grammar_forms SET display_name = 'く形' WHERE name = 'ku-form'")
    execute("UPDATE grammar_forms SET display_name = 'かった形' WHERE name = 'katta-form'")
    execute("UPDATE grammar_forms SET display_name = 'な形' WHERE name = 'na-form'")
    execute("UPDATE grammar_forms SET display_name = 'で形' WHERE name = 'de-form'")
    execute("UPDATE grammar_forms SET display_name = 'でした形' WHERE name = 'deshita-form'")
    execute("UPDATE grammar_forms SET display_name = 'ではない形' WHERE name = 'dewa-nai-form'")
    execute("UPDATE grammar_forms SET display_name = 'ではなかった形' WHERE name = 'dewa-nakatta-form'")
  end
end
