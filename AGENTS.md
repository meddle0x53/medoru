# AGENTS.md - Medoru Japanese Learning Platform

> **⚠️ Multi-agent workspace rule for all agents:** This project uses multiple concurrent agents. The working directory is shared state. **Never revert, delete, or overwrite files you did not create or were not explicitly asked to modify.** Uncommitted changes likely belong to another active agent. If you are unsure whether a change is yours, check with the user before touching it.

## Current State

**Version**: 0.7.0 🔄 IN PROGRESS  
**Status**: v0.7.0 in progress. English-learning UI wiring complete. Daily Radical Hunt challenge complete and mobile-friendly. AI Word Enrichment remaining. Mature word content filtering complete. Gender dropdown in profile settings no longer resets when toggling checkboxes. Push notifications for classroom chats now open `/classrooms/<id>?tab=chat`. Kanji radical data bug fixed: 沢 now maps to 水 instead of 火. Admin user impersonation ("Login as") added. Admin user list shows last login timestamp. Presentation mode bug fixes: fullscreen background fills width on first entry, content scrolls to prevent kanji breakdown cut-off, vocabulary audio updates per slide. White board/stream posts and comments support copy-paste image uploads. Command parsers strip spaces around expressions. Grammar lesson from image now preserves examples in the description for both grammar and text steps and slices lesson title/description to fit validation limits. Vocabulary lesson from image now falls back to reading when AI omits text, strips optional brackets from expressions while preserving the bracketed form in notes, and prompts the AI to include katakana words, expressions, and phrases. Copy-to-wordset button and word-count badge removed from grammar lessons in classroom lesson lists. Grammar index page now highlights learned grammar points with a green border and "Learned" badge for logged-in users. Admin kanji form supports AI enrichment for metadata, readings, and stroke data, with local KanjiVG fallback for strokes.  
**Tests**: 1481 passing  
**URL**: https://medoru.net

### What's In Progress (v0.7.0)
- **Learning Language setting**: `users.learning_language` string column (default `japanese`, options: `english`, `bulgarian`). Editable on `/settings/profile` and displayed (localized) on public profile pages.
- **Word Open Graph previews**: `/words/:id` pages now include `og:title`, `og:description`, and `og:image` meta tags. If the word has an `image_path`, the word picture is used as the social-preview image.
- **Kanji stroke path normalization fix**: Added `Medoru.Content.KanjiStrokePathFix` to expand chained SVG path segments (e.g. multiple cubic bezier segments after a single `c`/`C` command) so the client-side stroke parser computes the correct expected endpoints. Run `Medoru.Content.KanjiStrokePathFix.apply()` to backfill the dev/production DB.
- **Daily Card Game English-learning mode**: For users with `learning_language` set to `english`, the daily card game shows English meanings on cards and asks for the Japanese word or reading on a match. All other users keep the original Japanese-word / meaning-input behavior.
- **Mobile Kanji Index search bar fix**: Rebuilt the `/kanji` search bar to match `/words` — plain styled `<input>` and `<button>` elements instead of DaisyUI `.btn`/`.input`, so the mobile CSS that forces a 44px min-width on `.btn` no longer squeezes the search field. Service worker cache bumped to `medoru-v34`.
- **Word chat preview image crop fix**: Chat word previews (`WordChatPreview`) now use `object-top` so portrait images are anchored at the top instead of being cropped from the center, preventing heads/tops from being cut off.
- **User English Progress**: Added `user_english_progress` table and `Medoru.Learning.UserEnglishProgress` schema for tracking words learned by users whose `learning_language` is English. Functions: `track_english_word_learned/2`, `untrack_english_word_learned/2`, `english_word_learned?/2`, `count_english_learned_words/1`, `list_english_learned_words/2`.
- **English-learning word progress wired into UI**: Dashboard and profile learned-word counts, `/words` index/show cards, learned-words list (`/users/:id/words`), and the daily card game word source all use `user_english_progress` for users with `learning_language == "english"`. The `/words` index and show pages swap English meaning and Japanese word/reading for these users.
- **Daily Radical Hunt challenge**: 4th daily challenge at `/daily-challenges/radical-hunt`. Picks a learned kanji, uses its first radical, ensures the radical has at least 10 related kanji (falls back to a common radical if needed), and runs a 120-second game. Awards 30 XP per found kanji plus a flat 50 XP participation bonus. Added to the daily challenges index and dashboard stats. Mobile input/button sizing uses plain styled markup to avoid DaisyUI mobile overrides.
- **English-learning Daily Test**: The standard `/daily-test` now generates a meaning-first daily test for users with `learning_language == "english"`. It sources words from `user_english_progress` and serves four question types: "What is the Japanese word for `<meaning>`?" (4 Japanese word options), "Choose the right picture for `<meaning>`" (4 image options when available), "Enter the Japanese word for `<meaning>`" (text input accepting the word or its reading), and "What does `<japanese word>` mean?" (text input for the English meaning). Questions are fully gettext-localized. Backend generator is `DailyTestGenerator.generate_english_daily_test/1`; LiveView branches in `DailyTestLive`. Completion tracks words in `user_english_progress` via `Learning.track_word_learned_for_user/2`.
- **Kanji radical data bug fix**: Corrected 沢 (`d4ecc622-f6d7-4986-a7f3-b4090d368f58`) from radical 火 to 水 in `KanjiRadicalFixes` and moved it from the 火 to the 水 group in `KanjiRadicals.frequency_and_kanji`. Ran `Medoru.Content.KanjiRadicalFixes.apply!/0` to backfill the local dev DB; production/QA still need the same backfill.
- **Admin user impersonation ("Login as")**: Admins can click "Login as" from `/admin/users` or `/admin/users/:id/edit` to view the site as any non-admin user. The session stores the real admin ID under `:impersonator_user_id` while `:user_id` becomes the target user, so all existing auth code works unchanged. A persistent banner shows who is being impersonated with an "Exit impersonation" button that restores the admin session. Routes: `POST /admin/users/:id/impersonate` and `POST /admin/users/stop-impersonation`. Tests in `test/medoru_web/controllers/admin/user_controller_test.exs`.
- **Daily Test image question reading**: For `image_to_meaning` questions (picture options for a Japanese word), the prompt now displays the word's reading below the Japanese text, matching the behavior of `word_to_meaning` questions.
- **Kanji radical data fix (気)**: Corrected 気 (`e793c55a-41f0-4ed6-8075-a791cebefe7d`) from radical 水 to 气 in `KanjiRadicalFixes` and moved it from the 水 to the 气 group in `KanjiRadicals.frequency_and_kanji`. Added `apply_for/1` to `KanjiRadicalFixes` so single characters or small lists can be backfilled without running the full map. Ran `Medoru.Content.KanjiRadicalFixes.apply_for("気")` to backfill the local dev DB.
- **Admin last login timestamp**: Added `last_login :utc_datetime` (nullable) to `users`. `Accounts.update_last_login/1` records the current UTC time on OAuth login and admin impersonation. The `/admin/users` table shows a "Last Login" column (desktop and mobile), with "Never" for users who haven't logged in since the field was added.
- **Presentation mode bug fixes**: `.presentation-active` now fills the fullscreen viewport width immediately (`width: 100%`, `max-width: none`) and allows vertical scrolling so tall content (e.g. kanji breakdown) isn't cut off. Vocabulary lesson audio elements now use a per-word `src` and unique `id`, forcing LiveView to re-mount the player on each slide so the pronunciation matches the current word.
- **White board / stream image paste**: Posts (`BoardInput` hook) and comments (`CommentInput` hook) on the white board and dashboard stream now support pasting images from the clipboard. Pasted images are uploaded via `/api/chat/uploads` and inserted as markdown image tags. Existing file-attachment button behavior is unchanged.
- **Command parser spacing fix**: `/word`, `/w`, `/grammar`, `/g`, `/kanji`, `/k` and their backslash variants now strip leading/trailing spaces around the expression in messages, classroom chat, and white board posts/comments. `/w   食べる   ` and `/grammar   te-form   ` now resolve correctly.
- **Daily test size consistency**: The Japanese-learning daily test now targets a stable `daily_goal` word count (10/15/20/25 words based on learned vocabulary) by filling any shortfall with unreviewed learned words instead of capping new words at 5. This eliminates the yo-yo between large review-heavy tests and tiny 9-word tests. `Learning.get_daily_review_stats/1` now returns the real scaled goal instead of a hardcoded 10.
- **Custom vocabulary lesson word reordering fix**: The edit page was using the `StepSorter` hook (designed for test steps) to reorder lesson words, but lesson word cards use `data-word-id` and emit a `reorder` event. Added a dedicated `WordSorter` hook that reads `data-word-id` and pushes `reorder` with `word_ids`, and wired it into `/teacher/custom-lessons/:id/edit`.
- **Lesson presentation mode layout fix**: Vocabulary and grammar lesson cards in `/classrooms/:id/custom-lessons/:lesson_id` now stretch to 100% width and height in presentation mode, and the Previous/Next navigation is always anchored at the bottom of the viewport (even on small screens). The card body scrolls independently when content is tall, so buttons never drop below the fold.
- **Memories! map event**: New `MemoryScene` for `TILE_TYPES.MEMORY` tiles. 5×4 grid (20 cards / 10 pairs) built from the player's learned words. The player flips cards to find matching pairs, then must type the word's meaning to claim them. Wrong attempts count both mismatched pairs and failed meaning challenges, with the maximum based on the player's Luck stat (5 base, scaling up to 15 at 100+ Luck). Rewards are based on the matched word's part of speech: verbs grant a new weapon/class ability, nouns grant 1–3 random items, adjectives grant a weapon socket charm (20% chance to be a hero charm), and other word types roll a rarity-weighted reward (gold plus a chance for an item, charm, or ability). Gold (10–30) is always awarded. Routes from `MapScene` when a memory tile is clicked.
- **Weapon/shield upgrades**: Weapon and shield are now persisted in the loadout. Upgrade costs scale by level: 50G for +1–+3, 100G for +4–+6, 200G for +7–+9, and 500G for +10. Each upgrade raises the weapon's base damage by 2 (shield base defense by 1) and improves scaling grades at +3, +6, and +9. Socket unlocks remain level-based (1 socket at +3, 2 at +6, 3 at +9). New `ShopScene` handles `SHOP` tiles with weapon/shield upgrade buttons, and `RestScene` lets the player rest to heal 40% HP or sharpen the weapon instead.
- **Weapon/shield socket charm system**: Weapons/shields now have 4 socket slots unlocked at +1, +3, +6, +7. First-socket charms (Sharp, Heavy, Fire/Water/Wind/Earth/Poison/Dark/Light, Lucky, etc.) override base scaling and unlock ability families. Sword scaling now follows STR C→B→A and SKL D→C milestones; shield scaling follows STR D→C→B. A new `SocketScene` is reachable from the loadout screen and lets the player equip owned socket charms into unlocked slots. Abilities can declare `requiredSocketCharm` or `requiredCharmFamily`; `getAvailableActions` filters by equipped socket charms. Socket charm data lives in `assets/js/game/data/socketCharms.js`. Socket 2/3/4 charm categories and ultimate/cooldown mechanics are planned per `.agents/logs/PLAN-weapon-sockets-and-builds.md`.
- **Grammar lesson from image fixes**: `GrammarParser` no longer discards examples for text steps; `GrammarImageBuilder` embeds formatted examples into the description for both grammar and text steps while keeping structured `examples` for grammar steps. Lesson title/description are sliced to `CustomLesson` validation limits (100/500). Added migration to ensure `grammar_lesson_steps.explanation` is `:text`. Fixed `CreateClassroomChatsForExisting` migration to reference only columns that exist at that point in time, so fresh DBs can migrate cleanly.
- **Vocabulary lesson from image improvements**: `ImageVocabulary` prompt now explicitly asks for katakana words, expressions, set phrases, and multi-word phrases. When the AI omits `text`, the word falls back to `reading`. Bracketed expressions like `[どうぞ]よろしく[ございます]` are cleaned (brackets removed from `text`/`image_text`) and the original bracketed form is preserved in notes. Non-Japanese entries such as Latin words (e.g. "CD") are filtered out. `ImageLessonBuilder` slices title/description to `CustomLesson` limits.
- **Classroom grammar lesson copy-to-wordset removed**: The "Copy words to word set" button and the `{word_count} words` badge are no longer rendered for grammar lessons on the classroom lesson list (`ClassroomLive.Show`). Vocabulary lessons still show both, and the existing copy-to-wordset behavior is unchanged.
- **Grammar index learned indicator**: `/grammars` now loads the current user's learned grammar IDs and marks learned cards with a green border/title and a "Learned" badge, matching the visual treatment used for words and kanji.
- **Writing fill-in image extraction**: Multi-line question text is no longer dropped when creating writing fill-in test steps from an image. `Medoru.AI.ImageTestSteps.single_line/1` now trims each line, drops blank lines, and joins the remaining text with single spaces so all content is preserved on one line.
- **Teacher test details editing**: Teachers can now edit the title and description of an existing test from the test show page (`/teacher/tests/:id`) using the new inline "Edit title and description" form.
- **Game map progression fix**: Completed battle tiles are no longer highlighted with the active current-tile pulse; they show a green checkmark and cannot be re-entered. `WinScene` explicitly marks the battle tile `completed` (via `player.completeTile`) before returning to `MapScene`, and `MapScene.doTileAction` defensively rejects completed tiles. Service worker cache bumped to `medoru-v141`; game bundle bumped to `game.js?v=241`.
- **Socket 2 passive procs**: Weapon/shield socket charms in slot 2 now trigger passive effects in battle (`on_hit`, `on_defend`, `on_turn_start`, `on_battle_start`). Added `SocketProcSystem` to resolve chances and apply heals, damage, thorns, status infliction, and stamina regen. Added example charms: Life Dew, Venom Edge, Wind Spirit (sword slot 2); Thorn Shell, Steady Guard (shield slot 2). Socket charm loader now aggregates charms for all slots, and `Player.getCharmEffects` includes always-on `effect` bonuses from socket charms.
- **Map progression / repeatable battle fix**: Battle tiles are now marked `completed` immediately on victory in `BattleScene.onBattleEnd` (before `WinScene`), so gambling rewards can no longer leave the tile active. `Player.completeTile` also advances `currentTileId` to the only uncompleted forward connection when there is a single path, keeping the hero marker on the next node instead of the finished one. Completed tiles no longer show the active pulse and display a green checkmark.
- **Loadout/Abilities interaction fixes**: Ability row hit areas now scroll in sync with the list, preventing "unclickable" or misaligned rows. The ability detail dialog disables the row hit areas while open, stopping dialog-button clicks from also selecting the row behind it. Use Item gets its own dedicated active slot and no longer blocks combat abilities. `startBattle()` auto-fills any empty combat active slots from the selected battle pool (attacks preferred). WinScene reward generation now excludes already-known abilities.
- **Weapon/shield socket prep**: Updated legacy `getWeaponCharmSlots()` / `getShieldCharmSlots()` in `assets/js/game/data/charms.js` to the +1/+3/+6/+7 four-slot schedule, matching the Player methods. `ShopScene` now shows the correct `/4` socket cap. `socketCharmIds` defaults and `getEffectiveScaling()` were already in place.
- **Family-locked ability rewards**: `getRewardPool()` now accepts a Player object and injects family-locked abilities (`gutting_slash` for bleed, `seismic_slam` for heavy, `flame_arc` for fire) into the weapon/shield reward pools when the matching Socket 1 charm family is equipped. `WinScene` and `MemoryScene` use the new signature and exclude already-known abilities.
- Service worker cache bumped to `medoru-v146`; game bundle bumped to `game.js?v=246`.

