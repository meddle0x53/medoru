# Medoru v0.1.0 Iteration Plan

## Overview
This document outlines the iterations required to reach Medoru version 0.1.0. Each iteration builds upon the previous ones and follows the iteration-based development workflow.

---

## Iteration 8: User Types & Admin Foundation

**Goal**: Establish the role system and admin infrastructure

### Tasks
1. **Database Schema**
   - Add `type` field to `users` table (enum: `:student`, `:teacher`, `:admin`, default: `:student`)
   - Migration with index on `type` for querying

2. **User Schema Updates**
   - Update `User` schema with `type` field
   - Add validation for role enum
   - Add helper functions: `admin?/1`, `teacher?/1`, `student?/1`

3. **Authorization Foundation**
   - Create `MedoruWeb.Admin` module for admin-only plugs/live_session
   - Create `MedoruWeb.Teacher` module for teacher+admin access

4. **Admin Interface - User Management**
   - Route: `/admin/users` - List all users with pagination
   - Route: `/admin/users/:id/edit` - Edit user type
   - LiveView: `Admin.UserLive.Index` with user table
   - LiveView: `Admin.UserLive.Edit` with role selector
   - Search/filter by email, name, type

5. **First Admin Setup**
   - Mix task: `mix medoru.make_admin email@example.com`
   - Or config-based initial admin emails

### Deliverables
- Users have types: student, teacher, admin
- Admin can view all users and change their types
- Admin interface is protected (only admins can access)

---

## Iteration 9: Enhanced Profiles - Display Name, Avatar & Settings

**Goal**: Allow users to customize their public profile

### Tasks
1. **Profile Schema Updates**
   - Ensure `display_name` is unique and validated
   - Avatar upload support (local storage or external URL)
   - Add `bio` field (optional, max 500 chars)
   - Add `preferred_badge_id` field (FK to badges, nullable)

2. **Avatar Handling**
   - Use Waffle or similar for file uploads
   - Generate thumbnails (64x64, 128x128, 256x256)
   - Default avatar if none uploaded

3. **Profile Settings LiveView**
   - Route: `/settings/profile`
   - Form: display name, avatar upload, bio, timezone, theme
   - Live validation for display name uniqueness
   - Avatar preview with drag-drop upload

4. **Public Profile Page**
   - Route: `/users/:id` or `/u/:display_name`
   - Shows: avatar, display name, bio, equipped badge, stats
   - List of earned badges (clickable to see details)

5. **Navigation Updates**
   - Show display name instead of email in header
   - Avatar in header dropdown

### Deliverables
- Users can set unique display name and avatar
- Public profile pages accessible to all users
- Settings page for profile management

---

## Iteration 10: Badge System Foundation

**Goal**: Create the badge/achievement system structure

### Tasks
1. **Badge Schema**
   ```elixir
   %Badge{
     name: String,           # "First Steps", "Streak Master", etc.
     description: String,    # "Complete your first lesson"
     icon: String,           # SVG path or icon name
     color: String,          # Badge color theme
     category: :lesson | :streak | :test | :duel | :social | :special,
     requirement_type: String,  # "lessons_completed", "streak_days", etc.
     requirement_value: Integer, # threshold value
     secret: Boolean         # Hidden until earned?
   }
   ```

2. **UserBadge Schema**
   - Join table: `user_badges`
   - Fields: `earned_at`, `progress` (for multi-step badges)

3. **Badge Service Module**
   - `Gamification.check_and_award_badges/1` - Check all badges for user
   - `Gamification.award_badge/2` - Grant badge to user
   - `Gamification.progress_toward/2` - Update progress on specific badge

4. **Badge Detection System**
   - Hooks in lesson completion → check lesson badges
   - Hooks in streak updates → check streak badges
   - Hooks in test completion → check test badges

5. **Badge Display Components**
   - `<.badge_icon>` component with tooltip
   - Badge grid component for profile
   - "New badge earned!" toast notification

