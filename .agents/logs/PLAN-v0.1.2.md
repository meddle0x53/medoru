# Medoru v0.1.2 Release Plan

## Overview
Small improvements and bug fixes for the Medoru Japanese learning platform.

**Estimated Duration**: 3-4 days  
**Total Features**: 5

---

## Feature 1: Daily Test Step Type Preferences

### Description
Allow users to customize which types of test steps appear in their daily tests via settings.

### Current Behavior
- Daily test generator hardcodes question types in `select_question_types/1`
- New words get: `[:word_to_meaning, :word_to_reading]` (multichoice only)
- Review words get: random mix of multichoice and reading_text

### Desired Behavior
- Users can enable/disable step types:
  - **Multichoice** (word→meaning, word→reading)
  - **Fill-in/Reading text** (type meaning and reading)
  - **Kanji writing** (draw the kanji)
- At least one type must be selected (validation)
- Settings stored in UserProfile or new UserSettings table
- Daily test generator respects these preferences

### Implementation Plan

**Step 1.1: Database Migration**
```elixir
# priv/repo/migrations/XXX_add_daily_test_preferences_to_user_profiles.exs
create table(:user_settings) do
  add :user_id, references(:users, type: :binary_id), null: false
  add :daily_test_step_types, {:array, :string}, default: ["multichoice", "reading_text", "writing"]
  # Future: other user preferences
end
```

**Step 1.2: Schema Changes**
- Create `Medoru.Accounts.UserSettings` schema
- Add `has_one :settings` to User schema
- Ensure settings are created with default values when user registers

**Step 1.3: Update Daily Test Generator**
- Modify `select_question_types/2` to accept user preferences
- Filter available question types based on user settings
- Fall back to default behavior if no preferences set

**Step 1.4: Settings UI**
- Create new route: `/settings/daily-test`
- Create `SettingsLive.DailyTest` LiveView
- Checkboxes for each step type with validation
- Save preferences to UserSettings

### Files to Modify
- `lib/medoru/accounts/user_settings.ex` (new)
- `lib/medoru/accounts.ex` - Add settings CRUD functions
- `lib/medoru/learning/daily_test_generator.ex` - Respect preferences
- `lib/medoru_web/live/settings_live/daily_test.ex` (new)
- `lib/medoru_web/router.ex` - Add route

---

## Feature 2: Fix Daily Tests Showing Unlearned Words

### Description
Fix the bug where daily tests include words that the user hasn't actually learned yet.

### Root Cause Analysis
Looking at the code flow:
1. `DailyTestGenerator.generate_daily_test/1` calls `get_eligible_new_words/2`
2. `get_eligible_new_words/2` calls `Learning.get_new_words_for_review/1`
3. This queries `UserProgress` where word_id is not nil AND (no ReviewSchedule OR repetitions == 0)

**The Issue**: Words are being tracked as "learned" (UserProgress created) before the user has actually completed a lesson test. This happens when:
- User views a lesson but doesn't complete the test
- Words are pre-populated in UserProgress somehow
- `track_word_learned` is called prematurely

### Solution
Modify `get_new_words_for_review` to only include words that:
1. Have UserProgress with `mastery_level >= 1` (not just 0)
2. OR have a completed lesson test associated
3. OR have been reviewed at least once

### Implementation Plan

**Step 2.1: Fix Learning Context**
```elixir
# lib/medoru/learning.ex
def get_new_words_for_review(user_id, opts \\ []) do
  limit = Keyword.get(opts, :limit, 5)

  query =
    from up in UserProgress,
      where: up.user_id == ^user_id and not is_nil(up.word_id),
      # Only include words that have been actually learned
      where: up.mastery_level >= 1 or up.times_reviewed > 0,
      left_join: rs in ReviewSchedule,
      on: rs.user_progress_id == up.id,
      where: is_nil(rs.id) or rs.repetitions == 0,
      preload: [:word, :kanji],
      order_by: [asc: up.inserted_at],
      limit: ^limit

  Repo.all(query)
end
```

**Step 2.2: Audit Word Tracking**
- Review all places where `track_word_learned` is called
- Ensure it's only called after lesson test completion
- Remove any pre-population of UserProgress

**Step 2.3: Add Test Coverage**
- Add test to verify unlearned words (mastery_level 0) don't appear in daily tests
- Add test for proper word eligibility

### Files to Modify
- `lib/medoru/learning.ex` - Fix `get_new_words_for_review/1`
- `test/medoru/learning_test.exs` - Add regression tests

---

## Feature 3: Public Kanji and Words Access

### Description
Ensure kanji and vocabulary pages are fully accessible to non-logged-in users.

### Current State
- Routes are already in `:public` live_session (no auth required)
- `KanjiLive.Show` already handles anonymous users gracefully
- Need to verify `WordLive.Show` does the same

### Verification Checklist
- [ ] `/kanji` - List view works anonymously
- [ ] `/kanji/:id` - Detail view works anonymously
- [ ] `/words` - List view works anonymously
- [ ] `/words/:id` - Detail view works anonymously
- [ ] No "Learn" buttons shown for anonymous users (or redirect to login)
- [ ] Progress indicators hidden for anonymous users

### Implementation
Mostly verification. May need minor fixes in:
- `lib/medoru_web/live/word_live/index.ex`
- `lib/medoru_web/live/word_live/show.ex`

Add conditional rendering:
```elixir
<%= if @current_user do %>
  <!-- Show progress/learn buttons -->
<% end %>
```

---

## Feature 4: Anonymous Language Switching

### Description
Allow non-logged-in users to change the interface language.