### What's In Progress (v0.8.0)
- **Admin word kanji de-association**: The admin/moderator word edit page (`/admin/words/:id/edit`, `/moderator/words/:id/edit`) now lets users remove one or multiple kanji associations from a word. Each kanji card has a "Select" checkbox, and a "Remove selected" button deletes the checked `word_kanjis` rows via `Content.delete_word_kanjis/2`.
- **Learned kanji practice pagination**: The `/users/:id/kanji/practice` page now paginates learned kanji at 30 per page (matching `/users/:id/kanji`). Selection state is preserved across pages, so users can choose kanji from any page for drawing practice.
- **Grammar text step section truncation fix**: Added migration `change_grammar_lesson_step_explanation_sections_to_text` to store `grammar_lesson_steps.explanation_sections` as `text[]` instead of `varchar(255)[]`, preventing `string_data_right_truncation` crashes when grammar lessons from images create long text-step sections.
- **Draft lesson preview crash fix**: Previewing a draft custom lesson (`/teacher/custom-lessons/:id/preview`) no longer crashes when the lesson is not published to a classroom. The preview classroom fallback now includes `theme: nil`, the back link points to the editor, word links are disabled, last-step navigation shows "Back to Editor", and the `complete` event is a no-op in preview mode. Previewing a grammar lesson with zero steps is also handled gracefully.
- **Grammar lesson word color fixes**: Changing the "apply_to" dropdown for a lesson/step word color no longer crashes with a `FunctionClauseError`. The select now uses a dedicated `WordColorApplyTo` JS hook that pushes the update event with the correct index and field metadata. Also fixed the student/preview rendering so text following a colored word is no longer dropped by Earmark (a zero-width space is inserted before line-leading `<span>` tags).
- **Router duplicate white-board route warning**: Removed the unreachable duplicate `live "/:id/white-board", UserWhiteBoardLive` route in the `/users` scope.

### What's Complete (v0.2.0) — Social, XP System, Level Badges
**Phase 1: Database & Admin Infrastructure ✅ COMPLETE**
- **Migrations**: `tags`, `user_tags`, `follows`, `xp_transactions`, `add_profile_fields_to_user_profiles`
- **Schemas**: `Tag`, `UserTag`, `Follow`, `XpTransaction` with validations
- **Tags Seeds**: 50+ official tags across 8 categories with colors
- **UserProfile Extended**: `age`, `gender`, `location`
- **Social Context**: Full follow/tag API
- **Admin Tag Management**: `/admin/tags` with full CRUD

**Phase 2: User-Facing UI ✅ COMPLETE**
- **Profile Settings**: `age`, `gender`, `location` fields
- **Tag Selection**: Interactive picker, max 15 tags
- **Public Profile**: Tags, follower counts, Follow/Unfollow button
- **User Directory**: Follow buttons, tag filter, pagination
- **Tailwind v4 Fix** + **Service Worker Cache Bust**

**Phase 3: XP & Badge Wiring ✅ COMPLETE**
- ✅ `Accounts.add_xp/3` with `XpTransaction` audit logging, level formula `100n² + 900n`, level 0 start
- ✅ Level + XP display on profile, directory, and dashboard
- ✅ **Chunk B**: Lesson XP (50×words, 150×grammar steps), Test XP (per-step-type)
- ✅ **Chunk C**: Daily streak bonus, cascade/card game XP, follow XP, badge XP
- ✅ **Chunk D**: Level badge auto-award (Lv 1/5/10/20/30/50), level-up notifications, backfill migration
- ✅ **Bug fixes**: `daily_reviews` badges wired, `user_stats` counters now increment (kanji, words, tests)

**Chat & Messaging Polish ✅ COMPLETE**
- **Message Reactions**: Emoji picker (15 common emoji), reaction pills with count, one reaction per user per message (add/remove/replace logic)
- **Chat File Uploads**: Multipart HTTP endpoint (`POST /api/chat/uploads`) supporting images/audio/documents up to 50MB in both encrypted and classroom chats via drag-drop, click-to-select, and clipboard paste
- **Encrypted Chat Flickering Fix**: `phx-update="ignore"` on all encrypted content elements prevents `morphdom` from resetting decrypted text to `[...]`; `ChatCrypto` hook `updated()` now skips `decryptAll()` when no encrypted elements remain
- **UTF-8 Word Link Fix**: `binary_part` replaces `String.slice` for `|word|`, `[[word]]`, `「word」` syntax since regex returns byte indices
- **Chat Avatar Links**: All user avatars in 1:1, group, and classroom chat link to `/users/:id` with `target="_blank" rel="noopener noreferrer"`
- **Mobile-Friendly Reactions**: 40px mobile / 44px desktop emoji buttons, enlarged reaction pills (`px-2 py-1`), responsive picker (`w-40 sm:w-48 max-w-[90vw]`), `phx-click-away` tap-outside-to-close
- **Reaction Optimistic Update Fix**: Nested `Map.update/4` bug replaced with explicit `Map.get` + `Map.put`/`Map.delete` pattern in both `MessagesLive.Show` and `ClassroomLive.Show`
- **Service Worker**: Cache bumped to `medoru-v7` to invalidate stale assets

**Daily Challenges System ✅ COMPLETE**
- **`user_daily_challenges` table**: Tracks completion per challenge type per day with `challenge_type`, `date`, `completed_at`, `xp_awarded`, `score`, `metadata`
- **`Learning.complete_daily_challenge/4`**: Idempotent completion — records challenge, updates streak only on first challenge of day, awards streak bonus (`10 × current_streak`) only once per day
- **`Learning.get_daily_challenge_stats/1`**: Returns `completed_count`, `total_challenges`, per-challenge completion booleans, streak info
- **Daily Test refactor**: Fixed kana-only bug, now uses `complete_daily_challenge("daily_test", ...)`
- **Daily Card Game** (`/daily-challenges/cards`): Standalone LiveView with in-memory state (no DB game records). 10 learned words in 5×4 grid. Meaning input modal on each match — correct meaning collects cards, wrong consumes attempt. 300 XP win, 100 XP loss. Back button during gameplay.
- **Daily Kanji Test** (`/daily-challenges/kanji`): 10 learned kanji with stroke data. Shows first 1-2 meanings + On/Kun readings. Per-kanji XP scoring: ≤3 wrong strokes = 30 XP, 4+ = 0 XP. Hook reinitialization between kanji steps via unique element IDs. Back button during gameplay.
- **Dashboard**: Links to `/daily-challenges`, shows `{completed}/{total} Completed` on daily goal card (e.g., "1/3 Completed")
- **Admin Reset**: User profile "Reset Daily Challenges" button (admin-only) calls `reset_daily_challenges/1` — deletes today's challenge records but preserves streak state
- **WritingComponent**: Updated to show first 1-2 meanings + On/Kun readings for all kanji writing steps (daily, custom lessons, word sets)

**Profile Improvements ✅ COMPLETE**
- **Bio markdown rendering**: `render_markdown/1` with `Earmark.as_html/2`, wrapped in `prose prose-sm dark:prose-invert`
- **Display name kanji/kana support**: Removed `~r/^[a-zA-Z0-9_\-\s]+$/` regex validation from `UserProfile` changeset
- **Age/gender/location display**: Compact info row with icons (`hero-cake`, `hero-user` with gender color, `hero-map-pin`) shown only when set

See [PLAN-v0.6.0.md](.agents/logs/PLAN-v0.6.0.md) for upcoming features

### What's Complete (v0.3.0) — User White Board
**Status**: ✅ COMPLETE

