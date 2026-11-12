# meaning_to_word / meaning_to_text Step Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new word-test step types — `meaning_to_word` (multichoice: N meanings → pick the word) and `meaning_to_text` (typed: N meanings → type word or reading) — to daily tests, word-set practice tests, classroom vocabulary tests, and teacher hand-built steps.

**Architecture:** Both types are *sub-types* of existing `question_type`s, dispatched via `question_data["type"]`, following the existing `text_mode` / `meaning_to_japanese` conventions — no new schema enum values. Meaning segments (1–3, `/`-split) are chosen at generation time (RNG) or by the teacher (indices), stored in `question_data.meaning_indices`, and localized at render time. Shared logic lives in one new context module; validation extends `ReadingAnswerValidator`.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto (JSONB `question_data`), Gettext, ExUnit + Phoenix.LiveViewTest.

**Spec:** `docs/superpowers/specs/2026-11-12-meaning-to-word-step-types-design.md`

## Global Constraints

- Never hardcode Japanese/kanji in tests — use existing test fixtures (`Medoru.AccountsFixtures`, word fixtures; check `test/support/fixtures/` for a word fixture; if none exists create words with `Medoru.Content` functions or `Repo.insert` of `%Word{}` with unique `text`).
- All new `question_data` keys are **strings** (`"type"`, `"meaning_indices"`, etc.) — generators must write string-keyed maps (`%{"type" => "meaning_to_word", ...}`), not atoms.
- Supported locales: `"en"`, `"bg"`, `"ja"`; meanings localize via `Medoru.Content.get_localized_meaning/2` (returns `/`-separated string, falls back to `word.meaning`).
- Meaning count N ∈ {1, 2, 3}; segments joined with `" / "` for display.
- `mix format` all changed files; run the full suite `mix test` before reporting done.
- Do not modify other agents' uncommitted work.

## Naming (used throughout)

- `question_data["type"]` values: `"meaning_to_word"` (multichoice) and `"meaning_to_text"` (typed).
- `question_type`: `:multichoice` for `meaning_to_word` (1 point), `:reading_text` for `meaning_to_text` (2 points).
- `question_data` shape for both:
  ```elixir
  %{
    "type" => "meaning_to_word" | "meaning_to_text",
    "word_id" => word.id,
    "word_text" => word.text,
    "word_reading" => word.reading,
    "meaning_indices" => [0, 2]          # chosen at generation / by teacher
  }
  ```
- `meaning_to_word` additionally has `"options"` (array of `"text / reading"` strings) and `correct_answer` set to the correct `"text / reading"` string.

## Review Focus

1. **Kana-only words** (word with katakana/hiragana text, no kanji): `meaning_to_text` must accept the reading answer too (reading == text family) — validator must check both fields regardless.
2. **Duplicate display options**: two distractor words with identical `"text / reading"` display — daily generator must `Enum.uniq` options (word-set/classroom use `option_word_ids` alignment, safe by construction).
3. **Translation with fewer segments than base meaning**: render falls back to the full localized string when an index is out of range (per spec).
4. **Points invariants**: `meaning_to_word` must always be 1 point (schema rule `{:multichoice, p, _} when p != 1`), `meaning_to_text` 1–2 points — generator tests must assert.
5. **Teacher step with no word attached**: segment multi-select renders empty; saving a `meaning_to_word` step without `meaning_indices` falls back to showing the full meaning at render (prompt helper handles `nil`).

---

### Task 1: `Medoru.Tests.MeaningSegments` — segment picking helpers

**Files:**
- Create: `lib/medoru/tests/meaning_segments.ex`
- Test: `test/medoru/tests/meaning_segments_test.exs`

**Interfaces:**
- Produces:
  - `split/1` — `split("to eat/to consume") -> ["to eat", "to consume"]` (trim each, drop empties)
  - `random_count/0` — `:rand.uniform(3)` → 1..3
  - `pick_random/1` — `pick_random(meaning_string) :: {segments :: [String.t], indices :: [integer]}` — picks random count, then random distinct indices (via `Enum.take_random/2` over `Enum.with_index(split(meaning))`), returns trimmed segments and sorted indices.
  - `pick_indices/2` — `pick_indices(meaning_string, indices) :: [String.t]` — segments at given indices, skipping out-of-range.
  - `join/1` — `join(segments) :: String.t` — `Enum.join(segments, " / ")`.

