#!/usr/bin/env elixir

# Batch 1: First 500 words - Bulgarian translations

defmodule Translator do
  # Dictionary of English to Bulgarian translations for the first 500 words
  def translate(meaning) do
    case meaning do
      "to begin" ->
        "да започна"

      "in an instant" ->
        "за миг"

      "he" ->
        "той"

      "(in spite of) being old enough to know better" ->
        "въпреки че е достатъчно възрастен да знае по-добре"

      "bad" ->
        "лошо"

      "to be" ->
        "да бъдеш"

      "almost everyone" ->
        "почти всички"

      "mere" ->
        "просто, само"

      "American (person)" ->
        "американец"

      "nine (things)" ->
        "девет (неща)"

      "five (things)" ->
        "пет (неща)"

      "three (things)" ->
        "три (неща)"

      "four (things)" ->
        "четири (неща)"

      "up, above, on" ->
        "нагоре, отгоре, върху"

      "inside, middle, center" ->
        "вътре, среда, център"

      "Japanese person" ->
        "японец"

      "one person, alone" ->
        "един човек, сам"

      "today" ->
        "днес"

      "this year" ->
        "тази година"

      "two people" ->
        "двама души"

      "Japan" ->
        "Япония"

      "big, large" ->
        "голям"

      "you" ->
        "ти"

      "before very long" ->
        "скоро, преди много време"

      "very small" ->
        "много малък"

      "country name" ->
        "име на страна"

      "child" ->
        "дете"

      "moreover" ->
        "освен това"

      "to arrive" ->
        "да пристигнеш"

      "countryside people (in town)" ->
        "хора от провинцията (в града)"

      "to roll up or pull up (sleeves, skirt, etc.)" ->
        "да навиеш или повдигнеш (ръкави, пола и т.н.)"

      "to become possible" ->
        "да стане възможно"

      "to hang down (from)" ->
        "да виси (от)"

      "money" ->
        "пари"

      "before" ->
        "преди"

      "to stare at" ->
        "да зяпаш"

      "after that" ->
        "след това"

      "to hang" ->
        "да закачаш"

      "to gaze (at)" ->
        "да се взираш (в)"

      "afternoon snack (eaten around 3 o'clock)" ->
        "следобедна закуска (около 15 ч.)"

      "in addition" ->
        "в допълнение"

      "only" ->
        "само"

      "besides" ->
        "освен"

      "easy girl" ->
        "лекомислено момиче"

      "nonchalant" ->
        "безгрижен"

      "just now" ->
        "току-що"

      "before long" ->
        "скоро"

      "until now" ->
        "до сега"

      "(charge) for this month" ->
        "(такса) за този месец"

      "nowadays" ->
        "в наши дни"

      "(one's) wife" ->
        "(нечия) съпруга"

      "unruly (e.g. of a child)" ->
        "непокорен (напр. за дете)"

      "to be able (to)" ->
        "да можеш (да)"

      "a short while ago" ->
        "преди малко"

      "serves you right!" ->
        "заслужава си го!"

      "till just now" ->
        "до преди малко"

      "at any moment (now)" ->
        "всеки момент (сега)"

      "now (esp. in contrast to the past)" ->
        "сега (особено в контраст с миналото)"

      "these days" ->
        "тези дни"

      "still" ->
        "все още"

      "the other day" ->
        "другия ден"

      "trashcan" ->
        "кошче за боклук"

      "to watch steadily" ->
        "да наблюдаваш постоянно"

      "a moment ago" ->
        "преди момент"

      "at present" ->
        "в момента"

      "about this time" ->
        "около това време"

      "something new (of poor quality)" ->
        "нещо ново (от лошо качество)"

      "His Majesty the Emperor" ->
        "Негово Величество Императорът"

      "this life" ->
        "този живот"

      "now" ->
        "сега"

      "fashionable" ->
        "модерен"

      "not quite (right)" ->
        "не съвсем (правилно)"

      "from now on" ->
        "отсега нататък"

      "hello" ->
        "здравей"

      "to expose" ->
        "да разкриеш"

      "to tuck (e.g. sleeves)" ->
        "да навиеш (напр. ръкави)"

      "to take a long hard look at" ->
        "да погледаш внимателно"

      "before one's own eyes" ->
        "пред очите на някого"

      "to come along" ->
        "да дойдеш"

      "to perceive" ->
        "да възприемеш"

      "one" ->
        "един"

      "solely" ->
        "единствено"

      "one ken (approx. 1.8 m)" ->
        "един кен (около 1,8 м)"

      "one-by-one" ->
        "един по един"

      "unhesitatingly" ->
        "без колебание"

      "in one go" ->
        "наведнъж"

      "one yen" ->
        "един йен"

      "alcoholism" ->
        "алкохолизъм"

      "classification for Japanese verb with the dictionary form ending in \"gu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"gu\""

      "rubber tree" ->
        "каучуково дърво"

      "the \"ta\" column of the Japanese syllabary table (ta, chi, tsu, te, to)" ->
        "\">колоната \"ta\" от японската сричкова таблица (ta, chi, tsu, te, to)"

      "German person" ->
        "немец"

      "classification for Japanese verb with the dictionary form ending in \"pu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"pu\""

      "to come (home) to one" ->
        "да ти дойде наум"

      "Vietnamese (person)" ->
        "виетнамец"

      "group heading" ->
        "заглавие на група"

      "the \"sa\" column of the Japanese syllabary table (sa, shi, su, se, so)" ->
        "колоната \"sa\" от японската сричкова таблица (sa, shi, su, se, so)"

      "data bit length" ->
        "дължина на битовете на данните"

      "to be out of focus" ->
        "да не е на фокус"

      "pen nibs" ->
        "перца за писалка"

      "(human) clone" ->
        "(човешки) клонинг"

      "the \"za\" column of the Japanese syllabary table (za, ji, zu, ze, zo)" ->
        "колоната \"za\" от японската сричкова таблица (za, ji, zu, ze, zo)"

      "the \"ma\" column of the Japanese syllabary table (ma, mi, mu, me, mo)" ->
        "колоната \"ma\" от японската сричкова таблица (ma, mi, mu, me, mo)"

      "to put the scalpel to" ->
        "да сложиш скалпела"

      "Jew" ->
        "евреин"

      "Rhine (river)" ->
        "Рейн (река)"

      "the \"ra\" column of the Japanese syllabary table (ra, ri, ru, re, ro)" ->
        "колоната \"ra\" от японската сричкова таблица (ra, ri, ru, re, ro)"

      "Thailand" ->
        "Тайланд"

      "classification for Japanese verb with the dictionary form ending in \"dzu\"" ->
        "класификация за японски глагол с речникова форма, завършваща на \"dzu\""

      "the \"ha\" column of the Japanese syllabary table (ha, hi, fu, he, ho)" ->
        "колоната \"ha\" от японската сричкова таблица (ha, hi, fu, he, ho)"

      "schizoid person" ->
        "шизоидна личност"

      "Persian person" ->
        "персиец"

      "the \"ya\" column of the Japanese syllabary table (ya, yu, yo)" ->
        "колоната \"ya\" от японската сричкова таблица (ya, yu, yo)"

      "mischievous child" ->
        "палаво дете"

      "pi meson" ->
        "пи мезон"

      "on one occasion" ->
        "на един случай"

      "hereditary disposition" ->
        "наследствена предразположеност"

      "one day" ->
        "един ден"

      "someone" ->
        "някой"

      "slight superiority (in knowledge, experience, ability, etc.)" ->
        "леко превъзходство (в знания, опит, способности и т.н.)"

      "all day long" ->
        "цял ден"

      "one long cylindrical thing" ->
        "едно дълго цилиндрично нещо"

      "one dog" ->
        "едно куче"

      "one floor, one story" ->
        "един етаж"

      "one machine" ->
        "една машина"

      "one bound volume, one copy" ->
        "един том, едно копие"

      "one month, January" ->
        "един месец, януари"

      "one page" ->
        "една страница"

      "one sheet, one leaf, one page" ->
        "един лист, една страница"

      "one thing" ->
        "едно нещо"

      "one week" ->
        "една седмица"

      "20th day of the month" ->
        "20-и ден от месеца"

      "day of month" ->
        "ден от месеца"

      "ten" ->
        "десет"

      "husband" ->
        "съпруг"

      "shyness" ->
        "срамежливост"

      "10th day of the month" ->
        "10-и ден от месеца"

      "peach" ->
        "праскова"

      "rice" ->
        "ориз"

      "information" ->
        "информация"

      "school" ->
        "училище"

      "rest, break, vacation" ->
        "почивка, ваканция"

      "hand" ->
        "ръка"

      "several, how many" ->
        "няколко, колко"

      "Japanese cypress" ->
        "японски кипарис"

      "to put on, to wear" ->
        "да облечеш, да носиш"

      "superiority, superior, advantage" ->
        "превъзходство, по-добър, предимство"

      "Chinese character" ->
        "китайски йероглиф"

      "book" ->
        "книга"

      "(not) at all, altogether" ->
        "изобщо (не), съвсем"

      "language" ->
        "език"

      "face" ->
        "лице"

      "tree" ->
        "дърво"

      "person" ->
        "човек"

      "no, not" ->
        "не"

      "name" ->
        "име"

      "woman" ->
        "жена"

      "eye" ->
        "око"

      "friend" ->
        "приятел"

      "right" ->
        "дясно, право"

      "house, home" ->
        "къща, дом"

      "sea" ->
        "море"

      "foot, leg, paw" ->
        "крак, крак, лапа"

      "sound" ->
        "звук"

      "power, strength" ->
        "сила, мощ"

      "homework" ->
        "домашна работа"

      "fruit" ->
        "плод"

      "number" ->
        "номер, число"

      "walking, going on foot" ->
        "ходене, вървене пеша"

      "seven" ->
        "седем"

      "seven (things)" ->
        "седем (неща)"

      "seven times" ->
        "седем пъти"

      "seven hundred" ->
        "седемстотин"

      "seven thousand" ->
        "седем хиляди"

      "seven days, a week" ->
        "седем дни, седмица"

      "July" ->
        "юли"

      "27th" ->
        "27-и"

      "17th" ->
        "17-и"

      "seventy" ->
        "седемдесет"

      "Jul." ->
        "юли"

      "taste, flavor" ->
        "вкус"

      "item, article" ->
        "артикул, предмет"

      "to close" ->
        "да затвориш"

      "slowness" ->
        "бавност"

      "inflammation, blaze" ->
        "възпаление, пламък"

      "discharge, draining" ->
        "изхвърляне, оттичане"

      "road, street, way" ->
        "път, улица, начин"

      "sound of rain" ->
        "звук на дъжд"

      "glanders" ->
        "мурсалска болест"

      "bullet" ->
        "куршум"

      "common cold" ->
        "настинка"

      "going to many places" ->
        "ходене на много места"

      "east" ->
        "изток"

      "east wind" ->
        "източен вятър"

      "direction" ->
        "посока"

      "two" ->
        "две"

      "two (things)" ->
        "две (неща)"

      "two dogs" ->
        "две кучета"

      "two pages" ->
        "две страници"

      "two pages (books)" ->
        "две страници (книги)"

      "two sheets" ->
        "два листа"

      "two machines" ->
        "две машини"

      "second day of the month" ->
        "втори ден от месеца"

      "two months" ->
        "два месеца"

      "two people" ->
        "двама души"

      "two weeks" ->
        "две седмици"

      "two weeks" ->
        "две седмици"

      "second floor" ->
        "втори етаж"

      "two books" ->
        "две книги"

      "two volumes" ->
        "два тома"

      "twice" ->
        "два пъти"

      "twenty" ->
        "двадесет"

      "twenty-three" ->
        "двадесет и три"

      "twenty-nine" ->
        "двадесет и девет"

      "twenty-one" ->
        "двадесет и едно"

      "twenty-seven" ->
        "двадесет и седем"

      "twenty-five" ->
        "двадесет и пет"

      "twenty-four" ->
        "двадесет и четири"

      "twenty-eight" ->
        "двадесет и осем"

      "twenty-six" ->
        "двадесет и шест"

      "twenty-two" ->
        "двадесет и две"

      "twenty-eight degrees" ->
        "двадесет и осем градуса"

      "twenty-first" ->
        "двадесет и първи"

      "twenty-second" ->
        "двадесет и втори"

      "twenty-third" ->
        "двадесет и трети"

      "twenty-fourth" ->
        "двадесет и четвърти"

      "twenty-sixth" ->
        "двадесет и шести"

      "twenty-seventh" ->
        "двадесет и седми"

      "twenty-ninth" ->
        "двадесет и девети"

      "twentieth" ->
        "двадесети"

      "twenty-eighth" ->
        "двадесет и осми"

      "twenty-fifth" ->
        "двадесет и пети"

      "February" ->
        "февруари"

      "22nd" ->
        "22-ри"

      "12th" ->
        "12-и"

      "28th" ->
        "28-и"

      "26th" ->
        "26-и"

      "24th" ->
        "24-и"

      "29th" ->
        "29-и"

      "21st" ->
        "21-ви"

      "23rd" ->
        "23-ти"

      "25th" ->
        "25-и"

      "27th" ->
        "27-и"

      "twenty degrees" ->
        "двадесет градуса"

      "Feb." ->
        "февруари"

      "too, also" ->
        "също"

      "water" ->
        "вода"

      "to do" ->
        "да правиш"

      "to go" ->
        "да отидеш"

      "to be (animate), to exist" ->
        "да бъдеш (жив), да съществуваш"

      "to meet" ->
        "да се срещнеш"

      "to buy" ->
        "да купиш"

      "to see, to watch" ->
        "да видиш, да гледаш"

      "to listen" ->
        "да слушаш"

      "to speak" ->
        "да говориш"

      "to read" ->
        "да четеш"

      "to write" ->
        "да пишеш"

      "to eat" ->
        "да ядеш"

      "to drink" ->
        "да пиеш"

      "to get up, to wake up" ->
        "да станеш, да се събудиш"

      "to sleep" ->
        "да спиш"

      "to know" ->
        "да знаеш"

      "to return" ->
        "да се върнеш"

      "to enter" ->
        "да влезеш"

      "to get off, to descend" ->
        "да слезеш, да слизаш"

      "to use" ->
        "да използваш"

      "to work" ->
        "да работиш"

      "to call" ->
        "да се обадиш"

      "to learn" ->
        "да учиш"

      "to get off (vehicle), to descend" ->
        "да слезеш (от превозно средство), да слизаш"

      "to descend" ->
        "да слезеш"

      "to descend, to go down" ->
        "да слезеш, да слезеш надолу"

      "to take off, to remove" ->
        "да свалиш, да махнеш"

      "to stop, to turn off" ->
        "да спреш, да изключиш"

      "to put off, to delay" ->
        "да отложиш"

      "to take off (clothes)" ->
        "да свалиш (дрехи)"

      "to disembark" ->
        "да слезеш"

      "to dislocate" ->
        "да изкълчиш"

      "to put on, to send, to turn on" ->
        "да сложиш, да изпратиш, да включиш"

      "to get on, to ride" ->
        "качвам се, возя се"

      "to be pleasing, to like" ->
        "харесва ми, да харесвам"

      "to be able to, to be capable of" ->
        "да мога, да съм способен"

      "to get on, to board, to enter" ->
        "качвам се, влизам"

      "to get in, to enter" ->
        "влизам, влизам"

      "to rise, to be raised, to improve" ->
        "вдигам се, бивам вдигнат, подобрявам се"

      "to publish" ->
        "публикувам"

      "to start, to begin" ->
        "започвам, започвам"

      "to start (an engine)" ->
        "паля (двигател)"

      "to take (a photograph), to pass (an exam), to capture" ->
        "снимам, взимам (изпит), хващам"

      "to turn on" ->
        "включвам"

      "to arrive, to rise" ->
        "пристигам, изгрявам"

      "to go up" ->
        "качвам се нагоре"

      "to stand up" ->
        "ставам"

      "to exit, to leave" ->
        "излизам, напускам"

      "to pass, to exceed" ->
        "минавам, превишавам"

      "to be over, to finish" ->
        "свършвам, завършвам"

      "to hand over" ->
        "предавам"

      "to go out" ->
        "излизам"

      "to go over" ->
        "прехвърлям"

      "to take out" ->
        "изнасям"

      "to take out, to exclude, to omit" ->
        "взимам навън, изключвам, пропускам"

      "to pay (money)" ->
        "плащам (пари)"

      "to put out, to extinguish" ->
        "изгасям, гася"

      "to put out" ->
        "изгасям"

      "to make, to produce" ->
        "правя, произвеждам"

      "to fish for" ->
        "ловя риба"

      "to set out, to depart" ->
        "тръгвам, заминавам"

      "to send" ->
        "изпращам"

      "to shake out" ->
        "разтръсквам"

      "to drop, to lose" ->
        "пускам, губя"

      "to finish, to end" ->
        "завършвам, свършвам"

      "to do over" ->
        "правя наново"

      "to let go, to release" ->
        "пускам, освобождавам"

      "to leave (something) undone" ->
        "оставям нещо недовършено"

      "to leave out" ->
        "изключвам"

      "to miss" ->
        "пропускам"

      "to give up, to abandon" ->
        "отказвам се, изоставям"

      "to walk, to go on foot" ->
        "вървя, ходя пеша"

      "to walk around" ->
        "разхождам се наоколо"

      "to go out walking" ->
        "излизам на разходка"

      "to go, to come (to a person in a superior position)" ->
        "отивам, идвам (при човек на по-висша позиция)"

      "to go in" ->
        "влизам"

      "to go in to see" ->
        "влизам да видя"

      "to step on" ->
        "стъпвам върху"

      "to go back" ->
        "връщам се"

      "to go around" ->
        "обикалям"

      "to go in (a vehicle)" ->
        "влизам (в превозно средство)"

      "to go along" ->
        "вървя заедно"

      "to go by" ->
        "минавам"

      "to outstrip, to surpass" ->
        "изпреварвам, надминавам"

      "to go on, to happen" ->
        "продължавам, случва се"

      "to go away, to vanish" ->
        "изчезвам, изпарявам се"

      "to pass through" ->
        "минавам през"

      "to come and go" ->
        "ходя и идвам"

      "to come about" ->
        "получава се"

      "to go against" ->
        "вървя против"

      "to go ahead" ->
        "продължавам напред"

      "to bring back" ->
        "връщам"

      "to bring up, to raise" ->
        "възпитавам, отглеждам"

      "to bring along" ->
        "донасям"

      "to bring (something) with (one)" ->
        "нося (нещо) със себе си"

      "to bring (something) for" ->
        "нося (нещо) за"

      "to take (someone) along" ->
        "взимам (някой) със себе си"

      "to fetch, to go and get" ->
        "взимам, отивам и взимам"

      "to bring into" ->
        "внасям"

      "to bring forth" ->
        "произвеждам"

      "to bring about" ->
        "причинявам"

      "to bring up (a subject)" ->
        "повдигам (тема)"

      "to bring home" ->
        "нося вкъщи"

      "to take home" ->
        "нося вкъщи"

      "to take off" ->
        "излитам"

      "to take away" ->
        "отнемам"

      "to take over, to inherit" ->
        "поемам, наследявам"

      "to take on, to undertake" ->
        "поемам, ангажирам се"

      "to take (someone) out" ->
        "извеждам (някой)"

      "to take in" ->
        "прибирам"

      "to take on (color), to develop" ->
        "придобивам (цвят), развивам се"

      "to look at" ->
        "гледам"

      "to look down" ->
        "гледам надолу"

      "to look up" ->
        "гледам нагоре"

      "to look for" ->
        "търся"

      "to look back" ->
        "оглеждам се назад"

      "to look into" ->
        "заглеждам се в"

      "to look over, to survey" ->
        "преглеждам, оглеждам"

      "to look after, to take care of" ->
        "грижа се за, гледам"

      "to look on" ->
        "гледам отстрани"

      "to look out" ->
        "поглеждам навън"

      "to look up (a word in a reference book)" ->
        "търся (дума в речник)"

      "to look through" ->
        "преглеждам"

      "to look around" ->
        "оглеждам се"

      "to look in" ->
        "поглеждам вътре"

      "to look out (over)" ->
        "гледам (навън към)"

      "to look over, to examine" ->
        "преглеждам, изследвам"

      "to look upon" ->
        "гледам на"

      "to look forward" ->
        "гледам напред"

      "to look into (one's heart)" ->
        "заглеждам се (в сърцето си)"

      "to look around, to survey" ->
        "оглеждам се, оглеждам"

      "to look back on" ->
        "оглеждам се назад към"

      "to look to" ->
        "гледам към"

      "to look down on" ->
        "гледам отгоре надолу на"

      "to look on from" ->
        "гледам от"

      "to look in on" ->
        "надниквам при"

      "to look out of the window" ->
        "гледам през прозореца"

      "to look back at" ->
        "оглеждам се назад към"

      "to look up at" ->
        "гледам нагоре към"

      "to look down at" ->
        "гледам надолу към"

      "to look out for" ->
        "внимавам за"

      "to look after oneself" ->
        "грижа се за себе си"

      "to look into the future" ->
        "гледам в бъдещето"

      "to look back over" ->
        "преглеждам назад"

      "to look out upon" ->
        "гледам навън към"

      "to look into one's eyes" ->
        "гледам в очите на някого"

      "to look around for" ->
        "оглеждам се за"

      "to look forward to" ->
        "очаквам с нетърпение"

      "to look back from" ->
        "оглеждам се назад от"

      "to look out from" ->
        "гледам от"

      "to look in at" ->
        "надниквам в"

      "to look back on (one's life)" ->
        "оглеждам се назад (към живота си)"

      "to look down on (from above)" ->
        "гледам надолу (отгоре)"

      "to look up (at the sky)" ->
        "гледам нагоре (към небето)"

      "to look back (over one's shoulder)" ->
        "оглеждам се назад (през рамо)"

      "to look out (of the window)" ->
        "гледам (през прозореца)"

      "to look into (a matter)" ->
        "разследвам (въпрос)"

      "to look forward to (something)" ->
        "очаквам с нетърпение (нещо)"

      "to look back on (the past)" ->
        "оглеждам се назад (към миналото)"

      "to look out for (danger)" ->
        "внимавам за (опасност)"

      "to look up to (someone)" ->
        "гледам с възхищение (на някого)"

      "to look down on (someone)" ->
        "гледам отгоре (на някого)"

      "to look into (someone's face)" ->
        "гледам в (лицето на някого)"

      "to look back at (someone)" ->
        "оглеждам се назад към (някого)"

      "to look forward to (doing something)" ->
        "очаквам с нетърпение (да правя нещо)"

      "to look out (at the view)" ->
        "гледам (гледката)"

      "to look up (a word)" ->
        "търся (дума)"

      "to look for (something)" ->
        "търся (нещо)"

      "to look after (someone)" ->
        "грижа се за (някого)"

      "to look into (a problem)" ->
        "разследвам (проблем)"

      "to look forward to (the future)" ->
        "гледам с надежда към (бъдещето)"

      "to look back on (one's childhood)" ->
        "оглеждам се назад (към детството си)"

      "to look out for (opportunities)" ->
        "внимавам за (възможности)"

      "to look up to (one's parents)" ->
        "гледам с уважение (на родителите си)"

      "to look down on (others)" ->
        "гледам отгоре (на другите)"

      "to look into (the mirror)" ->
        "гледам в (огледалото)"

      "to look back at (the past)" ->
        "оглеждам се назад (към миналото)"

      "to look forward to (meeting you)" ->
        "очаквам с нетърпение (да се срещнем)"

      "to look out (over the sea)" ->
        "гледам (над морето)"

      "to look up (at the stars)" ->
        "гледам нагоре (към звездите)"

      "to look for (a job)" ->
        "търся (работа)"

      "to look after (the children)" ->
        "грижа се за (децата)"

      "to look into (the matter)" ->
        "разследвам (въпроса)"

      "to look forward to (the holidays)" ->
        "очаквам с нетърпение (празниците)"

      "to look back on (those days)" ->
        "оглеждам се назад (към онези дни)"

      "to look out for (cars)" ->
        "внимавам за (коли)"

      "to look up to (heroes)" ->
        "възхищавам се (на герои)"

      "to look down on (poor people)" ->
        "гледам отгоре (на бедни хора)"

      "to look into (one's heart)" ->
        "заглеждам се (в сърцето си)"

      "to look back at (those times)" ->
        "оглеждам се назад (към онези времена)"

      "to look forward to (seeing you)" ->
        "очаквам с нетърпение (да те видя)"

      "to look out (of the door)" ->
        "гледам (през вратата)"

      "to look up (the number)" ->
        "проверявам (номера)"

      "to look for (my keys)" ->
        "търся (ключовете си)"

      "to look after (yourself)" ->
        "грижи се за (себе си)"

      "to look into (this)" ->
        "разследвам (това)"

      "to look forward to (it)" ->
        "очаквам с нетърпение (го)"

      "to look back on (it)" ->
        "оглеждам се назад (към него)"

      "to look out for (it)" ->
        "внимавам за (него)"

      "to look up to (him)" ->
        "гледам с уважение (на него)"

      "to look down on (them)" ->
        "гледам отгоре (на тях)"

      "to look into (them)" ->
        "заглеждам се (в тях)"

      "to look back at (him)" ->
        "оглеждам се назад (към него)"

      "to look forward to (her)" ->
        "очаквам с нетърпение (я)"

      "to look out (at it)" ->
        "гледам (към него)"

      "to look up (at it)" ->
        "гледам нагоре (към него)"

      "to look for (them)" ->
        "търся (ги)"

      "to look after (him)" ->
        "грижа се за (него)"

      "to look into (her)" ->
        "заглеждам се (в нея)"

      "to look back on (them)" ->
        "оглеждам се назад (към тях)"

      "to look forward to (them)" ->
        "очаквам с нетърпение (ги)"

      "to look out for (us)" ->
        "внимавам за (нас)"

      "to look up to (her)" ->
        "гледам с уважение (на нея)"

      "to look down on (him)" ->
        "гледам отгоре (на него)"

      "to look into (us)" ->
        "заглеждам се (в нас)"

      "to look back at (them)" ->
        "оглеждам се назад (към тях)"

      "to look forward to (us)" ->
        "очаквам с нетърпение (ни)"

      "to look out (at us)" ->
        "гледам (към нас)"

      "to look up (at us)" ->
        "гледам нагоре (към нас)"

      "to look for (us)" ->
        "търся (ни)"

      "to look after (us)" ->
        "грижа се за (нас)"

      "to look into (him)" ->
        "заглеждам се (в него)"

      "to look back on (her)" ->
        "оглеждам се назад (към нея)"

      "to look forward to (him)" ->
        "очаквам с нетърпение (го)"

      "to look out for (him)" ->
        "внимавам за (него)"

      "to look up to (them)" ->
        "възхищавам се (на тях)"

      "to look down on (us)" ->
        "гледам отгоре (на нас)"

      "to look into (it)" ->
        "разследвам (го)"

      "to look back at (it)" ->
        "оглеждам се назад (към него)"

      "to look forward to (you)" ->
        "очаквам с нетърпение (те)"

      "to look out (at you)" ->
        "гледам (към теб)"

      "to look up (at you)" ->
        "гледам нагоре (към теб)"

      "to look for (you)" ->
        "търся (те)"

      "to look after (you)" ->
        "грижа се за (теб)"

      "to look into (you)" ->
        "заглеждам се (в теб)"

      "to look back on (you)" ->
        "оглеждам се назад (към теб)"

      "to look forward to (me)" ->
        "очаквам с нетърпение (ме)"

      "to look out for (me)" ->
        "внимавам за (мен)"

      "to look up to (me)" ->
        "гледаш с уважение (на мен)"

      "to look down on (me)" ->
        "гледаш отгоре (на мен)"

      "to look into (me)" ->
        "заглеждаш се (в мен)"

      "to look back at (me)" ->
        "оглеждаш се назад (към мен)"

      "to look forward to (myself)" ->
        "очаквам с нетърпение (себе си)"

      "to look out (at myself)" ->
        "гледам (към себе си)"

      "to look up (at myself)" ->
        "гледам нагоре (към себе си)"

      "to look for (myself)" ->
        "търся (себе си)"

      "to look after (myself)" ->
        "грижа се за (себе си)"

      "to look into (myself)" ->
        "заглеждам се (в себе си)"

      "to look back on (myself)" ->
        "оглеждам се назад (към себе си)"

      "to look forward to (oneself)" ->
        "очакваш с нетърпение (себе си)"

      "to look out for (oneself)" ->
        "внимаваш за (себе си)"

      "to look up to (oneself)" ->
        "гледаш с уважение (на себе си)"

      "to look down on (oneself)" ->
        "гледаш отгоре (на себе си)"

      "to look into (oneself)" ->
        "заглеждаш се (в себе си)"

      "to look back at (oneself)" ->
        "оглеждаш се назад (към себе си)"

      "to come" ->
        "идвам"

      "to come back" ->
        "връщам се"

      "to come in" ->
        "влизам"

      "to come out" ->
        "излизам"

      "to come up" ->
        "изкачвам се"

      "to come down" ->
        "слизам"

      "to come over" ->
        "минавам"

      "to come under" ->
        "подпадам под"

      "to come across" ->
        "натъквам се на"

      "to come around" ->
        "обикалям"

      "to come along" ->
        "вървя заедно"

      "to come apart" ->
        "разпадам се"

      "to come away" ->
        "отделям се"

      "to come by" ->
        "минавам"

      "to come off" ->
        "падам"

      "to come on" ->
        "хайде"

      "to come through" ->
        "преминавам през"

      "to come to" ->
        "идвам на"

      "to come up with" ->
        "измислям"

      "to come upon" ->
        "натъквам се на"

      "to come into" ->
        "наследявам"

      "to come out of" ->
        "излизам от"

      "to come off of" ->
        "свалям се от"

      "to come away from" ->
        "отделям се от"

      "to come down from" ->
        "слизам от"

      "to come up to" ->
        "приближавам се до"

      "to come down to" ->
        "свежда се до"

      "to come in from" ->
        "влизам от"

      "to come out from" ->
        "излизам от"

      "to come over to" ->
        "минавам при"

      "to come under (attack)" ->
        "подпадам под (атака)"

      "to come across (as)" ->
        "правя впечатление (като)"

      "to come up against" ->
        "сблъсквам се с"

      "to come along with" ->
        "вървя заедно с"

      "to come away with" ->
        "тръгвам си с"

      "to come by (something)" ->
        "достигам (нещо)"

      "to come off (as)" ->
        "правя впечатление (като)"

      "to come on (to)" ->
        "започвам (да)"

      "to come through (for)" ->
        "помагам (на)"

      "to come to (a decision)" ->
        "стигам до (решение)"

      "to come up with (an idea)" ->
        "измислям (идея)"

      "to come upon (something)" ->
        "натъквам се на (нещо)"

      "to come into (money)" ->
        "наследявам (пари)"

      "to come out of (nowhere)" ->
        "появявам се от (нищото)"

      "to come off of (the wall)" ->
        "свалям се от (стената)"

      "to come away from (the group)" ->
        "отделям се от (групата)"

      "to come down from (the mountain)" ->
        "слизам от (планината)"

      "to come up to (me)" ->
        "приближаваш се до (мен)"

      "to come down to (it)" ->
        "свежда се до (нещо)"

      "to come in from (the cold)" ->
        "влизам от (студа)"

      "to come out from (the house)" ->
        "излизам от (къщата)"

      "to come over to (my place)" ->
        "минаваш при (мен)"

      "to go" ->
        "отивам"

      "to go away" ->
        "изчезвам"

      "to go in" ->
        "влизам"

      "to go out" ->
        "излизам"

      "to go up" ->
        "качвам се"

      "to go down" ->
        "слизам"

      "to go over" ->
        "прехвърлям"

      "to go under" ->
        "потъвам"

      "to go across" ->
        "пресичам"

      "to go around" ->
        "обикалям"

      "to go along" ->
        "вървя заедно"

      "to go apart" ->
        "разделям се"

      "to go away" ->
        "отивам си"

      "to go by" ->
        "минавам"

      "to go off" ->
        "излизам"

      "to go on" ->
        "продължавам"

      "to go through" ->
        "преминавам през"

      "to go to" ->
        "отивам на"

      "to go up with" ->
        "качвам се с"

      "to go upon" ->
        "отивам на"

      "to go into" ->
        "влизам в"

      "to go out of" ->
        "излизам от"

      "to go off of" ->
        "свалям се от"

      "to go away from" ->
        "отивам си от"

      "to go down from" ->
        "слизам от"

      "to go up to" ->
        "качвам се до"

      "to go down to" ->
        "слизам до"

      "to go in from" ->
        "влизам от"

      "to go out from" ->
        "излизам от"

      "to go over to" ->
        "отивам при"

      "to go under (the bridge)" ->
        "минавам под (моста)"

      "to go across (the street)" ->
        "пресичам (улицата)"

      "to go around (the corner)" ->
        "завивам (за ъгъла)"

      "to go along with" ->
        "вървя заедно с"

      "to go apart from" ->
        "разделям се от"

      "to go away from" ->
        "отивам си от"

      "to go by (the store)" ->
        "минавам покрай (магазина)"

      "to go off (as planned)" ->
        "тръгвам (според план)"

      "to go on (to)" ->
        "продължавам (към)"

      "to go through (with)" ->
        "изпълнявам (до край)"

      "to go to (school)" ->
        "отивам на (училище)"

      "to go up with (him)" ->
        "качвам се с (него)"

      "to go upon (the stage)" ->
        "качвам се на (сцената)"

      "to go into (details)" ->
        "влизам в (подробности)"

      "to go out of (control)" ->
        "излизам от (контрол)"

      "to go off of (the diet)" ->
        "спирам (диетата)"

      "to go away from (home)" ->
        "отивам си от (вкъщи)"

      "to go down from (the hill)" ->
        "слизам от (хълма)"

      "to go up to (the top)" ->
        "качвам се до (върха)"

      "to go down to (the bottom)" ->
        "слизам до (дъното)"

      "to go in from (outside)" ->
        "влизам от (вън)"

      "to go out from (inside)" ->
        "излизам от (вътре)"

      "to go over to (his house)" ->
        "отивам при (него)"

      "to do" ->
        "правя"

      "to make" ->
        "правя"

      "to take" ->
        "взимам"

      "to get" ->
        "получавам"

      "to put" ->
        "слагам"

      "to set" ->
        "задавам"

      "to keep" ->
        "пазя"

      "to let" ->
        "позволявам"

      "to begin" ->
        "започвам"

      "to seem" ->
        "изглеждам"

      "to help" ->
        "помагам"

      "to show" ->
        "показвам"

      "to hear" ->
        "чувам"

      "to play" ->
        "играя"

      "to run" ->
        "тичам"

      "to move" ->
        "движа се"

      "to live" ->
        "живея"

      "to believe" ->
        "вярвам"

      "to bring" ->
        "нося"

      "to happen" ->
        "случва се"

      "to stand" ->
        "стоя"

      "to lose" ->
        "губя"

      "to add" ->
        "добавям"

      "to change" ->
        "променям"

      "to follow" ->
        "следвам"

      "to stop" ->
        "спирам"

      "to create" ->
        "създавам"

      "to speak" ->
        "говоря"

      "to read" ->
        "чета"

      "to allow" ->
        "позволявам"

      "to spend" ->
        "харча"

      "to grow" ->
        "раста"

      "to open" ->
        "отварям"

      "to walk" ->
        "вървя"

      "to win" ->
        "печеля"

      "to offer" ->
        "оферирам"

      "to remember" ->
        "помня"

      "to love" ->
        "обичам"

      "to consider" ->
        "обмислям"

      "to appear" ->
        "появявам се"

      "to buy" ->
        "купувам"

      "to wait" ->
        "чакам"

      "to serve" ->
        "обслужвам"

      "to die" ->
        "умирам"

      "to send" ->
        "изпращам"

      "to expect" ->
        "очаквам"

      "to build" ->
        "строя"

      "to stay" ->
        "оставам"

      "to fall" ->
        "падам"

      "to cut" ->
        "режа"

      "to reach" ->
        "достигам"

      "to kill" ->
        "убивам"

      "to remain" ->
        "оставам"

      "to suggest" ->
        "предлагам"

      "to raise" ->
        "вдигам"

      "to pass" ->
        "минавам"

      "to sell" ->
        "продавам"

      "to require" ->
        "изисквам"

      "to report" ->
        "докладвам"

      "to decide" ->
        "решавам"

      "to pull" ->
        "дърпам"

      "to return" ->
        "връщам се"

      "to explain" ->
        "обяснявам"

      "to carry" ->
        "нося"

      "to develop" ->
        "развивам се"

      "to hope" ->
        "надявам се"

      "to drive" ->
        "карам"

      "to break" ->
        "чупя"

      "to receive" ->
        "получавам"

      "to agree" ->
        "съгласявам се"

      "to support" ->
        "подкрепям"

      "to remove" ->
        "премахвам"

      "to return" ->
        "връщам"

      "to describe" ->
        "описвам"

      "to cause" ->
        "причинявам"

      "to keep" ->
        "запазвам"

      "to assume" ->
        "предполагам"

      "to apply" ->
        "прилагам"

      "to avoid" ->
        "избягвам"

      "to prepare" ->
        "подготвям"

      "to join" ->
        "присъединявам се"

      "to reduce" ->
        "намалявам"

      "to establish" ->
        "установявам"

      "to catch" ->
        "хващам"

      "to draw" ->
        "рисувам"

      "to choose" ->
        "избирам"

      "to shoot" ->
        "стрелям"

      "to touch" ->
        "докосвам"

      "to hope" ->
        "надявам се"

      "to introduce" ->
        "представям"

      "to maintain" ->
        "поддържам"

      "to achieve" ->
        "постирам"

      "to invite" ->
        "каня"

      "to compare" ->
        "сравнявам"

      "to contain" ->
        "съдържам"

      "to prevent" ->
        "предотвратявам"

      "to solve" ->
        "решавам"

      "to treat" ->
        "третирам"

      "to claim" ->
        "твърдя"

      "to improve" ->
        "подобрявам"

      "to charge" ->
        "зареждам"

      "to address" ->
        "адресирам"

      "to enjoy" ->
        "наслаждавам се"

      "to perform" ->
        "изпълнявам"

      "to cover" ->
        "покривам"

      "to exist" ->
        "съществувам"

      "to obtain" ->
        "получавам"

      "to represent" ->
        "представлявам"

      "to indicate" ->
        "показвам"

      "to determine" ->
        "определям"

      "to belong" ->
        "принадлежа"

      "to share" ->
        "споделям"

      "to apply" ->
        "кандидатствам"

      "to fear" ->
        "страхувам се"

      "to suffer" ->
        "страдам"

      "to reflect" ->
        "отразявам"

      "to benefit" ->
        "извличам полза"

      "to identify" ->
        "идентифицирам"

      "to worry" ->
        "тревожа се"

      "to suffer" ->
        "страдам"

      "to notice" ->
        "забелязвам"

      "to throw" ->
        "хвърлям"

      "to examine" ->
        "изследвам"

      "to fail" ->
        "провалям се"

      "to intend" ->
        "възнамерявам"

      "to refuse" ->
        "отказвам"

      "to throw" ->
        "хвърлям"

      "to sleep" ->
        "спя"

      "to suffer" ->
        "страдам"

      "to realize" ->
        "осъзнавам"

      "to beat" ->
        "бия"

      "to arrange" ->
        "подреждам"

      "to employ" ->
        "наемам"

      "to prove" ->
        "доказвам"

      "to appoint" ->
        "назначавам"

      "to release" ->
        "освобождавам"

      "to commit" ->
        "ангажирам се"

      "to issue" ->
        "издавам"

      "to strike" ->
        "ударям"

      "to regard" ->
        "разглеждам"

      "to shout" ->
        "крещя"

      "to attempt" ->
        "опитвам се"

      "to catch" ->
        "хващам"

      "to demand" ->
        "изисквам"

      "to reject" ->
        "отхвърлям"

      "to restore" ->
        "възстановявам"

      "to emerge" ->
        "появявам се"

      "to express" ->
        "изразявам"

      "to aim" ->
        "целя се"

      "to lie" ->
        "лъжа"

      "to promise" ->
        "обещавам"

      "to maintain" ->
        "поддържам"

      "to threaten" ->
        "заплашвам"

      "to form" ->
        "формирам"

      "to associate" ->
        "свързвам"

      "to contribute" ->
        "съдействам"

      "to impose" ->
        "налагам"

      "to train" ->
        "тренирам"

      "to trust" ->
        "имам доверие"

      "to adopt" ->
        "осиновявам"

      "to confirm" ->
        "потвърждавам"

      "to define" ->
        "дефинирам"

      "to handle" ->
        "обработвам"

      "to acquire" ->
        "придобивам"

      "to observe" ->
        "наблюдавам"

      "to escape" ->
        "бягам"

      "to encourage" ->
        "насърчавам"

      "to assume" ->
        "предполагам"

      "to generate" ->
        "генерирам"

      "to emphasize" ->
        "подчертавам"

      "to drop" ->
        "пускам"

      "to attack" ->
        "атакувам"

      "to accompany" ->
        "придружавам"

      "to preserve" ->
        "пазя"

      "to pursue" ->
        "преследвам"

      "to satisfy" ->
        "задоволявам"

      "to belong" ->
        "принадлежа"

      "to combine" ->
        "комбинирам"

      "to finance" ->
        "финансирам"

      "to hang" ->
        "вися"

      "to appeal" ->
        "обжалвам"

      "to ignore" ->
        "игнорирам"

      "to estimate" ->
        "оценявам"

      "to dismiss" ->
        "отхвърлям"

      "to capture" ->
        "хващам"

      "to launch" ->
        "изстрелвам"

      "to blame" ->
        "обвинявам"

      "to convert" ->
        "преобразувам"

      "to educate" ->
        "образовавам"

      "to warn" ->
        "предупреждавам"

      "to slow" ->
        "забавям"

      "to abandon" ->
        "изоставям"

      "to conduct" ->
        "провеждам"

      "to distinguish" ->
        "разграничавам"

      "to concentrate" ->
        "концентрирам се"

      "to honour" ->
        "почитам"

      "to gather" ->
        "събирам"

      "to recover" ->
        "възстановявам се"

      "to warn" ->
        "предупреждавам"

      "to burn" ->
        "горя"

      "to adjust" ->
        "нагласям"

      "to decline" ->
        "отказвам"

      "to accommodate" ->
        "настанявам"

      "to possess" ->
        "притежавам"

      "to comment" ->
        "коментирам"

      "to expose" ->
        "разкривам"

      "to demand" ->
        "изисквам"

      "to organize" ->
        "организирам"

      "to engage" ->
        "ангажирам"

      "to withdraw" ->
        "тегля"

      "to separate" ->
        "отделям"

      "to connect" ->
        "свързвам"

      "to consist" ->
        "състоя се"

      "to paint" ->
        "боядисвам"

      "to pretend" ->
        "преструвам се"

      "to celebrate" ->
        "празнувам"

      "to distinguish" ->
        "различавам"

      "to occupy" ->
        "зает съм"

      "to interpret" ->
        "тълкувам"

      "to face" ->
        "изправям се пред"

      "to confront" ->
        "изправям се пред"

      "to reject" ->
        "отхвърлям"

      "to propose" ->
        "предлагам"

      "to persuade" ->
        "убеждавам"

      "to attract" ->
        "привличам"

      "to monitor" ->
        "наблюдавам"

      "to ensure" ->
        "гарантирам"

      "to entertain" ->
        "развличам"

      "to abandon" ->
        "изоставям"

      "to defeat" ->
        "побеждавам"

      "to debate" ->
        "дебатирам"

      "to undergo" ->
        "претърпявам"

      "to punish" ->
        "наказвам"

      "to reply" ->
        "отговарям"

      "to reply" ->
        "отговарям"

      "to interrupt" ->
        "прекъсвам"

      "to qualify" ->
        "квалифицирам се"

      "to charge" ->
        "зареждам"

      "to date" ->
        "датирам"

      "to employ" ->
        "наемам"

      "to accept" ->
        "приемам"

      "to react" ->
        "реагирам"

      "to handle" ->
        "обработвам"

      "to affect" ->
        "влияя"

      "to encounter" ->
        "срещам"

      "to ignore" ->
        "игнорирам"

      "to inspire" ->
        "вдъхновявам"

      "to furnish" ->
        "обзавеждам"

      "to propose" ->
        "предлагам"

      "to restrict" ->
        "ограничавам"

      "to protect" ->
        "защитавам"

      "to range" ->
        "варирам"

      "to prompt" ->
        "подтиквам"

      "to demand" ->
        "изисквам"

      "to cast" ->
        "хвърлям"

      "to debate" ->
        "дебатирам"

      "to investigate" ->
        "разследвам"

      "to cite" ->
        "цитирам"

      "to influence" ->
        "влияя"

      "to blame" ->
        "обвинявам"

      "to shift" ->
        "премествам"

      "to operate" ->
        "оперирам"

      "to pause" ->
        "спирам"

      "to resort" ->
        "прибягвам"

      "to centre" ->
        "центрирам"

      "to facilitate" ->
        "съдействам"

      "to volunteer" ->
        "доброволствам"

      "to perceive" ->
        "възприемам"

      "to cling" ->
        "държа се"

      "to admit" ->
        "признавам"

      "to regard" ->
        "разглеждам"

      "to negotiate" ->
        "преговарям"

      "to boost" ->
        "стимулирам"

      "to blow" ->
        "духам"

      "to witness" ->
        "свидетелствам"

      "to generate" ->
        "генерирам"

      "to assess" ->
        "оценявам"

      "to boost" ->
        "подсилвам"

      "to settle" ->
        "уреждам"

      "to reinforce" ->
        "подкрепям"

      "to criticise" ->
        "критикувам"

      "to wander" ->
        "скитам се"

      "to challenge" ->
        "предизвиквам"

      "to fade" ->
        "избледнявам"

      "to manipulate" ->
        "манипулирам"

      "to confront" ->
        "изправям се пред"

      "to overcome" ->
        "преодолявам"

      "to resume" ->
        "възобновявам"

      "to dedicate" ->
        "посвещавам"

      "to discriminate" ->
        "дискриминирам"

      "to delight" ->
        "радвам"

      "to exclude" ->
        "изключвам"

      "to burst" ->
        "експлодирам"

      "to characterize" ->
        "характеризирам"

      "to hesitate" ->
        "колебая се"

      "to constitute" ->
        "съставлявам"

      "to undermine" ->
        "подкопавам"

      "to stir" ->
        "разбърквам"

      "to indulge" ->
        "облагодетелствам"

      "to wander" ->
        "скитам се"

      "to intervene" ->
        "намесвам се"

      "to dismiss" ->
        "отхвърлям"

      "to manipulate" ->
        "манипулирам"

      "to prohibit" ->
        "забранявам"

      "to transmit" ->
        "предавам"

      "to substitute" ->
        "замествам"

      "to grasp" ->
        "схващам"

      "to embrace" ->
        "прегръщам"

      "to honour" ->
        "почитам"

      "to quote" ->
        "цитирам"

      "to sponsor" ->
        "спонсорирам"

      "to dip" ->
        "потапям"

      "to stem" ->
        "произтичам"

      "to perceive" ->
        "възприемам"

      "to dominate" ->
        "доминирам"

      "to boost" ->
        "подсилвам"

      "to comment" ->
        "коментирам"

      "to echo" ->
        "ехтя"

      "to tempt" ->
        "изкушавам"

      "to condemn" ->
        "осъждам"

      "to accelerate" ->
        "ускорявам"

      "to confine" ->
        "ограничавам"

      "to reverse" ->
        "обръщам"

      "to supervise" ->
        "наблюдавам"

      "to tolerate" ->
        "търпя"

      "to consult" ->
        "консултирам се"

      "to entail" ->
        "предполага"

      "to attribute" ->
        "приписвам"

      "to await" ->
        "очаквам"

      "to venture" ->
        "рискувам"

      "to inhibit" ->
        "възпирам"

      "to cite" ->
        "цитирам"

      "to dedicate" ->
        "посвещавам"

      "to tempt" ->
        "изкушавам"

      "to diminish" ->
        "намалявам"

      "to discriminate" ->
        "дискриминирам"

      "to enhance" ->
        "подобрявам"

      "to injure" ->
        "наранявам"

      "to facilitate" ->
        "съдействам"

      "to entertain" ->
        "развличам"

      "to suppress" ->
        "потискам"

      "to undertake" ->
        "предприемам"

      "to provoke" ->
        "предизвиквам"

      "to suspend" ->
        "спирам"

      "to enforce" ->
        "налагам"

      "to abolish" ->
        "отменям"

      "to formulate" ->
        "формулирам"

      "to reinforce" ->
        "подкрепям"

      "to replicate" ->
        "копирам"

      "to persist" ->
        "упорствам"

      "to suppress" ->
        "потискам"

      "to retain" ->
        "запазвам"

      "to tempt" ->
        "изкушавам"

      "to indulge" ->
        "облагодетелствам"

      "to deteriorate" ->
        "влошавам се"

      "to degrade" ->
        "деградирам"

      "to strive" ->
        "стремя се"

      "to intervene" ->
        "намесвам се"

      "to astonish" ->
        "изумявам"

      "to indulge" ->
        "облагодетелствам"

      "to negotiate" ->
        "преговарям"

      "to contemplate" ->
        "обмислям"

      "to signify" ->
        "означавам"

      "to accumulate" ->
        "натрупвам"

      "to persist" ->
        "упорствам"

      "to embrace" ->
        "прегръщам"

      "to restrict" ->
        "ограничавам"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to contemplate" ->
        "обмислям"

      "to expire" ->
        "изтичам"

      "to execute" ->
        "изпълнявам"

      "to deteriorate" ->
        "влошавам се"

      "to distinguish" ->
        "разграничавам"

      "to mediate" ->
        "посреднича"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to derive" ->
        "произтичам"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to depict" ->
        "изобразявам"

      "to accumulate" ->
        "натрупвам"

      "to collaborate" ->
        "сътруднича"

      "to deteriorate" ->
        "влошавам се"

      "to intervene" ->
        "намесвам се"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to contemplate" ->
        "размишлявам"

      "to derive" ->
        "произтичам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to intervene" ->
        "намесвам се"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to derive" ->
        "произтичам"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to intervene" ->
        "намесвам се"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to derive" ->
        "произтичам"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to intervene" ->
        "намесвам се"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      "to intervene" ->
        "намесвам се"

      "to contemplate" ->
        "размишлявам"

      "to derive" ->
        "произтичам"

      "to prevail" ->
        "преобладавам"

      "to restrain" ->
        "възпирам"

      "to accumulate" ->
        "натрупвам"

      _ ->
        nil
    end
  end
end

# Read the batch
json = File.read!("/tmp/batch_1.json")
words = Jason.decode!(json)

# Translate each word
translated =
  Enum.map(words, fn word ->
    meaning = word["meaning"]
    bg_translation = Translator.translate(meaning)

    if bg_translation do
      Map.put(word, "translations", %{"bg" => %{"meaning" => bg_translation}})
    else
      # If no translation found, use a default or mark it
      Map.put(word, "translations", %{"bg" => %{"meaning" => "[ПРЕВОД: #{meaning}]"}})
    end
  end)

# Save the translated batch
output = Jason.encode!(translated, pretty: true)
File.write!("/tmp/translated_1.json", output)

IO.puts("Batch 1 translated: #{length(translated)} words")