**Features:**
- **Canvas Drawing**: Interactive drawing board with pencil/eraser, 8 colors, line width, undo, clear. Square grid options (20px/40px/80px). White canvas background for dark-theme visibility.
- **Background Images**: Users can upload background images (stretched to canvas) for drawings. Stored in `canvas_data["background"]` and replayed by `CanvasPlayer`.
- **Post Types**: Text posts (markdown + autolinking) and canvas posts (stroke replay)
- **Visibility**: `public` or `followers` per post. `can_view_post?/2` checks owner/public/follower status with blocked-user filtering
- **Reactions**: One reaction per user per post (add/remove/replace). Optimistic updates with `broadcast_from` to exclude sender
- **Comments & Nested Replies**: Top-level and reply comments. `parent_comment` preloaded for reply UI showing "Replying to [name]" with text preview
- **Bug Fixes**: Double-comment bug fixed via `broadcast_from` pattern; replies vanishing fixed by removing `is_nil(parent_id)` filter in `load_comments_for_posts/1`
- **Mobile-Friendly**: Canvas toolbar uses `flex-nowrap overflow-x-auto` on mobile; post form stacks vertically; emoji picker constrained to `max-w-[90vw]`; comment input uses `flex-wrap`
- **Profile Integration**: Whiteboard image button on profile card linking to `/users/:id/white-board`
- **PubSub**: Real-time updates for posts, edits, deletions, reactions, and comments
- **i18n**: Full Bulgarian localization in polite form (Вие)
- **Tests**: 58 new tests (36 context + 22 LiveView)
- **Service Worker**: Cache bumped to `medoru-v8` to invalidate stale assets

**Routes:** `/users/:id/white-board`

**Key Technical Changes:**
- Migrations: `board_posts`, `board_comments`, `board_reactions`
- New schemas: `BoardPost`, `BoardComment`, `BoardReaction`
- Context: `Medoru.WhiteBoard`
- LiveView: `MedoruWeb.UserWhiteBoardLive`
- JS Hooks: `FreeDraw`, `CanvasPlayer`
- `can_view_post?/2` rewritten with `cond do` for correct early-return logic
- Service worker cache: `medoru-v8`

### What's Complete (v0.3.1) — Kanji Data Overhaul
**Status**: ✅ COMPLETE

**Features:**
- **Kanji Missing Seeder (`KanjiMissingSeeder`)**: Imports 2,798 missing kanji from `missing_kanji_full.json` — idempotent, packaged with release. Covers kanji not in original makemeahanzi dataset.
- **Nullable `jlpt_level`**: Migration `20260603172623_make_kanji_jlpt_level_nullable.exs` allows non-JLPT kanji. Schema updated.
- **KanjiRadicalFixes**: 251 hardcoded classical radical corrections from kanjidic2. Applied to all kanji (old + newly seeded).
- **KanjiDecompositionRadicals**: Restored hardcoded `@fixes` map (1,190 kanji with multi-radical assignments from IDS decomposition). Added dynamic `apply_all!/0` fallback for kanji not in hardcoded map.
- **KanjiRadicals `@frequency_and_kanji`**: Regenerated from full 5,012-kanji DB — 223 radicals with `{char, id, freq}` tuples.
- **KanjiStrokeFixer (`KanjiStrokeFixer`)**: Imports KanjiVG-derived stroke data from `kanjivg_stroke_fixes.json` for 426 kanji missing makemeahanzi stroke data. Parsed from local KanjiVG SVG files (109×109 viewBox, compatible with StrokeAnimator).
- **Production runbook**: `KanjiMissingSeeder.run()` → `KanjiRadicalFixes.apply!()` → `KanjiDecompositionRadicals.apply_all!()` → `KanjiStrokeFixer.apply!()`

**Data coverage post-seed:**
- 5,012 total kanji (was 2,217)
- 2,267 with makemeahanzi stroke data
- 426 with KanjiVG stroke data
- 105 without any stroke data (not in either dataset)
- 2,267 with decomposition
- 2,253 with radical data

**Key files:**
- `lib/medoru/content/kanji_missing_seeder.ex`
- `lib/medoru/content/kanji_radical_fixes.ex`
- `lib/medoru/content/kanji_decomposition_radicals.ex`
- `lib/medoru/content/kanji_radicals.ex`
- `lib/medoru/content/kanji_stroke_fixer.ex`
- `priv/repo/seeds/missing_kanji_full.json`
- `priv/repo/seeds/kanjivg_stroke_fixes.json`

### What's Complete (v0.4.0) — Block/Following Logic, Profile Privacy & Classroom Rankings
**Status**: ✅ COMPLETE

**Block/Following Logic Audit & Fixes:**
- **Profile 404 on reverse block**: Blocked users visiting a blocker's profile get redirected with "User not found."
- **Bidirectional post blocking**: `WhiteBoard.can_view_post?/2`, `apply_blocked_filter/2`, and `list_comments_for_post/2` all check blocking in both directions
- **Auto-unfollow on block**: `Social.block_user/3` silently unfollows in both directions
- **Message redirect**: `MessagesLive.Show` redirects blocked 1:1 conversations to `/messages` with "Conversation not found."
- **Group chat block prevention**: `Chat.create_group_conversation/4` raises if any participant pair has a block
- **User directory filtering**: Blocked users are hidden from the blocker; blockers can still find blocked users to unblock them
- **Search privacy**: `filter_blocked_by_users` always applies (not just when `only_following=true`)

**Profile Privacy:**
- **`is_public` on `user_profiles`**: New boolean (default `true`). Private profiles are hidden from the user directory and search
- **Settings toggle**: "Show my profile in the user directory" checkbox on `/settings/profile`
- **Directory filtering**: `Social.list_users`/`search_users` filter out `is_public = false` users

**Classroom Rankings:**
- **Clickable avatars**: Classroom ranking avatars and names now link to `/users/:id`
- Applied to `ClassroomLive.Show` (compact + full rankings) and `ClassroomLive.Rankings`

**Avatar Fallback Fixes:**
- **OAuth avatar copy**: `register_user_with_oauth` copies `avatar_url` into `profile.avatar` on registration
- **Template fallbacks**: Profile page, white board, and dashboard now fall back to `user.avatar_url` when `profile.avatar` is nil

**User Directory UX:**
- **Tag dropdown auto-filter**: Changing the tag `<select>` immediately filters results (via `phx-change` on the select only, not the search input)

**Key files:**
- `lib/medoru/social.ex`, `lib/medoru/white_board.ex`, `lib/medoru/chat.ex`
- `lib/medoru_web/live/user_live/show.ex`, `lib/medoru_web/live/messages_live/show.ex`
- `lib/medoru_web/live/classroom_live/show.ex`, `lib/medoru_web/live/classroom_live/rankings.ex`
- `lib/medoru_web/live/users_live/index.html.heex`
- `lib/medoru/accounts.ex`, `lib/medoru/accounts/user_profile.ex`

### What's Complete (v0.4.1) — Classroom Test Coverage Expansion
**Status**: ✅ COMPLETE

**Classroom Context Tests:**
- `list_visible_classrooms/2` — owned/joined/public visibility, archived exclusion, search, pagination
- `list_public_classrooms/0` — active public only, excludes private/closed/archived
- `user_classroom_status/2` — `:owner`, `:none`, `:pending`, `:member` states
- `get_membership!/1` — returns membership, raises on missing
- `list_classroom_memberships/1` — returns all memberships
- `get_classroom_stats_batch/1` — batch stats for multiple classrooms
- `get_classroom_leaderboard/2` — sorted by points, limit option
- `get_test_leaderboard/3` — test-specific leaderboard
- `get_or_create_lesson_progress/3` — creates new or returns existing
- `start_lesson/3` & `complete_lesson/5` — lesson progress lifecycle
- `list_user_lesson_progress/2` & `list_classroom_lesson_progress/1`

**Classroom LiveView Tests:**
- `ClassroomLive.Index` — 20 new tests covering mount, search, invite code validation, join (invite + public), cancel application
- `Teacher.ClassroomLive.Show` — 7 new tests covering regenerate invite code, approve/reject/remove members, edit/save/cancel settings, tab changes

**Bug Fixes:**
- Fixed `ChatTest` (`mark_participant_left/2`) to query `ConversationParticipant` directly since `get_classroom_conversation` now filters out left users

**Key files:**
- `test/medoru/classrooms_test.exs`
- `test/medoru_web/live/classroom_live/index_test.exs`
- `test/medoru_web/live/teacher/classroom_live_test.exs`
- `test/medoru/chat_test.exs`

### What's Complete (v0.5.0) — Grammar Definitions
**Status**: ✅ COMPLETE

**Database & Schema:**
- **Migration**: `20260605000000_create_grammar_definitions.exs` — `grammar_definitions` table with title, slug, pattern_elements, word_colors, description (localized en/bg/ja), examples (sentence/reading/meaning + bg/ja variants), jlpt_level
- **Schema**: `GrammarDefinition` with auto-slug generation, pattern element validation (non-empty), example validation (max 5, required fields), word color validation (0-31 index, apply_to field)
- **Localized helpers**: `localized_description/2`, `localized_example_meaning/2` with fallback to English

**Context Functions:**
- `list_grammar_definitions/1` — paginated with page/per_page, jlpt_level filter, title search (ILIKE)
- `get_grammar_definition!/1`, `get_grammar_definition_by_slug/1`
- `create_grammar_definition/1`, `update_grammar_definition/2`, `delete_grammar_definition/1`
- `change_grammar_definition/2`, `search_grammar_definitions/2`

**Public Routes & LiveViews:**
- `/grammars` — `GrammarDefinitionLive.Index` with JLPT level filter, search, pagination, pattern preview cards
- `/grammars/:slug` — `GrammarDefinitionLive.Show` with pattern display (colored bubbles), markdown description, examples with readings, "Try Your Own Example" validation using `Grammar.Validator`

**Admin/Moderator Management:**
- `/admin/grammars/*` — `Admin.GrammarDefinitionLive.Index` (table with filters, delete) + `Form` (new/edit with pattern builder, word colors, examples)
- `/moderator/grammars/*` — `Moderator.GrammarDefinitionLive.Index` + `Form` (exact duplicate under moderator namespace)
- Pattern builder reuses grammar lesson patterns: word slots (with forms), particles, literal text
- Example validation within form using `Grammar.Validator.validate_sentence/2`

**Navigation:**
- "Grammar" link added after "Words" in desktop nav, mobile drawer, admin content management, moderator content management

**Grammar Forms Dropdown:**
- Admin/moderator forms use `<select>` populated from `Content.list_grammar_forms()` for word slot forms
- Form event handling fixed with individual `<form>` wrappers per input for reliable `phx-change`/`phx-value-*`

**Frequency Field:**
- Added `frequency` (integer, default 1000) to grammar_definitions with migration
- Sorting: `asc: frequency, asc: jlpt_level, asc: title`

**Dashboard & Navigation:**
- Admin and moderator dashboards have "Grammar" quick-access cards
- "Grammar" nav link added after "Words" in desktop nav, mobile drawer, admin/moderator content management

**Teacher "From Grammar Definition" Button:**
- Teacher form modal to browse/search grammar definitions and auto-populate a new grammar step
- `create_step_from_grammar_definition/2` maps definition fields to lesson step structure

**Grammar Commands in Chat/Posts/Comments:**
- `/grammar <text>`, `/g <text>`, `\grammar <text>`, `\g <text>` render grammar preview cards
- Validation before send; error flash if not found
- White board: shows original text when grammar not found

**Inline Grammar Links:**
- `\<text>/` syntax in messages, posts, comments creates links to grammar show pages
- Same search logic as `/grammar` command; displays `text` without delimiters when found
- Falls back to plain `text` (delimiters removed) when not found

**Encrypted Chat Grammar Support:**
- `chat_crypto.js` hook updated to render grammar previews and inline links client-side after decryption
- `GET /api/grammar-preview/:text` endpoint for client-side grammar lookups

**Comment Improvements:**
- Comment timestamps added via `format_localized_datetime` on white board feed and dashboard stream
- Comments wired through `WhiteBoardPostRenderer.render_comment_content/1` for grammar/word/kanji rendering

**Mobile Fixes:**
- `grammar_chat_preview` max-width adaptive
- Modal padding `p-4 sm:p-6`
- Word color editor `grid-cols-4 sm:grid-cols-8`

