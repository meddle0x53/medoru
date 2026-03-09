#!/usr/bin/env elixir
# Organize words into topic-aligned order for v7 lessons
# 
# This script analyzes word meanings and categorizes them into topics,
# then outputs a reorganized word pool that matches the lesson structure.

defmodule WordTopicOrganizer do
  @moduledoc """
  Organizes words by topic to match lesson titles.
  """

  # Topic definitions with matching keywords
  defp n5_topic_definitions do
    %{
    "Basic Greetings" => %{keywords: ["hello", "goodbye", "morning", "evening", "night", "thanks", "please", "sorry", "excuse", "greeting"], prefer_kana: true},
    "Numbers 1-10" => %{keywords: ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], kanji_match: ~r/^[一二三四五六七八九十]$/},
    "Numbers 11-100" => %{keywords: ["hundred", "thousand", "eleven", "twelve", "twenty", "thirty", "100"], kanji_match: ~r/^(十|百|[一二三四五六七八九]十)/},
    "Time Basics" => %{keywords: ["hour", "minute", "second", "time", "o'clock", "clock", "watch", "moment", "instant"]},
    "Days of Week" => %{keywords: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "week"]},
    "Family Basics" => %{keywords: ["family", "mother", "father", "parent", "child", "brother", "sister", "sibling", "mom", "dad"]},
    "Pronouns" => %{keywords: ["i", "you", "he", "she", "we", "they", "me", "him", "her", "us", "them", "myself", "yourself"], word_type: "noun"},
    "Common Verbs 1" => %{word_type: "verb", max_complexity: 1},
    "Common Verbs 2" => %{word_type: "verb", max_complexity: 2},
    "Question Words" => %{keywords: ["what", "who", "where", "when", "why", "how", "which"]},
    
    "Food Basics" => %{keywords: ["food", "meal", "eat", "breakfast", "lunch", "dinner", "rice", "bread", "meat", "fish", "vegetable", "fruit"]},
    "Drinks" => %{keywords: ["drink", "water", "tea", "coffee", "alcohol", "beer", "sake", "juice", "milk", "beverage"]},
    "Restaurants" => %{keywords: ["restaurant", "menu", "order", "bill", "waiter", "delicious", "cook", "cuisine", "dining"]},
    "Shopping" => %{keywords: ["buy", "sell", "shop", "store", "price", "cheap", "expensive", "shopping", "goods"]},
    "Money" => %{keywords: ["money", "yen", "dollar", "coin", "bill", "pay", "wallet", "cash", "currency"]},
    "Colors" => %{keywords: ["color", "red", "blue", "green", "yellow", "black", "white", "brown", "purple", "pink", "orange", "grey", "gold", "silver"]},
    "Clothing 1" => %{keywords: ["clothes", "shirt", "pants", "dress", "shoes", "wear", "hat", "coat", "skirt", "sock"]},
    "Clothing 2" => %{keywords: ["put on", "take off", "fit", "size", "fashion", "uniform", "button", "zip"]},
    "Weather 1" => %{keywords: ["weather", "rain", "snow", "sun", "cloud", "wind", "storm", "sunny", "rainy"]},
    "Weather 2" => %{keywords: ["season", "spring", "summer", "fall", "autumn", "winter", "temperature", "degree", "climate"]},
    
    "Months" => %{keywords: ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december", "month"]},
    "Dates" => %{keywords: ["date", "day", "today", "tomorrow", "yesterday", "calendar", "year"]},
    "House Rooms" => %{keywords: ["house", "room", "kitchen", "bedroom", "bathroom", "living", "door", "window", "home", "apartment"]},
    "Furniture" => %{keywords: ["furniture", "table", "chair", "bed", "desk", "shelf", "couch", "sofa", "cabinet"]},
    "Appliances" => %{keywords: ["refrigerator", "television", "phone", "computer", "machine", "appliance", "ac", "heater", "microwave"]},
    
    "School Items" => %{keywords: ["school", "pen", "pencil", "paper", "book", "notebook", "eraser", "bag", "classroom"]},
    "Occupations 1" => %{keywords: ["teacher", "student", "doctor", "nurse", "company", "work", "job", "office"]},
    "Occupations 2" => %{keywords: ["employee", "worker", "manager", "business", "profession", "engineer", "lawyer"]},
    "Transportation 1" => %{keywords: ["train", "bus", "car", "taxi", "bicycle", "subway", "transport", "vehicle"]},
    "Transportation 2" => %{keywords: ["airplane", "airport", "ticket", "station", "drive", "ride", "ship", "boat"]},
    
    "Verbs - Movement" => %{word_type: "verb", keywords: ["walk", "run", "fly", "jump", "swim", "move", "go", "come"]},
    "Verbs - Daily" => %{word_type: "verb", keywords: ["wake", "sleep", "work", "rest", "get up", "go to bed"]},
    "Verbs - Eating" => %{word_type: "verb", keywords: ["eat", "drink", "cook", "cut", "taste", "meal", "bite", "chew"]},
    "Verbs - Communication" => %{word_type: "verb", keywords: ["speak", "talk", "say", "tell", "ask", "answer", "write", "read", "hear"]},
    "Verbs - Perception" => %{word_type: "verb", keywords: ["see", "look", "watch", "hear", "listen", "feel", "notice"]},
    
    "Adjectives 1" => %{word_type: "adjective", max_kanji: 1},
    "Adjectives 2" => %{word_type: "adjective"},
    "Adverbs 1" => %{keywords: ["very", "quite", "somewhat", "always", "often", "sometimes", "never", "usually", "already"]},
    "Adverbs 2" => %{keywords: ["quickly", "slowly", "early", "late", "well", "carefully", "suddenly", "gradually"]},
    "Expressions 1" => %{keywords: ["please", "thank", "welcome", "excuse", "sorry", "pardon"]},
    
    "Body Parts 1" => %{keywords: ["head", "hand", "arm", "leg", "foot", "face", "eye", "ear", "nose", "mouth"]},
    "Body Parts 2" => %{keywords: ["body", "finger", "toe", "hair", "neck", "shoulder", "back", "stomach"]},
    "Health 1" => %{keywords: ["health", "sick", "illness", "pain", "medicine", "doctor", "hospital", "hurt", "fever"]},
    "Health 2" => %{keywords: ["injury", "cold", "cough", "headache", "stomachache", "recover", "cure"]},
    
    "Places in Town 1" => %{keywords: ["town", "city", "building", "street", "park", "bank", "post office"]},
    "Places in Town 2" => %{keywords: ["hospital", "school", "library", "museum", "police", "fire station"]},
    "Stores" => %{keywords: ["store", "shop", "department", "market", "supermarket", "convenience store"]},
    "Public Buildings" => %{keywords: ["government", "office", "city hall", "embassy", "consulate"]},
    "Nature 1" => %{keywords: ["nature", "mountain", "river", "sea", "tree", "flower", "grass", "forest"]},
    "Nature 2" => %{keywords: ["lake", "ocean", "beach", "island", "valley", "hill", "sky", "star"]},
    "Animals 1" => %{keywords: ["animal", "dog", "cat", "bird", "fish", "horse", "insect", "bug"]},
    "Animals 2" => %{keywords: ["bear", "chicken", "cow", "pig", "rabbit", "mouse", "snake"]},
    "Directions" => %{keywords: ["north", "south", "east", "west", "left", "right", "straight", "direction"]},
    "Position Words" => %{keywords: ["above", "below", "inside", "outside", "front", "back", "middle", "between", "next to"]},
    
    "Country Names" => %{keywords: ["japan", "america", "england", "france", "china", "korea", "germany", "country"]},
    "Languages" => %{keywords: ["language", "english", "japanese", "speak", "talk", "conversation"]},
    "People" => %{keywords: ["person", "people", "man", "woman", "child", "adult", "human"]},
    "Emotions 1" => %{keywords: ["happy", "sad", "angry", "glad", "feel", "emotion", "feeling"]},
    "Emotions 2" => %{keywords: ["surprise", "worry", "disappoint", "like", "dislike", "love", "hate"]},
    
    "Time Expressions" => %{keywords: ["morning", "afternoon", "evening", "night", "today", "tomorrow", "yesterday", "now"]},
    "Frequency" => %{keywords: ["always", "often", "sometimes", "rarely", "never", "every", "once", "twice"]},
    "Quantity" => %{keywords: ["many", "few", "much", "little", "some", "all", "none", "lot", "several"]},
    "Size" => %{keywords: ["big", "small", "tall", "short", "long", "wide", "narrow", "huge", "tiny"]},
    "Distance" => %{keywords: ["near", "far", "close", "distant", "long", "short", "away", "around"]},
    "Quality" => %{keywords: ["good", "bad", "better", "best", "high", "low", "quality", "grade"]},
    "Temperature" => %{keywords: ["hot", "cold", "warm", "cool", "temperature", "heat", "freeze", "burn"]},
    "Preferences" => %{keywords: ["like", "love", "enjoy", "prefer", "favorite", "hate", "dislike"]},
    "Abilities" => %{keywords: ["can", "able", "capable", "skill", "possible", "ability", "talent"]},
    "Desires" => %{keywords: ["want", "desire", "wish", "hope", "would like", "long for"]},
    
    "Family Relations 1" => %{keywords: ["grandmother", "grandfather", "grandparent", "aunt", "uncle", "cousin"]},
    "Family Relations 2" => %{keywords: ["wife", "husband", "daughter", "son", "relative", "married", "couple"]},
    "Household Chores" => %{keywords: ["clean", "wash", "cook", "laundry", "chore", "housework", "sweep", "vacuum"]},
    "Daily Routine" => %{keywords: ["morning", "breakfast", "commute", "work", "return", "evening", "bed"]},
    "Hobbies 1" => %{keywords: ["hobby", "play", "game", "sport", "music", "read", "dance", "sing"]},
    "Hobbies 2" => %{keywords: ["draw", "paint", "garden", "travel", "camp", "hike", "fishing"]},
    "Sports" => %{keywords: ["sport", "soccer", "baseball", "tennis", "swim", "run", "basketball", "volleyball"]},
    "Music" => %{keywords: ["music", "song", "sing", "instrument", "guitar", "piano", "drum", "violin"]},
    "Movies/TV" => %{keywords: ["movie", "film", "television", "drama", "actor", "watch", "show", "cinema"]},
    "Reading" => %{keywords: ["read", "book", "novel", "magazine", "newspaper", "story", "author", "library"]},
    
    # Reviews - fill with remaining words
    "Reading Practice 1" => %{fill_remaining: true},
    "Reading Practice 2" => %{fill_remaining: true},
    "Reading Practice 3" => %{fill_remaining: true},
    "Reading Practice 4" => %{fill_remaining: true},
    "Reading Practice 5" => %{fill_remaining: true},
    "Reading Practice 6" => %{fill_remaining: true},
    "Reading Practice 7" => %{fill_remaining: true},
    "Reading Practice 8" => %{fill_remaining: true},
    "Reading Practice 9" => %{fill_remaining: true},
    "Reading Practice 10" => %{fill_remaining: true},
    "Grammar Review 1" => %{fill_remaining: true},
    "Grammar Review 2" => %{fill_remaining: true},
    "Grammar Review 3" => %{fill_remaining: true},
    "Grammar Review 4" => %{fill_remaining: true},
    "Grammar Review 5" => %{fill_remaining: true},
    "Grammar Review 6" => %{fill_remaining: true},
    "Grammar Review 7" => %{fill_remaining: true},
    "Grammar Review 8" => %{fill_remaining: true},
    "Grammar Review 9" => %{fill_remaining: true},
    "Final Review" => %{fill_remaining: true},
    }
  end

  def organize do
    IO.puts("Loading word pool...")
    json = File.read!("data/v7_lesson_pool.json")
    data = Jason.decode!(json)

    IO.puts("\nOrganizing N5 words by topic...")
    n5_organized = organize_level(data["words_by_level"]["n5"], n5_topic_definitions())

    # For N4 and N3, just use the original order for now
    # We can enhance these later with similar topic definitions
    organized = %{
      "meta" => data["meta"],
      "words_by_level" => %{
        "n5" => n5_organized,
        "n4" => data["words_by_level"]["n4"],
        "n3" => data["words_by_level"]["n3"]
      }
    }

    IO.puts("\n  Encoding JSON...")
    encoded = Jason.encode!(organized, pretty: true)
    IO.puts("  Writing file...")
    File.write!("data/v7_lesson_pool_organized.json", encoded)
    
    IO.puts("\n✅ Organization complete!")
    IO.puts("Output: data/v7_lesson_pool_organized.json")
    
    # Print stats
    IO.puts("\nN5 Topic Distribution:")
    Enum.each(n5_organized, fn {topic, words} ->
      if length(words) > 0 do
        samples = words |> Enum.take(3) |> Enum.map(& &1["word"]) |> Enum.join(", ")
        IO.puts("  #{topic}: #{length(words)} words (#{samples}...)")
      end
    end)
  end

  defp organize_level(words, topic_definitions) do
    topics = Map.keys(topic_definitions)
    
    # Categorize each word to best matching topic
    total = length(words)
    {categorized, uncategorized} = 
      Enum.reduce(Enum.with_index(words), {%{}, []}, fn {word, idx}, {acc, uncategorized} ->
        if rem(idx, 100) == 0, do: IO.write("\r  Processing #{idx}/#{total} words...")
        topic = find_best_topic(word, topic_definitions)
        
        if topic do
          {Map.update(acc, topic, [word], &[word | &1]), uncategorized}
        else
          {acc, [word | uncategorized]}
        end
      end)

    IO.puts("\n  Building topic lists...")
    topic_count = length(topics)
    IO.puts("  Total topics: #{topic_count}")
    
    # Simple approach: just take words for each topic
    organized = 
      topics
      |> Enum.map(fn topic ->
        defn = topic_definitions[topic]
        topic_words = Map.get(categorized, topic, [])
        
        # Limit to 15 words
        selected = Enum.take(topic_words, 15)
        {topic, selected}
      end)
      |> Map.new()
    
    IO.puts("  Done building topics!")
    organized
  end

  defp find_best_topic(word, topic_definitions) do
    meaning = String.downcase(word["meaning"] || "")
    example = String.downcase(word["example_english"] || "")
    word_type = to_string(word["word_type"])
    word_text = word["word"] || ""
    kanji_count = word["kanji_count"] || 0
    
    # Score each topic
    scored = 
      topic_definitions
      |> Enum.reject(fn {_, defn} -> defn[:fill_remaining] end)
      |> Enum.map(fn {topic, defn} ->
        score = score_topic(meaning, example, word_type, word_text, kanji_count, defn)
        {topic, score}
      end)
    
    # Find best match (need minimum score of 2)
    case Enum.max_by(scored, fn {_, score} -> score end) do
      {topic, score} when score >= 2 -> topic
      _ -> nil
    end
  end

  defp score_topic(meaning, example, word_type, word_text, kanji_count, defn) do
    scores = []
    
    # Keyword matching in meaning (10 pts each)
    scores = if keywords = defn[:keywords] do
      count = Enum.count(keywords, fn kw -> 
        String.contains?(meaning, kw) or String.contains?(example, kw)
      end)
      [count * 10 | scores]
    else
      scores
    end
    
    # Word type matching (5 pts)
    scores = if type = defn[:word_type] do
      type_score = if word_type == type, do: 5, else: 0
      [type_score | scores]
    else
      scores
    end
    
    # Prefer kana-only words (3 pts)
    scores = if defn[:prefer_kana] do
      kana_score = if kanji_count == 0, do: 3, else: 0
      [kana_score | scores]
    else
      scores
    end
    
    # Max kanji constraint
    scores = if max_k = defn[:max_kanji] do
      max_score = if kanji_count <= max_k, do: 2, else: -50
      [max_score | scores]
    else
      scores
    end
    
    # Kanji pattern matching (15 pts)
    scores = if pattern = defn[:kanji_match] do
      pattern_score = if Regex.match?(pattern, word_text), do: 15, else: 0
      [pattern_score | scores]
    else
      scores
    end
    
    Enum.sum(scores)
  end
end

WordTopicOrganizer.organize()
