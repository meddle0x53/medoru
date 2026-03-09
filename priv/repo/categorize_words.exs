#!/usr/bin/env elixir
# Categorize words by topic based on their meanings and content
# 
# Usage: mix run priv/repo/categorize_words.exs

defmodule WordCategorizer do
  @moduledoc """
  Categorizes words into topics based on their meanings, readings, and example sentences.
  """

  # Topic keywords for matching
  @topic_keywords %{
    # N5 Topics
    "Basic Greetings" => ["hello", "goodbye", "morning", "evening", "night", "thanks", "please", "sorry", "excuse"],
    "Numbers 1-10" => ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
    "Numbers 11-100" => ["eleven", "twelve", "twenty", "thirty", "hundred", "11", "12", "20", "30", "100"],
    "Time Basics" => ["hour", "minute", "second", "time", "o'clock", "clock", "watch", "moment", "instant"],
    "Days of Week" => ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "week"],
    "Family Basics" => ["family", "mother", "father", "parent", "child", "brother", "sister", "sibling"],
    "Pronouns" => ["i", "you", "he", "she", "we", "they", "me", "him", "her", "us", "them", "myself", "yourself"],
    "Common Verbs 1" => ["be", "is", "are", "am", "have", "do", "make", "exist"],
    "Common Verbs 2" => ["go", "come", "return", "leave", "arrive"],
    "Question Words" => ["what", "who", "where", "when", "why", "how", "which"],
    
    "Food Basics" => ["food", "meal", "eat", "breakfast", "lunch", "dinner", "rice", "bread", "meat", "fish"],
    "Drinks" => ["drink", "water", "tea", "coffee", "alcohol", "beer", "sake", "juice", "milk"],
    "Restaurants" => ["restaurant", "menu", "order", "bill", "waiter", "delicious", "cook", "cuisine"],
    "Shopping" => ["buy", "sell", "shop", "store", "price", "cheap", "expensive", "money", "pay"],
    "Money" => ["money", "yen", "dollar", "coin", "bill", "price", "cost", "pay", "wallet"],
    "Colors" => ["color", "red", "blue", "green", "yellow", "black", "white", "brown", "purple"],
    "Clothing 1" => ["clothes", "shirt", "pants", "dress", "shoes", "wear", "hat", "coat"],
    "Clothing 2" => ["put on", "take off", "fit", "size", "fashion", "uniform", "socks"],
    "Weather 1" => ["weather", "rain", "snow", "sun", "cloud", "wind", "storm"],
    "Weather 2" => ["season", "spring", "summer", "fall", "autumn", "winter", "temperature"],
    
    "Months" => ["january", "february", "march", "april", "may", "june", "month"],
    "Dates" => ["date", "day", "calendar", "year", "today", "tomorrow", "yesterday"],
    "House Rooms" => ["house", "room", "kitchen", "bedroom", "bathroom", "living", "door", "window"],
    "Furniture" => ["furniture", "table", "chair", "bed", "desk", "shelf", "couch", "sofa"],
    "Appliances" => ["appliance", "refrigerator", "tv", "television", "phone", "computer", "machine"],
    
    "School Items" => ["school", "pen", "pencil", "paper", "book", "notebook", "eraser", "bag"],
    "Occupations 1" => ["job", "work", "teacher", "student", "doctor", "nurse", "company"],
    "Occupations 2" => ["employee", "worker", "office", "manager", "business", "profession"],
    "Transportation 1" => ["train", "bus", "car", "taxi", "bicycle", "subway", "transport"],
    "Transportation 2" => ["airplane", "airport", "ticket", "station", "drive", "ride", "vehicle"],
    
    "Verbs - Movement" => ["walk", "run", "fly", "jump", "swim", "move"],
    "Verbs - Daily" => ["wake", "sleep", "work", "rest", "get up", "go to bed"],
    "Verbs - Eating" => ["eat", "drink", "cook", "cut", "taste", "meal"],
    "Verbs - Communication" => ["speak", "talk", "say", "tell", "ask", "answer", "write", "read", "hear"],
    "Verbs - Perception" => ["see", "look", "watch", "hear", "listen", "feel", "notice"],
    
    "Adjectives 1 - i-adj" => ["big", "small", "tall", "short", "long", "new", "old", "young", "good", "bad", "hot", "cold"],
    "Adjectives 2 - na-adj" => ["quiet", "noisy", "beautiful", "clean", "dirty", "healthy", "convenient"],
    "Adverbs 1" => ["very", "quite", "somewhat", "always", "often", "sometimes", "never"],
    "Adverbs 2" => ["quickly", "slowly", "early", "late", "well", "carefully", "suddenly"],
    "Expressions 1" => ["please", "thank you", "you're welcome", "excuse me", "sorry"],
    
    "Body Parts 1" => ["body", "head", "hand", "arm", "leg", "foot", "face", "eye", "ear"],
    "Health 1" => ["health", "sick", "illness", "pain", "medicine", "doctor", "hospital", "hurt"],
    
    "Places in Town" => ["town", "city", "building", "street", "park", "bank", "post office"],
    "Nature" => ["nature", "mountain", "river", "sea", "ocean", "tree", "flower", "grass"],
    "Animals" => ["animal", "dog", "cat", "bird", "fish", "horse", "insect"],
    "Directions" => ["direction", "north", "south", "east", "west", "left", "right", "straight"],
    
    "Country Names" => ["country", "japan", "america", "england", "france", "china", "korea"],
    "Emotions" => ["happy", "sad", "angry", "surprised", "worried", "glad", "disappointed"],
  }

  def categorize do
    IO.puts("Loading word pool...")
    json = File.read!("data/v7_lesson_pool.json")
    data = Jason.decode!(json)

    categorized = %{
      "n5" => categorize_level(data["words_by_level"]["n5"], "n5"),
      "n4" => categorize_level(data["words_by_level"]["n4"], "n4"),
      "n3" => categorize_level(data["words_by_level"]["n3"], "n3")
    }

    # Save categorized pool
    output = %{
      "meta" => data["meta"],
      "words_by_level" => categorized
    }

    File.write!("data/v7_lesson_pool_categorized.json", Jason.encode!(output, pretty: true))
    
    IO.puts("\n✅ Categorization complete!")
    IO.puts("Output: data/v7_lesson_pool_categorized.json")
    
    # Print stats
    Enum.each(["n5", "n4", "n3"], fn level ->
      topics = Map.keys(categorized[level])
      word_count = Enum.sum(Enum.map(categorized[level], fn {_, words} -> length(words) end))
      IO.puts("  #{level}: #{length(topics)} topics, #{word_count} words")
    end)
  end

  defp categorize_level(words, level) do
    IO.puts("\nCategorizing #{length(words)} #{level} words...")
    
    # Get relevant topics for this level
    topics = get_topics_for_level(level)
    
    # Categorize each word
    {categorized, uncategorized} = 
      Enum.reduce(words, {%{}, []}, fn word, {acc, uncategorized} ->
        topic = find_best_topic(word, topics)
        
        if topic do
          {Map.update(acc, topic, [word], &[word | &1]), uncategorized}
        else
          {acc, [word | uncategorized]}
        end
      end)

    # Distribute uncategorized words to "Miscellaneous"
    categorized = Map.put(categorized, "Miscellaneous", uncategorized)
    
    # Reverse word lists to maintain original order
    Map.new(categorized, fn {topic, words} -> {topic, Enum.reverse(words)} end)
  end

  defp get_topics_for_level("n5") do
    Map.keys(@topic_keywords)
  end
  
  defp get_topics_for_level("n4") do
    Map.keys(@topic_keywords) ++ [
      "Counters", "Time Counters", "Money Counters", "Polite Verbs",
      "Te-form", "Ta-form", "Nai-form", "Potential Form",
      "Feelings", "Thoughts", "Plans", "Goals", 
      "Company", "Business", "Meetings", "Technology",
      "Friends", "Travel", "Hotels", "Cooking"
    ]
  end
  
  defp get_topics_for_level("n3") do
    Map.keys(@topic_keywords) ++ [
      "Causative-Passive", "Honorifics", "Humble", "Formal",
      "Research", "Education", "Employment", "Economics",
      "Politics", "Society", "Culture", "Literature"
    ]
  end

  defp find_best_topic(word, topics) do
    meaning = String.downcase(word["meaning"] || "")
    example = String.downcase(word["example_english"] || "")
    word_text = word["word"] || ""
    
    # Score each topic
    scored = 
      Enum.map(topics, fn topic ->
        keywords = Map.get(@topic_keywords, topic, [String.downcase(topic)])
        score = score_match(meaning, example, word_text, keywords)
        {topic, score}
      end)
    
    # Find best match (minimum score of 1)
    case Enum.max_by(scored, fn {_, score} -> score end) do
      {topic, score} when score > 0 -> topic
      _ -> nil
    end
  end

  defp score_match(meaning, example, word_text, keywords) do
    meaning_score = count_keywords(meaning, keywords) * 2
    example_score = count_keywords(example, keywords)
    word_score = if word_text in keywords, do: 3, else: 0
    
    meaning_score + example_score + word_score
  end

  defp count_keywords(text, keywords) do
    keywords
    |> Enum.count(fn keyword ->
      String.contains?(text, keyword)
    end)
  end
end

WordCategorizer.categorize()
