# Iteration 24A: UI Internationalization (i18n)

**Status**: 🚧 IN PROGRESS  
**Priority**: 🟡 MEDIUM  
**Estimated**: 2-3 days  
**Languages**: English (default), Bulgarian, Japanese

## Overview

Implement full UI internationalization using Phoenix Gettext. All interface text will be translatable into English, Bulgarian, and Japanese. Language selection available in both header and settings.

## Technical Approach

### Gettext Setup
- Use Phoenix built-in Gettext for translations
- `priv/gettext/en/LC_MESSAGES/default.po` - Source (English)
- `priv/gettext/bg/LC_MESSAGES/default.po` - Bulgarian
- `priv/gettext/ja/LC_MESSAGES/default.po` - Japanese

### Language Detection (Priority Order)
1. URL parameter (`?locale=bg`)
2. User preference (stored in `users.settings["locale"]`)
3. Cookie (`medoru_locale`)
4. Browser Accept-Language header
5. Default: English

### Storage
- User setting: `users.settings["locale"]` (persisted)
- Cookie: 1-year expiration
- Session: for guest users

## Files to Create

```
lib/medoru_web/plugs/set_locale.ex              # Locale detection & setting
lib/medoru_web/live/settings_live/language.ex   # Language preference settings
priv/gettext/bg/LC_MESSAGES/default.po          # Bulgarian translations
priv/gettext/ja/LC_MESSAGES/default.po          # Japanese translations
```

## Files to Modify

```
config/config.exs                               # Default locale, Gettext config
lib/medoru_web/router.ex                        # Add SetLocale plug
lib/medoru_web.ex                               # Import Gettext macros
lib/medoru_web/components/layouts.ex            # Language selector in header
lib/medoru_web/components/core_components.ex    # Wrap text in gettext()

# All LiveViews - Replace hardcoded strings:
lib/medoru_web/live/*_live.ex                  # All LiveView modules
lib/medoru_web/live/*_live/*.ex                # Nested LiveViews
lib/medoru_web/components/*.ex                 # All components
```

## Language Selector Component

**Location**: Header (dropdown) + Settings page (full preference)

**Design**:
- Header: Compact dropdown with flag icons 🇬🇧 🇧🇬 🇯🇵
- Settings: Full list with preview text in each language
- Auto-save on selection
- Shows "Restart may be required" for some changes

## Translation Process

### Step 1: Extract Strings
```bash
mix gettext.extract
```

### Step 2: Generate PO Files Structure
- Creates `priv/gettext/en/LC_MESSAGES/default.po` with all strings
- Template for translators

### Step 3: AI Translation (using tokens)
- Translate `default.po` entries to Bulgarian
- Translate `default.po` entries to Japanese
- Ensure context-aware translations (e.g., "test" as exam vs test as verb)

### Step 4: User Review (Approval Required)
- Review Bulgarian translations
- Review Japanese translations
- Mark approved/reject with comments

### Step 5: Compile
```bash
mix gettext.merge priv/gettext --locale bg
mix gettext.merge priv/gettext --locale ja
```

## Key Strings to Translate (Categories)

### Navigation
- "Dashboard", "Lessons", "Kanji", "Words", "Classrooms"
- "My Tests", "Custom Lessons", "Admin"
- "My Profile", "Settings", "Sign out"
- "Sign in with Google"

### Actions
- "Start Lesson", "Continue", "Complete", "Submit"
- "Create", "Edit", "Delete", "Save", "Cancel"
- "Add", "Remove", "Publish", "Archive"
- "Next", "Previous", "Back"

### Test-Related
- "Question", "Step", "Points", "Score"
- "Correct", "Incorrect", "Hint", "Skip"
- "Time Remaining", "Time's Up"
- "Congratulations!", "Try Again"

### Form Labels
- "Title", "Description", "Difficulty"
- "Name", "Email", "Password"
- "Invite Code", "Classroom"

### Messages
- Flash messages (success/error/info)
- Validation errors
- Empty states ("No lessons yet", "No results found")
- Confirmation dialogs

### Classroom
- "Join Classroom", "Apply", "Approve", "Reject"
- "Members", "Rankings", "Analytics"
- "Published", "Draft", "Archived"

## Special Considerations

### Japanese UI
- Keep Japanese content (words/kanji) as-is
- Only translate UI chrome/labels
- Consider text length (Japanese often shorter, but not always)
- Right-to-left not needed (Japanese is LTR)

### Bulgarian UI
- Cyrillic support (already works)
- Pluralization rules (different from English)
- Text may be longer than English

### Date/Time
- Use `Cldr` or `Timex` for localized dates
- "3 hours ago" → "преди 3 часа" / "3時間前"

## Testing
- [ ] Switch language in header → UI updates
- [ ] Switch language in settings → persists after logout/login
- [ ] Guest user → cookie stores preference
- [ ] All flash messages appear in selected language
- [ ] No untranslated strings remain (use `mix gettext.extract` to verify)

## User Approval Required
- [ ] Bulgarian translations reviewed and approved
- [ ] Japanese translations reviewed and approved
- [ ] Language selector UX tested and approved