**"Mark as Learned" for Grammar Definitions:**
- Polymorphic `user_progress` table extended with `grammar_definition_id` nullable FK + partial unique index
- `UserStats` schema: `total_grammar_learned` counter
- `Learning` context: `grammar_learned?/2`, `track_grammar_learned/2`, `unlearn_grammar/2`, `list_learned_grammar_definitions/2`, `count_learned_grammar_definitions/1`
- `Gamification.check_grammar_badges/2` with `:grammar_count` badge criteria type
- `GrammarDefinitionLive.Show`: learned toggle button (green "Learned" → red hover to unlearn)
- Dashboard + Profile: "Grammar Learned" stat card with link to `/users/:id/grammars`
- New `LearnedGrammarsLive.Index` page: paginated list of learned grammar with pattern preview, JLPT badge, links to `/grammars/:slug`

**"Copy To Grammar" Admin Feature:**
- Admin-only "Copy To Grammar" button on grammar lesson steps (student view + preview)
- Checks if grammar definition with same title exists; if not, copies step data to new definition
- Pattern element transformation: `form` → `forms` array, `value` → `text`, `word_class_id` → `word_class`
- Japanese-only title slug fallback: SHA256 hash-based slug

**Tests:**
- `test/medoru/grammar_definitions_test.exs` — 18 context tests
- `test/medoru_web/live/grammar_definition_live_test.exs` — 12 public LiveView tests
- `test/medoru_web/live/admin/grammar_definition_live_test.exs` — 10 admin LiveView tests
- `test/medoru_web/live/moderator_live_test.exs` — 2 moderator access tests
- `test/medoru_web/live/learned_grammars_live_test.exs` — 6 learned grammar list tests
- `test/medoru_web/live/classroom_live/custom_lesson_test.exs` — 6 "Copy To Grammar" tests
- `test/medoru_web/controllers/grammar_preview_controller_test.exs` — 4 preview API tests
- `test/medoru_web/live/teacher/grammar_lesson_live_test.exs` — 4 "From Grammar Definition" modal tests
- `test/medoru_web/live/user_white_board_live_test.exs` — 3 white board grammar command tests
- `test/medoru/content_test.exs` — 5 `get_grammar_definition_by_title` context tests
- `test/medoru_web/live/classroom_live/chat_test.exs` — 4 classroom chat grammar tests

**Localization:**
- Full gettext extraction for all new UI strings (en, bg, ja) — 0 new untranslated messages

**Key files:**
- `lib/medoru/content/grammar_definition.ex`
- `lib/medoru/content.ex` (grammar definition section)
- `lib/medoru_web/live/grammar_definition_live/index.ex`, `show.ex`
- `lib/medoru_web/live/admin/grammar_definition_live/index.ex`, `form.ex`
- `lib/medoru_web/live/moderator/grammar_definition_live/index.ex`, `form.ex`
- `lib/medoru_web/live/learned_grammars_live/index.ex`, `index.html.heex`
- `lib/medoru_web/live/classroom_live/custom_lesson.ex` (copy_to_grammar event)
- `lib/medoru/learning.ex` (grammar progress tracking)
- `lib/medoru/gamification.ex` (`check_grammar_badges/2`)
- `assets/js/hooks/chat_crypto.js` (client-side grammar rendering)

### Profile Followers/Following Links
- **Own-profile follower/following counts are clickable** and navigate to `/users/:id/followers` and `/users/:id/following`
- **Privacy**: counts remain plain text when viewing another user's profile or as an anonymous viewer
- **New list pages**: `UserLive.Followers` and `UserLive.Following` with paginated user cards, avatar, level badge, and Follow/Unfollow + Message actions
- **Owner-only access**: non-owners and anonymous users are redirected to the profile page with an error flash

**Key files:**
- `lib/medoru_web/live/user_live/followers.ex`, `followers.html.heex`
- `lib/medoru_web/live/user_live/following.ex`, `following.html.heex`
- `lib/medoru_web/live/user_live/show/profile_page.html.heex`
- `lib/medoru_web/router.ex`

### What's Complete (v0.5.1) — Kill Medoru! Battle MVP (v1.0.0-prealpha)
**Status**: ✅ MVP BATTLE COMPLETE — Admin-only, parallel development toward v1.0.0

**Game Architecture:**
- **Phaser 3** runs client-authoritative in a separate JS bundle (`assets/js/game.js`)
- **Phoenix** serves user data (learned kanji, words, level) and receives run results
- Admin-only access at `/admin/game` — decoupled design for future Steam export
- Phaser loaded via `assets/vendor/phaser.min.js`, not bundled with esbuild

**MVP Battle Scene:**
- Warrior (player, blue square) vs Lesser Oni (enemy, red square)
- Turn-based stamina system: player gets 10 stamina/turn, enemy gets 8
- 3 fixed skills: Forward Slash (attack), Setup Defence (block), Heal Potion (heal)
- Kanji challenge before every skill: type the reading within 5 seconds
- Challenge tiers: Perfect (<40% time) = 125%, Success = 100%, Fail = 50%
- Aggressive enemy AI: prefers attacks → buffs → recover
- Floating combat text, screen shake on crits, HP/stamina bars
- Win grants 50 XP; lose also reports to server
- Stats scale with user's site level

**Scenes Implemented (MVP):**
- `BootScene` — Procedural square textures (replaceable with sprites)
- `BattleScene` — Full combat loop with challenge overlay

**Planned Scenes (v1.0.0 roadmap):**
- `MapScene` — Node graph with battles, events, rest, shop
- `EquipmentScene` — Inventory & skill loadout management
- `RewardScene` — Choose 1 of 3 drops after battle
- `RestScene` — Upgrade stats or heal
- `TextEventScene` — Narrative choices
- `MiniGameScene` — Reuse existing site games (cascade, cards, etc.)
- `ShopScene` — Buy potions/upgrades

**Key Files:**
- `assets/js/game.js` — Entry point (loads `window.Phaser`)
- `assets/js/game/scenes/BattleScene.js` — Main battle loop
- `assets/js/game/entities/{Character,Player,Enemy}.js` — Entity system
- `assets/js/game/systems/{TurnManager,ChallengeSystem}.js` — Core systems
- `assets/js/game/data/{skills,enemies}.js` — Fixed definitions
- `lib/medoru_web/live/admin/game_live.ex` — Admin game page
- `lib/medoru_web/controllers/game_api_controller.ex` — Run result API

### What's Complete (v0.6.0) — Classroom & Chat Themes
- **Classroom Themes**: Per-classroom DaisyUI themes, teacher theme picker in classroom settings
- **Per-Chat Theme Settings**: Shared theme for 1-1 and group conversations persisted on `conversations.theme`
  - Route `/messages/:id/settings` with theme grid; any participant can change the theme
  - `Chat.update_conversation_theme/2` validates against `Classroom.allowed_themes/0` and broadcasts `{:conversation_updated, conversation}`
  - Chat page applies `data-theme` from `@conversation.theme`; classroom chats continue using `@conversation.classroom.theme`
  - `MessagesLive.Show` handles `{:conversation_updated, _}` to update the theme in real time for all viewers
  - Tests: `MessagesLive.SettingsTest` (6 LiveView tests) + `ChatTest` context tests
  - Service worker cache bumped to `medoru-v33`

### What's In Progress (v0.6.0)
- **AI Word Enrichment**: Admin word form "Enrich with AI" button calling OpenAI API with editable predefined prompt. Populates meanings (separated by `/`), readings, examples (separated by `/`), translations, frequency, and word type.
  - `lib/medoru/ai/word_enrichment.ex` — Pure Elixir OpenAI client using `Req`
  - Configurable model via `OPENAI_MODEL` env var (default `gpt-4o-mini`)
  - 9 unit tests + 8 LiveView tests
- **Writing Fill In Test Step Type**: New `:writing_fill_in` question type for tests and custom lessons. Students see example(s) plus a sentence template with `___` blanks; their completed full sentence is compared against a hidden `correct_answer` and optional `alt_correct_answers`.
  - Schema: `Medoru.Tests.TestStep` enum, default 10 points, points validation
  - Manual form: `MedoruWeb.Teacher.TestLive.WritingFillInStepForm`
  - AI image extraction: `Medoru.AI.ImageTestSteps.extract_writing_fill_in_steps/2`
  - Shared component: `MedoruWeb.WritingFillInComponents.fill_in_question/1` + `build_filled_sentence/2`
  - Student views wired in `LessonTestLive.Show`, `ClassroomLive.Test`, and `ClassroomLive.CustomLessonTest`
- See [PLAN-v0.6.0.md](.agents/logs/PLAN-v0.6.0.md)

### Mature Word Content Filtering ✅ COMPLETE
- **Database & schemas**: `mature` boolean on `words`, `safety` boolean on `user_profiles`
- **Visibility helper**: `Medoru.Content.MatureContent.mature_word_visible_to_user?/2` — hidden from anonymous users, users without age, users under 18, and users with safety mode ON
- **Public word surfaces**: `WordLive.Index`, `WordLive.Show`, `KanjiLive.Show` lists filter mature words for restricted viewers; mature word show page returns 404-style redirect
- **Admin/moderator UI**: Word forms include "Mature content" checkbox; profile settings include "Safety Mode" toggle
- **Chat & post previews**: `/word` commands and inline word links in messages, classroom chat, and white-board posts/comments render an "unsafe content detected" placeholder for restricted viewers
- **Encrypted chat**: `WordPreviewController` returns `{blocked: true}` for mature words; `chat_crypto.js` renders the placeholder client-side
- **Service Worker**: Cache bumped to `medoru-v30` so browsers fetch the updated `chat_crypto.js` and chat input hook bundles
- **Tests**: `MatureContentTest`, `WordLiveTest` filtering/redirect tests, `WordPreviewControllerTest`, `WhiteBoardPostRendererTest`
- **Key files**:
  - `lib/medoru/content/mature_content.ex`
  - `lib/medoru/content/word.ex`
  - `lib/medoru/accounts/user_profile.ex`
  - `lib/medoru/content.ex`
  - `lib/medoru_web/live/word_live/{index,show}.ex`
  - `lib/medoru_web/live/kanji_live/show.ex`
  - `lib/medoru_web/components/word_chat_preview.ex`
  - `lib/medoru_web/live/messages_live/show.ex`
  - `lib/medoru_web/live/classroom_live/show.ex`
  - `lib/medoru_web/white_board_post_renderer.ex`
  - `lib/medoru_web/controllers/word_preview_controller.ex`
  - `assets/js/hooks/chat_crypto.js`

### What's Complete (v0.1.9) — Chat, User Directory & End-to-End Encryption
- **User Directory**: Public `/users` page with searchable, paginated list of learners
  - Filtered by users with display names set
  - PostgreSQL trigram similarity search by display name
  - Avatar, name, and direct message button per user
- **User Blocking**: Block/unblock users via profile page or `/settings/blocks`
  - Bidirectional block check prevents messaging between blocked users
  - Blocked users filtered from directory and conversation lists
- **1:1 Messaging**: Direct conversations between any two users
  - Auto-creates conversation on first message from user profile
  - Real-time messaging via Phoenix PubSub
  - Typing indicators and read receipts
  - Reply-to-message support with threaded preview
- **Group Chat**: Multi-user conversations with group name
  - Multi-select users on `/users` directory to start group
  - `/messages/new-group` page for group creation with title
  - Participant list and group avatars in UI
  - Same real-time infrastructure as 1:1 chats
- **End-to-End Encryption (Group-Capable)**: Replaced old 1:1-only ECDH with RSA-OAEP + AES-256-GCM shared keys
  - Each user generates an RSA-OAEP 2048 key pair in-browser (private key in `localStorage`)
  - Each conversation has one shared AES-256-GCM key
  - Conversation key is encrypted per-participant with their RSA public key and stored server-side
  - Messages encrypted/decrypted client-side; server stores only ciphertext + IV
  - First sender generates and distributes the conversation key
  - Missing-key detection disables messaging until all participants register RSA keys
  - **Chat Invitation Flow**: User can send notification invitation when other participant hasn't set up encryption yet; recipient clicks notification → generates keys → auto-re-encryption by online participant
  - Auto-re-encryption on mount when user lacks conversation key but others have it
  - `ensure_conversation_key` fixed to not push `create_conversation_key` when keys exist for other participants