6. **Seed Badges**
   - `first_lesson` - Complete first lesson
   - `streak_3`, `streak_7`, `streak_30` - Streak achievements
   - `test_perfect` - 100% on a test
   - `learner_10`, `learner_50`, `learner_100` - Words learned milestones

### Deliverables
- Badge system with schema and awarding logic
- Auto-award on relevant actions
- Badges display on profiles
- Users can select "featured badge" for profile

---

## Iteration 11: Multi-Step Test System Architecture

**Goal**: Redesign tests to support steps with different types and subtypes

### Tasks
1. **Test Schema Redesign**
   ```elixir
   %Test{
     name: String,
     description: String,
     created_by_id: user_id | nil,  # nil = system-generated (daily)
     test_type: :daily | :lesson | :custom | :classroom,
     status: :created | :ready | :published,  # for teacher tests
     classroom_id: nil | id,  # nil = public, otherwise classroom-only
     step_count: Integer,     # default 10
     time_limit_minutes: Integer | nil,
     total_points: Integer,
     inserted_at, updated_at
   }
   ```

2. **TestStep Schema**
   ```elixir
   %TestStep{
     test_id: id,
     position: Integer,       # Order in test (0, 1, 2...)
     step_type: :reading | :writing | :listening | :grammar | :speaking,
     sub_type: :multichoice | :fill | :match | :order,  # per type variants
     
     # Content (JSONB for flexibility)
     content: %{
       question: String,
       # For multichoice:
       options: [String],
       correct_answer: String,
       # For fill:
       accepted_answers: [String],  # Multiple correct variations
       case_sensitive: Boolean,
       # Reference to content:
       kanji_id: nil | id,
       word_id: nil | id,
       lesson_id: nil | id
     },
     
     points: Integer,         # Default: multichoice=1, fill=2
     difficulty: 1..5
   }
   ```

3. **TestSession Schema Updates**
   ```elixir
   %TestSession{
     user_id: id,
     test_id: id,
     status: :in_progress | :completed | :abandoned,
     started_at: DateTime,
     completed_at: DateTime | nil,
     total_steps: Integer,
     current_step: Integer,   # Current position
     score: Integer,          # Total points earned
     max_possible_score: Integer,
     
     has_many :step_answers, TestStepAnswer
   }
   ```

4. **TestStepAnswer Schema**
   ```elixir
   %TestStepAnswer{
     test_session_id: id,
     test_step_id: id,
     position: Integer,
     answer_given: String,
     correct: Boolean,
     points_earned: Integer,
     answered_at: DateTime,
     time_spent_seconds: Integer
   }
   ```

5. **Test Context Module**
   - `Tests.create_test/1` - Create test with steps
   - `Tests.publish_test/1` - Change status to published
   - `Tests.start_test_session/2` - Begin taking a test
   - `Tests.submit_step_answer/3` - Submit answer for current step
   - `Tests.complete_test_session/1` - Finalize and calculate score
   - `Tests.get_test_with_steps/1` - Load test and all steps
   - `Tests.get_session_with_answers/1` - Load session progress

6. **Step Type: Reading - Multichoice**
   - Port existing multichoice logic
   - Generate options from similar kanji/words
   - Support meaning→kanji, reading→kanji, kanji→meaning, kanji→reading

7. **Step Type: Reading - Fill**
   - Text input validation
   - Multiple accepted answers (hiragana/katakana variations)
   - Fuzzy matching for common mistakes
   - Visual feedback: correct/incorrect with correct answer shown

### Deliverables
- New test architecture with steps
- Support for multichoice (1 point) and fill (2 points) in reading
- Test sessions track progress step by step
- Backward compatibility or migration for existing tests

---

## Iteration 12: Teacher Test Creation Interface

**Goal**: Teachers can create custom tests with steps

### Tasks
1. **Test Builder LiveView - Overview**
   - Route: `/teacher/tests` - List teacher's tests
   - Route: `/teacher/tests/new` - Create new test
   - Test list shows: name, status, step count, classroom

