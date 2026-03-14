# Iteration 31: Teacher Custom Lessons

**Status**: ⏳ NOT STARTED  
**Priority**: 🔴 HIGH  
**Estimated**: 3-4 days  
**Depends On**: Iteration 29 (Classroom Publishing), Iteration 25B (Step Builder with word search)

## Overview

Allow teachers to create custom reading lessons by selecting words from the vocabulary database. Unlike system lessons (which have auto-generated tests), teacher lessons are completed by simply reading/studying the material - no test required.

## Key Differences from System Lessons

| Aspect | System Lessons | Teacher Custom Lessons |
|--------|---------------|----------------------|
| Creation | Auto-generated | Teacher-created |
| Content | Fixed from Core 6000 | Teacher picks words |
| Test | Auto-generated, required | None, self-study |
| Completion | Pass lesson test | Mark as read/complete |
| Word meanings | Fixed from DB | Teacher can customize |
| Examples | From Core 6000 | Teacher adds/edits |

## Database Schema

### New Table: `custom_lessons`

```elixir
schema "custom_lessons" do
  field :title, :string
  field :description, :text
  field :lesson_type, :string, default: "reading"  # Only :reading for now
  field :difficulty, :integer  # 1-5 or nil for auto
  field :status, :string, default: "draft"  # draft, published, archived
  field :word_count, :integer, default: 0
  
  belongs_to :creator, User  # Teacher who created it
  belongs_to :classroom, Classroom  # Optional: created for specific classroom
  
  has_many :custom_lesson_words, CustomLessonWord, preload_order: [asc: :position]
  has_many :words, through: [:custom_lesson_words, :word]
  
  timestamps()
end
```

### New Table: `custom_lesson_words`

```elixir
schema "custom_lesson_words" do
  field :position, :integer
  field :custom_meaning, :text  # Override default word meaning
  field :examples, {:array, :text}, default: []  # Usage examples
  
  belongs_to :custom_lesson
  belongs_to :word
  
  timestamps()
end
```

### New Table: `custom_lesson_progress` (or reuse `classroom_lesson_progress`)

Option A: Extend `classroom_lesson_progress` with `lesson_source` field (`:system | :custom`)
Option B: Create new `custom_lesson_progress` table

**Recommended**: Option A - extend existing schema:
```elixir
# Add to classroom_lesson_progress migration:
add :lesson_source, :string, default: "system"  # "system" or "custom"
add :custom_lesson_id, references(:custom_lessons, type: :binary_id, on_delete: :delete_all)
# Make lesson_id nullable for custom lessons
```

## Context Functions

### `Medoru.Content` context additions:

```elixir
# Custom Lesson Management
def list_teacher_custom_lessons(teacher_id, opts \\ [])
def get_custom_lesson!(id)
def create_custom_lesson(attrs)
def update_custom_lesson(custom_lesson, attrs)
def delete_custom_lesson(custom_lesson)
def publish_custom_lesson(custom_lesson)
def archive_custom_lesson(custom_lesson)

# Custom Lesson Words
def add_word_to_lesson(lesson_id, word_id, attrs \\ %{})
def remove_word_from_lesson(lesson_id, word_id)
def reorder_lesson_words(lesson_id, word_ids_in_order)
def update_lesson_word(lesson_word, attrs)
def list_lesson_words(lesson_id)

# Publishing to classrooms
def publish_lesson_to_classroom(lesson_id, classroom_id, teacher_id, attrs \\ %{})
def unpublish_lesson_from_classroom(lesson_classroom_id, teacher_id)
def list_classroom_custom_lessons(classroom_id)
```

### `Medoru.Classrooms` context additions:

```elixir
# Custom lesson progress (extend existing functions)
def start_custom_lesson(classroom_id, user_id, custom_lesson_id)
def complete_custom_lesson(classroom_id, user_id, custom_lesson_id)
def get_custom_lesson_progress(classroom_id, user_id, custom_lesson_id)
```

## LiveViews

### Teacher Interface

**`Teacher.CustomLessonLive.Index`** - `/teacher/custom-lessons`
- List all teacher's custom lessons
- Filter by status (draft/published/archived)
- Create new lesson button
- Card view with word count, assigned classrooms

**`Teacher.CustomLessonLive.New`** - `/teacher/custom-lessons/new`
- Lesson title input
- Description textarea
- Difficulty selector (optional, for filtering)
- Create button → redirects to edit

**`Teacher.CustomLessonLive.Edit`** - `/teacher/custom-lessons/:id/edit`
- **Word Builder Interface**:
  - Word search autocomplete (reuse from test step builder)
  - Selected words list with drag-drop reordering
  - Per-word expansion panel:
    - Display: Word text, reading, default meaning
    - Editable: Custom meaning textarea
    - Examples: Add/remove example sentences
  - Word count indicator (1-50, show warning at limits)
- Publish controls:
  - Save as Draft
  - Publish to Classroom(s) button
  - Archive button

**`Teacher.CustomLessonLive.Publish`** - `/teacher/custom-lessons/:id/publish`
- Select classroom(s) to publish to
- Optional due date per classroom
- List of currently published classrooms
- Unpublish option

### Student Interface

**`ClassroomLive.Show` (Lessons Tab)** - Update existing
- Show both system lessons AND custom lessons
- Custom lessons marked with teacher name
- Status badges: Not started, In Progress, Completed

**`ClassroomLive.CustomLesson`** - `/classrooms/:id/custom-lessons/:lesson_id`
- **Study Mode** (NOT test mode):
  - Title and description
  - Word list with:
    - Japanese text (large)
    - Reading (furigana style)
    - Meaning
    - Usage examples
  - Navigation: Previous/Next word or scroll
  - "Mark as Complete" button at bottom
  - Progress indicator (e.g., "Word 5 of 12")