- **Mobile Reply**: Reply button always visible on mobile (`<sm`), hover-only on desktop
- **Navigation updates**: Added "Users" and "Messages" links to desktop nav and mobile drawer
- **User Directory Fix**: `/users` now shows users with OAuth `name` even if they haven't set a `display_name` (left join on profiles instead of inner join)
- **Production Migration Fix**: `CreateClassroomChatsForExisting` migration rewritten to use `insert_all` with schema module, avoiding `is_archived` column that didn't exist at migration time
- **Notification Real-time Badge**: Bell icon + unread count moved into `NotificationDropdownLive` so badge updates with dropdown via PubSub
- **Chat Entry Clears Notifications**: Entering a chat room marks all chat notifications for that conversation as read and broadcasts updated count
- **Classroom Chats in /messages**: Conversation list preloads classroom, routes to classroom chat tab, archive button hidden for classroom chats
- **Teacher Classroom Chat Access**: Teachers can view classroom chat without membership (membership nil, leave button hidden)
- **Classroom Chat Bubble Size**: Fixed HEEx whitespace causing extra line box with `whitespace-pre-wrap`
- **Word Chat Preview Localization**: Word preview cards in chat now show localized meaning based on user's locale (falls back to English)
- **Inline Word Links in Chat**: Normal text messages support `|word|` syntax — words wrapped in pipes are looked up and rendered as links to their `/words/:id` page (works for Japanese text, kana readings, meanings, and conjugations)
- **Kana Reading Support for `/word` Commands**: `/word えいご` now finds "英語" via exact reading match
- **"Add to Word Set" on Word Pages**: Word show page (`/words/:id`) has an "Add to Word Set" button that opens a modal with a paginated list of the user's word sets; clicking "Add" adds the word to the selected set (with "Already added" disabled state and full/error handling)

### What's Complete (v0.1.8) — Grammar Lessons + Kana Cascade Polish & Navigation
- **"du" accepted for づ/ヅ**: `kana_romaji_list/1` returns `["zu", "du"]`; exact match and prefix check both support multiple romaji
- **"di" accepted for ぢ/ヂ**: Added to Kana/Kanji/Words falling games
- **Flick keyboard popup Android Firefox fix**: Popup appended to pressed key with `position: absolute`; removed `flick-popup` animation class causing `opacity: 0`
- **Dakuten active state on touch devices**: Fixed modifier button orange state persistence
  - Changed modifier buttons from `click` to `pointerdown` with `stopPropagation`
  - Added `phx-update="ignore"` on flick keyboard container to prevent LiveView DOM patches from resetting classes
  - High-specificity CSS `.flick-modifier-btn.flick-modifier-active` with `!important`
- **Navigation v0.1.8 restructuring**: New `/teacher` dashboard with cards, new `/games` index
  - Desktop nav: Dashboard, Classrooms, Kanji, Words, Games, [Teacher], [Admin]
  - Mobile drawer with smart grouping (Learning / Teacher / Admin)
  - i18n extracted for all nav labels
- **Grid hiragana keyboard removed**: Flick keyboard now used on all screen sizes
- **Kanji Falling Game**: Full game using Kana Cascade engine with kanji reading input
- **Game Skill Levels**: 5 levels (Beginner→Expert) with color coding, teacher-configurable dropdown, sorted by difficulty in Games tab
- **Lesson Skill Levels**: Repurposed `difficulty` field on `custom_lessons`, color-coded UI in forms/tabs, sorted by difficulty
- **Site Settings for Featured Classroom**: Admin can select a public classroom to be accessible without registration
- **Anonymous Public Access**: `/games` and `/lessons` available to anonymous users via featured classroom
  - Games: Memory cards, Kana Cascade, Kanji Cascade playable with in-memory sessions (no DB persistence)
  - Lessons: Custom lessons viewable, progress not saved, tests skipped, completion shows sign-in CTA
- **Grammar lesson word coloring**: Teacher can highlight words with 32-color palette; works in explanation + examples
- **Markdown support**: Explanation (grammar steps) and explanation sections (text steps) render markdown via Earmark with `escape: false, smartypants: false`
- **Text steps**: Replaced intro/outro with unified `text` step type (title + multiple explanation sections, no pattern/examples, no test generation)
- **Step reordering**: Up/down arrows in teacher form swap positions atomically
- **Keyboard navigation**: Left/right arrow keys navigate steps (LessonPlayer JS hook)
- **Presentation mode**: Fullscreen button + `P` keyboard shortcut, `.presentation-active` CSS class hides chrome
- **Teacher preview**: Route `/teacher/custom-lessons/:id/preview` renders lesson as student sees it
- **Per-step test inclusion**: `include_in_test` boolean per grammar step; lesson-level `requires_test` syncs with step checkboxes; test generator filters by this flag
- **Student sentence validation**: `allows_student_validation` flag per grammar step; student gets input + validate button using `Grammar.Validator`
- **Validation input persistence**: Typed sentence persists after validation so student can edit and retry
- **Grammar edit routing fix**: Preview and classroom lesson edit links correctly route to grammar edit form

### What's Complete (v0.1.7) — Kana Cascade & Classroom Improvements
- **Kana Cascade** (formerly Kana Falling): Typing game for hiragana/katakana practice
  - Falling kana with configurable speed (10 levels, 1800ms → 100ms per row)
  - Lives system with extra life thresholds; danger line at row 20
  - Score persistence via `KanaFallingSession` with classroom rankings
  - Explosion animation on kana destruction (CSS keyframe + JS hook)
  - Color-coded rows: each gojūon row gets a unique background color (teacher toggle)
  - Optional background image upload for game field (≤2MB)
  - Teacher row picker: All, a–wa, Dakuten, Handakuten, Small
  - Game creation selector: Word Memory, Kana Memory, Kana Cascade cards
- **On-screen keyboard** (portrait + landscape)
  - Portrait: QWERTY staggered layout at bottom (`bottom: 100px`)
  - Landscape: split left/right halves fixed to viewport sides
  - Landscape keys: dark bluish background (`bg-slate-800`) for contrast
  - Responsive sizing: 36px → 40px → 48px → 56px across breakpoints
  - Same `key_pressed` event as physical keyboard
- **Pause/exit controls**: Esc toggles pause/resume→exit; no `P` shortcut conflict
- **Fullscreen behavior**: Mobile auto-fullscreens; PC shows Start Game + Play Windowed
- **Rankings & nicknames**: Ready and game-over screens show `display_name` with fallback
- Classroom settings editing: Teachers can edit classroom name and description
- Classroom membership approval toggle: `should_approve_memberships` field
  - When true (default): students apply and wait for teacher approval
  - When false: students are auto-approved on join
- Public classrooms: `public` field makes classrooms discoverable
  - Public classrooms listed in `/classrooms` with search and pagination
  - Students can join public classrooms without an invite code
  - Teachers can set public/private on creation and in settings
- Lesson reordering bug fix: `ensure_lesson_order_indices` now handles duplicate indices
- Invite code join protection: Teachers can no longer join their own classrooms

### What's Next (v0.2.0)
- See [PLAN-v0.6.0.md](.agents/logs/PLAN-v0.6.0.md) for upcoming features
- Real-time infrastructure, game engine, classroom chat, user levels, badges

### What's Complete (v0.1.6)
- Word type filter: Filter words by type (noun, verb, adjective, etc.)
- Word pronunciations: Audio pronunciations support for words
- Listening custom test step: New `listening` step type for teacher-created tests
- Test generator refactoring: Shared code across test generators for maintainability
- Translation fixes: Various i18n improvements

### What's Complete (v0.1.5)
- Word Sets: User-created collections of up to 100 words
- Word Set management: Create, edit, delete, paginated list with search/sort
- Word selection: Autocomplete input for adding words
- Practice Tests: Full test-taking experience with all question types
  - Multichoice (word_to_meaning, word_to_reading, image_to_meaning)
  - Text input (reading_text)
  - Kanji writing with stroke validation
  - Answer validation and feedback
  - Test completion statistics (correct/incorrect/score)
- Copy Lesson to Word Set: Students can copy classroom lesson words to a new word set
  - Button in classroom lessons list
  - Confirmation modal
  - Batch insert for efficiency
  - Auto-creates word set with lesson name/description
- Full i18n support (Bulgarian, Japanese translations)
- Routes: `/words/sets/*` with full CRUD

### What's Complete (v0.1.4)
- Grammar lesson system with pattern builder
- Sentence validation against grammar patterns
- Alternative forms for contracted Japanese (ない→な)
- ETS caching for 50x validation performance
- Admin progress reset feature

### What's Complete (v0.1.2)
- Daily test step type preferences
- Fix for unlearned words appearing in daily tests
- Public kanji/words access for anonymous users
- Anonymous language switching
- Word picture uploads (admin)

### What's Complete (v0.1.5) - Word Sets
**Status**: ✅ COMPLETE  
**Date**: 2026-04-06

**Features:**
- Word Sets: User-created collections of up to 100 words
- Word Set management: Create, edit, delete, paginated list with search/sort
- Word selection: Autocomplete input for adding words
- Word reordering: Drag-and-drop to change word order in set
- Practice Tests: Full test-taking experience
  - Configurable step types (word_to_meaning, word_to_reading, reading_text, image_to_meaning, kanji_writing)
  - Max steps per word (1-5, random per word)
  - All question types supported with proper UI
  - Answer validation using server's validation logic
  - Test completion with statistics (correct/incorrect/score)
  - No points awarded (practice only)
- Copy Lesson to Word Set: Students can copy classroom lesson words
  - Button in classroom lessons list (`/classrooms/:id?tab=lessons`)
  - Confirmation modal with i18n
  - Creates new word set with lesson name/description
  - Batch insert for efficiency (all words in one query)
  - Duplicates automatically skipped (unique words only)
  - Redirects to new word set after creation
- Full i18n support: Bulgarian and Japanese translations for all UI text

**Routes:** `/words/sets/*`

**Key Technical Changes:**
- Migration: `word_sets` and `word_set_words` tables
- Schemas: `WordSet`, `WordSetWord` with position tracking
- Context: `Learning.WordSets` for CRUD and test generation
  - Added `create_word_set_from_lesson/2` with batch insert
- Generator: `Tests.WordSetTestGenerator` for practice test creation
- LiveViews: Index, Form, EditWords, Show, TestConfig, Test
- Added `show_submit` attribute to WritingComponent for flexible button display
- Updated `ClassroomLive.Show` with copy lesson functionality

---

### What's Next (v0.2.0)
See [PLAN-v0.6.0.md](.agents/logs/PLAN-v0.6.0.md) for upcoming features.

**Epics:**
1. Real-time infrastructure (PubSub, Presence, Channels)
2. Game engine architecture (plugin-based)
3. Memory Cards game (first game type)
4. Real-time classroom chat
5. User tags & following system
6. User level system with XP
7. Badge system fixes

---

## Project Overview

**Medoru** is a social Japanese learning platform built with Phoenix LiveView.

**Core Features:**
- OAuth authentication (Google)
- Kanji database (N1-N5) with stroke data
- Word database cross-referenced to kanji and specific readings
- Lesson system (vocabulary + grammar)
- Multiple test types (multichoice, fill-in, kanji writing, text input)
- Daily review tests with SRS scheduling
- Classroom system (teachers, students, tests)
- Real-time learning games
- Rankings and leaderboards

**Tech Stack:**
- Elixir 1.17+, Phoenix 1.8+, LiveView 1.0+
- PostgreSQL with JSONB for flexible kanji data
- Google OAuth via Ueberauth
- Tailwind CSS for UI
- ETS caching for grammar validation

---

## Version History

### v0.3.1 - Kanji Data Overhaul (2026-06-03)
**Status**: ✅ COMPLETE