- [ ] **Step 1: Write failing tests** — for each function above: split with 1/2/3 segments and empty parts; pick_random returns count within 1..3, indices valid and distinct, segments match indices; pick_indices drops out-of-range indices; join produces `"a / b"`.
- [ ] **Step 2: Run, verify FAIL** — `mix test test/medoru/tests/meaning_segments_test.exs` → module undefined.
- [ ] **Step 3: Implement** the module (pure functions, `@moduledoc` one line).
- [ ] **Step 4: Run, verify PASS.**

### Task 2: Render-time prompt helper in `Medoru.Content`

**Files:**
- Modify: `lib/medoru/content.ex` (near `get_localized_meaning/2`, line ~3380)
- Test: add cases to an existing content test file, or create `test/medoru/content/meaning_prompt_test.exs`

**Interfaces:**
- Consumes: `MeaningSegments.pick_indices/2`, `MeaningSegments.join/1`, `get_localized_meaning/2`.
- Produces:
  - `localized_meaning_prompt(word_id, locale, indices)` — loads the word by id (`Repo.get(Word, word_id)`), returns `nil` if word missing; localizes via `get_localized_meaning(word, locale)`; if `indices` is nil/empty → returns the full localized string; else `localized |> MeaningSegments.split() |> pick_indices(indices) |> join()`, and if that yields `[]` (index out of range), falls back to the full localized string.

- [ ] **Step 1: Write failing test** — word fixture with meaning `"to eat/to consume"` and translation `%{"bg" => %{"meaning" => "ям/консумирам"}}`: `localized_meaning_prompt(id, "bg", [1]) == "консумирам"`; `[0, 1]` joins with `" / "`; out-of-range `[5]` falls back to full `"ям/консумирам"`; `nil` indices → full string; `"en"` → base meaning segments; missing word → `nil`.
- [ ] **Step 2: Run, verify FAIL** (function undefined).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**

### Task 3: `ReadingAnswerValidator.validate_text_or_reading/3`

**Files:**
- Modify: `lib/medoru/tests/reading_answer_validator.ex`
- Test: `test/medoru/tests/reading_answer_validator_test.exs` (create or extend existing)

**Interfaces:**
- Produces:
  - `validate_text_or_reading(word_text, reading, user_answer) :: boolean` — `true` if trimmed `user_answer` matches any `/`-split alternative of `word_text` (case-sensitive exact, but reuse `normalize_kana/1` on both sides for kana-only safety) OR `validate_reading(reading, user_answer)` is true.

