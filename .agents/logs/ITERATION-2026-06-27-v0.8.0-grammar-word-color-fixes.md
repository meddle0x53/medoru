# Iteration Log: Grammar Lesson Word Color Fixes

**Date:** 2026-06-27
**Version:** v0.8.0
**Branch:** master

## Problem

Production crashes and rendering bugs related to grammar lesson word colors:

1. **`FunctionClauseError` on "apply_to" change** — In the grammar lesson editor (`/teacher/grammar-lessons/:id/edit`), changing the "apply_to" dropdown for a lesson or step word color crashed the LiveView. The `update_lesson_word_color`/`update_step_word_color` handlers expected `index` and `field` params, but LiveView's `phx-change` for a `<select>` reads `phx-value-*` from the containing `<form>`, not from the element itself. Since the select was not wrapped in a form with those hidden fields, the params were missing.

2. **Text after colored words hidden in student/preview view** — In `ClassroomLive.CustomLesson.markdown_with_colors/3`, colored words were wrapped in inline `<span>` tags and the result passed to `Earmark.as_html/2`. When a `<span>` started a line, Earmark treated it as an HTML block and discarded all text after the closing `</span>` on the same line, so trailing explanation text disappeared.

3. **Router compile warning** — `lib/medoru_web/router.ex` had two identical routes for `/users/:id/white-board`, making the second one unreachable.

## Solution

### 1. Word color "apply_to" dropdown

- Added a new JS hook `assets/js/hooks/word_color_apply_to.js` that listens for `change` events on the apply-to `<select>` and pushes the update event with the correct `index`, `field`, and `apply_to` payload.
- Registered the hook in `assets/js/app.js`.
- Updated the `word_color_editor` component in `lib/medoru_web/live/teacher/grammar_lesson_live/form.ex` to attach the hook to the apply-to select (with a unique `id`, which LiveView requires for `phx-hook`).

This avoids the need for nested forms (which are invalid HTML and broke the outer lesson form in the browser/parser).

### 2. Preserving text after colored words

- In `lib/medoru_web/live/classroom_live/custom_lesson.ex`, `markdown_with_colors/3` now inserts a zero-width space (`\u200B`) before any `<span>` that starts a line. This prevents Earmark from treating the span as an HTML block and dropping the text that follows it.

### 3. Router warning

- Removed the duplicate `live "/:id/white-board", UserWhiteBoardLive` route from the `/users` scope in `lib/medoru_web/router.ex`. The route at the top-level public browser scope already handles the same path.

## Files Changed

- `lib/medoru_web/live/teacher/grammar_lesson_live/form.ex`
- `lib/medoru_web/live/classroom_live/custom_lesson.ex`
- `lib/medoru_web/router.ex`
- `assets/js/hooks/word_color_apply_to.js` (new)
- `assets/js/app.js`
- `test/medoru_web/live/teacher/grammar_lesson_live_test.exs`
- `test/medoru_web/live/classroom_live/custom_lesson_test.exs`
- `AGENTS.md`

## Tests Added

- `changing lesson word color apply_to does not crash`
- `changing step word color apply_to does not crash`
- `preserves text after colored word in preview`

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix format --check-formatted` — clean
- Targeted tests (`grammar_lesson_live_test.exs`, `custom_lesson_test.exs`) — 23 tests, 0 failures
- Full suite — 1485 tests, 1 unrelated failure (`daily_test_generator_test.exs:448`, flaky `word_fixture/1` issue; passes when run in isolation)