**Features:**
- **Missing Kanji Seeder**: `KanjiMissingSeeder.run()` imports 2,798 kanji from `missing_kanji_full.json` — idempotent, packaged with release
- **Nullable JLPT**: Migration makes `jlpt_level` nullable for non-JLPT kanji (2,796 unclassified)
- **Classical Radical Fixes**: `KanjiRadicalFixes.apply!/0` — 251 kanjidic2-based corrections
- **Decomposition Multi-Radicals**: Hardcoded `@fixes` map with 1,190 kanji; dynamic `apply_all!/0` fallback
- **Frequency Map Regeneration**: `@frequency_and_kanji` updated for full 5,012-kanji dataset (223 radicals)
- **KanjiVG Stroke Fixer**: `KanjiStrokeFixer.apply!/0` imports stroke data for 426 kanji missing makemeahanzi data

**Production runbook:**
1. `Medoru.Release.migrate()`
2. `KanjiMissingSeeder.run()` (~2,798 new kanji)
3. `KanjiRadicalFixes.apply!()` (251 fixes)
4. `KanjiDecompositionRadicals.apply_all!()` (multi-radical assignments)
5. `KanjiStrokeFixer.apply!()` (426 stroke data fixes)
6. Optional: classify unclassified kanji to N1 via `Repo.update_all(where: is_nil(jlpt_level), set: [jlpt_level: 1])`

**Data coverage:**
- 5,012 total kanji (was 2,217)
- 4,693 with stroke data (2,267 makemeahanzi + 426 KanjiVG)
- 105 without stroke data
- 4,265 with decomposition data

**Key files:**
- `lib/medoru/content/kanji_missing_seeder.ex`
- `lib/medoru/content/kanji_radical_fixes.ex`
- `lib/medoru/content/kanji_decomposition_radicals.ex`
- `lib/medoru/content/kanji_radicals.ex`
- `lib/medoru/content/kanji_stroke_fixer.ex`
- `priv/repo/seeds/missing_kanji_full.json`
- `priv/repo/seeds/kanjivg_stroke_fixes.json`

---

### v0.3.0 - User White Board (2026-06-01)
**Status**: ✅ COMPLETE

**Features:**
- **Canvas Drawing**: Interactive drawing board with pencil/eraser, 8 colors, line width, undo, clear. Square grid options (20px/40px/80px). White canvas background for dark-theme visibility.
- **Background Images**: Users can upload background images (stretched to canvas) for drawings. Stored in `canvas_data["background"]` and replayed by `CanvasPlayer`.
- **Post Types**: Text posts (markdown + autolinking) and canvas posts (stroke replay)
- **Visibility**: `public` or `followers` per post. `can_view_post?/2` checks owner/public/follower status with blocked-user filtering
- **Reactions**: One reaction per user per post (add/remove/replace). Optimistic updates with `broadcast_from` to exclude sender
- **Comments & Nested Replies**: Top-level and reply comments. `parent_comment` preloaded for reply UI showing "Replying to [name]" with text preview
- **Double-Comment Bug Fix**: `broadcast_comment` uses `broadcast_from` to exclude sender (same pattern as reactions)
- **Replies Vanishing Fix**: `load_comments_for_posts/1` removed `is_nil(c.parent_id)` filter, preloads `parent_comment: [user: [:profile]]`
- **Mobile-Friendly**: Canvas toolbar uses `flex-nowrap overflow-x-auto` on mobile; post form stacks vertically; emoji picker constrained to `max-w-[90vw]`; comment input uses `flex-wrap`
- **Profile Integration**: Whiteboard image button on profile card linking to `/users/:id/white-board`
- **PubSub**: Real-time updates for posts, edits, deletions, reactions, and comments
- **i18n**: Full Bulgarian localization in polite form (Вие)
- **Tests**: 58 new tests (36 context + 22 LiveView)

**Routes:** `/users/:id/white-board`

**Key Technical Changes:**
- Migrations: `board_posts`, `board_comments`, `board_reactions`
- New schemas: `BoardPost`, `BoardComment`, `BoardReaction`
- Context: `Medoru.WhiteBoard`
- LiveView: `MedoruWeb.UserWhiteBoardLive`
- JS Hooks: `FreeDraw`, `CanvasPlayer`
- `can_view_post?/2` rewritten with `cond do` for correct early-return logic

---

### v0.2.0 - Social, XP System, Level Badges & Chat Polish (2026-05-24 → 2026-05-31)
**Status**: ✅ COMPLETE

**Features:**
- **Tags & Following System**: 50+ curated tags across 8 categories, user profile tag selection (max 15), follow/unfollow with counts
- **User Directory v2**: Tag filters, follow buttons, level display, XP progress
- **XP & Level System**: `Accounts.add_xp/3` with `XpTransaction` audit logging, level formula `100n² + 900n`, level 0 start
- **Level Badges**: Auto-award at Lv 1/5/10/20/30/50 with level-up notifications
- **XP Wiring**: Lesson completion (50×words, 150×grammar), test steps, daily streak bonus, games, follows, badges
- **Message Reactions**: Emoji picker, reaction pills, one per user per message
- **Chat File Uploads**: Images, audio, documents up to 50MB in encrypted and classroom chats
- **Chat Polish**: Encrypted content flickering fix, UTF-8 word links, avatar links, mobile-friendly reactions
- **Daily Challenges System**: `user_daily_challenges` table with per-type daily tracking. Daily Test, Daily Card Game (`/daily-challenges/cards`), Daily Kanji Test (`/daily-challenges/kanji`). Streak bonus awarded only on first challenge of day. Dashboard shows `X/Y Completed` progress.

**Routes:** `/users`, `/settings/profile`, `/admin/tags`, `/messages/*`, `/daily-challenges`, `/daily-challenges/cards`, `/daily-challenges/kanji`

**Key Technical Changes:**
- Migrations: `tags`, `user_tags`, `follows`, `xp_transactions`, `add_profile_fields_to_user_profiles`, `message_reactions`, `user_daily_challenges`
- New schemas: `Tag`, `UserTag`, `Follow`, `XpTransaction`, `MessageReaction`, `UserDailyChallenge`
- Contexts: `Medoru.Social` (tags/following), `Medoru.Accounts` (XP/levels), `Medoru.Chat` (reactions), `Medoru.Learning` (daily challenges)
- `ChatCrypto` hook: `updated()` optimization, `phx-update="ignore"` on decrypted content
- `MessageReactions` unique composite index: `[:message_id, :user_id, :emoji]`
- Service worker cache: `medoru-v7`
- Daily Card Game: In-memory session state (no DB game records), meaning input modal on match
- Daily Kanji Test: Per-kanji XP scoring (≤3 wrong strokes = 30 XP, 4+ = 0 XP), hook reinitialization via unique element IDs per kanji
- `WritingComponent`: Shows first 1-2 meanings + On/Kun readings for all kanji writing steps

---

### v0.1.9 - Chat, User Directory & Word Set Integration (2026-05-24 → 2026-05-30)
**Status**: ✅ COMPLETE

**Features:**
- User Directory (`/users`): Searchable public directory of learners with profiles
  - Now includes users with OAuth `name` even without `display_name` set
- User Blocking: Block/unblock users, bidirectional enforcement
- 1:1 Messaging (`/messages`): Direct conversations with real-time PubSub
- Group Chat: Multi-user conversations with group names
- End-to-End Encryption: RSA-OAEP 2048 + AES-256-GCM shared conversation keys
  - **Chat Invitation Flow**: Send notification invitation when participant missing encryption keys
  - Auto-re-encryption on key registration and on mount (handles offline→online transitions)
  - `ensure_conversation_key` race condition fixed
- Mobile reply buttons, read receipts, typing indicators, reply-to-message
- Notifications: Real-time unread badge, chat notifications auto-cleared on entry
- Classroom chats accessible from `/messages` with proper routing
- **Word Chat Preview Localization**: Word preview cards in chat show localized meaning
- **Inline Word Links in Chat**: `|word|` syntax in normal messages renders as links to `/words/:id`
- **Kana Reading Support for `/word`**: `/word えいご` finds "英語" via reading match
- **"Add to Word Set" on Word Pages**: Modal with paginated word set list on `/words/:id`

**Routes:** `/users`, `/messages`, `/messages/new-group`, `/settings/blocks`, `/words/:id`

**Key Technical Changes:**
- Migrations: `conversations` (group fields), `conversation_keys` (encrypted AES keys), `conversation_participants` (joined_at, is_archived)
- New schemas: `ConversationKey`, updated `Conversation` with `is_group`/`title`
- New JS hooks: `ChatCrypto` (RSA/AES encryption), `ChatInput`, `GroupChatCreator`
- Contexts: `Medoru.Chat` (group support), `Medoru.Social` (blocking), `Medoru.Encryption` (RSA public keys)
- Presence tracking via `MedoruWeb.Presence`
- `Notifications.notify_chat_invitation/3` for invitation notifications
- `MessagesLive.Show` handles `send_chat_invitation`, `participant_key_registered`, and auto-re-encryption
- `Content.get_word_by_text_or_meaning/1` now checks `reading` field for kana matches
- `WordSets.list_word_set_ids_for_word/2` for pre-checking word set membership
- `WordLive.Show` modal state + `WordSets.add_word_to_set/2` integration

---

### v0.1.5 - Word Sets (2026-04-05)
**Status**: ✅ COMPLETE

**Features:**
- Word Sets: User-created collections of up to 100 words for focused study
- Word Set CRUD: Create, edit, delete with pagination, search, and sorting
- Word management: Add/remove words via autocomplete, reorder with up/down buttons
- Word Set view: Display words with N1-N5 proficiency levels
- Practice Tests: Configurable tests per word set
  - Selectable question types (word_to_meaning, word_to_reading, reading_text, image_to_meaning, kanji_writing)
  - Random 1-5 questions per word from selected types
  - No points awarded - pure practice
  - Hard-delete and recreate at any time

**Routes:** `/words/sets/*`

**Key Technical Changes:**
- Migration: `word_sets` and `word_set_words` tables
- Schemas: `WordSet`, `WordSetWord` with validations
- Context: `Learning.WordSets` for CRUD, word management, and test generation
- Generator: `Tests.WordSetTestGenerator` for configurable practice test creation
- LiveViews: Index, Form, EditWords, Show, TestConfig
- Router: Added `/words/sets` nested routes
- Navigation: Added "My Word Sets" link from `/words`

---

### v0.1.4 - Grammar Lessons (2026-03-31)
**Status**: ✅ COMPLETE

**Features:**
- Grammar lesson creation by teachers with pattern builder
- Sentence validation against grammar patterns
- Alternative forms support for contracted Japanese (e.g., 来ない→来な)
- Admin progress reset ("Danger Zone" in user edit)
- ETS caching for 50x validation performance improvement

**Key Technical Changes:**
- Migration: Added `alternative_forms` array to `word_conjugations` with GIN index
- Schema: Updated `WordConjugation` with `alternative_forms` field
- Cache: `ValidatorCache` preloads alternatives as lookup keys
- Validator: `Grammar.Validator` checks main and alternative forms
- Conjugations: 66,396 verb conjugations updated with alternative forms

**Log**: [ITERATION-GRAMMAR-STUDENT-TAKING.md](.agents/logs/ITERATION-GRAMMAR-STUDENT-TAKING.md)

### v0.1.2 - Small Improvements (2026-03-20)
**Status**: ✅ COMPLETE

**Features:**
- Daily test step type preferences (user-configurable)
- Fix for unlearned words appearing in daily tests
- Public kanji/words access for anonymous users
- Anonymous language switching (header selector)
- Word picture uploads (1-3 images per word)

**Log**: Archived

### v0.1.0 - MVP (2026-03-18)
**Status**: ✅ RELEASED  
**Live**: https://medoru.net

**Iterations 1-7 (Core MVP):**
- OAuth & Accounts
- Kanji & Readings (N5-N1)
- Words with Reading Links
- Lessons (300 topic-based)
- Learning Core (progress, streaks)
- Daily Reviews & SRS
- Polish & Integration