2. **Test Creation Flow**
   - Step 1: Test details (name, description, step count, classroom visibility)
   - Step 2: Build steps one by one
   - Step 3: Review and publish

3. **Step Builder Component**
   - Select step type (reading/writing/etc.)
   - Select sub-type (multichoice/fill)
   - For reading steps:
     - Search/select kanji or word from database
     - Auto-populate question based on selection
     - For multichoice: auto-generate distractors, editable
     - For fill: set accepted answers, case sensitivity
   - Preview step before saving
   - Drag-drop reordering of steps

4. **Test Status Workflow**
   - `created` - Initial state, being built
   - `ready` - All steps added, can be published
   - `published` - Visible to students
   - Actions: Save draft, Preview, Publish, Unpublish, Delete

5. **Test Preview Mode**
   - Teacher can take the test as a student would
   - See all steps and verify correct answers
   - Points calculation preview

6. **Test Management**
   - Duplicate test (clone for modification)
   - Archive old tests
   - View stats: attempts, average scores

### Deliverables
- Teachers can create multi-step tests
- Step-by-step builder with kanji/word selection
- Test workflow: created → ready → published
- Only published tests visible to students

---

## Iteration 13: Auto-Generated Daily Tests

**Goal**: System automatically creates personalized daily tests

### Tasks
1. **Daily Test Generator Service**
   - `DailyTests.generate_for_user/1`
   - Algorithm:
     1. Get SRS due reviews (words/kanji due for review today)
     2. Fill remaining slots with new/unlearned items (up to 5 new)
     3. Mix reading multichoice and fill questions
     4. Balance difficulty based on user level

2. **Question Generation Logic**
   - From ReviewSchedule: Create steps for due items
   - For kanji: meaning→kanji, reading→kanji
   - For words: meaning→reading (fill), reading→meaning (multichoice)
   - Prioritize fill questions for higher mastery items

3. **Daily Test Availability**
   - One daily test per user per day
   - Generated on first visit after midnight (user timezone)
   - Available until 23:59 user timezone
   - Must be completed to maintain streak

4. **Daily Test LiveView**
   - Route: `/daily` - Shows today's test or "Completed" state
   - Progress bar: X of N steps
   - Step renderer based on type/subtype
   - Summary page: score, correct/incorrect breakdown, XP earned

5. **Streak Integration**
   - Completing daily test updates streak
   - Reminder logic (can be future feature)

6. **Review Schedule Updates**
   - After test: update SRS intervals based on correctness
   - Correct: increase interval, boost ease factor
   - Incorrect: reset interval, decrease ease factor

### Deliverables
- Auto-generated daily test per user
- SRS-based review items + new words
- Mix of multichoice and fill questions
- Streak tracking integration

---

## Iteration 14: Vocabulary Lesson System

**Goal**: System-generated vocabulary lessons and teacher-created classroom lessons

### Tasks
1. **Lesson Schema Updates**
   ```elixir
   %Lesson{
     title: String,
     description: String,
     lesson_type: :kanji | :vocabulary | :grammar,  # Add :vocabulary
     difficulty: 1..5,          # JLPT level N5-N1
     status: :system | :teacher_custom | :published,
     created_by_id: user_id | nil,  # nil = system-generated
     classroom_id: user_id | nil,   # nil = global, otherwise classroom-specific
     position: Integer,         # Order within difficulty level
     
     has_many :lesson_words, LessonWord  # Join table to words
   }
   ```

2. **LessonWord Schema** (extends existing LessonKanji pattern)
   ```elixir
   %LessonWord{
     lesson_id: id,
     word_id: id,
     position: Integer,         # Order within lesson (0, 1, 2...)
     is_new_kanji: Boolean      # True if word introduces new kanji
   }
   ```

3. **Vocabulary Lesson Structure**
   - 3-5 words per lesson
   - Words organized by JLPT level (N5 → N1)
   - Progressive difficulty: mix of words with learned kanji + 1-2 new kanji
   - System lessons auto-numbered: "Vocabulary N5-01", "Vocabulary N5-02", etc.

