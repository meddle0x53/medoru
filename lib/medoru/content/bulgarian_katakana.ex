defmodule Medoru.Content.BulgarianKatakana do
  @moduledoc """
  Hardcoded Bulgarian alphabet → katakana/hiragana mappings with example words.

  Each Bulgarian letter is paired with its typical Japanese katakana reading,
  the equivalent hiragana, and a latin/romaji approximation. Example words are
  common Bulgarian words and phrases transliterated into katakana the way a
  Japanese speaker would approximate them.

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
          %{bulgarian: "Ананас", katakana: "アナナス", meaning: "パイナップル"},
          %{bulgarian: "Автобус", katakana: "アヴトブス", meaning: "バス"},
          %{bulgarian: "Апел", katakana: "アペル", meaning: "抗議"},
          %{bulgarian: "Артист", katakana: "アルティスト", meaning: "アーティスト"}
        ]
      },
      %__MODULE__{
        letter: "Б",
        katakana: "ブ",
        hiragana: "ぶ",
        latin: "bu",
        words: [
          %{bulgarian: "Банан", katakana: "バナン", meaning: "バナナ"},
          %{bulgarian: "Бебе", katakana: "ベベ", meaning: "赤ちゃん"},
          %{bulgarian: "България", katakana: "ブルガリア", meaning: "ブルガリア"},
          %{bulgarian: "Билет", katakana: "ビレット", meaning: "切符"},
          %{bulgarian: "Бургер", katakana: "ブルゲル", meaning: "ハンバーガー"}
        ]
      },
      %__MODULE__{
        letter: "В",
        katakana: "ヴ",
        hiragana: "ゔ",
        latin: "vu",
        words: [
          %{bulgarian: "Вода", katakana: "ヴォダ", meaning: "水"},
          %{bulgarian: "Време", katakana: "ヴレメ", meaning: "時間"},
          %{bulgarian: "Влак", katakana: "ヴラク", meaning: "電車"},
          %{bulgarian: "Вино", katakana: "ヴィノ", meaning: "ワイン"},
          %{bulgarian: "Врата", katakana: "ヴラタ", meaning: "ドア"}
        ]
      },
      %__MODULE__{
        letter: "Г",
        katakana: "グ",
        hiragana: "ぐ",
        latin: "gu",
        words: [
          %{bulgarian: "Град", katakana: "グラド", meaning: "街"},
          %{bulgarian: "Голям", katakana: "ゴリャム", meaning: "大きい"},
          %{bulgarian: "Грозде", katakana: "グロズデ", meaning: "ブドウ"},
          %{bulgarian: "Глава", katakana: "グラヴァ", meaning: "頭"},
          %{bulgarian: "Гора", katakana: "ゴラ", meaning: "山"}
        ]
      },
      %__MODULE__{
        letter: "Д",
        katakana: "ド",
        hiragana: "ど",
        latin: "do",
        words: [
          %{bulgarian: "Дом", katakana: "ドム", meaning: "家"},
          %{bulgarian: "Ден", katakana: "デン", meaning: "日"},
          %{bulgarian: "Дърво", katakana: "ダルヴォ", meaning: "木"},
          %{bulgarian: "Добър", katakana: "ドバル", meaning: "良い"},
          %{bulgarian: "Дядо", katakana: "ディャド", meaning: "おじいさん"}
        ]
      },
      %__MODULE__{
        letter: "Е",
        katakana: "エ",
        hiragana: "え",
        latin: "e",
        words: [
          %{bulgarian: "Един", katakana: "エディン", meaning: "一"},
          %{bulgarian: "Език", katakana: "エズィク", meaning: "言語"},
          %{bulgarian: "Елен", katakana: "エレン", meaning: "鹿"},
          %{bulgarian: "Екран", katakana: "エクラン", meaning: "画面"},
          %{bulgarian: "Европа", katakana: "エヴロパ", meaning: "ヨーロッパ"}
        ]
      },
      %__MODULE__{
        letter: "Ж",
        katakana: "ジュ",
        hiragana: "じゅ",
        latin: "ju",
        words: [
          %{bulgarian: "Жена", katakana: "ジェナ", meaning: "女"},
          %{bulgarian: "Живот", katakana: "ジヴォト", meaning: "人生"},
          %{bulgarian: "Жълто", katakana: "ジャルト", meaning: "黄色"},
          %{bulgarian: "Жираф", katakana: "ジラフ", meaning: "キリン"},
          %{bulgarian: "Желязо", katakana: "ジェリャゾ", meaning: "鉄"}
        ]
      },
      %__MODULE__{
        letter: "З",
        katakana: "ズ",
        hiragana: "ず",
        latin: "zu",
        words: [
          %{bulgarian: "Здравей", katakana: "ズドラヴェイ", meaning: "こんにちは"},
          %{bulgarian: "Зелен", katakana: "ゼレン", meaning: "緑"},
          %{bulgarian: "Зима", katakana: "ズィマ", meaning: "冬"},
          %{bulgarian: "Змия", katakana: "ズミヤ", meaning: "蛇"},
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
          %{bulgarian: "Искам", katakana: "イスカム", meaning: "欲しい"},
          %{bulgarian: "Индия", katakana: "インディヤ", meaning: "インド"},
          %{bulgarian: "Истина", katakana: "イスティナ", meaning: "真実"},
          %{bulgarian: "Игра", katakana: "イグラ", meaning: "遊び"}
        ]
      },
      %__MODULE__{
        letter: "Й",
        katakana: "イ",
        hiragana: "い",
        latin: "i",
        words: [
          %{bulgarian: "Йод", katakana: "ヨド", meaning: "ヨウ素"},
          %{bulgarian: "Йога", katakana: "ヨガ", meaning: "ヨガ"},
          %{bulgarian: "Май", katakana: "マイ", meaning: "五月"},
          %{bulgarian: "Чай", katakana: "チャイ", meaning: "お茶"},
          %{bulgarian: "Хайде", katakana: "ハイデ", meaning: "行こう"}
        ]
      },
      %__MODULE__{
        letter: "К",
        katakana: "ク",
        hiragana: "く",
        latin: "ku",
        words: [
          %{bulgarian: "Куче", katakana: "クチェ", meaning: "犬"},
          %{bulgarian: "Котка", katakana: "コトカ", meaning: "猫"},
          %{bulgarian: "Кафе", katakana: "カフェ", meaning: "コーヒー"},
          %{bulgarian: "Книга", katakana: "クニガ", meaning: "本"},
          %{bulgarian: "Кола", katakana: "コラ", meaning: "車"}
        ]
      },
      %__MODULE__{
        letter: "Л",
        katakana: "ル",
        hiragana: "る",
        latin: "lu",
        words: [
          %{bulgarian: "Лъв", katakana: "ラヴ", meaning: "ライオン"},
          %{bulgarian: "Лято", katakana: "リャト", meaning: "夏"},
          %{bulgarian: "Лимон", katakana: "リモン", meaning: "レモン"},
          %{bulgarian: "Луна", katakana: "ルナ", meaning: "月"},
          %{bulgarian: "Лекар", katakana: "レカル", meaning: "医者"}
        ]
      },
      %__MODULE__{
        letter: "М",
        katakana: "ム",
        hiragana: "む",
        latin: "mu",
        words: [
          %{bulgarian: "Мляко", katakana: "ムリャコ", meaning: "牛乳"},
          %{bulgarian: "Майка", katakana: "マイカ", meaning: "母"},
          %{bulgarian: "Мъгла", katakana: "マグラ", meaning: "霧"},
          %{bulgarian: "Музика", katakana: "ムズィカ", meaning: "音楽"},
          %{bulgarian: "Месо", katakana: "メソ", meaning: "肉"}
        ]
      },
      %__MODULE__{
        letter: "Н",
        katakana: "ヌ",
        hiragana: "ぬ",
        latin: "nu",
        words: [
          %{bulgarian: "Небе", katakana: "ネベ", meaning: "空"},
          %{bulgarian: "Нощ", katakana: "ノシュト", meaning: "夜"},
          %{bulgarian: "Нос", katakana: "ノス", meaning: "鼻"},
          %{bulgarian: "Неделя", katakana: "ネデリャ", meaning: "日曜日"},
          %{bulgarian: "Нова", katakana: "ノヴァ", meaning: "新しい"}
        ]
      },
      %__MODULE__{
        letter: "О",
        katakana: "オ",
        hiragana: "お",
        latin: "o",
        words: [
          %{bulgarian: "Око", katakana: "オコ", meaning: "目"},
          %{bulgarian: "Огън", katakana: "オガン", meaning: "火"},
          %{bulgarian: "Овца", katakana: "オヴツァ", meaning: "羊"},
          %{bulgarian: "Оранжев", katakana: "オランジェヴ", meaning: "橙色"},
          %{bulgarian: "Обичам", katakana: "オブィチャム", meaning: "愛してる"}
        ]
      },
      %__MODULE__{
        letter: "П",
        katakana: "プ",
        hiragana: "ぷ",
        latin: "pu",
        words: [
          %{bulgarian: "Портокал", katakana: "ポートカル", meaning: "オレンジ"},
          %{bulgarian: "Пет", katakana: "ペト", meaning: "五"},
          %{bulgarian: "Птица", katakana: "プティツァ", meaning: "鳥"},
          %{bulgarian: "Приятел", katakana: "プリャテル", meaning: "友達"},
          %{bulgarian: "Пари", katakana: "パリ", meaning: "お金"}
        ]
      },
      %__MODULE__{
        letter: "Р",
        katakana: "ル",
        hiragana: "る",
        latin: "ru",
        words: [
          %{bulgarian: "Риба", katakana: "リバ", meaning: "魚"},
          %{bulgarian: "Ръка", katakana: "ラカ", meaning: "手"},
          %{bulgarian: "Роза", katakana: "ロザ", meaning: "バラ"},
          %{bulgarian: "Работа", katakana: "ラボタ", meaning: "仕事"},
          %{bulgarian: "Ресторант", katakana: "レストラント", meaning: "レストラン"}
        ]
      },
      %__MODULE__{
        letter: "С",
        katakana: "ス",
        hiragana: "す",
        latin: "su",
        words: [
          %{bulgarian: "Слънце", katakana: "スランツェ", meaning: "太陽"},
          %{bulgarian: "Сок", katakana: "ソク", meaning: "ジュース"},
          %{bulgarian: "Сняг", katakana: "スニャグ", meaning: "雪"},
          %{bulgarian: "Син", katakana: "シン", meaning: "息子"},
          %{bulgarian: "Сирене", katakana: "シレネ", meaning: "チーズ"}
        ]
      },
      %__MODULE__{
        letter: "Т",
        katakana: "ト",
        hiragana: "と",
        latin: "to",
        words: [
          %{bulgarian: "Тигър", katakana: "ティガル", meaning: "トラ"},
          %{bulgarian: "Топка", katakana: "トプカ", meaning: "ボール"},
          %{bulgarian: "Телефон", katakana: "テレフォン", meaning: "電話"},
          %{bulgarian: "Тук", katakana: "トゥク", meaning: "ここ"},
          %{bulgarian: "Таван", katakana: "タヴァン", meaning: "天井"}
        ]
      },
      %__MODULE__{
        letter: "У",
        katakana: "ウ",
        hiragana: "う",
        latin: "u",
        words: [
          %{bulgarian: "Улица", katakana: "ウリツァ", meaning: "通り"},
          %{bulgarian: "Утре", katakana: "ウトレ", meaning: "明日"},
          %{bulgarian: "Училище", katakana: "ウチリシュテ", meaning: "学校"},
          %{bulgarian: "Ухо", katakana: "ウホ", meaning: "耳"},
          %{bulgarian: "У дома", katakana: "ウ ドマ", meaning: "家に"}
        ]
      },
      %__MODULE__{
        letter: "Ф",
        katakana: "フ",
        hiragana: "ふ",
        latin: "fu",
        words: [
          %{bulgarian: "Футбол", katakana: "フトボル", meaning: "サッカー"},
          %{bulgarian: "Филм", katakana: "フィルム", meaning: "映画"},
          %{bulgarian: "Ферма", katakana: "フェルマ", meaning: "農場"},
          %{bulgarian: "Френски", katakana: "フレンスキ", meaning: "フランス語"},
          %{bulgarian: "Флашка", katakana: "フラシュカ", meaning: "USBメモリ"}
        ]
      },
      %__MODULE__{
        letter: "Х",
        katakana: "ハ",
        hiragana: "は",
        latin: "ha",
        words: [
          %{bulgarian: "Хляб", katakana: "ハリャブ", meaning: "パン"},
          %{bulgarian: "Хора", katakana: "ホラ", meaning: "人々"},
          %{bulgarian: "Хотел", katakana: "ホテル", meaning: "ホテル"},
          %{bulgarian: "Химия", katakana: "ヒミヤ", meaning: "化学"},
          %{bulgarian: "Хубав", katakana: "フバヴ", meaning: "美しい"}
        ]
      },
      %__MODULE__{
        letter: "Ц",
        katakana: "ツ",
        hiragana: "つ",
        latin: "tsu",
        words: [
          %{bulgarian: "Цвете", katakana: "ツヴェテ", meaning: "花"},
          %{bulgarian: "Цар", katakana: "ツァル", meaning: "皇帝"},
          %{bulgarian: "Целувка", katakana: "ツェルヴカ", meaning: "キス"},
          %{bulgarian: "Цигара", katakana: "ツィガラ", meaning: "タバコ"},
          %{bulgarian: "Цветя", katakana: "ツヴェティャ", meaning: "花々"}
        ]
      },
      %__MODULE__{
        letter: "Ч",
        katakana: "チ",
        hiragana: "ち",
        latin: "chi",
        words: [
          %{bulgarian: "Човек", katakana: "チョヴェク", meaning: "人"},
          %{bulgarian: "Чаша", katakana: "チャシャ", meaning: "カップ"},
          %{bulgarian: "Червен", katakana: "チェルヴェン", meaning: "赤い"},
          %{bulgarian: "Чанта", katakana: "チャンタ", meaning: "バッグ"},
          %{bulgarian: "Чистя", katakana: "チスティャ", meaning: "掃除する"}
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
          %{bulgarian: "Шофьор", katakana: "ショフリョル", meaning: "運転手"},
          %{bulgarian: "Шум", katakana: "シュム", meaning: "騒音"},
          %{bulgarian: "Шарен", katakana: "シャレン", meaning: "色とりどり"}
        ]
      },
      %__MODULE__{
        letter: "Щ",
        katakana: "シュト",
        hiragana: "しゅと",
        latin: "shto",
        words: [
          %{bulgarian: "Щастие", katakana: "シュタスティエ", meaning: "幸せ"},
          %{bulgarian: "Щипка", katakana: "シュティプカ", meaning: "ピンチ"},
          %{bulgarian: "Щъркел", katakana: "シュタルケル", meaning: "コウノトリ"},
          %{bulgarian: "Ще", katakana: "シュテ", meaning: "未来"},
          %{bulgarian: "Щука", katakana: "シュトゥカ", meaning: "カワカマス"}
        ]
      },
      %__MODULE__{
        letter: "Ъ",
        katakana: "ウ",
        hiragana: "う",
        latin: "u",
        words: [
          %{bulgarian: "Ъгъл", katakana: "ウガル", meaning: "角"},
          %{bulgarian: "Сън", katakana: "サン", meaning: "夢"},
          %{bulgarian: "Въздух", katakana: "ヴァズドゥフ", meaning: "空気"},
          %{bulgarian: "България", katakana: "ブルガリア", meaning: "ブルガリア"},
          %{bulgarian: "Дърво", katakana: "ダルヴォ", meaning: "木"}
        ]
      },
      %__MODULE__{
        letter: "Ь",
        katakana: "ウ",
        hiragana: "う",
        latin: "u",
        note: "soft sign",
        words: [
          %{bulgarian: "Сьомга", katakana: "ショムガ", meaning: "鮭"},
          %{bulgarian: "Бьорн", katakana: "ビョルン", meaning: "ビョルン"},
          %{bulgarian: "Аньо", katakana: "アニョ", meaning: "アニョ"},
          %{bulgarian: "Мьонх", katakana: "ミョンフ", meaning: "ミュンフ"},
          %{bulgarian: "Льо", katakana: "リョ", meaning: "レオ"}
        ]
      },
      %__MODULE__{
        letter: "Ю",
        katakana: "ユ",
        hiragana: "ゆ",
        latin: "yu",
        words: [
          %{bulgarian: "Юни", katakana: "ユニ", meaning: "六月"},
          %{bulgarian: "Юг", katakana: "ユグ", meaning: "南"},
          %{bulgarian: "Юбилей", katakana: "ユビレイ", meaning: "記念日"},
          %{bulgarian: "Юмрук", katakana: "ユムルク", meaning: "拳"},
          %{bulgarian: "Юрта", katakana: "ユルタ", meaning: "ゲル"}
        ]
      },
      %__MODULE__{
        letter: "Я",
        katakana: "ヤ",
        hiragana: "や",
        latin: "ya",
        words: [
          %{bulgarian: "Ябълка", katakana: "ヤバルカ", meaning: "りんご"},
          %{bulgarian: "Яко", katakana: "ヤコ", meaning: "かっこいい"},
          %{bulgarian: "Януари", katakana: "ヤヌアリ", meaning: "一月"},
          %{bulgarian: "Ястие", katakana: "ヤスティエ", meaning: "料理"},
          %{bulgarian: "Ядро", katakana: "ヤドロ", meaning: "核"}
        ]
      }
    ]
  end

  @doc "Get a Bulgarian letter entry by its Cyrillic character (e.g. \"А\" or \"я\")."
  def get_by_letter(letter) when is_binary(letter) do
    upper = String.upcase(letter)
    list_letters() |> Enum.find(&(&1.letter == upper))
  end

  @doc "Returns true if the given character is a known Bulgarian letter."
  def letter?(letter) when is_binary(letter) do
    get_by_letter(letter) != nil
  end
end
