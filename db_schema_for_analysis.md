# Medoru Database Schema

## Overview
Medoru is a Japanese language learning platform with PostgreSQL database. All primary keys are UUID (`binary_id`), foreign keys use `binary_id` type.

---

## 1. ACCOUNTS CONTEXT

### users
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| email | string | Unique |
| provider | string | OAuth provider (e.g., "google") |
| provider_uid | string | OAuth UID |
| name | string | Display name from OAuth |
| avatar_url | string | Profile image URL |
| type | string | Enum: student, teacher, admin (default: student) |
| moderator | boolean | Content manager flag (default: false) |
| timestamps | utc_datetime | created_at, updated_at |

**Relationships:**
- has_one :profile → user_profiles
- has_one :stats → user_stats

**Indexes:**
- UNIQUE (email)
- UNIQUE (provider, provider_uid)

---

### user_profiles
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| display_name | string | Custom display name (unique) |
| avatar | string | Custom avatar path |
| bio | string | User bio (max 500 chars) |
| timezone | string | Default: "UTC" |
| daily_goal | integer | Default: 10 |
| theme | string | Enum: light, dark, system |
| daily_test_step_types | string[] | Array of question types |
| featured_badge_id | integer (FK) | → badges |
| timestamps | utc_datetime | |

**daily_test_step_types values:** word_to_meaning, word_to_reading, reading_text, image_to_meaning, kanji_writing

---

### user_stats
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| total_kanji_learned | integer | Default: 0 |
| total_words_learned | integer | Default: 0 |
| current_streak | integer | Default: 0 |
| longest_streak | integer | Default: 0 |
| total_tests_completed | integer | Default: 0 |
| total_duels_played | integer | Default: 0 |
| total_duels_won | integer | Default: 0 |
| xp | integer | Default: 0 |
| level | integer | Default: 1 |
| timestamps | utc_datetime | |

---

### api_tokens
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| name | string | Token name |
| token_hash | string | Hashed token |
| expires_at | utc_datetime_usec | Expiration timestamp |
| last_used_at | utc_datetime_usec | Last usage |
| timestamps | utc_datetime_usec | |

---

## 2. CONTENT CONTEXT

### kanji
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| character | string | Single kanji character (UNIQUE) |
| meanings | string[] | Array of English meanings |
| stroke_count | integer | Number of strokes |
| jlpt_level | integer | JLPT level: 1-5 |
| school_level | integer | Japanese school level: 1-7 |
| stroke_data | map (jsonb) | SVG paths, stroke order |
| radicals | string[] | Array of radicals |
| frequency | integer | Usage frequency ranking |
| translations | map (jsonb) | %{"bg" => %{}, "ja" => %{}} |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (character)
- INDEX (jlpt_level)

---

### kanji_readings
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| kanji_id | binary_id (FK) | → kanji |
| reading_type | enum | :on (katakana) or :kun (hiragana) |
| reading | string | The reading in kana |
| romaji | string | Romanized reading |
| usage_notes | string | Usage context notes |
| timestamps | utc_datetime | |

**Indexes:**
- INDEX (kanji_id)

---

### words
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| text | string | Japanese word (UNIQUE) |
| meaning | string | English meaning |
| reading | string | Hiragana reading |
| difficulty | integer | 1-5 difficulty level |
| usage_frequency | integer | Default: 1000 |
| word_type | enum | :noun, :verb, :adjective, :adverb, :particle, :pronoun, :counter, :expression, :other |
| sort_score | integer | Pre-computed for lesson ordering |
| core_rank | integer | Core 6000 frequency rank |
| example_sentence | string | Example usage |
| example_reading | string | Reading of example |
| example_meaning | string | Meaning of example |
| translations | map (jsonb) | %{"bg" => %{}, "ja" => %{}} |
| image_path | string | Path to illustration image |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (text)
- INDEX (difficulty)
- INDEX (word_type)

---

### word_kanjis (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| word_id | binary_id (FK) | → words |
| kanji_id | binary_id (FK) | → kanji |
| kanji_reading_id | binary_id (FK) | → kanji_readings |
| position | integer | Position in word |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (word_id, kanji_id, position)
- INDEX (word_id)
- INDEX (kanji_id)

