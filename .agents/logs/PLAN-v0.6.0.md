# PLAN v0.6.0 — Classroom Themes

## Overview
Teachers can set a custom site theme for their classroom. All students viewing that classroom see the chosen theme (buttons, menus, backgrounds, cards, etc.). Each theme has both a light and dark variant that respects the user's system/settings preference.

## Main Feature: Per-Classroom DaisyUI Themes

### Backend
- **Migration**: Add `theme` string field to `classrooms` table (default `nil`, falls back to site default)
- **Schema**: `Classroom` schema gets `theme` field with validation against allowed DaisyUI theme names
- **Context**: `Classrooms.update_classroom_theme/2` or extend `update_classroom/2`
- **Allowed themes**: All DaisyUI built-in themes (e.g. `light`, `dark`, `cupcake`, `bumblebee`, `emerald`, `corporate`, `synthwave`, `retro`, `cyberpunk`, `valentine`, `halloween`, `garden`, `forest`, `aqua`, `lofi`, `pastel`, `fantasy`, `wireframe`, `black`, `luxury`, `dracula`, `cmyk`, `autumn`, `business`, `acid`, `lemonade`, `night`, `coffee`, `winter`, `dim`, `nord`, `sunset`)

### Frontend
- **Root layout**: Apply `data-theme` attribute on `<html>` based on current classroom's theme
  - If no classroom theme is set → use user's/system preference (current behavior)
  - If classroom theme is set → use classroom theme, still respecting light/dark preference
- **Teacher settings UI**: Theme picker in classroom settings
  - Visual preview cards showing each theme's color palette
  - Light/dark toggle in preview
  - "Reset to default" option

### Scope
- Theme applies when viewing:
  - Classroom show page
  - Classroom lessons
  - Classroom chat
  - Classroom rankings
- Theme does NOT apply when viewing global pages (dashboard, user directory, games, public pages)

## Feature 2: AI Word Enrichment (Admin)

### Overview
Admins can enrich word data using OpenAI directly from the word edit form. A modal shows a predefined prompt (editable) that calls the OpenAI API. The response pre-fills all form fields including meanings, readings, examples, and translations.

### Key Requirements
- **Meanings and examples separated by `/`**: Multiple meanings or examples are returned as a single string like `"meaning 1 / meaning 2"`. Applies to `meaning`, `example_sentence`, `example_reading`, `example_meaning`, `translations.bg.meaning`, `translations.bg.example`, `translations.ja.meaning`, and `translations.ja.example`.
- **Editable prompt**: Admins can modify the predefined prompt before sending.
- **Pure Elixir**: No external service — Phoenix calls OpenAI directly via `Req`.

### Backend
- **New module**: `lib/medoru/ai/word_enrichment.ex`
  - `@predefined_prompt` module attribute with structured JSON prompt
  - `enrich/2` calls OpenAI Chat Completions API with `response_format: %{type: "json_object"}`
  - Normalizes fields (string difficulty → integer, word_type → lowercase)
  - Returns `{:ok, map}` or `{:error, reason}`
- **Config**: `openai_api_key` and `openai_model` in `config/runtime.exs`, `dev.exs`, `test.exs`
- **Default model**: `gpt-4o-mini` (configurable via `OPENAI_MODEL` env var)

### Frontend
- **Admin word form** (`/admin/words/new` and `/admin/words/:id/edit`):
  - "Enrich with AI" button next to the word text field
  - DaisyUI modal with:
    - Word text display (read-only)
    - Editable prompt textarea (pre-filled from `@predefined_prompt`)
    - "Generate" button with loading spinner
    - Error alert on API failure
  - On success: modal closes, form fields populated, success flash shown

### Tests
- `test/medoru/ai/word_enrichment_test.exs` — 9 tests covering success, normalization, error handling, custom prompts
- `test/medoru_web/live/admin/word_live_test.exs` — 8 LiveView tests covering modal, enrichment, errors, prompt editing

## Technical Notes
- DaisyUI themes are already compiled into the CSS bundle
- Switching themes is a runtime CSS change via `data-theme` — no extra CSS download needed
- Need to audit hardcoded Tailwind colors (e.g. `bg-slate-800`, `text-gray-400`) and replace with semantic DaisyUI classes where theming should apply
