defmodule Medoru.Content.KanaRomaji do
  @moduledoc """
  Converts hiragana/katakana word readings to a latin/romaji approximation.

  Handles standard monographs, yoon digraphs, voiced/semi-voiced marks,
  the sokuon (っ/ッ), and the prolonged sound mark (ー).
  """

  @doc """
  Returns a latin approximation for a kana reading.

  Readings separated by "/" are converted separately and joined with " / ".
  """
  def to_romaji(reading) when is_binary(reading) and reading != "" do
    reading
    |> String.split("/")
    |> Enum.map(&do_to_romaji/1)
    |> Enum.join(" / ")
  end

  def to_romaji(_), do: ""

  defp do_to_romaji(reading) do
    reading
    |> String.graphemes()
    |> to_romaji_chars([])
    |> Enum.reverse()
    |> Enum.join()
    |> mark_long_vowels()
  end

  defp to_romaji_chars([], acc), do: acc

  # Sokuon (っ/ッ) before a digraph: double the following consonant.
  defp to_romaji_chars([sokuon, c1, c2 | rest], acc)
       when sokuon in ["っ", "ッ"] do
    case Map.fetch(digraphs(), c1 <> c2) do
      {:ok, romaji} ->
        to_romaji_chars(rest, [geminate(romaji) | acc])

      :error ->
        # Not a valid digraph; geminate the next kana alone and continue.
        case Map.fetch(monographs(), c1) do
          {:ok, romaji} -> to_romaji_chars([c2 | rest], [geminate(romaji) | acc])
          :error -> to_romaji_chars([c2 | rest], acc)
        end
    end
  end

  # Sokuon before a single kana.
  defp to_romaji_chars([sokuon, c | rest], acc)
       when sokuon in ["っ", "ッ"] do
    case Map.fetch(monographs(), c) do
      {:ok, romaji} -> to_romaji_chars(rest, [geminate(romaji) | acc])
      :error -> to_romaji_chars(rest, acc)
    end
  end

  # Prolonged sound mark: repeat the last emitted vowel.
  defp to_romaji_chars(["ー" | rest], acc) do
    to_romaji_chars(rest, [last_vowel(acc) | acc])
  end

  # Standard yoon digraphs.
  defp to_romaji_chars([c1, c2 | rest], acc) do
    if Map.has_key?(digraphs(), c1 <> c2) do
      to_romaji_chars(rest, [Map.fetch!(digraphs(), c1 <> c2) | acc])
    else
      # Not a valid digraph; process the first kana on its own and continue.
      case Map.fetch(monographs(), c1) do
        {:ok, romaji} -> to_romaji_chars([c2 | rest], [romaji | acc])
        :error -> to_romaji_chars([c2 | rest], acc)
      end
    end
  end

  # Single kana.
  defp to_romaji_chars([c | rest], acc) do
    case Map.fetch(monographs(), c) do
      {:ok, romaji} -> to_romaji_chars(rest, [romaji | acc])
      :error -> to_romaji_chars(rest, acc)
    end
  end

  defp last_vowel([]), do: ""

  defp last_vowel([last | _]) do
    case String.last(last) do
      v when v in ["a", "e", "i", "o", "u"] -> v
      _ -> ""
    end
  end

  defp geminate(romaji) do
    cond do
      String.starts_with?(romaji, "ch") -> "t" <> romaji
      String.starts_with?(romaji, "sh") -> "s" <> romaji
      String.starts_with?(romaji, "ts") -> "t" <> romaji
      true ->
        case String.first(romaji) do
          <<c>> when c in ?a..?z -> <<c>> <> romaji
          _ -> romaji
        end
    end
  end

  # Convert adjacent vowel pairs that represent long sounds into macron forms.
  defp mark_long_vowels(romaji) do
    romaji
    |> String.replace("ou", "ō")
    |> String.replace("ei", "ē")
    |> String.replace("aa", "ā")
    |> String.replace("ii", "ī")
    |> String.replace("uu", "ū")
    |> String.replace("ee", "ē")
    |> String.replace("oo", "ō")
  end

  defp monographs do
    %{
      # Hiragana
      "あ" => "a",
      "い" => "i",
      "う" => "u",
      "え" => "e",
      "お" => "o",
      "か" => "ka",
      "き" => "ki",
      "く" => "ku",
      "け" => "ke",
      "こ" => "ko",
      "が" => "ga",
      "ぎ" => "gi",
      "ぐ" => "gu",
      "げ" => "ge",
      "ご" => "go",
      "さ" => "sa",
      "し" => "shi",
      "す" => "su",
      "せ" => "se",
      "そ" => "so",
      "ざ" => "za",
      "じ" => "ji",
      "ず" => "zu",
      "ぜ" => "ze",
      "ぞ" => "zo",
      "た" => "ta",
      "ち" => "chi",
      "つ" => "tsu",
      "て" => "te",
      "と" => "to",
      "だ" => "da",
      "ぢ" => "ji",
      "づ" => "zu",
      "で" => "de",
      "ど" => "do",
      "な" => "na",
      "に" => "ni",
      "ぬ" => "nu",
      "ね" => "ne",
      "の" => "no",
      "は" => "ha",
      "ひ" => "hi",
      "ふ" => "fu",
      "へ" => "he",
      "ほ" => "ho",
      "ば" => "ba",
      "び" => "bi",
      "ぶ" => "bu",
      "べ" => "be",
      "ぼ" => "bo",
      "ぱ" => "pa",
      "ぴ" => "pi",
      "ぷ" => "pu",
      "ぺ" => "pe",
      "ぽ" => "po",
      "ま" => "ma",
      "み" => "mi",
      "む" => "mu",
      "め" => "me",
      "も" => "mo",
      "や" => "ya",
      "ゆ" => "yu",
      "よ" => "yo",
      "ら" => "ra",
      "り" => "ri",
      "る" => "ru",
      "れ" => "re",
      "ろ" => "ro",
      "わ" => "wa",
      "を" => "wo",
      "ん" => "n",
      # Katakana
      "ア" => "a",
      "イ" => "i",
      "ウ" => "u",
      "エ" => "e",
      "オ" => "o",
      "カ" => "ka",
      "キ" => "ki",
      "ク" => "ku",
      "ケ" => "ke",
      "コ" => "ko",
      "ガ" => "ga",
      "ギ" => "gi",
      "グ" => "gu",
      "ゲ" => "ge",
      "ゴ" => "go",
      "サ" => "sa",
      "シ" => "shi",
      "ス" => "su",
      "セ" => "se",
      "ソ" => "so",
      "ザ" => "za",
      "ジ" => "ji",
      "ズ" => "zu",
      "ゼ" => "ze",
      "ゾ" => "zo",
      "タ" => "ta",
      "チ" => "chi",
      "ツ" => "tsu",
      "テ" => "te",
      "ト" => "to",
      "ダ" => "da",
      "ヂ" => "ji",
      "ヅ" => "zu",
      "デ" => "de",
      "ド" => "do",
      "ナ" => "na",
      "ニ" => "ni",
      "ヌ" => "nu",
      "ネ" => "ne",
      "ノ" => "no",
      "ハ" => "ha",
      "ヒ" => "hi",
      "フ" => "fu",
      "ヘ" => "he",
      "ホ" => "ho",
      "バ" => "ba",
      "ビ" => "bi",
      "ブ" => "bu",
      "ベ" => "be",
      "ボ" => "bo",
      "パ" => "pa",
      "ピ" => "pi",
      "プ" => "pu",
      "ペ" => "pe",
      "ポ" => "po",
      "マ" => "ma",
      "ミ" => "mi",
      "ム" => "mu",
      "メ" => "me",
      "モ" => "mo",
      "ヤ" => "ya",
      "ユ" => "yu",
      "ヨ" => "yo",
      "ラ" => "ra",
      "リ" => "ri",
      "ル" => "ru",
      "レ" => "re",
      "ロ" => "ro",
      "ワ" => "wa",
      "ヲ" => "wo",
      "ン" => "n",
      "ヴ" => "vu"
    }
  end

  defp digraphs do
    %{
      # Hiragana yoon
      "きゃ" => "kya",
      "きゅ" => "kyu",
      "きょ" => "kyo",
      "ぎゃ" => "gya",
      "ぎゅ" => "gyu",
      "ぎょ" => "gyo",
      "しゃ" => "sha",
      "しゅ" => "shu",
      "しょ" => "sho",
      "じゃ" => "ja",
      "じゅ" => "ju",
      "じょ" => "jo",
      "ちゃ" => "cha",
      "ちゅ" => "chu",
      "ちょ" => "cho",
      "ぢゃ" => "ja",
      "ぢゅ" => "ju",
      "ぢょ" => "jo",
      "にゃ" => "nya",
      "にゅ" => "nyu",
      "にょ" => "nyo",
      "ひゃ" => "hya",
      "ひゅ" => "hyu",
      "ひょ" => "hyo",
      "びゃ" => "bya",
      "びゅ" => "byu",
      "びょ" => "byo",
      "ぴゃ" => "pya",
      "ぴゅ" => "pyu",
      "ぴょ" => "pyo",
      "みゃ" => "mya",
      "みゅ" => "myu",
      "みょ" => "myo",
      "りゃ" => "rya",
      "りゅ" => "ryu",
      "りょ" => "ryo",
      # Katakana yoon
      "キャ" => "kya",
      "キュ" => "kyu",
      "キョ" => "kyo",
      "ギャ" => "gya",
      "ギュ" => "gyu",
      "ギョ" => "gyo",
      "シャ" => "sha",
      "シュ" => "shu",
      "ショ" => "sho",
      "ジャ" => "ja",
      "ジュ" => "ju",
      "ジョ" => "jo",
      "チャ" => "cha",
      "チュ" => "chu",
      "チョ" => "cho",
      "ヂャ" => "ja",
      "ヂュ" => "ju",
      "ヂョ" => "jo",
      "ニャ" => "nya",
      "ニュ" => "nyu",
      "ニョ" => "nyo",
      "ヒャ" => "hya",
      "ヒュ" => "hyu",
      "ヒョ" => "hyo",
      "ビャ" => "bya",
      "ビュ" => "byu",
      "ビョ" => "byo",
      "ピャ" => "pya",
      "ピュ" => "pyu",
      "ピョ" => "pyo",
      "ミャ" => "mya",
      "ミュ" => "myu",
      "ミョ" => "myo",
      "リャ" => "rya",
      "リュ" => "ryu",
      "リョ" => "ryo",
      # Extended katakana for foreign sounds
      "ファ" => "fa",
      "フィ" => "fi",
      "フェ" => "fe",
      "フォ" => "fo",
      "ウィ" => "wi",
      "ウェ" => "we",
      "ウォ" => "wo",
      "ヴァ" => "va",
      "ヴィ" => "vi",
      "ヴェ" => "ve",
      "ヴォ" => "vo",
      "ツァ" => "tsa",
      "ツィ" => "tsi",
      "ツェ" => "tse",
      "ツォ" => "tso",
      "ティ" => "ti",
      "トゥ" => "tu",
      "ディ" => "di",
      "ドゥ" => "du",
      "シェ" => "she",
      "チェ" => "che",
      "ジェ" => "je",
      "イェ" => "ye",
      "クァ" => "kwa",
      "クィ" => "kwi",
      "クェ" => "kwe",
      "クォ" => "kwo",
      "グァ" => "gwa",
      "グィ" => "gwi",
      "グェ" => "gwe",
      "グォ" => "gwo"
    }
  end
end