- [ ] **Step 1: Write failing tests** — `word_text = "食べる"`, `reading = "たべる"`: accepts `"食べる"`, `"たべる"`, `"タベる"` (katakana input); rejects `"食べます"`, `""`; multiple readings `"よん/し"` accepts either; multiple text alternatives `"此れ/これ"` accepts either.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** (make `normalize_kana/1` reusable — it's private; either call the existing public pipeline or extract minimally).
- [ ] **Step 4: Run, verify PASS.**

### Task 4: `TestStepBuilder.add_distractors/5` — `format_option` opt

**Files:**
- Modify: `lib/medoru/tests/test_step_builder.ex:20-55`
- Test: `test/medoru/tests/test_step_builder_test.exs` (create or extend)

**Interfaces:**
- Consumes: existing `add_distractors/5` behavior.
- Produces: new opt `format_option: (word -> String.t)` (default `&Map.get(&1, field)`); the formatted value is used for distractor option strings AND `step.correct_answer` must be pre-formatted by the caller (document in `@doc`).

- [ ] **Step 1: Write failing test** — pool of word structs; `add_distractors(step, correct_word, 2, pool, field: :text, format_option: fn w -> "#{w.text} / #{w.reading}" end)` → options all match the `"text / reading"` shape, `option_word_ids` index-aligned, correct answer at correct word's index.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** — apply `format_option` in the `Enum.map(&Map.get(&1, field))` distractor step only.
- [ ] **Step 4: Run, verify PASS.**

### Task 5: Daily test generator

**Files:**
- Modify: `lib/medoru/learning/daily_test_generator.ex` (`select_question_types/2` valid list ~915; `build_word_steps/4` new clauses after `"word_to_reading"` ~737; new private `fetch_word_display_options/2` next to `fetch_meaning_options/2` ~976)
- Modify: `lib/medoru/accounts/user_profile.ex:88-109` — add `"meaning_to_word"`, `"meaning_to_text"` to `valid_types`
- Modify: `lib/medoru_web/live/settings_live/daily_test_preferences.ex` — add two toggle cards to `@available_step_types` (mirror existing entries; labels: gettext("Meaning to Word"), gettext("Meaning to Text"))
- Test: `test/medoru/learning/daily_test_generator_test.exs` (extend existing; run with `mix test test/medoru/learning/daily_test_generator_test.exs`)

**Interfaces:**
- Consumes: `MeaningSegments.pick_random/1`, `MeaningSegments.join/1`, `Content.localized_meaning_prompt/3` (not needed here — generation stores base-meaning indices), `ReadingAnswerValidator` (not here).
- Produces: `"meaning_to_word"` clause building:
  ```elixir
  {segments, indices} = MeaningSegments.pick_random(word.meaning)
  Map.merge(base_attrs, %{
    question_type: :multichoice,
    question: "__MSG_WHAT_WORD_MEANS__|#{MeaningSegments.join(segments)}",
    correct_answer: "#{word.text} / #{word.reading}",
    points: 1,
    options: fetch_word_display_options(word, user_id),
    question_data: %{
      "type" => "meaning_to_word",
      "word_id" => word.id, "word_text" => word.text, "word_reading" => word.reading,
      "meaning_indices" => indices, "display_meaning" => MeaningSegments.join(segments)
    }
  })
  ```
  and `"meaning_to_text"` clause identical except `question_type: :reading_text`, `points: 2`, no `options`, question `"__MSG_TYPE_WORD_FOR_MEANING__|..."`, `"type" => "meaning_to_text"`. `fetch_word_display_options(word, user_id)` mirrors `fetch_meaning_options/2` but `select([w, up], fragment("? || ' / ' || ?", w.text, w.reading))`... **simpler**: select `%{text: w.text, reading: w.reading}` and format in Elixir; return `[formatted_correct | distractors] |> Enum.uniq() |> Enum.shuffle()`.

- [ ] **Step 1: Write failing tests** — generator entry point used by existing tests in the file (e.g. `build_word_steps` via a public generate function — mirror how existing tests drive it): force step types `["meaning_to_word"]` and `["meaning_to_text"]`; assert: `question_type`/points correct; `question_data["meaning_indices"]` length 1..3, valid against `MeaningSegments.split(word.meaning)`; `correct_answer == "#{word.text} / #{word.reading}"`; options contain correct answer, length 4, all `" / "`-shaped, unique; `"meaning_to_text"` step has no options and `points == 2`. Also: profile validation accepts the two new strings.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** clauses + fetch + allowlists + preferences UI cards.
- [ ] **Step 4: Run file tests, verify PASS.**

### Task 6: Word-set practice generator

**Files:**
- Modify: `lib/medoru/tests/word_set_test_generator.ex` (`validate_step_types/1` ~336; `build_step_data/4` new clauses; atoms `:meaning_to_word`, `:meaning_to_text`)
- Test: `test/medoru/tests/word_set_test_generator_test.exs` (extend)

**Interfaces:**
- Consumes: `MeaningSegments.pick_random/1`, `MeaningSegments.join/1`, `TestStepBuilder.add_distractors/5` with `format_option` (Task 4).
- Produces: `:meaning_to_word` clause — `question_type: :multichoice`, `points: 0` (practice), `question: MeaningSegments.join(segments)`, `correct_answer: "#{word.text} / #{word.reading}"`, `question_data: %{"type" => "meaning_to_word", "word_text" => ..., "word_reading" => ..., "meaning_indices" => indices, "question_label" => "word"}` (string keys), then `TestStepBuilder.add_distractors(step, word, distractor_count, distractor_pool, field: :text, format_option: fn w -> "#{w.text} / #{w.reading}" end)`. `:meaning_to_text` clause — `question_type: :reading_text`, `question_data` with `"type" => "meaning_to_text"`, `"text_mode" => "word_or_reading"`, plus a `text_mode` free-form note; no distractors.

- [ ] **Step 1: Write failing tests** mirroring Task 5 assertions (points 0 here), plus `option_word_ids` index-aligned with options.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**

### Task 7: Classroom vocabulary generator

**Files:**
- Modify: `lib/medoru/tests/classroom_vocabulary_test_generator.ex` (`@allowed_step_types` ~14-20; step-building clause mirroring the existing `word_to_meaning` one, reading `opts[:distractor_pool]`)
- Modify: `lib/medoru_web/live/teacher/classroom_live/generate_vocabulary_test.ex` — two cards in `available_step_types/0` (~405-438): ids `"meaning_to_word"`, `"meaning_to_text"`, labels via gettext.
- Test: `test/medoru/tests/classroom_vocabulary_test_generator_test.exs` (extend)

**Interfaces:** Same as Task 6 (points per classroom defaults — mirror the existing `word_to_meaning` classroom clause's points).

- [ ] **Step 1: Write failing tests** — same shape as Task 6, for both `distractor_pool: :selected` and `:classroom`.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**

### Task 8: Word-set config UI cards

**Files:**
- Modify: `lib/medoru_web/live/word_set_live/test_config.ex` — `@step_type_meta` (~14-57) two entries: `%{id: "meaning_to_word", icon: "hero-arrow-uturn-left", label: "Meaning to Word", description: "..."}` and `%{id: "meaning_to_text", ...}` (follow existing entry shape; descriptions via plain strings, translated by `available_step_types/0` like existing entries).
- Test: extend `test/medoru_web/live/word_set_live/` tests if a test_config test exists; otherwise a small render test that the two new cards appear.

- [ ] **Step 1: Write failing test** — render `/word-sets/:id/test-config`-style route used by existing tests; assert "Meaning to Word" and "Meaning to Text" appear.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**

### Task 9: Rendering — daily test + word-set test LiveViews

**Files:**
- Modify: `lib/medoru_web/live/daily_test_live/daily_test_live.html.heex` — in the multichoice branch (~347): extend `english_multichoice?` to include `"meaning_to_word"`; question heading for it: `Content.localized_meaning_prompt(question_data["word_id"], @locale, question_data["meaning_indices"])`; option display: as-is (already `"text / reading"`). Add a `:reading_text` sub-branch (or extend the existing one) for `question_data["type"] == "meaning_to_text"`: heading = same prompt; single text input `phx-change="update_answer"`/`phx-blur`; submit button `phx-click="submit_meaning_to_text"`.
- Modify: `lib/medoru_web/live/daily_test_live.ex` — handlers `update_answer` (store assign) and `submit_meaning_to_text`: load word by `question_data["word_id"]`, `ReadingAnswerValidator.validate_text_or_reading(word.text, word.reading, answer)`, record via `Tests.record_step_answer(session.id, step.id, %{answer: answer, time_spent_seconds: ..., step_index: ..., is_correct: result}, locale: ...)` mirroring the existing `"submit_reading_text"` handler (~197).
- Modify: `lib/medoru_web/live/word_set_live/test.html.heex` + `test.ex` — multichoice branch: for `"meaning_to_word"` render prompt heading via `localized_meaning_prompt` instead of `word_text` (follow the existing `question_label` pattern at ~367). For `"meaning_to_text"`: in the `:reading_text` render branch (~210), add sub-branch when `question_data["type"] == "meaning_to_text"`: single input; in `test.ex` `"submit_reading_text"` dispatch (~155), add clause before text_mode dispatch: `question_data["type"] == "meaning_to_text"` → validate via `validate_text_or_reading(word.text, word.reading, answer)`, record with explicit `is_correct` (mirror `submit_single_text/4` ~297).
- Tests: extend `test/medoru_web/live/daily_test_live_test.exs` and the word-set test live test (find exact file via Glob `test/medoru_web/live/word_set_live/*test*`).

- [ ] **Step 1: Write failing tests** — build a test with a step whose `question_data["type"] == "meaning_to_word"` (insert via `Tests.create_test_steps` or the generator from Task 5/6): render shows the localized prompt (assert an English segment string appears and the word text does NOT appear in the question heading), options show `"text / reading"`. For `"meaning_to_text"`: `render_click(view, "submit_meaning_to_text", %{answer: word.text})` (daily) / `"submit_reading_text"` (word-set) → recorded answer `is_correct == true`; wrong answer → `is_correct == false`.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both files, verify PASS.**

### Task 10: Rendering — classroom test + lesson test LiveViews

**Files:**
- Modify: `lib/medoru_web/live/classroom_live/test.ex` — multichoice needs no dispatch change (standard path handles options); in the `:reading_text` template branch add a `"meaning_to_text"` sub-branch (single input, prompt from `localized_meaning_prompt`); in `handle_reading_text_answer` add a clause for `question_data["type"] == "meaning_to_text"` validating via `validate_text_or_reading` and recording with explicit `is_correct` (mirror lines ~802-860). `initial_answer_for_step/1`: `:reading_text` clause already exists — ensure single-input mode initializes `@meaning_answer`-style assign or reuse the existing ones.
- Modify: `lib/medoru_web/live/lesson_test_live/show.ex` — in the `question_type == :multichoice` render branch (~789): for `question_data["type"] == "meaning_to_word"` show prompt heading + options as-is (they are plain strings). In the `:reading_text` branch (~774): sub-branch for `"meaning_to_text"` single input; add matching submit handler (find the reading_text submit event in this file and mirror it).
- Tests: extend classroom test test file and `test/medoru_web/live/lesson_test_live/` tests — same assertions as Task 9 (correct + incorrect answer recording, prompt rendering).

- [ ] **Step 1: Write failing tests.**
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both files, verify PASS.**

### Task 11: Teacher step builder — new cards + segment multi-select

**Files:**
- Modify: `lib/medoru_web/components/step_builder_components.ex` — two `<.step_type_option>` cards in `step_type_selector/1` (~222-261): `type={:meaning_to_word}` title gettext("Meaning to Word") 1 point, vocabulary; `type={:meaning_to_text}` title gettext("Meaning to Text") 2 points.
- Modify: `lib/medoru_web/live/teacher/test_live/edit.ex`:
  - `select_step_type` case table (~123-142): add `"meaning_to_word" -> {:multichoice, "vocabulary"}` and `"meaning_to_text" -> {:reading_text, "vocabulary"}`.
  - In the step form (near the word-search UI, ~1316/166): when the step's question_type is one of the two and `@word_search_query`-selected word is attached (step has `word_id`), render a multi-checkbox list of the word's meaning segments (`MeaningSegments.split(word.meaning)`); toggling sends `"toggle_meaning_segment"` updating a `meaning_indices` list in the step form state (store sorted unique indices).
  - Save path (~623-843): when question_type is one of the two, write `question_data` with `"type"`, `"word_id"`, `"word_text"`, `"word_reading"`, `"meaning_indices"` (from form state), and set `correct_answer` to `"#{word.text} / #{word.reading}"` for `meaning_to_word` (options remain manually entered by the teacher, as today); set `question` to the joined selected base segments (fallback full `word.meaning`).
- Test: extend `test/medoru_web/live/teacher/test_live/` edit tests — select new type card, attach a word fixture, toggle segments 0 and 2, save, assert step has correct `question_data["meaning_indices"]`, `correct_answer` format, and question string.

- [ ] **Step 1: Write failing test.**
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**

### Task 12: Full verification

- [ ] **Step 1:** `mix format --check-formatted` on all changed files; fix.
- [ ] **Step 2:** `mix test` full suite. Expected: green except the known pre-existing failure `Medoru.AI.WordEnrichmentTest` "sends vibe prompt as instructions by default" (fails identically on `main`; do not fix here — report it).
- [ ] **Step 3:** `mix compile --warnings-as-errors`.
- [ ] **Step 4:** Update `AGENTS.md` Current State: version 1.6.0 status paragraph — append the two new step types (files, generators, teacher builder). Do NOT bump the version number.

## Self-Review Notes

- Spec coverage: Type A/B definitions → Tasks 5-11; localization at render → Tasks 2+9+10+11; teacher literal segment selection → Task 11; classroom inclusion → Task 7; daily preferences toggles → Task 5; Review Focus items 1/3/4/5 pinned in Task 5/2/6/11 tests; item 2 (`Enum.uniq` options) pinned in Task 5 test.
- No schema migration needed: both types reuse `:multichoice`/`:reading_text` `question_type` values; dispatch is via `question_data["type"]` per existing conventions.
- Proportion: plan ≈ spec length; generator clauses pinned to existing verbatim patterns, bodies left to implementer.