4. **Lesson Generation Algorithm** (System Lessons)
   ```elixir
   # Pseudocode for generating vocabulary lessons
   def generate_vocabulary_lessons(jlpt_level) do
     words = get_words_by_level(jlpt_level) |> sort_by_difficulty()
     
     lessons = []
     learned_kanji = MapSet.new()
     current_lesson_words = []
     new_kanji_in_lesson = MapSet.new()
     
     for word <- words do
       word_kanji = get_kanji_in_word(word)
       new_kanji = MapSet.difference(word_kanji, learned_kanji)
       
       cond do
         # Start new lesson if current is full (5 words)
         length(current_lesson_words) >= 5 ->
           lessons = [create_lesson(current_lesson_words) | lessons]
           learned_kanji = MapSet.union(learned_kanji, new_kanji_in_lesson)
           current_lesson_words = [word]
           new_kanji_in_lesson = new_kanji
           
         # Limit new kanji per lesson (max 2 new characters)
         MapSet.size(new_kanji) > 2 ->
           # Skip word for now, will appear in later lesson
           :skip
           
         # Word fits in current lesson
         true ->
           current_lesson_words = [word | current_lesson_words]
           new_kanji_in_lesson = MapSet.union(new_kanji_in_lesson, new_kanji)
       end
     end
     
     # Save remaining words as final lesson
     if current_lesson_words != [], do: [create_lesson(current_lesson_words) | lessons]
   end
   ```

5. **Lesson Generation Mix Task**
   - `mix medoru.generate_lessons` - Generate system vocabulary lessons
   - `--level N5` - Generate for specific level
   - `--all` - Generate for all levels
   - Idempotent: Can re-run without duplicating

6. **Teacher Custom Lessons (Classroom)**
   - Teachers can create custom lessons for their classroom
   - Route: `/teacher/classrooms/:id/lessons/new`
   - Search and select words from database
   - Preview lesson before publishing
   - Custom lessons only visible to classroom students
   - Status: `:teacher_custom` → `:published`

7. **Lesson Index & Display**
   - Route: `/lessons` - All system lessons (vocabulary + kanji)
   - Filter by: type (vocabulary/kanji), JLPT level
   - Progress indicator: X/Y lessons completed
   - Vocabulary lesson card shows: preview of words, new kanji count

8. **Lesson Learning Interface**
   - Word cards with: kanji, readings, meaning, example sentences
   - Mark which kanji are new in this lesson
   - "Mark as Learned" button
   - Mini-test at end (3-5 questions on lesson words)

### Deliverables
- Vocabulary lessons (3-5 words each) for all JLPT levels
- System-generated lessons following progression algorithm
- Teachers can create custom lessons for classrooms
- Lesson index with filtering and progress tracking

### Notes
- The full vocabulary lesson generation (covering ALL words) will be done after the complete Japanese vocabulary is imported
- Initial implementation can use seed/test data
- The generation algorithm is designed to be re-run as new vocabulary is added
- For now, we support vocabulary lessons only; kanji-only and grammar lessons are future work

---

## Iteration 15: Kanji Stroke Animation

**Goal**: Store and display kanji stroke order animations

### Tasks
1. **Kanji Schema Update**
   - Add `stroke_svg` field (text/blob for SVG paths)
   - OR: Add `stroke_data` JSONB with structured path data
   - Consider: `animation_speed` preference

2. **Stroke Data Format**
   ```elixir
   %{
     view_box: "0 0 109 109",
     strokes: [
       %{
         path: "M 30 30 Q 50 20 70 30",
         stroke_num: 1,
         timing: 500  # ms
       },
       ...
     ],
     total_duration: 5000
   }
   ```

3. **Stroke Animation Component**
   - `<.kanji_stroke_animation>` component
   - Props: kanji, autoplay, speed, show_numbers
   - Controls: Play, Pause, Reset, Step forward/backward
   - Visual: Stroke drawing with SVG path animation

4. **Data Import**
   - Script to import KanjiVG data (open source SVG kanji)
   - Migration to populate stroke data for existing kanji

