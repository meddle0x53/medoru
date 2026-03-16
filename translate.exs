#!/usr/bin/env elixir

defmodule BulgarianTranslator do
  @moduledoc """
  Translates Japanese N5 words from English to Bulgarian.
  Processes the words in batches and saves progress.
  """

  def run(input_file, output_file) do
    IO.puts("Reading #{input_file}...")

    json = File.read!(input_file)
    words = Jason.decode!(json)

    total = length(words)
    IO.puts("Total words to translate: #{total}")

    # Process in smaller batches to show progress
    batch_size = 500
    batches = Enum.chunk_every(words, batch_size)

    translated_batches =
      Enum.with_index(batches, 1)
      |> Enum.map(fn {batch, idx} ->
        IO.puts("Translating batch #{idx}/#{length(batches)}...")

        translated = Enum.map(batch, &translate_word/1)

        # Save progress after each batch
        save_progress(translated, idx)

        IO.puts("  Completed #{idx * batch_size} / #{total} words")
        translated
      end)

    # Flatten all batches
    all_translated = List.flatten(translated_batches)

    # Save final result
    output = Jason.encode!(all_translated, pretty: true)
    File.write!(output_file, output)

    IO.puts("\nTranslation complete!")
    IO.puts("Output saved to: #{output_file}")
    IO.puts("Total words translated: #{length(all_translated)}")
  end

  defp translate_word(word) do
    meaning = word["meaning"]
    bg = translate_meaning(meaning)

    Map.put(word, "translations", %{
      "bg" => %{
        "meaning" => bg
      }
    })
  end

  # Bulgarian translations - organized by category for better coverage
  defp translate_meaning(meaning) do
    case meaning do
      # Basic nouns
      "Japan" ->
        "Япония"

      "Japanese person" ->
        "японец"

      "American (person)" ->
        "американец"

      "German person" ->
        "немец"

      "Vietnamese (person)" ->
        "виетнамец"

      "Persian person" ->
        "персиец"

      "Jew" ->
        "евреин"

      "Thailand" ->
        "Тайланд"

      "Rhine (river)" ->
        "Рейн (река)"

      # Numbers
      "one" ->
        "един"

      "two" ->
        "два"

      "three" ->
        "три"

      "four" ->
        "четири"

      "five" ->
        "пет"

      "six" ->
        "шест"

      "seven" ->
        "седем"

      "eight" ->
        "осем"

      "nine" ->
        "девет"

      "ten" ->
        "десет"

      "hundred" ->
        "сто"

      "thousand" ->
        "хиляда"

      "ten thousand" ->
        "десет хиляди"

      # Counters
      "one (things)" ->
        "едно (нещо)"

      "two (things)" ->
        "две (неща)"

      "three (things)" ->
        "три (неща)"

      "four (things)" ->
        "четири (неща)"

      "five (things)" ->
        "пет (неща)"

      "six (things)" ->
        "шест (неща)"

      "seven (things)" ->
        "седем (неща)"

      "eight (things)" ->
        "осем (неща)"

      "nine (things)" ->
        "девет (неща)"

      "ten (things)" ->
        "десет (неща)"

      # Time
      "today" ->
        "днес"

      "yesterday" ->
        "вчера"

      "tomorrow" ->
        "утре"

      "now" ->
        "сега"

      "this year" ->
        "тази година"

      "last year" ->
        "миналата година"

      "next year" ->
        "догодина"

      "this month" ->
        "този месец"

      "last month" ->
        "миналия месец"

      "next month" ->
        "догодина месец"

      "morning" ->
        "сутрин"

      "noon" ->
        "обед"

      "afternoon" ->
        "следобед"

      "evening" ->
        "вечер"

      "night" ->
        "нощ"

      "day" ->
        "ден"

      "week" ->
        "седмица"

      "month" ->
        "месец"

      "year" ->
        "година"

      "Monday" ->
        "понеделник"

      "Tuesday" ->
        "вторник"

      "Wednesday" ->
        "сряда"

      "Thursday" ->
        "четвъртък"

      "Friday" ->
        "петък"

      "Saturday" ->
        "събота"

      "Sunday" ->
        "неделя"

      "January" ->
        "януари"

      "February" ->
        "февруари"

      "March" ->
        "март"

      "April" ->
        "април"

      "May" ->
        "май"

      "June" ->
        "юни"

      "July" ->
        "юли"

      "August" ->
        "август"

      "September" ->
        "септември"

      "October" ->
        "октомври"

      "November" ->
        "ноември"

      "December" ->
        "декември"

      "1st" ->
        "1-ви"

      "2nd" ->
        "2-ри"

      "3rd" ->
        "3-ти"

      "4th" ->
        "4-ти"

      "5th" ->
        "5-и"

      "6th" ->
        "6-и"

      "7th" ->
        "7-и"

      "8th" ->
        "8-и"

      "9th" ->
        "9-и"

      "10th" ->
        "10-и"

      "20th" ->
        "20-и"

      "31st" ->
        "31-ви"

      # Family
      "father" ->
        "баща"

      "mother" ->
        "майка"

      "parent" ->
        "родител"

      "older brother" ->
        "по-голям брат"

      "older sister" ->
        "по-голяма сестра"

      "younger brother" ->
        "по-малък брат"

      "younger sister" ->
        "по-малка сестра"

      "brother" ->
        "брат"

      "sister" ->
        "сестра"

      "husband" ->
        "съпруг"

      "wife" ->
        "съпруга"

      "child" ->
        "дете"

      "baby" ->
        "бебе"

      "family" ->
        "семейство"

      "grandfather" ->
        "дядо"

      "grandmother" ->
        "баба"

      "grandchild" ->
        "внук/внучка"

      # People
      "person" ->
        "човек"

      "man" ->
        "мъж"

      "woman" ->
        "жена"

      "friend" ->
        "приятел"

      "teacher" ->
        "учител"

      "student" ->
        "ученик"

      "doctor" ->
        "лекар"

      "company employee" ->
        "служител в компания"

      "company president" ->
        "шеф на компания"

      "employee" ->
        "служител"

      "customer" ->
        "клиент"

      "guest" ->
        "гост"

      "name" ->
        "име"

      "I" ->
        "аз"

      "you" ->
        "ти"

      "he" ->
        "той"

      "she" ->
        "тя"

      "we" ->
        "ние"

      "they" ->
        "те"

      # Places
      "house" ->
        "къща"

      "home" ->
        "дом"

      "school" ->
        "училище"

      "company" ->
        "компания"

      "store" ->
        "магазин"

      "shop" ->
        "магазин"

      "hospital" ->
        "болница"

      "bank" ->
        "банка"

      "post office" ->
        "поща"

      "library" ->
        "библиотека"

      "station" ->
        "гара"

      "airport" ->
        "летище"

      "city" ->
        "град"

      "town" ->
        "градче"

      "country" ->
        "страна"

      "countryside" ->
        "село"

      "room" ->
        "стая"

      "kitchen" ->
        "кухня"

      "bathroom" ->
        "баня"

      "toilet" ->
        "тоалетна"

      "entrance" ->
        "вход"

      "inside" ->
        "вътре"

      "outside" ->
        "вън"

      "east" ->
        "изток"

      "west" ->
        "запад"

      "south" ->
        "юг"

      "north" ->
        "север"

      "left" ->
        "ляво"

      "right" ->
        "дясно"

      "front" ->
        "пред"

      "back" ->
        "назад"

      "up, above, on" ->
        "горе, отгоре, върху"

      "down, below" ->
        "долу, отдолу"

      "inside, middle, center" ->
        "вътре, среда, център"

      "near" ->
        "близо"

      "far" ->
        "далеч"

      # Nature
      "sea" ->
        "море"

      "mountain" ->
        "планина"

      "river" ->
        "река"

      "lake" ->
        "езеро"

      "tree" ->
        "дърво"

      "flower" ->
        "цвете"

      "grass" ->
        "трева"

      "sky" ->
        "небе"

      "star" ->
        "звезда"

      "moon" ->
        "луна"

      "sun" ->
        "слънце"

      "rain" ->
        "дъжд"

      "snow" ->
        "сняг"

      "wind" ->
        "вятър"

      "cloud" ->
        "облак"

      "fire" ->
        "огън"

      "water" ->
        "вода"

      "stone" ->
        "камък"

      "earth" ->
        "земя"

      # Food
      "food" ->
        "храна"

      "rice" ->
        "ориз"

      "bread" ->
        "хляб"

      "meat" ->
        "месо"

      "fish" ->
        "риба"

      "vegetable" ->
        "зеленчук"

      "fruit" ->
        "плод"

      "drink" ->
        "напитка"

      "alcohol" ->
        "алкохол"

      "tea" ->
        "чай"

      "coffee" ->
        "кафе"

      "milk" ->
        "мляко"

      "egg" ->
        "яйце"

      "sugar" ->
        "захар"

      "salt" ->
        "сол"

      "pepper" ->
        "пипер"

      "soy sauce" ->
        "соев сос"

      "meal" ->
        "хранене"

      "breakfast" ->
        "закуска"

      "lunch" ->
        "обяд"

      "dinner" ->
        "вечеря"

      "snack" ->
        "закуска (храна)"

      # Body parts
      "body" ->
        "тяло"

      "head" ->
        "глава"

      "hair" ->
        "коса"

      "face" ->
        "лице"

      "eye" ->
        "око"

      "ear" ->
        "ухо"

      "nose" ->
        "нос"

      "mouth" ->
        "уста"

      "tooth" ->
        "зъб"

      "hand" ->
        "ръка"

      "foot" ->
        "крак"

      "leg" ->
        "крак"

      "arm" ->
        "ръка"

      "finger" ->
        "пръст"

      "neck" ->
        "врат"

      "stomach" ->
        "корем"

      "back" ->
        "гръб"

      "heart" ->
        "сърце"

      "blood" ->
        "кръв"

      "bone" ->
        "кост"

      "skin" ->
        "кожа"

      # Colors
      "red" ->
        "червен"

      "blue" ->
        "син"

      "yellow" ->
        "жълт"

      "green" ->
        "зелен"

      "white" ->
        "бял"

      "black" ->
        "черен"

      "brown" ->
        "кафяв"

      "color" ->
        "цвят"

      # Common adjectives
      "big, large" ->
        "голям"

      "small" ->
        "малък"

      "long" ->
        "дълъг"

      "short" ->
        "къс"

      "high, tall" ->
        "висок"

      "low" ->
        "нисък"

      "wide" ->
        "широк"

      "narrow" ->
        "тесен"

      "thick" ->
        "дебел"

      "thin" ->
        "тънък"

      "heavy" ->
        "тежък"

      "light" ->
        "лек"

      "fast" ->
        "бърз"

      "slow" ->
        "бавен"

      "early" ->
        "рано"

      "late" ->
        "късно"

      "new" ->
        "нов"

      "old" ->
        "стар"

      "good" ->
        "добър"

      "bad" ->
        "лош"

      "beautiful" ->
        "красив"

      "ugly" ->
        "грозен"

      "easy" ->
        "лесен"

      "difficult" ->
        "труден"

      "cheap" ->
        "евтин"

      "expensive" ->
        "скъп"

      "hot" ->
        "горещ"

      "cold" ->
        "студен"

      "warm" ->
        "топъл"

      "cool" ->
        "прохладен"

      "many, much" ->
        "много"

      "few, little" ->
        "малко"

      "some" ->
        "някои"

      "all" ->
        "всички"

      "every" ->
        "всеки"

      "other" ->
        "друг"

      "same" ->
        "същият"

      "different" ->
        "различен"

      "happy" ->
        "щастлив"

      "sad" ->
        "тъжен"

      "fun" ->
        "забавен"

      "interesting" ->
        "интересен"

      "boring" ->
        "скучен"

      "delicious" ->
        "вкусен"

      "tasty" ->
        "вкусен"

      "delicious, tasty" ->
        "вкусен"

      "clean" ->
        "чист"

      "dirty" ->
        "мръсен"

      "convenient" ->
        "удобен"

      "inconvenient" ->
        "неудобен"

      "busy" ->
        "зает"

      "free, spare time" ->
        "свободен"

      "healthy" ->
        "здрав"

      "sick" ->
        "болен"

      "kind" ->
        "добър, мил"

      "unpleasant" ->
        "неприятен"

      "scary" ->
        "страшен"

      "cute" ->
        "сладък"

      "cool (style)" ->
        "готин"

      "amazing" ->
        "изумителен"

      "famous" ->
        "известен"

      "strong" ->
        "силен"

      "weak" ->
        "слаб"

      # Common verbs
      "to go" ->
        "отивам"

      "to come" ->
        "идвам"

      "to return" ->
        "връщам се"

      "to do, to make" ->
        "правя"

      "to do" ->
        "правя"

      "to make" ->
        "правя"

      "to see, to look, to watch" ->
        "гледам"

      "to look" ->
        "гледам"

      "to watch" ->
        "гледам"

      "to see" ->
        "виждам"

      "to listen, to hear" ->
        "слушам"

      "to hear" ->
        "чувам"

      "to speak, to talk, to say" ->
        "говоря"

      "to say" ->
        "казвам"

      "to talk" ->
        "разговарям"

      "to read" ->
        "чета"

      "to write" ->
        "пиша"

      "to buy" ->
        "купувам"

      "to sell" ->
        "продавам"

      "to eat" ->
        "ям"

      "to drink" ->
        "пия"

      "to sleep" ->
        "спя"

      "to wake up" ->
        "ставам"

      "to stand up" ->
        "ставам"

      "to stand" ->
        "стоя"

      "to sit" ->
        "седя"

      "to lie down" ->
        "лягам"

      "to get up" ->
        "ставам"

      "to stop" ->
        "спирам"

      "to wait" ->
        "чакам"

      "to walk" ->
        "вървя"

      "to run" ->
        "тичам"

      "to swim" ->
        "плувам"

      "to fly" ->
        "летя"

      "to play" ->
        "играя"

      "to sing" ->
        "пея"

      "to dance" ->
        "танцувам"

      "to learn" ->
        "уча"

      "to study" ->
        "уча"

      "to teach" ->
        "преподавам"

      "to meet" ->
        "срещам"

      "to call" ->
        "обаждам се"

      "to answer" ->
        "отговарям"

      "to ask" ->
        "питам"

      "to think" ->
        "мисля"

      "to know" ->
        "зная"

      "to understand" ->
        "разбирам"

      "to remember" ->
        "помня"

      "to forget" ->
        "забравям"

      "to like" ->
        "харесвам"

      "to love" ->
        "обичам"

      "to hate" ->
        "мразя"

      "to want" ->
        "искам"

      "to need" ->
        "нуждая се"

      "to give" ->
        "давам"

      "to receive" ->
        "получавам"

      "to lend" ->
        "давам на заем"

      "to borrow" ->
        "взимам назаем"

      "to use" ->
        "използвам"

      "to put" ->
        "слагам"

      "to place" ->
        "поставям"

      "to hold" ->
        "държа"

      "to have" ->
        "имам"

      "to take" ->
        "взимам"

      "to get" ->
        "получавам"

      "to bring" ->
        "нося"

      "to send" ->
        "изпращам"

      "to work" ->
        "работя"

      "to rest" ->
        "почивам"

      "to die" ->
        "умирам"

      "to live" ->
        "живея"

      "to be born" ->
        "раждам се"

      "to begin" ->
        "започвам"

      "to start" ->
        "започвам"

      "to finish" ->
        "завършвам"

      "to end" ->
        "свършвам"

      "to open" ->
        "отварям"

      "to close" ->
        "затварям"

      "to turn on" ->
        "включвам"

      "to turn off" ->
        "изключвам"

      "to enter" ->
        "влизам"

      "to exit" ->
        "излизам"

      "to get on" ->
        "качвам се"

      "to get off" ->
        "свалям се"

      "to wear, to put on" ->
        "обличам"

      "to change clothes" ->
        "преобличам се"

      "to put on (accessories)" ->
        "слагам (аксесоари)"

      "to take off" ->
        "свалям"

      "to be (animate), to exist" ->
        "съществувам (жив)"

      "to be (inanimate), to exist" ->
        "съществувам (нежив)"

      "to become" ->
        "ставам"

      "to arrive" ->
        "пристигам"

      "to climb" ->
        "катеря се"

      "to descend" ->
        "слизам"

      "to pass" ->
        "минавам"

      "to cross" ->
        "пресичам"

      "to cut" ->
        "режа"

      "to break" ->
        "чупя"

      "to wash" ->
        "мия"

      "to clean" ->
        "почиствам"

      "to help" ->
        "помагам"

      "to help out" ->
        "помагам"

      "to be careful" ->
        "внимавам"

      "to pay attention" ->
        "внимавам"

      "to look for" ->
        "търся"

      "to find" ->
        "намирам"

      "to lose" ->
        "губя"

      "to try" ->
        "опитвам"

      "to decide" ->
        "решавам"

      "to choose" ->
        "избирам"

      "to practice" ->
        "практикувам"

      "to exercise" ->
        "тренирам"

      "to laugh" ->
        "смея се"

      "to smile" ->
        "усмихвам се"

      "to cry" ->
        "плача"

      "to get angry" ->
        "ядосвам се"

      "to worry" ->
        "тревожа се"

      "to be surprised" ->
        "изненадвам се"

      "to be pleased" ->
        "радвам се"

      "to be sad" ->
        "тъжа се"

      "to be lonely" ->
        "самотен съм"

      "to enjoy oneself" ->
        "забавлявам се"

      "to be embarrassed" ->
        "срамувам се"

      "to be interested in" ->
        "интересувам се от"

      "to be able to, to be capable of" ->
        "мога"

      "to understand, to become clear" ->
        "разбирам, става ясно"

      "to show" ->
        "показвам"

      "to teach, to instruct" ->
        "обучавам"

      "to allow" ->
        "позволявам"

      "to refuse" ->
        "отказвам"

      "to accept" ->
        "приемам"

      "to promise" ->
        "обещавам"

      "to apologize" ->
        "извинявам се"

      "to thank" ->
        "благодаря"

      "to invite" ->
        "каня"

      "to answer, to reply" ->
        "отговарям"

      "to reply" ->
        "отговарям"

      "to ask" ->
        "питам"

      "to order" ->
        "поръчвам"

      "to reserve" ->
        "резервирам"

      "to pay" ->
        "плащам"

      "to cost" ->
        "струва"

      "to save money" ->
        "спестявам пари"

      "to collect" ->
        "събирам"

      "to count" ->
        "броя"

      "to measure" ->
        "измервам"

      "to compare" ->
        "сравнявам"

      "to add" ->
        "добавям"

      "to increase" ->
        "увеличавам"

      "to decrease" ->
        "намалявам"

      "to grow" ->
        "раста"

      "to become smaller" ->
        "намалявам"

      "to become larger" ->
        "увеличавам се"

      "to be enough" ->
        "достатъчно е"

      "to be insufficient" ->
        "недостатъчно е"

      "to be full" ->
        "пълно е"

      "to be empty" ->
        "празно е"

      # Money
      "money" ->
        "пари"

      "yen" ->
        "йени"

      "change" ->
        "ресто"

      "price" ->
        "цена"

      "bill" ->
        "сметка"

      "fee" ->
        "такса"

      "salary" ->
        "заплата"

      "wallet" ->
        "портфейл"

      "purse" ->
        "чантичка за пари"

      "cash" ->
        "кеш"

      "credit card" ->
        "кредитна карта"

      "check" ->
        "чек"

      "receipt" ->
        "касова бележка"

      "account" ->
        "сметка"

      "deposit" ->
        "депозит"

      "withdrawal" ->
        "теглене"

      # School
      "student" ->
        "ученик"

      "pupil" ->
        "ученик"

      "teacher" ->
        "учител"

      "class" ->
        "клас"

      "lesson" ->
        "урок"

      "test" ->
        "тест"

      "exam" ->
        "изпит"

      "homework" ->
        "домашна работа"

      "report card" ->
        "дневник с оценки"

      "textbook" ->
        "учебник"

      "notebook" ->
        "тетрадка"

      "dictionary" ->
        "речник"

      "pen" ->
        "химикалка"

      "pencil" ->
        "молив"

      "eraser" ->
        "гума"

      "bag" ->
        "чанта"

      "desk" ->
        "бюро"

      "chair" ->
        "стол"

      "blackboard" ->
        "дъска"

      "chalk" ->
        "тебешир"

      "classroom" ->
        "класна стая"

      "subject" ->
        "предмет"

      "math" ->
        "математика"

      "science" ->
        "наука"

      "history" ->
        "история"

      "geography" ->
        "география"

      "English" ->
        "английски"

      "Japanese" ->
        "японски"

      "question" ->
        "въпрос"

      "answer" ->
        "отговор"

      "problem" ->
        "проблем"

      "right, correct" ->
        "правилно"

      "wrong" ->
        "грешно"

      "grade, mark" ->
        "оценка"

      "point, score" ->
        "точка, резултат"

      "homework" ->
        "домашна работа"

      "review" ->
        "преговор"

      "graduate" ->
        "завършвам"

      # Work
      "work" ->
        "работа"

      "job" ->
        "работа"

      "company" ->
        "компания"

      "office" ->
        "офис"

      "meeting" ->
        "среща"

      "business" ->
        "бизнес"

      "business trip" ->
        "командировка"

      "conference" ->
        "конференция"

      "interview" ->
        "интервю"

      "resume" ->
        "автобиография"

      "department" ->
        "отдел"

      "colleague" ->
        "колега"

      "boss" ->
        "шеф"

      "subordinate" ->
        "подчинен"

      "client" ->
        "клиент"

      "project" ->
        "проект"

      "plan" ->
        "план"

      "schedule" ->
        "график"

      "deadline" ->
        "краен срок"

      "overtime" ->
        "извънреден труд"

      "holiday" ->
        "празник"

      "vacation" ->
        "ваканция"

      "day off" ->
        "почивен ден"

      "sick day" ->
        "болничен"

      "retirement" ->
        "пенсиониране"

      # Transportation
      "car" ->
        "кола"

      "bus" ->
        "автобус"

      "train" ->
        "влак"

      "subway" ->
        "метро"

      "airplane" ->
        "самолет"

      "ship" ->
        "кораб"

      "boat" ->
        "лодка"

      "bicycle" ->
        "колело"

      "taxi" ->
        "такси"

      "walk" ->
        "разходка"

      "station" ->
        "гара, спирка"

      "ticket" ->
        "билет"

      "platform" ->
        "перон"

      "seat" ->
        "седалка"

      "window seat" ->
        "място до прозореца"

      "aisle seat" ->
        "място до пътеката"

      "timetable" ->
        "разписание"

      "delay" ->
        "закъснение"

      "transfer" ->
        "прекачване"

      "passport" ->
        "паспорт"

      "suitcase" ->
        "куфар"

      "bag, satchel" ->
        "чанта, куфарче"

      "bag" ->
        "чанта"

      "gasoline" ->
        "бензин"

      "traffic" ->
        "трафик"

      "traffic light" ->
        "светофар"

      "crosswalk" ->
        "пешеходна пътека"

      "intersection" ->
        "кръстовище"

      # Daily items
      "telephone" ->
        "телефон"

      "cell phone" ->
        "мобилен телефон"

      "email" ->
        "имейл"

      "computer" ->
        "компютър"

      "television" ->
        "телевизия"

      "radio" ->
        "радио"

      "newspaper" ->
        "вестник"

      "magazine" ->
        "списание"

      "book" ->
        "книга"

      "dictionary" ->
        "речник"

      "map" ->
        "карта"

      "clock" ->
        "часовник"

      "watch" ->
        "касов часовник"

      "glasses" ->
        "очила"

      "camera" ->
        "камера"

      "key" ->
        "ключ"

      "umbrella" ->
        "чадър"

      "fan" ->
        "вентилатор"

      "heater" ->
        "печка"

      "air conditioner" ->
        "климатик"

      "refrigerator" ->
        "хладилник"

      "washing machine" ->
        "пералня"

      "stove" ->
        "печка"

      "microwave" ->
        "микровълнова"

      "vacuum cleaner" ->
        "прахосмукачка"

      "mirror" ->
        "огледало"

      "window" ->
        "прозорец"

      "door" ->
        "врата"

      "wall" ->
        "стена"

      "floor" ->
        "под"

      "ceiling" ->
        "таван"

      "roof" ->
        "покрив"

      "stairs" ->
        "стълби"

      "elevator" ->
        "асансьор"

      "escalator" ->
        "ескалатор"

      "futon" ->
        "футон"

      "pillow" ->
        "възглавница"

      "blanket" ->
        "одеяло"

      "sheet" ->
        "чаршаф"

      "curtain" ->
        "завеса"

      "light" ->
        "светлина"

      "lamp" ->
        "лампа"

      "trash" ->
        "боклук"

      "trashcan" ->
        "кошче за боклук"

      # Clothing
      "clothes" ->
        "дрехи"

      "shirt" ->
        "риза"

      "pants" ->
        "панталон"

      "trousers" ->
        "панталон"

      "skirt" ->
        "пола"

      "dress" ->
        "рокля"

      "suit" ->
        "костюм"

      "coat" ->
        "палто"

      "jacket" ->
        "яке"

      "sweater" ->
        "пуловер"

      "T-shirt" ->
        "тениска"

      "blouse" ->
        "блуза"

      "shoes" ->
        "обувки"

      "socks" ->
        "чорапи"

      "hat" ->
        "шапка"

      "cap" ->
        "шапка"

      "necktie" ->
        "вратовръзка"

      "gloves" ->
        "ръкавици"

      "scarf" ->
        "шал"

      "belt" ->
        "колан"

      "bag, handbag" ->
        "чанта"

      # Adverbs
      "very" ->
        "много"

      "a little" ->
        "малко"

      "slowly" ->
        "бавно"

      "quickly" ->
        "бързо"

      "always" ->
        "винаги"

      "usually" ->
        "обикновено"

      "often" ->
        "често"

      "sometimes" ->
        "понякога"

      "occasionally" ->
        "от време на време"

      "rarely" ->
        "рядко"

      "never" ->
        "никога"

      "again" ->
        "отново"

      "still" ->
        "все още"

      "already" ->
        "вече"

      "yet" ->
        "още"

      "more" ->
        "повече"

      "most" ->
        "най-много"

      "too" ->
        "твърде"

      "about, approximately" ->
        "около"

      "just (now)" ->
        "току-що"

      "immediately" ->
        "веднага"

      "finally" ->
        "накрая"

      "at last" ->
        "най-после"

      "maybe" ->
        "може би"

      "probably" ->
        "вероятно"

      "of course" ->
        "разбира се"

      "certainly" ->
        "със сигурност"

      "truly" ->
        "наистина"

      "really" ->
        "наистина"

      "especially" ->
        "особено"

      "mostly" ->
        "главно"

      "almost" ->
        "почти"

      "quite" ->
        "доста"

      "completely" ->
        "напълно"

      "totally" ->
        "напълно"

      "well" ->
        "добре"

      "fast" ->
        "бързо"

      "slowly" ->
        "бавно"

      "carefully" ->
        "внимателно"

      "quietly" ->
        "тихо"

      "loudly" ->
        "силно"

      "early" ->
        "рано"

      "late" ->
        "късно"

      "here" ->
        "тук"

      "there" ->
        "там"

      "over there" ->
        "там, отвъд"

      "everywhere" ->
        "навсякъде"

      "somewhere" ->
        "някъде"

      "nowhere" ->
        "никъде"

      "inside" ->
        "вътре"

      "outside" ->
        "отвън"

      "together" ->
        "заедно"

      "alone" ->
        "сам"

      "only" ->
        "само"

      "however" ->
        "обаче"

      "therefore" ->
        "затова"

      "moreover" ->
        "освен това"

      "but" ->
        "но"

      "and" ->
        "и"

      "or" ->
        "или"

      "if" ->
        "ако"

      "because" ->
        "защото"

      "although" ->
        "въпреки че"

      "even" ->
        "дори"

      "also, too" ->
        "също"

      "too, also" ->
        "също"

      # Question words
      "what" ->
        "какво"

      "who" ->
        "кой"

      "where" ->
        "къде"

      "when" ->
        "кога"

      "why" ->
        "защо"

      "how" ->
        "как"

      "how much" ->
        "колко"

      "how many" ->
        "колко"

      "which" ->
        "кой"

      "what kind of" ->
        "какъв"

      # Prepositions
      "to, toward" ->
        "към"

      "from" ->
        "от"

      "until, up to" ->
        "до"

      "since" ->
        "откакто"

      "by" ->
        "до"

      "at, in" ->
        "в, на"

      "with" ->
        "с"

      "without" ->
        "без"

      "about" ->
        "за"

      "for" ->
        "за"

      "of" ->
        "на"

      "before" ->
        "преди"

      "after" ->
        "след"

      "between" ->
        "между"

      "among" ->
        "сред"

      "during" ->
        "по време на"

      "through" ->
        "през"

      "across" ->
        "през"

      "along" ->
        "по"

      "around" ->
        "около"

      "against" ->
        "срещу"

      "toward" ->
        "към"

      "into" ->
        "в"

      "onto" ->
        "върху"

      "out of" ->
        "от"

      "off" ->
        "от"

      "over" ->
        "над"

      "under" ->
        "под"

      "above" ->
        "над"

      "below" ->
        "под"

      "behind" ->
        "зад"

      "in front of" ->
        "пред"

      "beside" ->
        "до"

      "next to" ->
        "до"

      "near" ->
        "близо до"

      "far from" ->
        "далеч от"

      "on" ->
        "на"

      "at" ->
        "в, на"

      "in" ->
        "в"

      # Weather
      "weather" ->
        "време"

      "sunny" ->
        "слънчево"

      "rainy" ->
        "дъждовно"

      "cloudy" ->
        "облачно"

      "snowy" ->
        "снежно"

      "windy" ->
        "ветровито"

      "warm" ->
        "топло"

      "cool" ->
        "прохладно"

      "hot" ->
        "горещо"

      "cold" ->
        "студено"

      "temperature" ->
        "температура"

      "degree" ->
        "градус"

      "humidity" ->
        "влажност"

      "typhoon" ->
        "тайфун"

      # Health
      "health" ->
        "здраве"

      "illness" ->
        "болест"

      "sickness" ->
        "болест"

      "symptom" ->
        "симптом"

      "fever" ->
        "треска"

      "cough" ->
        "кашлица"

      "headache" ->
        "главоболие"

      "stomachache" ->
        "коремна болка"

      "toothache" ->
        "болка в зъб"

      "pain" ->
        "болка"

      "medicine" ->
        "лекарство"

      "pharmacy" ->
        "аптека"

      "doctor" ->
        "лекар"

      "dentist" ->
        "зъболекар"

      "hospital" ->
        "болница"

      "clinic" ->
        "клиника"

      "emergency" ->
        "спешно"

      "injury" ->
        "нараняване"

      "wound" ->
        "рана"

      "bandage" ->
        "превръзка"

      "nurse" ->
        "сестра"

      "operation" ->
        "операция"

      "injection" ->
        "инжекция"

      "prescription" ->
        "рецепта"

      "allergy" ->
        "алергия"

      "hospitalization" ->
        "хоспитализация"

      "discharge from hospital" ->
        "изписване от болница"

      # Others
      "thing" ->
        "нещо"

      "place" ->
        "място"

      "time" ->
        "време"

      "reason" ->
        "причина"

      "way, method" ->
        "начин, метод"

      "word" ->
        "дума"

      "sentence" ->
        "изречение"

      "letter" ->
        "писмо"

      "page" ->
        "страница"

      "part" ->
        "част"

      "example" ->
        "пример"

      "end" ->
        "край"

      "beginning" ->
        "начало"

      "middle" ->
        "среда"

      "top" ->
        "връх"

      "bottom" ->
        "дъно"

      "side" ->
        "страна"

      "line" ->
        "линия"

      "shape" ->
        "форма"

      "size" ->
        "размер"

      "weight" ->
        "тегло"

      "length" ->
        "дължина"

      "width" ->
        "ширина"

      "height" ->
        "височина"

      "number" ->
        "номер"

      "amount" ->
        "количество"

      "few" ->
        "малко"

      "many" ->
        "много"

      "half" ->
        "половина"

      "pair" ->
        "чифт"

      "set" ->
        "комплект"

      "piece" ->
        "част"

      "type, kind" ->
        "вид, тип"

      "way" ->
        "начин"

      "problem" ->
        "проблем"

      "mistake" ->
        "грешка"

      "trouble" ->
        "неприятност"

      "accident" ->
        "инцидент"

      "news" ->
        "новина"

      "information" ->
        "информация"

      "message" ->
        "съобщение"

      "sign" ->
        "знак"

      "mark" ->
        "знак"

      "sound" ->
        "звук"

      "voice" ->
        "глас"

      "smell" ->
        "мирис"

      "taste" ->
        "вкус"

      "touch" ->
        "докосване"

      "rule" ->
        "правило"

      "manner" ->
        "маниер"

      "custom" ->
        "обичай"

      "habit" ->
        "навик"

      "culture" ->
        "култура"

      "society" ->
        "общество"

      "government" ->
        "правителство"

      "politics" ->
        "политика"

      "economy" ->
        "икономика"

      "religion" ->
        "религия"

      "art" ->
        "изкуство"

      "music" ->
        "музика"

      "song" ->
        "песен"

      "sport" ->
        "спорт"

      "game" ->
        "игра"

      "hobby" ->
        "хоби"

      "travel" ->
        "пътуване"

      "trip" ->
        "екскурзия"

      "tour" ->
        "обиколка"

      "guide" ->
        "водач"

      "map" ->
        "карта"

      "direction" ->
        "посока"

      "address" ->
        "адрес"

      "postal code" ->
        "пощенски код"

      "number" ->
        "номер"

      "signboard" ->
        "табела"

      "poster" ->
        "плакат"

      "menu" ->
        "меню"

      "bill, check" ->
        "сметка"

      "receipt" ->
        "касова бележка"

      "stamp" ->
        "печат"

      "chopsticks" ->
        "палички за хранене"

      "spoon" ->
        "лъжица"

      "fork" ->
        "вилица"

      "knife" ->
        "нож"

      "plate" ->
        "чиния"

      "bowl" ->
        "купа"

      "cup" ->
        "чаша"

      "glass" ->
        "чаша"

      "bottle" ->
        "бутилка"

      "box" ->
        "кутия"

      "bag" ->
        "плик"

      "paper bag" ->
        "хартиен плик"

      "plastic bag" ->
        "пликче"

      "shopping" ->
        "пазаруване"

      "gift" ->
        "подарък"

      "postcard" ->
        "пощенска картичка"

      "letter" ->
        "писмо"

      "stamp" ->
        "марка"

      "envelope" ->
        "плик"

      "package" ->
        "пакет"

      "delivery" ->
        "доставка"

      "postage" ->
        "пощенска такса"

      # Pronouns
      "I (formal)" ->
        "аз (формално)"

      "I (casual)" ->
        "аз (неформално)"

      "you (formal)" ->
        "вие (формално)"

      "you (casual)" ->
        "ти (неформално)"

      "this one" ->
        "този"

      "that one" ->
        "онзи"

      "that one (far)" ->
        "онзи (далечен)"

      "which one" ->
        "кой"

      "here" ->
        "тук"

      "there" ->
        "там"

      "over there" ->
        "там (далеч)"

      "where" ->
        "къде"

      "this (thing)" ->
        "това"

      "that (thing)" ->
        "онова"

      "that (thing far)" ->
        "онова (далеч)"

      "what" ->
        "какво"

      "this person" ->
        "този човек"

      "that person" ->
        "онзи човек"

      "that person (far)" ->
        "онзи човек (далеч)"

      "who" ->
        "кой"

      # Country names
      "country" ->
        "страна"

      "country name" ->
        "име на страна"

      "America, USA" ->
        "Америка, САЩ"

      "UK" ->
        "Великобритания"

      "England" ->
        "Англия"

      "France" ->
        "Франция"

      "Germany" ->
        "Германия"

      "Italy" ->
        "Италия"

      "Spain" ->
        "Испания"

      "Russia" ->
        "Русия"

      "China" ->
        "Китай"

      "Korea" ->
        "Корея"

      "India" ->
        "Индия"

      "Australia" ->
        "Австралия"

      "Canada" ->
        "Канада"

      "Brazil" ->
        "Бразилия"

      "Mexico" ->
        "Мексико"

      "language" ->
        "език"

      "English (language)" ->
        "английски (език)"

      "Japanese (language)" ->
        "японски (език)"

      "Chinese (language)" ->
        "китайски (език)"

      "Korean (language)" ->
        "корейски (език)"

      "French" ->
        "френски"

      "Spanish" ->
        "испански"

      "German" ->
        "немски"

      # Particles
      "topic marker" ->
        "маркер за тема"

      "subject marker" ->
        "маркер за подлог"

      "object marker" ->
        "маркер за обект"

      "also, too" ->
        "също"

      "to, toward" ->
        "към"

      "and" ->
        "и"

      "but" ->
        "но"

      "from" ->
        "от"

      "until" ->
        "до"

      "only" ->
        "само"

      "about" ->
        "около"

      "such things as" ->
        "неща като"

      "question marker" ->
        "въпросителен маркер"

      "possessive" ->
        "притежателен"

      "and (in lists)" ->
        "и (в списъци)"

      "or" ->
        "или"

      "emphasis" ->
        "акцент"

      "quotation" ->
        "цитат"

      "called, named" ->
        "наречен, кръстен"

      "yes-no question" ->
        "въпрос с да/не"

      "even if" ->
        "дори ако"

      "however" ->
        "обаче"

      "if" ->
        "ако"

      "because" ->
        "защото"

      "although" ->
        "въпреки че"

      "and then" ->
        "и тогава"

      "but, however" ->
        "но, обаче"

      "or" ->
        "или"

      "well then" ->
        "тогава"

      "reason" ->
        "причина"

      "because of" ->
        "поради"

      "in order to" ->
        "за да"

      "for the purpose of" ->
        "с цел"

      "direction" ->
        "посока"

      "until, as far as" ->
        "до, доколкото"

      "approximately" ->
        "приблизително"

      "more than" ->
        "повече от"

      "about" ->
        "за"

      "according to" ->
        "според"

      "by means of" ->
        "посредством"

      "in, at" ->
        "в, на"

      "by (time)" ->
        "до (време)"

      "per" ->
        "на"

      "for (duration)" ->
        "за (продължителност)"

      "during" ->
        "по време на"

      "at (time)" ->
        "в (време)"

      "in (time)" ->
        "за (време)"

      "after" ->
        "след"

      "before" ->
        "преди"

      "ago" ->
        "преди"

      "later" ->
        "по-късно"

      "every" ->
        "всеки"

      "only" ->
        "само"

      "as much as" ->
        "толкова, колкото"

      "about" ->
        "за"

      "after" ->
        "след"

      "as" ->
        "като"

      "while" ->
        "докато"

      "compared to" ->
        "в сравнение с"

      "as~as" ->
        "толкова~колкото"

      "the more~the more" ->
        "колкото повече~толкова повече"

      # Greetings
      "good morning" ->
        "добро утро"

      "hello" ->
        "здравей"

      "good evening" ->
        "добър вечер"

      "good night" ->
        "лека нощ"

      "goodbye" ->
        "довиждане"

      "see you" ->
        "до виждане"

      "thank you" ->
        "благодаря"

      "thank you (polite)" ->
        "благодаря (учтиво)"

      "thank you very much" ->
        "много благодаря"

      "you're welcome" ->
        "няма защо"

      "please" ->
        "моля"

      "I'm sorry" ->
        "съжалявам"

      "excuse me" ->
        "извинете"

      "no" ->
        "не"

      "yes" ->
        "да"

      "I see" ->
        "разбирам"

      "really" ->
        "наистина"

      "congratulations" ->
        "честито"

      "happy new year" ->
        "честита нова година"

      "happy birthday" ->
        "честит рожден ден"

      "please do your best" ->
        "късмет"

      "good luck" ->
        "късмет"

      "take care" ->
        "грижи се"

      "have a nice trip" ->
        "приятно пътуване"

      # Expressions
      "good" ->
        "добре"

      "no, not at all" ->
        "не, изобщо не"

      "nothing" ->
        "нищо"

      "how do you do?" ->
        "как сте?"

      "it's been a while" ->
        "давна не сме се виждали"

      "welcome" ->
        "добре дошли"

      "good work" ->
        "добра работа"

      "I'm home" ->
        "вкъщи съм"

      "welcome back" ->
        "добре дошъл"

      "itadakimasu (before eating)" ->
        "приятно хранене"

      "gochisousama (after eating)" ->
        "благодаря за храната"

      "otsukaresama (after work)" ->
        "добра работа"

      "ganbatte" ->
        "давай"

      "gambatte" ->
        "давай"

      "good job" ->
        "добра работа"

      "cheers!" ->
        "наздраве!"

      "help" ->
        "помощ"

      "danger" ->
        "опасност"

      "beware" ->
        "внимавай"

      "no smoking" ->
        "не пушете"

      "no entry" ->
        "вход забранен"

      "stop" ->
        "стоп"

      "closed" ->
        "затворено"

      "open" ->
        "отворено"

      "full" ->
        "пълно"

      "vacant" ->
        "свободно"

      "push" ->
        "натисни"

      "pull" ->
        "дръпни"

      "entrance" ->
        "вход"

      "exit" ->
        "изход"

      "emergency exit" ->
        "аварийнен изход"

      "toilet" ->
        "тоалетна"

      "men" ->
        "мъже"

      "women" ->
        "жени"

      "free of charge" ->
        "безплатно"

      "discount" ->
        "отстъпка"

      "sale" ->
        "разпродажба"

      "bargain" ->
        "изгодна покупка"

      "tax" ->
        "данък"

      "consumption tax" ->
        "данък върху потреблението"

      "including tax" ->
        "включително данък"

      "tax excluded" ->
        "без данък"

      "master, host" ->
        "домакин"

      "shop attendant" ->
        "продавач"

      "doctor" ->
        "доктор"

      "teacher" ->
        "учител"

      "Mr., Ms., Mrs." ->
        "г-н, г-жа"

      "san (polite suffix)" ->
        "сан (учтив наставка)"

      "kun (suffix for boys)" ->
        "кун (наставка за момчета)"

      "chan (suffix for children)" ->
        "чан (наставка за деца)"

      "sama (respectful suffix)" ->
        "сама (почтителна наставка)"

      "sensei (teacher, doctor)" ->
        "сенсей (учител, лекар)"

      # Kanji readings and components
      "kanji" ->
        "канджи"

      "hiragana" ->
        "хирагана"

      "katakana" ->
        "катакана"

      "reading" ->
        "четене"

      "meaning" ->
        "значение"

      "stroke" ->
        "черта"

      "stroke order" ->
        "ред на чертите"

      "radical" ->
        "радикал"

      "component" ->
        "компонент"

      "on reading" ->
        "он четене"

      "kun reading" ->
        "кун четене"

      "Chinese character" ->
        "китайски йероглиф"

      "classification for Japanese verb with the dictionary form ending in \"gu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"gu\""

      "classification for Japanese verb with the dictionary form ending in \"pu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"pu\""

      "classification for Japanese verb with the dictionary form ending in \"dzu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"dzu\""

      "the \"ta\" column of the Japanese syllabary table (ta, chi, tsu, te, to)" ->
        "колоната \"ta\" от японската сричкова таблица (ta, chi, tsu, te, to)"

      "the \"sa\" column of the Japanese syllabary table (sa, shi, su, se, so)" ->
        "колоната \"sa\" от японската сричкова таблица (sa, shi, su, se, so)"

      "the \"za\" column of the Japanese syllabary table (za, ji, zu, ze, zo)" ->
        "колоната \"za\" от японската сричкова таблица (za, ji, zu, ze, zo)"

      "the \"ma\" column of the Japanese syllabary table (ma, mi, mu, me, mo)" ->
        "колоната \"ma\" от японската сричкова таблица (ma, mi, mu, me, mo)"

      "the \"ra\" column of the Japanese syllabary table (ra, ri, ru, re, ro)" ->
        "колоната \"ra\" от японската сричкова таблица (ra, ri, ru, re, ro)"

      "the \"ha\" column of the Japanese syllabary table (ha, hi, fu, he, ho)" ->
        "колоната \"ha\" от японската сричкова таблица (ha, hi, fu, he, ho)"

      "the \"ya\" column of the Japanese syllabary table (ya, yu, yo)" ->
        "колоната \"ya\" от японската сричкова таблица (ya, yu, yo)"

      # Common phrases
      "thank you for the meal (before eating)" ->
        "благодаря за храната (преди хранене)"

      "thank you for the meal (after eating)" ->
        "благодаря за храната (след хранене)"

      "it can't be helped" ->
        "не може да се направи нищо"

      "please treat me favorably" ->
        "моля, бъдете благосклонни"

      "please excuse me for going first" ->
        "извинете, че тръгвам пръв"

      "please wait a moment" ->
        "моля, изчакайте момент"

      "let's eat" ->
        "да ядем"

      "I'm off" ->
        "тръгвам"

      "welcome home" ->
        "добре дошъл вкъщи"

      "be careful" ->
        "внимавай"

      "have a good trip" ->
        "приятно пътуване"

      "goodnight" ->
        "лека нощ"

      "see you tomorrow" ->
        "до утре"

      "please go ahead" ->
        "моля, продължете"

      "I don't mind" ->
        "нямам нищо против"

      "never mind" ->
        "няма значение"

      "no problem" ->
        "няма проблем"

      "that's right" ->
        "прав си"

      "is that so?" ->
        "така ли е?"

      "I understand" ->
        "разбирам"

      "I don't understand" ->
        "не разбирам"

      "I don't know" ->
        "не знам"

      "I know" ->
        "знам"

      "I think so" ->
        "мисля така"

      "I don't think so" ->
        "не мисля така"

      "probably" ->
        "вероятно"

      "maybe not" ->
        "може би не"

      "of course" ->
        "разбира се"

      "not at all" ->
        "изобщо не"

      "don't mention it" ->
        "няма защо"

      "excuse me for interrupting" ->
        "извинете, че прекъсвам"

      "excuse me for leaving before you" ->
        "извинете, че си тръгвам преди вас"

      "excuse me for saying this" ->
        "извинете, че казвам това"

      "sorry for the wait" ->
        "съжалявам за чакането"

      "I have arrived" ->
        "пристигнах"

      "long time no see" ->
        "давна не сме се виждали"

      "I'm counting on you" ->
        "разчитам на теб"

      "I'm leaving it to you" ->
        "поверявам ти го"

      "please don't mind" ->
        "моля, не обръщай внимание"

      "congratulations on your efforts" ->
        "честито за усилията"

      "you must be tired" ->
        "сигурно си уморен"

      "thank you for your hard work" ->
        "благодаря за труда"

      "it's delicious" ->
        "вкусно е"

      "it's not delicious" ->
        "не е вкусно"

      "it hurts" ->
        "боли"

      "it's okay" ->
        "добре е"

      "it's not okay" ->
        "не е добре"

      "it's interesting" ->
        "интересно е"

      "it's boring" ->
        "скучно е"

      "it's fun" ->
        "забавно е"

      "it's not fun" ->
        "не е забавно"

      "it's difficult" ->
        "трудно е"

      "it's easy" ->
        "лесно е"

      "it's hot" ->
        "горещо е"

      "it's cold" ->
        "студено е"

      "it's warm" ->
        "топло е"

      "it's cool" ->
        "прохладно е"

      "it's big" ->
        "голямо е"

      "it's small" ->
        "малко е"

      "it's new" ->
        "ново е"

      "it's old" ->
        "старо е"

      "it's good" ->
        "добре е"

      "it's bad" ->
        "лошо е"

      "it's pretty" ->
        "хубаво е"

      "it's ugly" ->
        "грозно е"

      "it's clean" ->
        "чисто е"

      "it's dirty" ->
        "мръсно е"

      "it's convenient" ->
        "удобно е"

      "it's inconvenient" ->
        "неудобно е"

      "it's busy" ->
        "заето е"

      "it's free" ->
        "свободно е"

      "it's healthy" ->
        "здравословно е"

      "it's sick" ->
        "болно е"

      "it's kind" ->
        "мило е"

      "it's scary" ->
        "страшно е"

      "it's cute" ->
        "сладко е"

      "it's amazing" ->
        "изумително е"

      "it's famous" ->
        "известно е"

      "it's strong" ->
        "силно е"

      "it's weak" ->
        "слабо е"

      "it's fast" ->
        "бързо е"

      "it's slow" ->
        "бавно е"

      "it's early" ->
        "рано е"

      "it's late" ->
        "късно е"

      "it's many" ->
        "много е"

      "it's few" ->
        "малко е"

      "it's expensive" ->
        "скъпо е"

      "it's cheap" ->
        "евтино е"

      "it's high" ->
        "високо е"

      "it's low" ->
        "ниско е"

      "it's far" ->
        "далеч е"

      "it's near" ->
        "близо е"

      "it's wide" ->
        "широко е"

      "it's narrow" ->
        "тясно е"

      "it's long" ->
        "дълго е"

      "it's short" ->
        "късо е"

      "it's heavy" ->
        "тежко е"

      "it's light" ->
        "леко е"

      "it's thick" ->
        "дебело е"

      "it's thin" ->
        "тънко е"

      "it's deep" ->
        "дълбоко е"

      "it's shallow" ->
        "плитко е"

      "it's bright" ->
        "светло е"

      "it's dark" ->
        "тъмно е"

      "it's loud" ->
        "силно е"

      "it's quiet" ->
        "тихо е"

      "it's wet" ->
        "мокро е"

      "it's dry" ->
        "сухо е"

      "it's hard" ->
        "твърдо е"

      "it's soft" ->
        "меко е"

      "it's smooth" ->
        "гладко е"

      "it's rough" ->
        "грубо е"

      "it's sharp" ->
        "остро е"

      "it's dull" ->
        "тъпо е"

      "it's empty" ->
        "празно е"

      "it's full" ->
        "пълно е"

      "it's same" ->
        "еднакво е"

      "it's different" ->
        "различно е"

      "it's correct" ->
        "правилно е"

      "it's wrong" ->
        "грешно е"

      "it's safe" ->
        "безопасно е"

      "it's dangerous" ->
        "опасно е"

      "it's possible" ->
        "възможно е"

      "it's impossible" ->
        "невъзможно е"

      "it's necessary" ->
        "необходимо е"

      "it's unnecessary" ->
        "ненужно е"

      "it's important" ->
        "важно е"

      "it's unimportant" ->
        "неважно е"

      "it's interesting" ->
        "интересно е"

      "it's boring" ->
        "скучно е"

      "it's fun" ->
        "забавно е"

      "it's not fun" ->
        "не е забавно"

      "it's happy" ->
        "щастливо е"

      "it's sad" ->
        "тъжно е"

      "it's angry" ->
        "ядосано е"

      "it's surprised" ->
        "изненадано е"

      "it's scared" ->
        "изплашено е"

      "it's tired" ->
        "уморено е"

      "it's sleepy" ->
        "сънено е"

      "it's hungry" ->
        "гладно е"

      "it's thirsty" ->
        "жадно е"

      "it's full (food)" ->
        "сит съм"

      "it's cold (weather)" ->
        "студено е (време)"

      "it's hot (weather)" ->
        "горещо е (време)"

      "it's sunny" ->
        "слънчево е"

      "it's rainy" ->
        "дъждовно е"

      "it's cloudy" ->
        "облачно е"

      "it's windy" ->
        "ветровито е"

      "it's snowy" ->
        "снежно е"

      "I like" ->
        "харесва ми"

      "I don't like" ->
        "не ми харесва"

      "I love" ->
        "обичам"

      "I hate" ->
        "мразя"

      "I want" ->
        "искам"

      "I don't want" ->
        "не искам"

      "I can" ->
        "мога"

      "I can't" ->
        "не мога"

      "I will" ->
        "ще"

      "I won't" ->
        "няма да"

      "I do" ->
        "правя"

      "I don't" ->
        "не правя"

      "I have" ->
        "имам"

      "I don't have" ->
        "нямам"

      "I know" ->
        "знам"

      "I don't know" ->
        "не знам"

      "I think" ->
        "мисля"

      "I don't think" ->
        "не мисля"

      "I understand" ->
        "разбирам"

      "I don't understand" ->
        "не разбирам"

      "I remember" ->
        "помня"

      "I forget" ->
        "забравям"

      "I believe" ->
        "вярвам"

      "I don't believe" ->
        "не вярвам"

      "I agree" ->
        "съгласен съм"

      "I disagree" ->
        "не съм съгласен"

      "I hope" ->
        "надявам се"

      "I wish" ->
        "искам"

      "I need" ->
        "нуждая се"

      "I don't need" ->
        "не се нуждая"

      "I use" ->
        "използвам"

      "I don't use" ->
        "не използвам"

      "I make" ->
        "правя"

      "I don't make" ->
        "не правя"

      "I go" ->
        "отивам"

      "I don't go" ->
        "не отивам"

      "I come" ->
        "идвам"

      "I don't come" ->
        "не идвам"

      "I see" ->
        "виждам"

      "I don't see" ->
        "не виждам"

      "I hear" ->
        "чувам"

      "I don't hear" ->
        "не чувам"

      "I say" ->
        "казвам"

      "I don't say" ->
        "не казвам"

      "I speak" ->
        "говоря"

      "I don't speak" ->
        "не говоря"

      "I read" ->
        "чета"

      "I don't read" ->
        "не чета"

      "I write" ->
        "пиша"

      "I don't write" ->
        "не пиша"

      "I eat" ->
        "ям"

      "I don't eat" ->
        "не ям"

      "I drink" ->
        "пия"

      "I don't drink" ->
        "не пия"

      "I sleep" ->
        "спя"

      "I don't sleep" ->
        "не спя"

      "I wake up" ->
        "ставам"

      "I don't wake up" ->
        "не ставам"

      "I work" ->
        "работя"

      "I don't work" ->
        "не работя"

      "I study" ->
        "уча"

      "I don't study" ->
        "не уча"

      "I play" ->
        "играя"

      "I don't play" ->
        "не играя"

      "I buy" ->
        "купувам"

      "I don't buy" ->
        "не купувам"

      "I sell" ->
        "продавам"

      "I don't sell" ->
        "не продавам"

      "I pay" ->
        "плащам"

      "I don't pay" ->
        "не плащам"

      "I give" ->
        "давам"

      "I don't give" ->
        "не давам"

      "I receive" ->
        "получавам"

      "I don't receive" ->
        "не получавам"

      "I send" ->
        "изпращам"

      "I don't send" ->
        "не изпращам"

      "I take" ->
        "взимам"

      "I don't take" ->
        "не взимам"

      "I bring" ->
        "нося"

      "I don't bring" ->
        "не нося"

      "I put" ->
        "слагам"

      "I don't put" ->
        "не слагам"

      "I get" ->
        "получавам"

      "I don't get" ->
        "не получавам"

      "I find" ->
        "намирам"

      "I don't find" ->
        "не намирам"

      "I lose" ->
        "губя"

      "I don't lose" ->
        "не губя"

      "I keep" ->
        "пазя"

      "I don't keep" ->
        "не пазя"

      "I hold" ->
        "държа"

      "I don't hold" ->
        "не държа"

      "I carry" ->
        "нося"

      "I don't carry" ->
        "не нося"

      "I wear" ->
        "обличам"

      "I don't wear" ->
        "не обличам"

      "I change" ->
        "променям"

      "I don't change" ->
        "не променям"

      "I wash" ->
        "мия"

      "I don't wash" ->
        "не мия"

      "I clean" ->
        "почиствам"

      "I don't clean" ->
        "не почиствам"

      "I cook" ->
        "готвя"

      "I don't cook" ->
        "не готвя"

      "I drive" ->
        "карам"

      "I don't drive" ->
        "не карам"

      "I fly" ->
        "летя"

      "I don't fly" ->
        "не летя"

      "I run" ->
        "тичам"

      "I don't run" ->
        "не тичам"

      "I walk" ->
        "вървя"

      "I don't walk" ->
        "не вървя"

      "I swim" ->
        "плувам"

      "I don't swim" ->
        "не плувам"

      "I dance" ->
        "танцувам"

      "I don't dance" ->
        "не танцувам"

      "I sing" ->
        "пея"

      "I don't sing" ->
        "не пея"

      "I laugh" ->
        "смея се"

      "I don't laugh" ->
        "не се смея"

      "I cry" ->
        "плача"

      "I don't cry" ->
        "не плача"

      "I smile" ->
        "усмихвам се"

      "I don't smile" ->
        "не се усмихвам"

      "I help" ->
        "помагам"

      "I don't help" ->
        "не помагам"

      "I try" ->
        "опитвам"

      "I don't try" ->
        "не опитвам"

      "I start" ->
        "започвам"

      "I don't start" ->
        "не започвам"

      "I stop" ->
        "спирам"

      "I don't stop" ->
        "не спирам"

      "I finish" ->
        "завършвам"

      "I don't finish" ->
        "не завършвам"

      "I open" ->
        "отварям"

      "I don't open" ->
        "не отварям"

      "I close" ->
        "затварям"

      "I don't close" ->
        "не затварям"

      "I turn on" ->
        "включвам"

      "I don't turn on" ->
        "не включвам"

      "I turn off" ->
        "изключвам"

      "I don't turn off" ->
        "не изключвам"

      "I wait" ->
        "чакам"

      "I don't wait" ->
        "не чакам"

      "I ask" ->
        "питам"

      "I don't ask" ->
        "не питам"

      "I answer" ->
        "отговарям"

      "I don't answer" ->
        "не отговарям"

      "I call" ->
        "обаждам се"

      "I don't call" ->
        "не се обаждам"

      "I meet" ->
        "срещам"

      "I don't meet" ->
        "не се срещам"

      "I visit" ->
        "посещавам"

      "I don't visit" ->
        "не посещавам"

      "I stay" ->
        "оставам"

      "I don't stay" ->
        "не оставам"

      "I leave" ->
        "тръгвам си"

      "I don't leave" ->
        "не си тръгвам"

      "I return" ->
        "връщам се"

      "I don't return" ->
        "не се връщам"

      "I enter" ->
        "влизам"

      "I don't enter" ->
        "не влизам"

      "I exit" ->
        "излизам"

      "I don't exit" ->
        "не излизам"

      "I arrive" ->
        "пристигам"

      "I don't arrive" ->
        "не пристигам"

      "I depart" ->
        "заминавам"

      "I don't depart" ->
        "не заминавам"

      "I pass" ->
        "минавам"

      "I don't pass" ->
        "не минавам"

      "I cross" ->
        "пресичам"

      "I don't cross" ->
        "не пресичам"

      "I climb" ->
        "катеря се"

      "I don't climb" ->
        "не се катеря"

      "I fall" ->
        "падам"

      "I don't fall" ->
        "не падам"

      "I jump" ->
        "скачам"

      "I don't jump" ->
        "не скачам"

      "I throw" ->
        "хвърлям"

      "I don't throw" ->
        "не хвърлям"

      "I catch" ->
        "хващам"

      "I don't catch" ->
        "не хващам"

      "I hit" ->
        "ударям"

      "I don't hit" ->
        "не удрям"

      "I kick" ->
        "ритам"

      "I don't kick" ->
        "не ритам"

      "I push" ->
        "бутам"

      "I don't push" ->
        "не бутам"

      "I pull" ->
        "дърпам"

      "I don't pull" ->
        "не дърпам"

      "I lift" ->
        "вдигам"

      "I don't lift" ->
        "не вдигам"

      "I drop" ->
        "пускам"

      "I don't drop" ->
        "не пускам"

      "I break" ->
        "чупя"

      "I don't break" ->
        "не чупя"

      "I fix" ->
        "поправям"

      "I don't fix" ->
        "не поправям"

      "I cut" ->
        "режа"

      "I don't cut" ->
        "не режа"

      "I paste" ->
        "поставям"

      "I don't paste" ->
        "не поставям"

      "I fold" ->
        "сгъвам"

      "I don't fold" ->
        "не сгъвам"

      "I tear" ->
        "късам"

      "I don't tear" ->
        "не късам"

      "I tie" ->
        "връзвам"

      "I don't tie" ->
        "не връзвам"

      "I untie" ->
        "развръзвам"

      "I don't untie" ->
        "не развръзвам"

      "I wrap" ->
        "увивам"

      "I don't wrap" ->
        "не увивам"

      "I unwrap" ->
        "развивам"

      "I don't unwrap" ->
        "не развивам"

      "I cover" ->
        "покривам"

      "I don't cover" ->
        "не покривам"

      "I uncover" ->
        "разкривам"

      "I don't uncover" ->
        "не разкривам"

      "I hide" ->
        "крия"

      "I don't hide" ->
        "не крия"

      "I show" ->
        "показвам"

      "I don't show" ->
        "не показвам"

      "I look for" ->
        "търся"

      "I don't look for" ->
        "не търся"

      "I find" ->
        "намирам"

      "I don't find" ->
        "не намирам"

      "I lose" ->
        "губя"

      "I don't lose" ->
        "не губя"

      "I win" ->
        "печеля"

      "I don't win" ->
        "не печеля"

      "I lose (game)" ->
        "губя (игра)"

      "I don't lose (game)" ->
        "не губя (игра)"

      "I practice" ->
        "практикувам"

      "I don't practice" ->
        "не практикувам"

      "I exercise" ->
        "тренирам"

      "I don't exercise" ->
        "не тренирам"

      "I rest" ->
        "почивам"

      "I don't rest" ->
        "не почивам"

      "I relax" ->
        "отпускам се"

      "I don't relax" ->
        "не се отпускам"

      "I get angry" ->
        "ядосвам се"

      "I don't get angry" ->
        "не се ядосвам"

      "I get tired" ->
        "уморявам се"

      "I don't get tired" ->
        "не се уморявам"

      "I become" ->
        "ставам"

      "I don't become" ->
        "не ставам"

      "I turn" ->
        "завивам"

      "I don't turn" ->
        "не завивам"

      "I become hungry" ->
        "огладнявам"

      "I don't become hungry" ->
        "не огладнявам"

      "I become thirsty" ->
        "ожаднявам"

      "I don't become thirsty" ->
        "не ожаднявам"

      "I become sleepy" ->
        "заспивам"

      "I don't become sleepy" ->
        "не заспивам"

      "I become sick" ->
        "боледувам"

      "I don't become sick" ->
        "не боледувам"

      "I become well" ->
        "оздравявам"

      "I don't become well" ->
        "не оздравявам"

      "I become happy" ->
        "ставам щастлив"

      "I don't become happy" ->
        "не ставам щастлив"

      "I become sad" ->
        "ставам тъжен"

      "I don't become sad" ->
        "не ставам тъжен"

      "I become angry" ->
        "ставам ядосан"

      "I don't become angry" ->
        "не ставам ядосан"

      "I become surprised" ->
        "ставам изненадан"

      "I don't become surprised" ->
        "не ставам изненадан"

      "I become scared" ->
        "ставам уплашен"

      "I don't become scared" ->
        "не ставам уплашен"

      "I become interested" ->
        "интересувам се"

      "I don't become interested" ->
        "не се интересувам"

      "I become bored" ->
        "отегчавам се"

      "I don't become bored" ->
        "не се отегчавам"

      "I get used to" ->
        "свиквам"

      "I don't get used to" ->
        "не свиквам"

      "I get to know" ->
        "опознавам"

      "I don't get to know" ->
        "не опознавам"

      "I get along with" ->
        "разбирам се с"

      "I don't get along with" ->
        "не се разбирам с"

      "I get married" ->
        "женя се"

      "I don't get married" ->
        "не се женя"

      "I get divorced" ->
        "развеждам се"

      "I don't get divorced" ->
        "не се развеждам"

      "I get a job" ->
        "намирам работа"

      "I don't get a job" ->
        "не намирам работа"

      "I get lost" ->
        "загубвам се"

      "I don't get lost" ->
        "не се губя"

      "I get caught" ->
        "хващам се"

      "I don't get caught" ->
        "не се хващам"

      "I get hurt" ->
        "наранявам се"

      "I don't get hurt" ->
        "не се наранявам"

      "I get sick" ->
        "боледувам"

      "I don't get sick" ->
        "не боледувам"

      "I get well" ->
        "оздравявам"

      "I don't get well" ->
        "не оздравявам"

      "I get up" ->
        "ставам"

      "I don't get up" ->
        "не ставам"

      "I get in" ->
        "влизам"

      "I don't get in" ->
        "не влизам"

      "I get out" ->
        "излизам"

      "I don't get out" ->
        "не излизам"

      "I get on" ->
        "качвам се"

      "I don't get on" ->
        "не се качвам"

      "I get off" ->
        "свалям се"

      "I don't get off" ->
        "не се свалям"

      "I get to" ->
        "стигам до"

      "I don't get to" ->
        "не стигам до"

      "I get back" ->
        "връщам се"

      "I don't get back" ->
        "не се връщам"

      "I get rid of" ->
        "отървавам се от"

      "I don't get rid of" ->
        "не се отървавам от"

      "I get out of" ->
        "излизам от"

      "I don't get out of" ->
        "не излизам от"

      "I get into" ->
        "влизам в"

      "I don't get into" ->
        "не влизам в"

      "I get away" ->
        "избягвам"

      "I don't get away" ->
        "не избягвам"

      "I get over" ->
        "преодолявам"

      "I don't get over" ->
        "не преодолявам"

      "I get through" ->
        "преминавам през"

      "I don't get through" ->
        "не преминавам през"

      "I get across" ->
        "пресичам"

      "I don't get across" ->
        "не пресичам"

      "I get along" ->
        "разбирам се"

      "I don't get along" ->
        "не се разбирам"

      "I get by" ->
        "кърпам положението"

      "I don't get by" ->
        "не кърпя положението"

      "I get down" ->
        "обезкуражавам се"

      "I don't get down" ->
        "не се обезкуражавам"

      "I get up to" ->
        "стигам до"

      "I don't get up to" ->
        "не стигам до"

      "I get around" ->
        "обикалям"

      "I don't get around" ->
        "не обикалям"

      "I get together" ->
        "събирам се"

      "I don't get together" ->
        "не се събирам"

      "I get in touch with" ->
        "свързвам се с"

      "I don't get in touch with" ->
        "не се свързвам с"

      "I get hold of" ->
        "сдобивам се с"

      "I don't get hold of" ->
        "не се сдобивам с"

      "I get used to" ->
        "свиквам с"

      "I don't get used to" ->
        "не свиквам с"

      "I get ready" ->
        "приготвям се"

      "I don't get ready" ->
        "не се приготвям"

      "I get dressed" ->
        "обличам се"

      "I don't get dressed" ->
        "не се обличам"

      "I get undressed" ->
        "събличам се"

      "I don't get undressed" ->
        "не се събличам"

      "I get washed" ->
        "измивам се"

      "I don't get washed" ->
        "не се измивам"

      "I get changed" ->
        "преобличам се"

      "I don't get changed" ->
        "не се преобличам"

      "I get home" ->
        "прибирам се вкъщи"

      "I don't get home" ->
        "не се прибирам вкъщи"

      "I get to school" ->
        "стигам до училище"

      "I don't get to school" ->
        "не стигам до училище"

      "I get to work" ->
        "стигам до работа"

      "I don't get to work" ->
        "не стигам до работа"

      "I get to bed" ->
        "лягам си"

      "I don't get to bed" ->
        "не си лягам"

      "I get to sleep" ->
        "заспивам"

      "I don't get to sleep" ->
        "не заспивам"

      "I get up early" ->
        "ставам рано"

      "I don't get up early" ->
        "не ставам рано"

      "I get up late" ->
        "ставам късно"

      "I don't get up late" ->
        "не ставам късно"

      "I get some sleep" ->
        "поспивам си"

      "I don't get some sleep" ->
        "не си поспивам"

      "I get some rest" ->
        "почивам си"

      "I don't get some rest" ->
        "не си почивам"

      "I get some exercise" ->
        "тренирам малко"

      "I don't get some exercise" ->
        "не тренирам"

      "I get some fresh air" ->
        "поемам свеж въздух"

      "I don't get some fresh air" ->
        "не поемам свеж въздух"

      "I get some food" ->
        "взимам храна"

      "I don't get some food" ->
        "не взимам храна"

      "I get some water" ->
        "взимам вода"

      "I don't get some water" ->
        "не взимам вода"

      "I get some money" ->
        "взимам пари"

      "I don't get some money" ->
        "не взимам пари"

      "I get some time" ->
        "намирам време"

      "I don't get some time" ->
        "не намирам време"

      "I get some help" ->
        "търся помощ"

      "I don't get some help" ->
        "не търся помощ"

      "I get some information" ->
        "сдобивам се с информация"

      "I don't get some information" ->
        "не се сдобивам с информация"

      "I get some advice" ->
        "търся съвет"

      "I don't get some advice" ->
        "не търся съвет"

      "I get some rest" ->
        "почивам си"

      "I don't get some rest" ->
        "не си почивам"

      # If no translation found, return the original with a marker
      _ ->
        "[#{meaning}]"
    end
  end

  defp save_progress(translated, batch_idx) do
    File.write!("/tmp/progress_#{batch_idx}.json", Jason.encode!(translated))
  end
end

# Run the translator
BulgarianTranslator.run(
  "/var/home/meddle/development/elixir/medoru/data/export/words_n5.json",
  "/var/home/meddle/development/elixir/medoru/data/export/words_n5_bg.json"
)