### Current State
- `SetLocale` plug supports cookies for non-logged-in users
- Language settings page requires authentication
- No UI for anonymous users to change language

### Solution
Add a language selector accessible to all users:

**Option A: Header Language Dropdown (Recommended)**
- Add language selector in the header/navigation
- Visible to both logged-in and anonymous users
- Changes language immediately via cookie

**Option B: Public Language Settings Page**
- Make `/settings/language` accessible without authentication
- Store preference in cookie for anonymous users

### Implementation Plan (Option A)

**Step 4.1: Create LanguageSelector Component**
```elixir
# lib/medoru_web/components/language_selector.ex
defmodule MedoruWeb.LanguageSelector do
  use Phoenix.Component
  # Dropdown with flags for en/bg/ja
  # Triggers JS to set cookie and reload
end
```

**Step 4.2: Add to Header**
- Modify `lib/medoru_web/components/layouts/app.html.heex`
- Add language dropdown in navigation bar
- Only show on non-authenticated pages or always visible

**Step 4.3: JavaScript Handler**
- Add `assets/js/hooks/language_selector.js`
- Handle language change, set cookie, reload page

### Files to Modify
- `lib/medoru_web/components/layouts/app.html.heex` - Add selector
- `lib/medoru_web/components/language_selector.ex` (new)
- `assets/js/hooks/language_selector.js` (new)
- `assets/js/app.js` - Add hook

---

## Feature 5: Word Picture Upload (Admin)

### Description
Allow admins to upload 1-3 pictures per word. Pictures display on the word detail page.

### Database Schema
```elixir
# priv/repo/migrations/XXX_create_word_images.exs
create table(:word_images, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :word_id, references(:words, type: :binary_id), null: false
  add :url, :string, null: false
  add :alt_text, :string
  add :sort_order, :integer, default: 0
  timestamps(type: :utc_datetime)
end

create index(:word_images, [:word_id])
create index(:word_images, [:word_id, :sort_order])
```

### Schema
```elixir
# lib/medoru/content/word_image.ex
defmodule Medoru.Content.WordImage do
  schema "word_images" do
    field :url, :string
    field :alt_text, :string
    field :sort_order, :integer, default: 0
    belongs_to :word, Medoru.Content.Word
  end
end
```

### Implementation Plan

**Step 5.1: Migration and Schema**
- Create migration for word_images table
- Create WordImage schema
- Add `has_many :images` to Word schema

**Step 5.2: Context Functions**
```elixir
# lib/medoru/content.ex
# List images for a word
# Create image with upload handling
# Delete image (also delete file)
# Reorder images
```

**Step 5.3: Admin Word Form - Image Upload**
- Modify `Admin.WordLive.Form`
- Add `allow_upload(:word_images, ...)` 
- Display existing images with delete button
- Handle upload in save event
- Maximum 3 images per word validation

**Step 5.4: Word Show Page - Display Images**
- Modify `WordLive.Show` template
- Display images in a gallery/grid
- Responsive sizing (max 2 columns on desktop)
- Fallback when no images

**Step 5.5: File Storage**
- Store in `/uploads/words/{word_id}/{filename}`
- Use same pattern as avatar uploads
- Serve via Phoenix static plug

### Files to Create/Modify

**New:**
- `lib/medoru/content/word_image.ex`
- `priv/repo/migrations/XXX_create_word_images.exs`

**Modified:**
- `lib/medoru/content/word.ex` - Add images association
- `lib/medoru/content.ex` - Add image management functions
- `lib/medoru_web/live/admin/word_live/form.ex` - Upload handling
- `lib/medoru_web/live/admin/word_live/form/form.html.heex` - Upload UI
- `lib/medoru_web/live/word_live/show.ex` - Load images
- `lib/medoru_web/live/word_live/show.html.heex` - Display images

---

## Implementation Order

### Phase 1: Bug Fix (Day 1)
1. **Feature 2**: Fix daily tests unlearned words bug
   - Critical fix, should be deployed first
   - Add regression tests

### Phase 2: Public Access (Day 1-2)
2. **Feature 3**: Verify public kanji/words access
   - Quick verification and minor fixes
3. **Feature 4**: Anonymous language switching
   - Add header language selector

### Phase 3: Daily Test Preferences (Day 2-3)
4. **Feature 1**: Daily test step type preferences
   - Database migration
   - Settings UI
   - Generator updates

### Phase 4: Word Images (Day 3-4)
5. **Feature 5**: Word picture uploads
   - Database and schema
   - Admin upload UI
   - Word page display

---

## Testing Checklist

### Feature 1
- [ ] User can save step type preferences
- [ ] Daily test only shows enabled step types
- [ ] At least one type must be selected (validation)
- [ ] Default preferences work for new users

### Feature 2
- [ ] Unlearned words (mastery_level 0) don't appear in daily tests
- [ ] Learned words (mastery_level >= 1) do appear
- [ ] Regression test added

### Feature 3
- [ ] All kanji/word pages work when logged out
- [ ] No errors on anonymous access
- [ ] Learn buttons hidden for anonymous users

### Feature 4
- [ ] Language selector visible when logged out
- [ ] Language change persists via cookie
- [ ] Works on all public pages

### Feature 5
- [ ] Admin can upload 1-3 images per word
- [ ] Images display on word show page
- [ ] Images can be deleted
- [ ] Max 3 images enforced
- [ ] Responsive image gallery

---

## Migration Summary

| Migration | Purpose |
|-----------|---------|
| `create_user_settings.exs` | Store daily test preferences |
| `create_word_images.exs` | Store word pictures |

---

## Configuration Changes

None required - all features use existing configuration patterns.
