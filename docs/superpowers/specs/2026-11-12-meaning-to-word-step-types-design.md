# 1.6.0 Feature: `meaning_to_word` and `meaning_to_text` test step types

Date: 2026-11-12
Status: approved design, pending implementation plan

## Goal

Two new word-test step types, available in daily tests, word-set practice tests, classroom
vocabulary tests, and teacher hand-built test steps. Both reverse the existing
`word_to_meaning` direction: the student sees one or more meanings (in their current locale)
and must produce the Japanese word — either by multichoice or by typing.

## Step type definitions

### Type A — `meaning_to_word` (multichoice)

- **Question:** N meaning segments joined with ` / `, localized to the student's current
  locale at *render* time (same pattern as the existing
  `localize_question_data_meaning/2` in `daily_test_live`).
- **Options:** `"{word.text} / {word.reading}"` for the correct word and distractors
  (e.g. `食べる / たべる`).
- **Distractor pools** (mirror existing `word_to_meaning`):
  - Daily: learned words from user progress, `mature == false`, random 3.
  - Word-set: other words in the set via `TestStepBuilder.add_distractors/5`.
  - Classroom vocab: configured distractor pool (`:selected` or all classroom words).
- **Meaning count N:**
  - Generated steps (daily / word-set / classroom vocab): RNG picks N ∈ {1, 2, 3} and
    RNG picks that many segments from the `/`-split localized meaning.
  - Teacher hand-built step: teacher picks exactly which segments are shown via a
    multi-select in the step builder (custom component or multi-select; segments listed
    from the word's meaning string split on `/`).

### Type B — `meaning_to_text` (fill-in)

- **Question:** same N-meanings prompt as Type A.
- **Answer:** free text. Student types **either** the word text (kanji version) **or** the
  reading. Validation succeeds if the input matches *any* `/`-separated alternative of
  `word.text` **or** `word.reading`, reusing `Medoru.Tests.ReadingAnswerValidator`
  normalization (katakana→hiragana, long-vowel variants, trimming).
- **Meaning count N:** same RNG/teacher rules as Type A.

## Meaning source and localization

- Raw meaning string is stored in `question_data` (e.g. `question_data.word_meaning`), not
  pre-localized, so the same generated test renders correctly for users of any locale —
  following the existing daily-test convention.
- Segment selection for generated steps happens at **generation** time (store
  `question_data.meaning_segments` — the chosen raw segments) so all students see the same
  question; localization translates those segments at render.
- Teacher hand-built steps: teacher selects segment **indices**; indices are applied after
  localization at render time. Caveat: if a translation has a different segment count than
  the base meaning, indices that don't exist fall back to showing the full meaning string.
  This is documented behavior, acceptable for v1.

## Touch points

1. `lib/medoru/tests/test_step.ex` — add `:meaning_to_word`, `:meaning_to_text` to
   `@question_types`; `default_points/1`; points validation; note existing
   `:picture_multichoice` inconsistency (do NOT fix in this change).
2. Generators:
   - `lib/medoru/learning/daily_test_generator.ex` — allowlist + build clause +
     distractor fetch + daily preferences UI.
   - `lib/medoru/tests/word_set_test_generator.ex` — allowlist + build clause.
   - `lib/medoru/tests/classroom_vocabulary_test_generator.ex` — allowlist + build clause.
3. Teacher UI:
   - `lib/medoru_web/components/step_builder_components.ex` — two new step cards.
   - `lib/medoru_web/live/teacher/test_live/edit.ex` — meaning-segment multi-select
     per step (word chosen first, then segments of that word's meaning offered).
4. User settings: `lib/medoru/accounts/user_profile.ex` validation allowlist +
   `lib/medoru_web/live/settings_live/daily_test_preferences.ex` two new toggles.
5. Rendering: branches in `daily_test_live.html.heex`, `word_set_live/test.html.heex`,
   `lesson_test_live/show.ex`, `classroom_live/test.ex`
   (+ `initial_answer_for_step/1`, submit-answer dispatch).
6. Validation: Type A via standard multichoice path (`correct_answer` matching);
   Type B via `ReadingAnswerValidator`-style alternative matching against
   `word.text` and `word.reading` alternatives.

## `question_data` shape (string keys)

```
%{
  "type" => "meaning_to_word" | "meaning_to_text",
  "word_text" => "食べる",
  "word_reading" => "たべる",
  "meaning_segments" => ["to eat", "to consume"],   # raw, localized at render
  "meaning_indices" => [0, 2],                       # teacher-built steps
  "question_label" => "..."                          # i18n tag, optional
}
```

## Testing

TDD per step type: generator unit tests (segment RNG bounds, distractors, question_data
shape), validation tests (Type B alternatives: kanji, reading, katakana input, long vowel),
LiveView render tests for at least daily + word-set + classroom, teacher editor test for
segment multi-select. Full suite must stay green.