**Iterations 8-21 (Extended MVP):**
- User types (student/teacher/admin)
- Enhanced Profiles
- Badge System
- Logging Infrastructure
- Multi-Step Test System
- Auto-Generated Daily Tests
- Vocabulary Lesson System
- Kanji Writing Tests
- Reading Text Input
- Classroom Core
- Classroom Membership
- Classroom Tests & Rankings
- Teacher Test Creation
- Admin Dashboard
- i18n (Bulgarian/Japanese)
- UI Polish & Mobile
- Deployment & Production

---

## Recent Changes

### 2026-04-06 - Word Sets v0.1.5 Complete
- Word Sets: User-created collections of up to 100 words
- Practice tests with all question types (multichoice, reading_text, kanji_writing, image_to_meaning)
- Full test-taking experience with answer validation and feedback
- Test completion statistics (correct/incorrect/score)
- Copy Lesson to Word Set: Students can copy classroom lesson words to a new word set
- Full i18n support (Bulgarian, Japanese)
- Bug fixes: duplicate options, answer validation, boolean event handling

### 2026-03-31 - Grammar v0.1.4 Complete
- Grammar lesson system with pattern validation
- Alternative forms for contracted Japanese (ない→な)
- 66,396 verb conjugations updated
- Admin progress reset feature
- 50x performance improvement with ETS caching

### 2026-03-26 - Grammar Validator Performance Optimization
- Implemented ETS-based caching for Grammar Validator
- Reduced validation time from 2500ms+ to ~50ms per sentence
- Cache key structure: `{:conjugation, text, word_type, allowed_forms, field_type}`
- Lazy loading per word type

### 2026-05-30 - v0.2.0 Phase 1 Complete
- **Tag System Infrastructure**: Migrations, schemas, seeds for curated official tags
  - 50+ tags across 8 categories with colors stored in `priv/repo/seeds/tags.json`
  - `UserProfile` extended with `age`, `gender`, `location` fields
  - `Social` context: full follow/tag CRUD, max 15 tags per user
- **Admin Tag Management**: `/admin/tags` with create, edit, delete, search, category filter
  - Tailwind color safelist ensures all tag badge colors render correctly
  - Fixed checkbox self-updating bug by using `.input` component with hidden field
  - Fixed newly created tags not showing in admin list (removed `is_official` filter)
- **Follow System**: One-way follows with `follow_user/2`, `unfollow_user/2`, `following?/2`, counts, and paginated lists
- **XP Transaction Schema**: Audit log table for tracking XP gains with source attribution

### 2026-05-31 - v0.2.0 Chat Polish & Reactions Complete
- **Message Reactions**: `message_reactions` table, `MessageReaction` schema, `Chat.toggle_reaction/3` (add/remove/replace)
- **Reaction UI**: Emoji picker (15 emoji), reaction pills with count, current user highlighted in primary color
- **Reaction Optimistic Update Fix**: Nested `Map.update/4` bug in `MessagesLive.Show` and `ClassroomLive.Show`
- **Chat File Uploads**: `POST /api/chat/uploads` multipart endpoint, 50MB limit, drag-drop/click/clipboard in encrypted + classroom chats
- **Classroom Chat Parity**: File uploads, audio player, document downloads, reply-to jump with highlight, inline word links
- **Encrypted Chat Flickering Fix**: `phx-update="ignore"` on decrypted content + `ChatCrypto` hook `updated()` optimization
- **UTF-8 Word Link Fix**: `binary_part` replaces `String.slice` for regex byte indices in Japanese text
- **Chat Avatar Links**: All avatars link to `/users/:id` with `target="_blank" rel="noopener noreferrer"`
- **Mobile-Friendly Reactions**: 40px mobile / 44px desktop emoji buttons, enlarged pills, responsive picker, `phx-click-away`
- **Service Worker**: Cache bumped to `medoru-v7`

### 2026-05-30 - v0.1.9 Complete
- **Word Chat Preview Localization**: Word preview cards show localized meaning based on user's locale
- **Inline Word Links in Chat**: `|word|` syntax in normal messages replaces words with links to `/words/:id`
- **Kana Reading `/word` Support**: `/word えいご` finds "英語" via exact reading match
- **"Add to Word Set" on Word Pages**: Modal with paginated word set list on `/words/:id`

### 2026-05-25 - v0.1.9 Progress
- **Chat Invitation Flow**: Notification-based invitation for users missing encryption keys; auto-re-encryption on key registration
- **User Directory Fix**: Show OAuth names when display_name unset; 22 production users now visible
- **Production Migration Fix**: `CreateClassroomChatsForExisting` UUID encoding and `is_archived` column ordering fixed
- **Classroom Chat Polish**: Bubble size, teacher access, routing from /messages
- **Notification Badge Real-time**: Unread counter updates live via PubSub
- **Chat Clears Notifications**: Entering chat marks related notifications read

### 2026-03-20 - v0.1.2 Complete
- Daily test preferences
- Public access fixes
- Word picture uploads

---

## Domain Architecture (Contexts)

### 1. Accounts Context (`lib/medoru/accounts/`)
**Responsibility:** User management, authentication, profiles

**Key Schemas:**
- `User` - OAuth data, profile, settings
- `UserProfile` - Display name, avatar, preferences
- `UserStats` - Aggregate stats (total learned, streak, etc.)

**Key Functions:**
- `register_user_with_oauth/1` - Google OAuth flow
- `get_user_by_email/1`, `get_user!/1`
- `update_profile/2`, `update_settings/2`

### 2. Content Context (`lib/medoru/content/`)
**Responsibility:** Kanji, readings, words, lessons - the learning material

**Key Schemas:**
- `Kanji` - Character, meanings, stroke count, JLPT level, stroke order data
- `KanjiReading` - Individual reading (on/kun) with type, romaji, and usage notes
- `Word` - Word text, meaning, difficulty, associated kanji
- `WordKanji` - Join table linking words to specific kanji AND specific readings
- `Lesson` - Title, description, ordered kanji list, difficulty
- `GrammarLesson` - Grammar patterns for validation
- `GrammarPattern` - Individual grammar patterns
- `WordConjugation` - Verb conjugations with alternative forms

**Key Functions:**
- `list_kanji_by_level/1` - Filter by N1-N5
- `get_word_with_readings/1` - Load word with kanji and their specific readings used
- `create_lesson/1`, `list_lessons/0`, `get_lesson!/1`

**Data Relationships:**
```
Kanji (id, character, meanings[], stroke_count, jlpt_level, stroke_data)
  ↓ (has many)
KanjiReading (id, kanji_id, reading_type, reading, romaji, usage_notes)
  ↓ (referenced by)
WordKanji (word_id, kanji_id, kanji_reading_id, position)
  ↓ (belongs to)
Word (id, text, meaning, difficulty, usage_frequency)
```

**Critical Design:**
- `kanji_readings` table stores each reading separately (e.g., "日" has 4 readings: ニチ, ジツ, ひ, か)
- `word_kanjis` table references BOTH the kanji AND the specific reading used
- This allows words to correctly link to which reading they use (e.g., "日本" uses ニチ not ジツ)
- `word_conjugations.alternative_forms` handles contracted forms (e.g., 来ない→来な)

### 3. Learning Context (`lib/medoru/learning/`)
**Responsibility:** User progress, lessons, daily reviews, SRS scheduling

**Key Schemas:**
- `UserProgress` - Which kanji/words user has learned, mastery level
- `LessonProgress` - Started/completed lessons, completion date
- `DailyStreak` - Streak tracking, last study date
- `ReviewSchedule` - SRS data (next review, interval, ease factor)

**Key Functions:**
- `start_lesson/2` - Begin lesson for user
- `complete_lesson/2` - Finish lesson, update progress
- `generate_daily_review/1` - Get due reviews + new words for daily study
- `update_streak/1` - Update streak logic
- `record_review/3` - Record SRS review with SM-2 algorithm

### 4. Tests Context (`lib/medoru/tests/`)
**Responsibility:** Multi-step test system for assessments and daily reviews

**Key Schemas:**
- `Test` - Test definition (daily, lesson, teacher, practice types)
- `TestStep` - Individual questions within a test
- `TestSession` - User's attempt at a test (tracks progress step-by-step)
- `TestStepAnswer` - User's answer to a specific step

**Test Types:**
- `:daily` - Auto-generated daily review test
- `:lesson` - Test at the end of a lesson
- `:teacher` - Custom test created by teachers
- `:practice` - Self-practice test

**Step Types:**
- `:reading`, `:writing`, `:listening`, `:grammar`, `:speaking`, `:vocabulary`

**Question Types:**
- `:multichoice` - Multiple choice (1 point)
- `:fill` - Fill in the blank (2 points)
- `:match` - Matching pairs (2 points)
- `:order` - Put in correct order (2 points)
- `:reading_text` - Text input (2 points)
- `:writing` - Kanji drawing (5 points)

**Key Functions:**
- `create_test/1`, `publish_test/1` - Test management
- `create_test_step/2`, `create_test_steps/2` - Add questions
- `start_test_session/2` - Begin taking a test
- `record_step_answer/3` - Submit answer with auto-scoring
- `complete_session/4` - Finish test and calculate score
- `get_user_test_stats/1`, `get_test_stats/1` - Analytics

**Scoring & Penalties:**
- Base points based on question type
- -25% per extra attempt beyond first
- -10% per hint used
- Minimum 10% of base points if correct

### 5. Classroom Context (`lib/medoru/classrooms/`)
**Responsibility:** Classroom management, memberships, tests

**Key Schemas:**
- `Classroom` - Name, slug, invite code, teacher
- `ClassroomMembership` - Student applications, status workflow
- `ClassroomTest` - Tests published to classrooms
- `ClassroomTestAttempt` - Student test attempts with points

**Key Functions:**
- `create_classroom/1` - Create with auto-generated slug and invite code
- `join_classroom/2` - Student application workflow
- `approve_membership/2`, `reject_membership/2` - Teacher moderation
- `publish_test_to_classroom/2` - Make test available to students
- `record_test_attempt/3` - Track completion and points

### 6. Gamification Context (`lib/medoru/gamification/`)
**Responsibility:** Scores, achievements, leaderboards

**Key Schemas:**
- `Score` - XP, level, category breakdown
- `Achievement` - Unlockable achievements
- `UserAchievement` - Join table with unlock date
- `LeaderboardEntry` - Cached rankings

### 7. Grammar Context (`lib/medoru/grammar/`)
**Responsibility:** Grammar validation and pattern matching

**Key Modules:**
- `Grammar.Validator` - Validates sentences against patterns
- `Grammar.ValidatorCache` - ETS cache for O(1) lookups
- `Grammar.Pattern` - Pattern component representation

**Key Features:**
- Pattern validation with word type matching
- Alternative forms support (contracted Japanese)
- ETS caching for performance (50x improvement)

### 8. Social Context (`lib/medoru/social/`)
**Responsibility:** User directory, search, blocking, following, tags

**Key Schemas:**
- `UserBlock` - Blocker/blocked relationship with reason and timestamp
- `Tag` - Curated official tags with category, color, slug
- `UserTag` - Join table linking users to tags (max 15 per user)
- `Follow` - One-way follow relationship (Twitter-style)

**Key Functions:**
- `list_users/2`, `search_users/3`, `count_users/1` - Directory with blocking filter
- `follow_user/2`, `unfollow_user/2`, `following?/2` - Follow management
- `count_followers/1`, `count_following/1`, `list_followers/2`, `list_following/2` - Follow stats
- `list_tags/0`, `list_tags_paginated/1`, `create_tag/1`, `update_tag/2`, `delete_tag/1` - Tag CRUD
- `set_user_tags/2`, `list_user_tags/1`, `list_user_tag_ids/1` - User tag selection
- `block_user/3`, `unblock_user/2`, `is_blocked?/2`, `blocked_by?/2` - Blocking
- `can_message?/2` - Messaging permission check

