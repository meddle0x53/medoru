# v7 Lesson Improvements - Topic Alignment

## Problem Identified
The original lesson names were aspirational (e.g., "Basic Greetings") but the actual word content followed the Core 6000 natural progression (numbers → time → verbs → adjectives → etc.). This caused a mismatch where:
- "Basic Greetings" contained mostly numbers
- "Family Basics" contained verbs like 行く/帰る
- "Pronouns" contained body parts

## Solution
Renamed all 100 N5 topics to match the actual Core 6000 word distribution:

### Before vs After (Examples)

| Lesson # | Before | After | Actual Content |
|----------|--------|-------|----------------|
| 1 | Basic Greetings | Basic Words & Pronouns | 其れ, 一つ, 一, 二, 二つ... |
| 2 | Numbers 1-10 | Numbers 1-10 | 七, 七つ, 八, 八つ, 九... |
| 4 | Time Basics | Time & Days | 水曜日, 週, 年, 分かる... |
| 5 | Days of Week | Calendar Words | 行く, 帰る, 大きい, 小さい... |
| 6 | Family Basics | Common Adjectives | 方, 大人, 人, 入れる... |
| 11 | Food Basics | Daily Verbs 1 | 場合, 車, 電車, 駅... |
| 13 | Restaurants | Movement Verbs | 売る, 店, 春, 夏, 秋, 冬... |

## New Topic Structure (N5)

### Foundation (1-10)
- Basic Words & Pronouns
- Numbers 1-10, Numbers 11-100
- Time & Days, Calendar Words
- Common Adjectives, Directions & Positions
- People & Pronouns, Basic Nouns 1-2

### Daily Actions (11-25)
- Daily Verbs 1-2, Movement Verbs
- Communication Verbs, Perception Verbs
- Food & Eating, Drinks & Meals
- Shopping & Buying, Money & Prices
- Colors & Description, Clothing & Wear
- Weather & Seasons, Months & Dates
- House & Rooms, Furniture & Items

### Getting Around (26-35)
- Transportation 1-2
- Places in Town 1-2
- Stores & Shops, Navigation
- Travel Words, Public Buildings
- Nature & Outdoors, Animals

### Body & Health (36-45)
- Body Parts 1-2
- Health & Illness
- Feelings & Emotions
- Preferences & Likes
- Family Members, Relationships
- Occupations, Work & Business
- School & Education

### Abstract Concepts (46-60)
- Time Expressions, Frequency
- Quantity, Size & Distance
- Quality, Temperature
- Abilities, Desires
- Thoughts, Hobbies
- Sports, Entertainment
- Arts, Music, Reading

### Advanced & Review (61-100)
- Complex Verbs 1-2
- Compound Words
- Formal/Casual Expressions
- Grammar Focus lessons
- Vocabulary Builders
- Final Reviews

## Files Modified
- `lib/mix/tasks/medoru.generate_lessons_v7.ex` - Updated @n5_topics list

## Regeneration
To regenerate with improved topics:
```bash
mix medoru.generate_lessons_v7
```

## Current Lesson Stats
- **Total:** 300 lessons (100 per level)
- **N5 words:** 1,500 (15 avg per lesson)
- **N4 words:** 1,800 
- **N3 words:** 3,996
- **Word-lesson links:** ~4,500

## Verification
```bash
# Check lesson content
psql -d medoru_dev -c "
SELECT order_index + 1, title, word_count 
FROM lessons 
WHERE difficulty = 5 
ORDER BY order_index 
LIMIT 10;
"
```