5. **Lesson Integration**
   - Show stroke animation in lesson detail
   - Toggle: "Show stroke order" button
   - Practice mode: trace overlay (future enhancement)

### Deliverables
- Kanji table stores stroke SVG/animation data
- Reusable stroke animation component
- Animation visible in lessons

---

## Iteration 16: Classroom System - Core

**Goal**: Create and manage classrooms

### Tasks
1. **Classroom Schema**
   ```elixir
   %Classroom{
     name: String,
     description: String,
     slug: String,            # URL-friendly identifier
     logo: String,            # Avatar URL/path
     invite_code: String,     # For easy joining
     status: :active | :archived,
     created_by_id: user_id,  # Original creator (always teacher)
     
     has_many :memberships, ClassroomMembership
     has_many :tests, Test  # Classroom-specific tests
   }
   ```

2. **ClassroomMembership Schema**
   ```elixir
   %ClassroomMembership{
     classroom_id: id,
     user_id: id,
     role: :teacher | :student,
     status: :pending | :approved | :rejected | :removed,
     joined_at: DateTime | nil,
     total_points: Integer,   # Accumulated classroom points
     
     # For student applications
     applied_at: DateTime,
     approved_by_id: user_id | nil,
     approved_at: DateTime | nil
   }
   ```

3. **Classroom Context**
   - `Classrooms.create_classroom/2` - Teacher creates
   - `Classrooms.update_classroom/2` - Edit details
   - `Classrooms.list_teacher_classrooms/1`
   - `Classrooms.list_student_classrooms/1`
   - `Classrooms.get_by_invite_code/1`

4. **Classroom Creation Interface**
   - Route: `/teacher/classrooms/new`
   - Form: name, description, logo upload
   - Auto-generate slug and invite code
   - Success: Redirect to classroom management

5. **Classroom Management (Teacher View)**
   - Route: `/teacher/classrooms/:id`
   - Tabs: Overview, Students, Lessons, Tests, Settings
   - Overview: Stats, recent activity
   - Students: List with points, kick option
   - Lessons: List custom lessons, create new (see Iteration 7)
   - Tests: List classroom tests, create new
   - Settings: Edit name, description, logo, regenerate invite code

### Deliverables
- Classroom creation and management
- Teacher can set logo, name, description
- Invite code system for joining

---

## Iteration 17: Classroom Membership & Applications

**Goal**: Student applications and teacher approvals

### Tasks
1. **Student Application Flow**
   - Route: `/classrooms/join` - Enter invite code
   - Search for classrooms by name
   - Submit application with optional message
   - View application status

2. **Teacher Approval Interface**
   - Notification badge for pending applications
   - Route: `/teacher/classrooms/:id/applications`
   - List pending applications with user info
   - Actions: Approve, Reject with reason
   - Bulk approve/reject

3. **Student Classroom View**
   - Route: `/classrooms` - List joined classrooms
   - Route: `/classrooms/:id` - Classroom dashboard
   - Shows: teacher info, class tests, rankings

4. **Membership Management**
   - Teacher can kick students (sets status to :removed)
   - Removed students lose access but keep history
   - Students can leave classroom voluntarily

5. **Notifications**
   - Application submitted → notify teachers
   - Application approved/rejected → notify student
   - New test published → notify students

### Deliverables
- Students can apply to classrooms
- Teachers approve/reject applications
- Kick/remove students functionality
- Notification system for membership events

---

## Iteration 18: Classroom Tests, Lessons & Rankings

**Goal**: Tests and lessons within classrooms with points and rankings

### Tasks
1. **Classroom Test Publishing**
   - When creating test, select "Classroom visibility"
   - Published tests only visible to classroom members
   - Test list filtered by membership

2. **Classroom Lesson Publishing**
   - Custom lessons created in Iteration 7 can be assigned to classroom
   - Lessons appear in classroom's lesson tab
   - Progress tracked per classroom