**`ClassroomLive.CustomLesson.Complete`** - `/classrooms/:id/custom-lessons/:lesson_id/complete`
- Congratulations message
- Summary: Words learned count
- XP/points earned (configurable)
- Button to return to classroom

## Components Needed

### `CustomLessonComponents`

```elixir
# Word card for editing
defp lesson_word_card(assigns)

# Word list display for students
defp word_study_card(assigns)

# Example input (add/remove examples)
defp example_input(assigns)

# Publish status badge
defp publish_status_badge(assigns)

# Lesson preview
defp lesson_preview(assigns)
```

## Technical Tasks

### 1. Database Migrations
- [ ] Create `custom_lessons` table
- [ ] Create `custom_lesson_words` table
- [ ] Extend `classroom_lesson_progress` with `lesson_source` and `custom_lesson_id`
- [ ] Create `classroom_custom_lessons` join table (for publishing)

### 2. Context Layer
- [ ] `CustomLesson` schema
- [ ] `CustomLessonWord` schema
- [ ] `ClassroomCustomLesson` schema
- [ ] `Content` context functions
- [ ] `Classrooms` context extensions
- [ ] Tests for all context functions

### 3. Teacher LiveViews
- [ ] Index page
- [ ] New lesson page
- [ ] Edit page with word builder
- [ ] Publish page
- [ ] Tests

### 4. Student LiveViews
- [ ] Update classroom show lessons tab
- [ ] Custom lesson study page
- [ ] Completion page
- [ ] Tests

### 5. Components & UI
- [ ] Reuse word search from test builder
- [ ] Drag-drop reordering for words
- [ ] Example input component
- [ ] Study mode word display

### 6. Integration
- [ ] Update classroom analytics for custom lessons
- [ ] Update rankings to include custom lesson points
- [ ] Update notifications (lesson published, completed)

## UI Flow

### Teacher Creating a Lesson

```
/teacher/custom-lessons
  ↓ [+ New Lesson]
/teacher/custom-lessons/new
  ↓ [Create]
/teacher/custom-lessons/:id/edit
  ↓ [Search word "日本" → Add]
  ↓ [Edit meaning → "Japan (country)"]
  ↓ [Add example → "日本に行きたいです"]
  ↓ [Add 4 more words...]
  ↓ [Drag to reorder]
  ↓ [Publish to Classroom]
/teacher/custom-lessons/:id/publish
  ↓ [Select Classroom "N5 Spring 2026"]
  ↓ [Set Due Date: 2026-04-01]
  ↓ [Publish]
/teacher/custom-lessons (back to list, shows "Published to 1 classroom")
```

### Student Taking a Lesson

```
/classrooms/:id (Lessons tab)
  ↓ [Custom Lesson: "Spring Vocabulary Set 1" - Start]
/classrooms/:id/custom-lessons/:lesson_id
  ↓ [Read word 1: 日本 - "Japan"]
  ↓ [Next →]
  ↓ [Read word 2: 学校 - "School"]
  ↓ [...]
  ↓ [Mark as Complete]
/classrooms/:id/custom-lessons/:lesson_id/complete
  ↓ [Return to Classroom]
/classrooms/:id (lesson now marked completed)
```

## Points System

Custom lessons award points on completion:
- Base: 10 points per word
- Bonus: 20 points for completing
- Example: 5-word lesson = 5×10 + 20 = 70 points

Points added to classroom membership total (for rankings).

## Validation Rules

### Lesson
- Title: required, 3-100 chars
- Description: optional, max 500 chars
- Difficulty: 1-5 or nil
- Status transitions: draft → published → archived

### Words
- Minimum 1 word
- Maximum 50 words
- No duplicate words in same lesson
- Custom meaning: optional, max 500 chars
- Examples: max 5 per word, each max 200 chars

## Edge Cases

1. **Word deleted from DB**: Lesson word remains but shows "[word removed]" placeholder
2. **Teacher archives lesson**: Already-published lessons remain accessible, new students can't see it
3. **Student starts but teacher edits**: Continue with original version, edits affect new students only
4. **Duplicate words**: Prevent adding same word twice
5. **Classroom deleted**: Cascade delete progress, keep lesson for teacher reuse

## Acceptance Criteria

- [ ] Teacher can create custom reading lesson
- [ ] Teacher can search and add words (1-50)
- [ ] Teacher can edit word meanings per lesson
- [ ] Teacher can add example sentences
- [ ] Teacher can reorder words via drag-drop
- [ ] Teacher can publish to one or more classrooms
- [ ] Student sees custom lessons in classroom
- [ ] Student can view lesson in study mode
- [ ] Student can mark lesson as complete
- [ ] Points are awarded on completion
- [ ] Progress appears in rankings
- [ ] Analytics show custom lesson completion stats

## Estimated Effort

| Task | Days |
|------|------|
| Database migrations | 0.5 |
| Context layer + tests | 1 |
| Teacher LiveViews | 1.5 |
| Student LiveViews | 0.75 |
| Integration (analytics, notifications) | 0.5 |
| **Total** | **~4 days** |

## Related Files

**To reference/reuse:**
- `lib/medoru_web/live/teacher/test_live/edit.ex` - Word search implementation
- `lib/medoru_web/components/step_builder_components.ex` - Search UI
- `assets/js/hooks/step_sorter.js` - Drag-drop reordering
- `lib/medoru/classrooms/classroom_test.ex` - Publishing pattern
- `lib/medoru_web/live/teacher/test_live/publish.ex` - Publish UI pattern
