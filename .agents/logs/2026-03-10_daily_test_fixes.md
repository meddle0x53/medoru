# Daily Test Fixes - March 10, 2026

## Issues Fixed

### 1. Daily Test Bug: Including Unlearned Words

**Problem**: Daily tests were including words that the user hadn't actually learned through lessons. This happened because the daily test generator was pulling words from UserProgress without verifying they came from lessons the user had started.

**Solution**: Added safety checks to ensure daily tests only include words from lessons the user has actually started:

- Added `get_started_lesson_ids/1` function to get all lessons the user has started
- Added `word_from_started_lesson?/2` function to verify a word belongs to a started lesson
- Modified `generate_daily_test/1` to return `{:error, :no_lessons_started}` if user hasn't started any lessons
- Modified `get_eligible_new_words/2` to filter words by started lessons
- Modified `build_test_items/3` to filter due reviews by started lessons

**Files Modified**:
- `lib/medoru/learning/daily_test_generator.ex`

### 2. Feature: Reading Text Input in Daily Tests

**Problem**: Daily tests only had multiple choice questions. Users wanted to experience the new reading text input (typing meaning + reading) in daily tests.

**Solution**: Integrated the reading_text question type into daily tests:

**Daily Test Generator Changes**:
- Modified `build_word_steps/1` to randomly assign question types per word
- New words: 2 multichoice questions (easier)
- Review words: 50% chance of getting 1 multichoice + 1 reading_text (more challenging)
- reading_text steps worth 2 points

**Daily Test Live Changes**:
- Added assigns: `:meaning_answer`, `:reading_answer`, `:meaning_error`, `:reading_error`, `:correct_meaning`, `:correct_reading`
- Added event handlers: `update_meaning`, `update_reading`, `submit_reading_text`
- Added `handle_incorrect_reading_text/4` function
- Updated template to conditionally render reading_text UI using `ReadingTextComponent`
- Shows correct answers after incorrect attempt
- "Continue" button after wrong answer

**Files Modified**:
- `lib/medoru/learning/daily_test_generator.ex`
- `lib/medoru_web/live/daily_test_live.ex`
- `lib/medoru_web/live/daily_test_live/daily_test_live.html.heex`

### 3. Test Updates

**Problem**: Existing daily test generator tests didn't account for the new lesson requirement.

**Solution**: Updated tests to:
- Create lesson progress before generating daily tests
- Use `lesson_word_fixture` to associate words with lessons
- Test the new `{:error, :no_lessons_started}` error case
- Test that words from unstarted lessons are filtered out

**Files Modified**:
- `test/medoru/learning/daily_test_generator_test.exs`
- `test/support/fixtures/content_fixtures.ex` (added `lesson_word_fixture`)

---

## User Flow Now

1. User must start a lesson before they can take a daily test
2. Daily test only includes words from lessons they've started
3. Daily test includes a mix of:
   - Review items (words with due ReviewSchedule)
   - New words (tracked in UserProgress but no ReviewSchedule yet)
4. Question types:
   - New words: 2 multichoice questions each
   - Review words: mix of multichoice and reading_text (typing)
5. Completing daily test:
   - Updates streak
   - Creates ReviewSchedule for new words
   - Updates mastery for reviewed words

---

## Testing

```bash
# Run daily test generator tests
mix test test/medoru/learning/daily_test_generator_test.exs

# Run full test suite
mix test
```

---

## Updates (Post Bug Fixes)

### Bug 1 Fix: Daily Test Available After Lesson Completion
**Problem**: After completing a lesson, the daily test was redirecting users to the lessons page saying they needed to learn words first.

**Root Cause**: The daily test generator was filtering words to only include those from "started lessons", which was too restrictive and caused words to be excluded.

**Solution**: Removed the strict `word_from_started_lesson?` filtering. Now the daily test includes ALL words the user has learned (in UserProgress), regardless of which lesson they came from.

### Bug 2 Fix: Lesson Tests Now Include Kanji Writing
**Problem**: Lesson tests weren't showing kanji writing steps.

**Root Cause**: The lesson words weren't being preloaded with their kanji associations.

**Solution**: Updated the preload in `generate_lesson_test` to include `word_kanjis: :kanji` so writing steps can be properly generated.

### Bug 3 Fix: Smarter Multichoice Distractors
**Problem**: Multichoice distractors were too easy - they used random words instead of words the user had already learned.

**Solution**: Modified `fetch_distractors` to prioritize:
1. **First**: Other words from the same lesson (most confusing because user is currently learning them)
2. **Second**: Words from same difficulty level (fallback)
3. **Third**: Generic placeholders (if still not enough)

This makes the tests more challenging and reinforces learning by using familiar words as distractors.

## UX Improvements

### Redirect Instead of Error

When a user hasn't learned any words and tries to access the daily test:
- **Before**: Would show an error or blank page
- **After**: Redirects to `/lessons` with a friendly message:
  > "Start a lesson to begin learning Japanese! Your daily review will be available once you've learned some words."

This guides new users to the learning flow instead of leaving them confused.