3. **Test Attempt Tracking**
   - `ClassroomTestAttempt` schema tracks attempts within classroom
   - Points contribute to classroom total
   - Best score counted for rankings

4. **Lesson Progress Tracking**
   - Track lesson completion within classroom context
   - Points for completing classroom lessons
   - Separate from system lesson progress

5. **Classroom Rankings**
   - Overall ranking: Total points across all tests and lessons
   - Per-test ranking: Best scores on specific tests
   - Per-lesson ranking: First to complete, best quiz scores
   - Leaderboard component with avatars and display names
   - Weekly/monthly/all-time filters

6. **Student Progress View**
   - Student sees their rank in classroom
   - Progress toward next rank
   - Completed tests and lessons with scores

7. **Teacher Analytics**
   - Class average scores per test/lesson
   - Student progress charts
   - Lesson completion rates
   - Identify struggling students

8. **Classroom LiveView Pages**
   - Student classroom dashboard with rankings
   - Test taking within classroom context
   - Lesson learning within classroom context
   - Results page with class average comparison

### Deliverables
- Tests and lessons can be published to classrooms
- Classroom-specific points and rankings (tests + lessons)
- Leaderboards (overall, per-test, per-lesson)
- Teacher analytics dashboard

---

## Iteration 19: Admin Dashboard & System Management

**Goal**: Complete admin interface for system oversight

### Tasks
1. **Admin Dashboard Overview**
   - Route: `/admin`
   - Stats: Total users, active today, new this week
   - Stats: Total kanji, words, lessons
   - Stats: Tests taken today, duels played

2. **Content Management**
   - CRUD for kanji (with stroke animation upload)
   - CRUD for words
   - CRUD for lessons
   - Bulk import from CSV/JSON

3. **Badge Management**
   - Create/edit badges
   - View badge statistics (how many earned)
   - Award badge manually to user

4. **Classroom Oversight**
   - List all classrooms
   - View classroom details and membership
   - Ability to archive/delete inappropriate classrooms

5. **System Settings**
   - Configure default daily test settings
   - Configure point values
   - Maintenance mode toggle

### Deliverables
- Comprehensive admin dashboard
- Content management (kanji, words, lessons)
- Badge management
- System-wide settings

---

## Summary Timeline

| Iteration | Feature Area | Est. Duration | Dependencies |
|-----------|--------------|---------------|--------------|
| 8 | User Types & Admin Foundation | 2-3 days | - |
| 9 | Enhanced Profiles | 2-3 days | Iteration 8 |
| 10 | Badge System | 2-3 days | Iteration 9 |
| 11 | Multi-Step Test System | 3-4 days | - |
| 12 | Teacher Test Creation | 3-4 days | Iteration 8, 11 |
| 13 | Daily Tests | 2-3 days | Iteration 11 |
| 14 | Vocabulary Lesson System | 3-4 days | - |
| 15 | Kanji Stroke Animation | 2-3 days | - |
| 16 | Classroom Core | 2-3 days | Iteration 8 |
| 17 | Classroom Membership | 2-3 days | Iteration 16 |
| 18 | Classroom Tests, Lessons & Rankings | 3-4 days | Iteration 12, 14, 16, 17 |
| 19 | Admin Dashboard | 2-3 days | All above |

**Total Estimated Duration**: 28-38 days of development

---

## Notes

- Iterations 11 (Test System) and 8-10 (User System) can potentially be done in parallel
- Iteration 14 (Vocabulary Lessons) and 15 (Kanji Animation) are mostly independent and can be done anytime
- Iterations 16-18 (Classroom) build sequentially
- Iteration 13 (Daily Tests) depends on 11, but can work with placeholder content until 14 is done
- These iterations (8-19) extend the v0.1.0 MVP milestone
- Each iteration includes tests and follows the review workflow

## Post-v0.1.0 Ideas

- Grammar lessons and tests
- Listening comprehension (audio) tests
- Speaking tests (voice recording)
- Writing tests (stroke recognition)
- Advanced duel modes
- Mobile app (React Native/Flutter)
- AI-powered learning recommendations