### 9. Chat Context (`lib/medoru/chat/`)
**Responsibility:** Conversations, messages, file uploads, reactions, typing indicators, read receipts, end-to-end encryption

**Key Schemas:**
- `Conversation` - 1:1 or group chat with `is_group`/`title`
- `ConversationParticipant` - User's participation with `joined_at`, `is_archived`
- `ConversationKey` - E2E encrypted AES key per participant (RSA-OAEP 2048 wrapped)
- `Message` - Chat message with `message_type`, `file_data`, `reply_to_id`
- `MessageReaction` - Emoji reaction (one per user per message, add/remove/replace)

**Key Functions:**
- `send_message/3`, `list_messages/2` - Message CRUD
- `toggle_reaction/3` - Add/remove/replace emoji reaction
- `list_reactions_for_messages/2` - Batch load reactions as `%{message_id => %{emoji => %{count, me?}}}`
- `broadcast_reaction/5` - PubSub broadcast excluding sender
- `ensure_conversation_key/2` - E2E key generation and distribution

---

## Critical Business Rules

### Learning Algorithm
- **New Lesson:** User must complete previous lesson OR placement test
- **Daily Test:** SRS-based review (words due for review) + 5 new words if available
- **Mastery Levels:** 
  - 0: New
  - 1-3: Learning (review intervals: 1d, 3d, 7d)
  - 4: Mastered (review interval: 30d)
- **Streak:** Break if no daily test completed by 23:59 user timezone

### Duel Fairness
- **Question Pool:** Intersection of both users' learned words
- **Minimum Pool:** If intersection < 10, use learned words of less advanced user
- **Difficulty:** Match average difficulty of both players
- **Ranking:** ELO system, K-factor 32, starting rating 1000

### Data Integrity
- **Kanji Uniqueness:** Character field unique, validate Unicode range
- **Word Readings:** Must reference valid kanji_reading records
- **Progress Tracking:** Immutable history, no deletion of test records

---

## Phoenix Conventions (Strict)

### Context Pattern
```
lib/medoru/accounts.ex          # Public API
lib/medoru/accounts/
  ├── user.ex                   # Schema + changesets
  ├── user_profile.ex
  └── user_stats.ex
```

### LiveView Structure
```
lib/medoru_web/live/
├── dashboard_live.ex           # Main learning dashboard
├── lesson_live/
│   ├── index.ex               # Lesson list
│   ├── show.ex                # Individual lesson
│   └── test.ex                # Lesson test mode
├── classroom_live/
│   ├── index.ex               # Student classrooms
│   ├── show.ex                # Classroom detail
│   └── test.ex                # Taking tests
├── teacher/
│   ├── classroom_live/        # Teacher management
│   └── test_live/             # Test creation
└── admin/
    ├── user_live.ex           # User management
    ├── kanji_live.ex          # Kanji management
    ├── word_live.ex           # Word management
    └── lesson_live.ex         # Lesson management
```

### Testing Requirements
- **Unit:** Context functions with sandbox
- **Integration:** LiveView tests with `PhoenixTest`
- **Factories:** ExMachina for User, Kanji, Word generation
- **Coverage:** 80%+ for contexts, 60%+ for LiveView

---

## Japanese Data Handling

### Kanji Storage
```elixir
%Kanji{
  character: "日",
  meanings: ["sun", "day", "Japan"],
  stroke_count: 4,
  jlpt_level: 5,
  stroke_data: %{svg: "...", paths: [...]}, # JSONB
  radicals: ["日"],
  frequency: 1
}
```

### KanjiReading Storage
```elixir
%KanjiReading{
  kanji_id: 1,
  reading_type: :on,  # :on or :kun
  reading: "ニチ",    # Katakana for on, hiragana for kun
  romaji: "nichi",
  usage_notes: "Used in compound words, formal readings"
}
```

### Word Storage with Reading Links
```elixir
%Word{
  text: "日本",
  meaning: "Japan",
  difficulty: 5,
  word_kanjis: [
    %WordKanji{
      position: 0,
      kanji: %Kanji{character: "日"},
      kanji_reading: %KanjiReading{reading: "ニチ", reading_type: :on}
    },
    %WordKanji{
      position: 1,
      kanji: %Kanji{character: "本"},
      kanji_reading: %KanjiReading{reading: "ホン", reading_type: :on}
    }
  ]
}
```

### Word Conjugations with Alternative Forms
```elixir
%WordConjugation{
  word_id: 1,
  grammar_form_id: 1,
  conjugated_form: "来ない",      # Full nai-form
  alternative_forms: ["来な"],     # Contracted form for combining
  reading: "こない"
}
```

### Word Reading Logic
Words store full reading in hiragana, but derive from specific kanji_reading records:
- "日本" -> reading "にほん" (from 日=ニチ + 本=ホン)
- System validates that word references valid kanji_reading IDs
- This ensures the reading shown matches the actual kanji readings used

---

## Development Workflow

### Database Seeding
```bash
mix run priv/repo/seeds.exs
```
Loads N5-N4 kanji, their readings, and ~500 common words with proper reading references from JSON files.

### Daily Operations
```bash
mix phx.server                    # Dev server
mix test                          # Full test suite
mix test.watch                    # Auto-run on changes
iex -S mix phx.server             # Interactive dev
```

### Code Quality Gates (Pre-Commit)
```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

---

## Kimi-Specific Instructions

### When Implementing Features:
1. **Start with Context:** Write schema + migration + context functions first
2. **Test Context:** Write unit tests for all public functions
3. **Build LiveView:** Create LiveView with mount/render/handle_event
4. **Test LiveView:** Use `PhoenixTest` for user flows
5. **Verify:** Run full test suite, fix any failures

### For Japanese Content:
- **NEVER** hardcode kanji in tests (use fixtures)
- **ALWAYS** validate Unicode: kanji must be in CJK Unified Ideographs range
- **CONSIDER** font rendering: test with common Japanese fonts
- **ENSURE** kanji_readings are properly linked in word_kanjis

### For Duels (Real-time):
- Use `Phoenix.PubSub` for broadcasting duel state
- Handle disconnects gracefully (pause/resume)
- Validate all inputs server-side (prevent cheating)

### When Adding Migrations:
- Provide `up` AND `down` functions
- Use `execute/1` for complex SQL with safety checks
- Never modify existing migrations that are deployed

---

## File Locations Quick Reference

| Type | Path |
|------|------|
| Contexts | `lib/medoru/{context}.ex` + `lib/medoru/{context}/` |
| LiveViews | `lib/medoru_web/live/*_live.ex` |
| Components | `lib/medoru_web/components/` |
| Tests | `test/medoru/{context}_test.exs`, `test/medoru_web/live/*_test.exs` |
| Seeds | `priv/repo/seeds/` |
| Static assets | `priv/static/` |
| Config | `config/runtime.exs` (env vars) |
| Logs | `.agents/logs/` |
| Skills | `.agents/skills/` |

---

## Project Guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 Guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your custom classes must fully style the input

### JS and CSS Guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & Design Guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions

---

## Boundaries

- ✅ **Always:** Run full test suite before claiming complete
- ✅ **Always:** Use changesets for data validation
- ✅ **Always:** Add indexes on foreign keys and frequently queried fields
- ✅ **Always:** Ensure word_kanjis references valid kanji_reading records
- ⚠️ **Ask first:** New dependencies, OAuth provider changes, database schema changes affecting existing data
- 🚫 **Never:** Store OAuth secrets in code, modify user progress history directly, skip database transactions for multi-step operations
- 🚫 **Never:** Allow orphaned kanji_readings or word_kanjis without proper references

---

## Additional Resources

### QA Testing with Playwright
The project includes a comprehensive E2E testing suite in the `/qa` directory using Playwright.

```bash
bin/qa setup       # Setup QA environment
bin/qa server      # Start QA server (port 4001)
bin/qa test        # Run all tests
bin/qa test:ui     # UI mode for debugging
```

See `qa/README.md` for full documentation.

### Logs and Planning
- **Current State**: See top of this file
- **v0.6.0 Plan**: [.agents/logs/PLAN-v0.6.0.md](.agents/logs/PLAN-v0.6.0.md)
- **Iteration Logs**: [.agents/logs/ITERATION-*.md](.agents/logs/)
- **Skills**: [.agents/skills/](.agents/skills/)

---

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->


<!-- phoenix:elixir-start -->
## phoenix:elixir usage
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages


<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## phoenix:ecto usage
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied

<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## phoenix:liveview usage
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

<!-- phoenix:liveview-end -->

## QA Testing with Playwright

The project includes a comprehensive E2E testing suite in the `/qa` directory using Playwright.

### Quick Start

```bash
# Setup everything (one-time)
bin/qa setup

# Start QA server (runs on port 4001, separate from dev on 4000)
bin/qa server

# In another terminal, run tests
bin/qa test

# Or use UI mode for debugging
bin/qa test:ui
```

### QA Environment

- **Port**: 4001 (dev runs on 4000 simultaneously)
- **Database**: `medoru_qa` (isolated from dev/test/prod)
- **Config**: `config/qa.exs`
- **Auth**: OAuth bypass for test users (via `/qa/bypass`)

### Test Users (Pre-seeded)

| Email | Type | Description |
|-------|------|-------------|
| `admin@qa.test` | admin | Full admin access |
| `teacher@qa.test` | teacher | Teacher with classrooms |
| `student@qa.test` | student | Regular student |
| `studentadvanced@qa.test` | student | Advanced (50 lessons, 15-day streak) |
| `studentnew@qa.test` | student | New student (3 lessons) |

See `qa/fixtures/users.ts` for all 18 test users.

### Writing QA Scenarios

1. Create a file in `qa/scenarios/`:
```typescript
import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../fixtures/users';
import { createAuthHelper, navigateTo } from '../helpers';

test('description', async ({ page }) => {
  const auth = createAuthHelper(page);
  await auth.login(TEST_USERS.student);
  await navigateTo(page, 'dashboard');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
```

2. Run the test:
```bash
npx playwright test scenarios/my-test.spec.ts --headed
```

### QA Commands

```bash
bin/qa setup       # Setup QA environment
bin/qa server      # Start QA server
bin/qa test        # Run all tests
bin/qa test:ui     # UI mode for debugging
bin/qa seed        # Reseed test data
bin/qa reset       # Reset DB and reseed
```

### Mix Aliases

```bash
mix qa.setup       # Setup DB and seed
mix qa.seed        # Just seed data
mix ecto.qa        # Create/migrate QA DB
mix ecto.reset.qa  # Reset QA DB
```

See `qa/README.md` for full documentation.

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->


## Future Battle Refinement Ideas (Paused)

The ability/infusion work is feature-complete for v0.x. Next focus: **map events**.

Future refinement ideas for the battle system, recorded for later:

- **Dynamic enemy infusions**: Give enemy AI `infuse_*` abilities and let it combine elements mid-fight (e.g. infuse fire → wind slash = blaze), using the same reaction table as the player.
- **More enemy variety**: Add water/void/poison themed enemies with distinct sprites and ability sets.
- **Infusions for mage/archer**: Extend `infusableWith` tags and level-banded kanji pools to mage/archer weapon/shield abilities.
- **Balance & tuning pass**: Adjust combo damage multipliers, base effect proc chances, enemy HP/stamina scaling, and gold drops after play-testing.
- **Sound & music**: Add elemental hit SFX, combo reaction sounds, and battle music.
- **Advanced VFX**: Particle bursts for statuses, element-specific attack animations.

Current battle system state:
- Infusion reactions, combo elements, and base elemental hit effects implemented.
- Enemy combo-element attacks added (blaze, magma, chaos, dust).
- Combat log history, pagination, elemental damage colors, screen flash/shake.
- Status effect icons with turn counters.
- Ember recoil scales down with mana / kanji quality.
- Enemy word/kanji challenges now reveal the correct answer on failure.
