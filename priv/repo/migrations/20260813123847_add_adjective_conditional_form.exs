defmodule Medoru.Repo.Migrations.AddAdjectiveConditionalForm do
  use Ecto.Migration

  def up do
    # Insert the shared conditional form for adjectives (idempotent)
    execute """
    INSERT INTO grammar_forms (id, name, display_name, word_type, suffix_pattern, description, inserted_at, updated_at)
    VALUES (gen_random_uuid(), 'conditional', 'ければ/なら', 'adjective', 'ければ/なら', 'Conditional form (if) for adjectives', NOW(), NOW())
    ON CONFLICT (name, word_type) DO NOTHING;
    """

    # Backfill conditional conjugations for い-adjectives (e.g. 安い -> 安ければ)
    execute """
    INSERT INTO word_conjugations (id, word_id, grammar_form_id, conjugated_form, alternative_forms, inserted_at, updated_at)
    SELECT gen_random_uuid(), w.id, gf.id,
           regexp_replace(w.text, 'い$', 'ければ'),
           ARRAY[]::varchar[],
           NOW(), NOW()
    FROM words w
    CROSS JOIN grammar_forms gf
    WHERE w.word_type = 'adjective'
      AND w.text LIKE '%い'
      AND gf.name = 'conditional'
      AND gf.word_type = 'adjective'
    ON CONFLICT (word_id, grammar_form_id) DO UPDATE SET
      conjugated_form = EXCLUDED.conjugated_form,
      alternative_forms = EXCLUDED.alternative_forms,
      updated_at = NOW();
    """

    # Backfill conditional conjugations for な-adjectives (e.g. 静かだ -> 静かなら)
    execute """
    INSERT INTO word_conjugations (id, word_id, grammar_form_id, conjugated_form, alternative_forms, inserted_at, updated_at)
    SELECT gen_random_uuid(), w.id, gf.id,
           regexp_replace(regexp_replace(w.text, 'だ$', ''), 'な$', '') || 'なら',
           ARRAY[]::varchar[],
           NOW(), NOW()
    FROM words w
    CROSS JOIN grammar_forms gf
    WHERE w.word_type = 'adjective'
      AND (w.text LIKE '%だ' OR w.text LIKE '%な')
      AND gf.name = 'conditional'
      AND gf.word_type = 'adjective'
    ON CONFLICT (word_id, grammar_form_id) DO UPDATE SET
      conjugated_form = EXCLUDED.conjugated_form,
      alternative_forms = EXCLUDED.alternative_forms,
      updated_at = NOW();
    """
  end

  def down do
    execute """
    DELETE FROM word_conjugations
    WHERE grammar_form_id IN (
      SELECT id FROM grammar_forms WHERE name = 'conditional' AND word_type = 'adjective'
    );
    """

    execute """
    DELETE FROM grammar_forms WHERE name = 'conditional' AND word_type = 'adjective';
    """
  end
end