---

### lessons
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| title | string | Lesson title |
| description | string | Lesson description |
| difficulty | integer | 1-5 difficulty |
| order_index | integer | Ordering within difficulty |
| lesson_type | enum | :reading, :writing, :listening, :speaking, :grammar |
| translations | map (jsonb) | Localized title/description |
| test_id | binary_id (FK) | → tests (associated test) |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (difficulty, order_index)

---

### lesson_kanjis (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| lesson_id | binary_id (FK) | → lessons |
| kanji_id | binary_id (FK) | → kanji |
| position | integer | Order in lesson |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (lesson_id, position)
- UNIQUE (lesson_id, kanji_id)

---

### lesson_words (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| lesson_id | binary_id (FK) | → lessons |
| word_id | binary_id (FK) | → words |
| position | integer | Order in lesson |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (lesson_id, position)
- UNIQUE (lesson_id, word_id)

---

### custom_lessons (teacher-created)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| title | string | Lesson title |
| description | string | Lesson description |
| lesson_type | string | Default: "reading" |
| lesson_subtype | string | "vocabulary" or "grammar" |
| difficulty | integer | 1-5 |
| status | string | "draft", "published", "archived" |
| word_count | integer | Default: 0 |
| creator_id | binary_id (FK) | → users |
| requires_test | boolean | Default: false |
| include_writing | boolean | Default: false |
| steps_per_word | integer | Default: 3 |
| test_id | binary_id (FK) | → tests |
| timestamps | utc_datetime_usec | |

---

### custom_lesson_words (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| custom_lesson_id | binary_id (FK) | → custom_lessons |
| word_id | binary_id (FK) | → words |
| position | integer | Order in lesson |
| custom_meaning | string | Override default meaning |
| examples | string[] | Custom example sentences |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (custom_lesson_id, word_id)

---

### grammar_forms
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| name | string | Form identifier (e.g., "te_form") |
| display_name | string | Human-readable name |
| word_type | string | "verb", "adjective", "noun" |
| suffix_pattern | string | Pattern for detection |
| description | string | Explanation |
| examples | string[] | Example conjugations |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (name, word_type)

---

### word_conjugations
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| word_id | binary_id (FK) | → words (base form) |
| grammar_form_id | binary_id (FK) | → grammar_forms |
| conjugated_form | string | The conjugated text |
| reading | string | Reading in hiragana |
| alternative_forms | string[] | Contracted forms (e.g., "ない" → "な") |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (word_id, grammar_form_id)
- GIN INDEX (alternative_forms)

---

### word_classes (semantic categories)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| name | string | Unique identifier |
| display_name | string | Human-readable |
| description | string | |
| examples | string[] | |
| pattern | string | Regex pattern for matching |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (name)

---

### word_class_memberships (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| word_id | binary_id (FK) | → words |
| word_class_id | binary_id (FK) | → word_classes |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (word_id, word_class_id)

---

### grammar_lesson_steps
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| custom_lesson_id | binary_id (FK) | → custom_lessons |
| position | integer | Order in lesson |
| title | string | Step title |
| explanation | string | Grammar explanation |
| examples | map[] | Array of %{sentence, reading, meaning} |
| pattern_elements | map[] | Grammar pattern components |
| difficulty | integer | 1-5 |
| timestamps | utc_datetime_usec | |

---

## 3. LEARNING CONTEXT

### user_progress (SRS tracking)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| kanji_id | binary_id (FK) | → kanji (OR word_id) |
| word_id | binary_id (FK) | → words (OR kanji_id) |
| mastery_level | integer | 0=new, 1-3=learning, 4=mastered, 5=burned |
| times_reviewed | integer | Default: 0 |
| last_reviewed_at | utc_datetime | |
| next_review_at | utc_datetime | |
| timestamps | utc_datetime | |

**Constraint:** Exactly one of kanji_id or word_id must be set (not both, not neither)

**Indexes:**
- UNIQUE (user_id, kanji_id)
- UNIQUE (user_id, word_id)
- INDEX (user_id)
- INDEX (next_review_at)

