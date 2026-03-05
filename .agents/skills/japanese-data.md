# Japanese Data Handling in Medoru

## Kanji Validation Rules
- Unicode range: 4E00-9FFF (CJK Unified Ideographs)
- Stroke count: 1-30 (validate reasonable range)
- JLPT level: 1-5 (integer, 5 is easiest)
- Must have at least one meaning and one reading

## Word-Kanji Relationship
When creating words:
1. Split word into characters
2. Identify which are kanji (not hiragana/katakana)
3. For each kanji, store position and whether it contributes its on/kun reading
4. Validate that word reading can be constructed from kanji readings

Example:
Word: "日本語" (にほんご)
- 日 (position 0, reading: に from ニチ/ジツ/ひ/か)
- 本 (position 1, reading: ほん from ホン/もと)
- 語 (position 2, reading: ご from ゴ/かたる)

## Reading Types
- On'yomi (音読み): Chinese-derived, use katakana in data, store as uppercase strings
- Kun'yomi (訓読み): Japanese-derived, use hiragana in data, store as lowercase strings
- Word reading: Full reading in hiragana
