defmodule Medoru.Content.BulgarianKatakana do
  @moduledoc """
  Hardcoded Bulgarian alphabet → katakana/hiragana mappings with example words.

  Each Bulgarian letter is paired with its typical Japanese katakana reading,
  the equivalent hiragana, and a latin/romaji approximation. Example words are
  common Bulgarian words and phrases transliterated into katakana the way a
  Japanese speaker would approximate them.

  Notes about the transliteration style used here:

    * Bulgarian В is usually written with ヴ when we want to preserve the "v" sound:
      Вода → ヴォダ, Вино → ヴィノ.
    * Bulgarian Ъ is represented as ア, because it is closer to a hard central
      "a/uh" sound than Japanese ウ.
    * Bulgarian Л and Р cannot be perfectly distinguished in Japanese, so both are
      approximated with Japanese ラ/リ/ル/レ/ロ sounds depending on the vowel.
    * Final Bulgarian consonants receive a small Japanese support vowel when needed:
      нощ → ノシュト, град → グラド, хляб → フリャブ.
    * These are practical learner-friendly approximations, not strict linguistic IPA.

  The `meaning` field for each word holds the Japanese equivalent so the detail
  page can link to the matching word entry on `/words` when available.
  """

  defstruct [:letter, :katakana, :hiragana, :latin, :note, :words]

  @type word :: %{
          bulgarian: String.t(),
          katakana: String.t(),
          meaning: String.t()
        }

  @type t :: %__MODULE__{
          letter: String.t(),
          katakana: String.t(),
          hiragana: String.t(),
          latin: String.t(),
          note: String.t() | nil,
          words: list(word())
        }

  @doc "List all Bulgarian letters with their katakana readings and example words."
  def list_letters do
    [
      %__MODULE__{
        letter: "А",
        katakana: "ア",
        hiragana: "あ",
        latin: "a",
        words: [
          %{bulgarian: "Аз", katakana: "アス", meaning: "私"},
          %{bulgarian: "Ало", katakana: "アロ", meaning: "もしもし"},
          %{bulgarian: "Адрес", katakana: "アドレス", meaning: "住所"},
          %{bulgarian: "Аптека", katakana: "アプテカ", meaning: "薬局"},
          %{bulgarian: "Автобус", katakana: "アヴトブス", meaning: "バス"}
        ]
      },
      %__MODULE__{
        letter: "Б",
        katakana: "ブ",
        hiragana: "ぶ",
        latin: "bu",
        words: [
          %{bulgarian: "Благодаря", katakana: "ブラゴダリャ", meaning: "ありがとう"},
          %{bulgarian: "България", katakana: "ブルガリヤ", meaning: "ブルガリア"},
          %{bulgarian: "Билет", katakana: "ビレット", meaning: "切符"},
          %{bulgarian: "Баня", katakana: "バニャ", meaning: "風呂"},
          %{bulgarian: "Бързо", katakana: "バルゾ", meaning: "速い"}
        ]
      },
      %__MODULE__{
        letter: "В",
        katakana: "ヴ",
        hiragana: "ゔ",
        latin: "vu",
        words: [
          %{bulgarian: "Вода", katakana: "ヴォダ", meaning: "水"},
          %{bulgarian: "Вино", katakana: "ヴィノ", meaning: "ワイン"},
          %{bulgarian: "Вечер", katakana: "ヴェチェル", meaning: "夕方"},
          %{bulgarian: "Вход", katakana: "ヴホド", meaning: "入口"},
          %{bulgarian: "Вкусно", katakana: "ヴクスノ", meaning: "おいしい"}
        ]
      },
      %__MODULE__{
        letter: "Г",
        katakana: "グ",
        hiragana: "ぐ",
        latin: "gu",
        words: [
          %{bulgarian: "Град", katakana: "グラド", meaning: "街"},
          %{bulgarian: "Гара", katakana: "ガラ", meaning: "駅"},
          %{bulgarian: "Гладен съм", katakana: "グラデン サム", meaning: "お腹が空いた"},
          %{bulgarian: "Горещо", katakana: "ゴレシュト", meaning: "暑い"},
          %{bulgarian: "Говоря", katakana: "ゴヴォリャ", meaning: "話す"}
        ]
      },
      %__MODULE__{
        letter: "Д",
        katakana: "ド",
        hiragana: "ど",
        latin: "do",
        words: [
          %{bulgarian: "Добър ден", katakana: "ドバル デン", meaning: "こんにちは"},
          %{bulgarian: "Добро утро", katakana: "ドブロ ウトロ", meaning: "おはよう"},
          %{bulgarian: "Добър вечер", katakana: "ドバル ヴェチェル", meaning: "こんばんは"},
          %{bulgarian: "До скоро", katakana: "ド スコロ", meaning: "またね"},
          %{bulgarian: "Да", katakana: "ダ", meaning: "はい"}
        ]
      },
      %__MODULE__{
        letter: "Е",
        katakana: "エ",
        hiragana: "え",
        latin: "e",
        words: [
          %{bulgarian: "Един", katakana: "エディン", meaning: "一"},
          %{bulgarian: "Евтино", katakana: "エヴティノ", meaning: "安い"},
          %{bulgarian: "Език", katakana: "エズィク", meaning: "言語"},
          %{bulgarian: "Елате", katakana: "エラテ", meaning: "来てください"},
          %{bulgarian: "Европа", katakana: "エヴロパ", meaning: "ヨーロッパ"}
        ]
      },
      %__MODULE__{
        letter: "Ж",
        katakana: "ジュ",
        hiragana: "じゅ",
        latin: "zhu",
        words: [
          %{bulgarian: "Жена", katakana: "ジェナ", meaning: "女性"},
          %{bulgarian: "Живея", katakana: "ジヴェヤ", meaning: "住む"},
          %{bulgarian: "Живот", katakana: "ジヴォト", meaning: "人生"},
          %{bulgarian: "Жаден съм", katakana: "ジャデン サム", meaning: "喉が渇いた"},
          %{bulgarian: "Жълто", katakana: "ジャルト", meaning: "黄色"}
        ]
      },
      %__MODULE__{
        letter: "З",
        katakana: "ズ",
        hiragana: "ず",
        latin: "zu",
        words: [
          %{bulgarian: "Здравей", katakana: "ズドラヴェイ", meaning: "こんにちは"},
          %{bulgarian: "Здрасти", katakana: "ズドラスティ", meaning: "やあ"},
          %{bulgarian: "Заповядайте", katakana: "ザポヴャダイテ", meaning: "どうぞ"},
          %{bulgarian: "Знам", katakana: "ズナム", meaning: "知っている"},
          %{bulgarian: "Захар", katakana: "ザハル", meaning: "砂糖"}
        ]
      },
      %__MODULE__{
        letter: "И",
        katakana: "イ",
        hiragana: "い",
        latin: "i",
        words: [
          %{bulgarian: "Име", katakana: "イメ", meaning: "名前"},
          %{bulgarian: "Искам вода", katakana: "イスカム ヴォダ", meaning: "水が欲しい"},
          %{bulgarian: "Извинете", katakana: "イズヴィネテ", meaning: "すみません"},
          %{bulgarian: "Имам", katakana: "イマム", meaning: "持っている"},
          %{bulgarian: "Игра", katakana: "イグラ", meaning: "ゲーム"}
        ]
      },
      %__MODULE__{
        letter: "Й",
        katakana: "イ",
        hiragana: "い",
        latin: "y / i",
        note: "short i / y sound; usually appears after a vowel",
        words: [
          %{bulgarian: "Май", katakana: "マイ", meaning: "五月"},
          %{bulgarian: "Чай", katakana: "チャイ", meaning: "お茶"},
          %{bulgarian: "Здравей", katakana: "ズドラヴェイ", meaning: "こんにちは"},
          %{bulgarian: "Хайде", katakana: "ハイデ", meaning: "行こう"},
          %{bulgarian: "Йога", katakana: "ヨガ", meaning: "ヨガ"}
        ]
      },
      %__MODULE__{
        letter: "К",
        katakana: "ク",
        hiragana: "く",
        latin: "ku",
        words: [
          %{bulgarian: "Как си?", katakana: "カク スィ", meaning: "元気ですか"},
          %{bulgarian: "Кафе", katakana: "カフェ", meaning: "コーヒー"},
          %{bulgarian: "Къде?", katakana: "カデ", meaning: "どこ"},
          %{bulgarian: "Колко струва?", katakana: "コルコ ストルヴァ", meaning: "いくらですか"},
          %{bulgarian: "Късмет", katakana: "カスメト", meaning: "幸運"}
        ]
      },
      %__MODULE__{
        letter: "Л",
        katakana: "ル",
        hiragana: "る",
        latin: "lu",
        note: "Bulgarian Л is approximated with Japanese r/l row sounds",
        words: [
          %{bulgarian: "Лека нощ", katakana: "レカ ノシュト", meaning: "おやすみ"},
          %{bulgarian: "Ляво", katakana: "リャヴォ", meaning: "左"},
          %{bulgarian: "Лесно", katakana: "レスノ", meaning: "簡単"},
          %{bulgarian: "Лекар", katakana: "レカル", meaning: "医者"},
          %{bulgarian: "Лято", katakana: "リャト", meaning: "夏"}
        ]
      },
      %__MODULE__{
        letter: "М",
        katakana: "ム",
        hiragana: "む",
        latin: "mu",
        words: [
          %{bulgarian: "Моля", katakana: "モリャ", meaning: "お願いします"},
          %{bulgarian: "Може ли?", katakana: "モジェ リ", meaning: "いいですか"},
          %{bulgarian: "Майка", katakana: "マイカ", meaning: "母"},
          %{bulgarian: "Малко", katakana: "マルコ", meaning: "少し"},
          %{bulgarian: "Много добре", katakana: "ムノゴ ドブレ", meaning: "とても良い"}
        ]
      },
      %__MODULE__{
        letter: "Н",
        katakana: "ヌ",
        hiragana: "ぬ",
        latin: "nu",
        words: [
          %{bulgarian: "Не", katakana: "ネ", meaning: "いいえ"},
          %{bulgarian: "Няма проблем", katakana: "ニャマ プロブレム", meaning: "問題ありません"},
          %{bulgarian: "Наздраве", katakana: "ナズドラヴェ", meaning: "乾杯"},
          %{bulgarian: "Нощ", katakana: "ノシュト", meaning: "夜"},
          %{bulgarian: "Неделя", katakana: "ネデリャ", meaning: "日曜日"}
        ]
      },
      %__MODULE__{
        letter: "О",
        katakana: "オ",
        hiragana: "お",
        latin: "o",
        words: [
          %{bulgarian: "Обичам те", katakana: "オビチャム テ", meaning: "愛してる"},
          %{bulgarian: "Още веднъж", katakana: "オシュテ ヴェドナジュ", meaning: "もう一度"},
          %{bulgarian: "Откъде сте?", katakana: "オトカデ ステ", meaning: "どちらからですか"},
          %{bulgarian: "Окей", katakana: "オケイ", meaning: "オーケー"},
          %{bulgarian: "Отивам", katakana: "オティヴァム", meaning: "行く"}
        ]
      },
      %__MODULE__{
        letter: "П",
        katakana: "プ",
        hiragana: "ぷ",
        latin: "pu",
        words: [
          %{bulgarian: "Приятно ми е", katakana: "プリャトノ ミ エ", meaning: "はじめまして"},
          %{bulgarian: "Помощ", katakana: "ポモシュト", meaning: "助け"},
          %{bulgarian: "Пари", katakana: "パリ", meaning: "お金"},
          %{bulgarian: "Пазар", katakana: "パザル", meaning: "市場"},
          %{bulgarian: "Приятел", katakana: "プリャテル", meaning: "友達"}
        ]
      },
      %__MODULE__{
        letter: "Р",
        katakana: "ル",
        hiragana: "る",
        latin: "ru",
        note: "Bulgarian Р is approximated with Japanese r row sounds",
        words: [
          %{bulgarian: "Разбирам", katakana: "ラズビラム", meaning: "分かる"},
          %{bulgarian: "Радвам се", katakana: "ラドヴァム セ", meaning: "嬉しい"},
          %{bulgarian: "Работа", katakana: "ラボタ", meaning: "仕事"},
          %{bulgarian: "Ресторант", katakana: "レストラント", meaning: "レストラン"},
          %{bulgarian: "Риба", katakana: "リバ", meaning: "魚"}
        ]
      },
      %__MODULE__{
        letter: "С",
        katakana: "ス",
        hiragana: "す",
        latin: "su",
        words: [
          %{bulgarian: "Съжалявам", katakana: "サジャリャヴァム", meaning: "ごめんなさい"},
          %{bulgarian: "Сега", katakana: "セガ", meaning: "今"},
          %{bulgarian: "Супер", katakana: "スペル", meaning: "すごい"},
          %{bulgarian: "Сметката, моля", katakana: "スメトカタ モリャ", meaning: "お会計お願いします"},
          %{bulgarian: "Семейство", katakana: "セメイストヴォ", meaning: "家族"}
        ]
      },
      %__MODULE__{
        letter: "Т",
        katakana: "ト",
        hiragana: "と",
        latin: "to",
        words: [
          %{bulgarian: "Тук", katakana: "トゥク", meaning: "ここ"},
          %{bulgarian: "Там", katakana: "タム", meaning: "そこ"},
          %{bulgarian: "Така", katakana: "タカ", meaning: "そう"},
          %{bulgarian: "Телефон", katakana: "テレフォン", meaning: "電話"},
          %{bulgarian: "Топло е", katakana: "トプロ エ", meaning: "暖かい"}
        ]
      },
      %__MODULE__{
        letter: "У",
        katakana: "ウ",
        hiragana: "う",
        latin: "u",
        words: [
          %{bulgarian: "Утре", katakana: "ウトレ", meaning: "明日"},
          %{bulgarian: "Улица", katakana: "ウリツァ", meaning: "通り"},
          %{bulgarian: "У дома", katakana: "ウ ドマ", meaning: "家に"},
          %{bulgarian: "Училище", katakana: "ウチリシュテ", meaning: "学校"},
          %{bulgarian: "Уморен съм", katakana: "ウモレン サム", meaning: "疲れた"}
        ]
      },
      %__MODULE__{
        letter: "Ф",
        katakana: "フ",
        hiragana: "ふ",
        latin: "fu",
        words: [
          %{bulgarian: "Фактура", katakana: "ファクトゥラ", meaning: "請求書"},
          %{bulgarian: "Филм", katakana: "フィルム", meaning: "映画"},
          %{bulgarian: "Футбол", katakana: "フトボル", meaning: "サッカー"},
          %{bulgarian: "Френски", katakana: "フレンスキ", meaning: "フランス語"},
          %{bulgarian: "Фирма", katakana: "フィルマ", meaning: "会社"}
        ]
      },
      %__MODULE__{
        letter: "Х",
        katakana: "ハ",
        hiragana: "は",
        latin: "ha",
        words: [
          %{bulgarian: "Хляб", katakana: "フリャブ", meaning: "パン"},
          %{bulgarian: "Хора", katakana: "ホラ", meaning: "人々"},
          %{bulgarian: "Хубаво", katakana: "フバヴォ", meaning: "良い"},
          %{bulgarian: "Хотел", katakana: "ホテル", meaning: "ホテル"},
          %{bulgarian: "Хайде", katakana: "ハイデ", meaning: "行こう"}
        ]
      },
      %__MODULE__{
        letter: "Ц",
        katakana: "ツ",
        hiragana: "つ",
        latin: "tsu",
        words: [
          %{bulgarian: "Център", katakana: "ツェンタル", meaning: "中心"},
          %{bulgarian: "Цена", katakana: "ツェナ", meaning: "値段"},
          %{bulgarian: "Цвете", katakana: "ツヴェテ", meaning: "花"},
          %{bulgarian: "Цял ден", katakana: "ツャル デン", meaning: "一日中"},
          %{bulgarian: "Целувка", katakana: "ツェルヴカ", meaning: "キス"}
        ]
      },
      %__MODULE__{
        letter: "Ч",
        katakana: "チ",
        hiragana: "ち",
        latin: "chi",
        words: [
          %{bulgarian: "Чао", katakana: "チャオ", meaning: "バイバイ"},
          %{bulgarian: "Чай", katakana: "チャイ", meaning: "お茶"},
          %{bulgarian: "Чакайте", katakana: "チャカイテ", meaning: "待ってください"},
          %{bulgarian: "Честито", katakana: "チェスティト", meaning: "おめでとう"},
          %{bulgarian: "Човек", katakana: "チョヴェク", meaning: "人"}
        ]
      },
      %__MODULE__{
        letter: "Ш",
        katakana: "シ",
        hiragana: "し",
        latin: "shi",
        words: [
          %{bulgarian: "Шоколад", katakana: "ショコラド", meaning: "チョコレート"},
          %{bulgarian: "Шапка", katakana: "シャプカ", meaning: "帽子"},
          %{bulgarian: "Шофьор", katakana: "ショフィョル", meaning: "運転手"},
          %{bulgarian: "Шумно е", katakana: "シュムノ エ", meaning: "うるさい"},
          %{bulgarian: "Шише вода", katakana: "シシェ ヴォダ", meaning: "水のボトル"}
        ]
      },
      %__MODULE__{
        letter: "Щ",
        katakana: "シュト",
        hiragana: "しゅと",
        latin: "sht",
        words: [
          %{bulgarian: "Ще се видим", katakana: "シュテ セ ヴィディム", meaning: "また会いましょう"},
          %{bulgarian: "Ще дойда", katakana: "シュテ ドイダ", meaning: "行きます"},
          %{bulgarian: "Ще платя", katakana: "シュテ プラティャ", meaning: "払います"},
          %{bulgarian: "Щастлив съм", katakana: "シュタストリヴ サム", meaning: "嬉しい"},
          %{bulgarian: "Още", katakana: "オシュテ", meaning: "もっと"}
        ]
      },
      %__MODULE__{
        letter: "Ъ",
        katakana: "ア",
        hiragana: "あ",
        latin: "ǎ",
        note: "hard central Bulgarian vowel; closer to a short hard 'a/uh' than Japanese ウ",
        words: [
          %{bulgarian: "Къде?", katakana: "カデ", meaning: "どこ"},
          %{bulgarian: "Добър", katakana: "ドバル", meaning: "良い"},
          %{bulgarian: "Сън", katakana: "サン", meaning: "夢"},
          %{bulgarian: "България", katakana: "ブルガリヤ", meaning: "ブルガリア"},
          %{bulgarian: "Ръка", katakana: "ラカ", meaning: "手"}
        ]
      },
      %__MODULE__{
        letter: "Ь",
        katakana: "ヨ",
        hiragana: "よ",
        latin: "yo / soft sign",
        note:
          "soft sign; in Bulgarian it usually appears before О and softens the previous consonant",
        words: [
          %{bulgarian: "Сьомга", katakana: "ショムガ", meaning: "鮭"},
          %{bulgarian: "Шофьор", katakana: "ショフィョル", meaning: "運転手"},
          %{bulgarian: "Актьор", katakana: "アクティョル", meaning: "俳優"},
          %{bulgarian: "Пеньо", katakana: "ペニョ", meaning: "ペニョ"},
          %{bulgarian: "Гьол", katakana: "ギョル", meaning: "池"}
        ]
      },
      %__MODULE__{
        letter: "Ю",
        katakana: "ユ",
        hiragana: "ゆ",
        latin: "yu",
        words: [
          %{bulgarian: "Юни", katakana: "ユニ", meaning: "六月"},
          %{bulgarian: "Юли", katakana: "ユリ", meaning: "七月"},
          %{bulgarian: "Юг", katakana: "ユグ", meaning: "南"},
          %{bulgarian: "Ютия", katakana: "ユティヤ", meaning: "アイロン"},
          %{bulgarian: "Юмрук", katakana: "ユムルク", meaning: "拳"}
        ]
      },
      %__MODULE__{
        letter: "Я",
        katakana: "ヤ",
        hiragana: "や",
        latin: "ya",
        words: [
          %{bulgarian: "Ябълка", katakana: "ヤバルカ", meaning: "りんご"},
          %{bulgarian: "Ям", katakana: "ヤム", meaning: "食べる"},
          %{bulgarian: "Ясно", katakana: "ヤスノ", meaning: "分かった"},
          %{bulgarian: "Януари", katakana: "ヤヌアリ", meaning: "一月"},
          %{bulgarian: "Якo", katakana: "ヤコ", meaning: "かっこいい"}
        ]
      }
    ]
  end

  @doc "Get a Bulgarian letter entry by its Cyrillic character, e.g. \"А\" or \"я\"."
  def get_by_letter(letter) when is_binary(letter) do
    upper = String.upcase(letter)
    list_letters() |> Enum.find(&(&1.letter == upper))
  end

  @doc "Returns true if the given character is a known Bulgarian letter."
  def letter?(letter) when is_binary(letter) do
    get_by_letter(letter) != nil
  end
end