---

### lesson_progress
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| lesson_id | binary_id (FK) | → lessons |
| status | enum | :started, :completed |
| started_at | utc_datetime | |
| completed_at | utc_datetime | |
| progress_percentage | integer | Default: 0 |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (user_id, lesson_id)

---

### daily_streaks
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| current_streak | integer | Default: 0 |
| longest_streak | integer | Default: 0 |
| last_study_date | date | |
| timezone | string | Default: "UTC" |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (user_id)

---

### review_schedules (SM-2 algorithm)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| user_progress_id | binary_id (FK) | → user_progress |
| next_review_at | utc_datetime | |
| interval | integer | Days until next review (default: 1) |
| ease_factor | float | SM-2 ease factor (default: 2.5) |
| repetitions | integer | Successful review count (default: 0) |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (user_id, user_progress_id)

---

### word_sets (user-created collections)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| name | string | Set name (max 100 chars) |
| description | string | Set description (max 500 chars) |
| word_count | integer | Default: 0 (max 100) |
| practice_test_id | binary_id (FK) | → tests |
| timestamps | utc_datetime_usec | |

---

### word_set_words (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| word_set_id | binary_id (FK) | → word_sets |
| word_id | binary_id (FK) | → words |
| position | integer | Order in set |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (word_set_id, word_id)

---

## 4. TESTS CONTEXT

### tests
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| title | string | Test title |
| description | string | Test description |
| test_type | enum | :daily, :lesson, :teacher, :practice |
| status | enum | :draft, :ready, :published, :archived |
| setup_state | string | "in_progress", "ready", "published", "archived" |
| total_points | integer | Default: 0 |
| time_limit_seconds | integer | Optional time limit (60-7200) |
| max_attempts | integer | Optional (1-10) |
| is_system | boolean | Default: false |
| metadata | map (jsonb) | Additional configuration |
| lesson_id | binary_id (FK) | → lessons (for lesson tests) |
| creator_id | binary_id (FK) | → users (for teacher tests) |
| timestamps | utc_datetime | |

---

### test_steps
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| test_id | binary_id (FK) | → tests |
| order_index | integer | Position in test |
| step_type | enum | :reading, :writing, :listening, :grammar, :speaking, :vocabulary |
| question_type | enum | :multichoice, :fill, :match, :order, :writing, :reading_text, :sentence_validation, :conjugation, :conjugation_multichoice, :word_order |
| question | string | The question text |
| question_data | map (jsonb) | Additional question configuration |
| correct_answer | string | Correct answer |
| options | string[] | Multiple choice options |
| points | integer | Default: 1 |
| hints | string[] | Available hints |
| explanation | string | Answer explanation |
| time_limit_seconds | integer | Per-step time limit |
| max_attempts | integer | Default: 5 |
| kanji_id | binary_id (FK) | → kanji (for writing questions) |
| word_id | binary_id (FK) | → words |
| timestamps | utc_datetime | |

**Point values by type:**
- multichoice: 1
- fill: 2
- match/order: 2
- reading_text: 2
- writing: 5
- sentence_validation: 10
- conjugation/conjugation_multichoice/word_order: 3

**Indexes:**
- UNIQUE (test_id, order_index)
- INDEX (test_id)

---

### test_sessions
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| test_id | binary_id (FK) | → tests |
| status | enum | :started, :in_progress, :completed, :abandoned, :timed_out |
| score | integer | Default: 0 |
| total_possible | integer | Default: 0 |
| percentage | float | Calculated score % |
| started_at | utc_datetime | |
| completed_at | utc_datetime | |
| time_spent_seconds | integer | Default: 0 |
| current_step_index | integer | Default: 0 |
| metadata | map (jsonb) | Session data |
| timestamps | utc_datetime | |

**Indexes:**
- INDEX (user_id, test_id)

---

### test_step_answers
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| test_session_id | binary_id (FK) | → test_sessions |
| test_step_id | binary_id (FK) | → test_steps |
| step_index | integer | Position in session |
| answer | string | User's answer |
| is_correct | boolean | |
| points_earned | integer | Default: 0 |
| time_spent_seconds | integer | Default: 0 |
| attempts | integer | Default: 1 |
| hints_used | integer | Default: 0 |
| answered_at | utc_datetime | |
| metadata | map (jsonb) | Additional answer data |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (test_session_id, step_index)

---

## 5. CLASSROOMS CONTEXT

### classrooms
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| name | string | Classroom name (3-100 chars) |
| slug | string | URL-friendly identifier (UNIQUE) |
| description | string | |
| invite_code | string | 8-character join code (UNIQUE) |
| status | enum | :active, :archived, :closed |
| settings | map (jsonb) | Configuration |
| teacher_id | binary_id (FK) | → users (creator) |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (slug)
- UNIQUE (invite_code)

---

### classroom_memberships
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| classroom_id | binary_id (FK) | → classrooms |
| user_id | binary_id (FK) | → users |
| status | enum | :pending, :approved, :rejected, :left, :removed |
| role | enum | :student, :assistant (default: student) |
| joined_at | utc_datetime | |
| points | integer | Default: 0 |
| settings | map (jsonb) | |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (classroom_id, user_id)

---

### classroom_tests (published tests)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| classroom_id | binary_id (FK) | → classrooms |
| test_id | binary_id (FK) | → tests |
| published_by_id | binary_id (FK) | → users |
| status | enum | :active, :archived, :unpublished |
| published_at | utc_datetime_usec | |
| unpublished_at | utc_datetime_usec | |
| due_date | utc_datetime | |
| max_attempts | integer | Override test default |
| settings | map (jsonb) | |
| publish_count | integer | Default: 1 |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (classroom_id, test_id)

---

### classroom_test_attempts
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| classroom_id | binary_id (FK) | → classrooms |
| user_id | binary_id (FK) | → users |
| test_id | binary_id (FK) | → tests |
| test_session_id | binary_id (FK) | → test_sessions |
| score | integer | Default: 0 |
| max_score | integer | |
| points_earned | integer | Default: 0 (can go negative, min 0) |
| time_limit_seconds | integer | |
| time_spent_seconds | integer | Default: 0 |
| time_remaining_seconds | integer | |
| started_at | utc_datetime_usec | |
| completed_at | utc_datetime_usec | |
| status | string | "in_progress", "completed", "timed_out" |
| auto_submitted | boolean | Default: false |
| reset_count | integer | Default: 0 |
| reset_at | utc_datetime_usec | |
| reset_by_id | binary_id (FK) | → users (teacher who reset) |
| ranking_score | decimal | Computed: points + time bonus |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (classroom_id, test_id, user_id)

---

### classroom_custom_lessons (published lessons)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| classroom_id | binary_id (FK) | → classrooms |
| custom_lesson_id | binary_id (FK) | → custom_lessons |
| published_by_id | binary_id (FK) | → users |
| status | string | "active", "unpublished" |
| due_date | date | |
| points_override | integer | |
| published_at | utc_datetime_usec | |
| unpublished_at | utc_datetime_usec | |
| order_index | integer | Default: 0 |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (classroom_id, custom_lesson_id)

---

### classroom_lesson_progress
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| classroom_id | binary_id (FK) | → classrooms |
| user_id | binary_id (FK) | → users |
| lesson_id | binary_id (FK) | → lessons (system lessons) |
| custom_lesson_id | binary_id (FK) | → custom_lessons |
| test_session_id | binary_id (FK) | → test_sessions |
| status | string | "not_started", "in_progress", "completed" |
| progress_percent | integer | Default: 0 |
| points_earned | integer | Default: 0 |
| lesson_source | string | "system" or "custom" |
| test_score | integer | |
| test_max_score | integer | |
| started_at | utc_datetime_usec | |
| completed_at | utc_datetime_usec | |
| timestamps | utc_datetime_usec | |

**Indexes:**
- UNIQUE (classroom_id, user_id, lesson_id)

---

## 6. GAMIFICATION CONTEXT

### badges
| Field | Type | Notes |
|-------|------|-------|
| id | integer (PK) | Auto-increment |
| name | string | Unique badge name |
| description | string | |
| icon | string | Icon identifier |
| color | string | Default: "blue" |
| criteria_type | enum | :manual, :streak, :kanji_count, :words_count, :lessons_completed, :daily_reviews |
| criteria_value | integer | Threshold for auto-award |
| order_index | integer | Default: 0 |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (name)

---

### user_badges (join table)
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| badge_id | integer (FK) | → badges |
| awarded_at | utc_datetime | |
| is_featured | boolean | Default: false |
| timestamps | utc_datetime | |

**Indexes:**
- UNIQUE (user_id, badge_id)

---

## 7. NOTIFICATIONS CONTEXT

### notifications
| Field | Type | Notes |
|-------|------|-------|
| id | binary_id (PK) | UUID |
| user_id | binary_id (FK) | → users |
| type | string | badge_earned, streak_milestone, lesson_complete, daily_reminder, classroom, classroom_lesson, classroom_test |
| title | string | |
| message | string | |
| read_at | utc_datetime | |
| data | map (jsonb) | Additional payload |
| timestamps | utc_datetime | |

**Indexes:**
- INDEX (user_id)
- INDEX (user_id, read_at) for unread queries

---

## Entity Relationship Diagram (Text)

```
users
├── has_one → user_profiles
├── has_one → user_stats
├── has_many → user_progress
├── has_many → lesson_progress
├── has_many → daily_streaks
├── has_many → review_schedules
├── has_many → test_sessions
├── has_many → notifications
├── has_many → user_badges
├── has_many → api_tokens
├── has_many → classrooms (as teacher)
├── has_many → classroom_memberships (as student)
├── has_many → word_sets
└── has_many → custom_lessons (as creator)

kanji
├── has_many → kanji_readings
├── has_many → word_kanjis
├── has_many → lesson_kanjis
└── has_many → user_progress

words
├── has_many → word_kanjis
├── has_many → lesson_words
├── has_many → custom_lesson_words
├── has_many → word_conjugations
├── has_many → word_class_memberships
├── has_many → test_steps
├── has_many → word_set_words
└── has_many → user_progress

lessons
├── has_many → lesson_kanjis
├── has_many → lesson_words
├── has_many → lesson_progress
├── belongs_to → tests
└── has_many → classroom_lesson_progress

custom_lessons
├── has_many → custom_lesson_words
├── has_many → grammar_lesson_steps
├── belongs_to → users (creator)
├── belongs_to → tests
├── has_many → classroom_custom_lessons
└── has_many → classroom_lesson_progress

tests
├── has_many → test_steps
├── has_many → test_sessions
├── has_many → lessons
├── has_many → custom_lessons
├── has_many → classroom_tests
├── has_many → classroom_test_attempts
└── belongs_to → users (creator)

test_sessions
├── has_many → test_step_answers
├── belongs_to → users
├── belongs_to → tests
└── has_many → classroom_test_attempts

classrooms
├── has_many → classroom_memberships
├── has_many → classroom_tests
├── has_many → classroom_test_attempts
├── has_many → classroom_custom_lessons
├── has_many → classroom_lesson_progress
└── belongs_to → users (teacher)

badges
└── has_many → user_badges

word_sets
├── has_many → word_set_words
├── belongs_to → users
└── belongs_to → tests (practice_test)

grammar_forms
└── has_many → word_conjugations

word_classes
└── has_many → word_class_memberships
```

---

## Key Business Rules

1. **User Progress**: A user_progress record tracks either a kanji OR a word, never both (validated at application level)

2. **SRS Scheduling**: Uses SM-2 algorithm with fields: interval, ease_factor, repetitions, next_review_at

3. **Mastery Levels**: 0=New, 1-3=Learning, 4=Mastered, 5=Burned

4. **Test Scoring**: 
   - Points have penalties: -25% per extra attempt, -10% per hint
   - Minimum 10% of base points if correct

5. **Classroom Tests**: Students get one attempt unless teacher resets. Ranking score = points + (time_remaining/time_limit * 0.01)

6. **Word Sets**: Maximum 100 words per set, user-created for focused study

7. **Grammar Validation**: Word conjugations support alternative forms for contracted Japanese (e.g., "来ない" → "来な")
