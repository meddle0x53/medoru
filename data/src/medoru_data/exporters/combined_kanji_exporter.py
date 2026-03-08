"""Combined exporter that merges kanji metadata with stroke data."""

import json
from pathlib import Path

from rich.console import Console

console = Console()


class CombinedKanjiExporter:
    """Export kanji with both metadata (from kanji-data) and stroke data (from KanjiVG)."""
    
    def export_combined(self, 
                        kanji_list: list[dict], 
                        kanjivg_spider,
                        output_path: str,
                        include_readings: bool = True) -> bool:
        """Export kanji with metadata and stroke data combined.
        
        Args:
            kanji_list: List of kanji dictionaries from kanji-data (with N5-N1 levels)
            kanjivg_spider: Instance of KanjiVGSpider for stroke data lookup
            output_path: Output file path
            include_readings: Whether to include on/kun readings
            
        Returns:
            True if successful, False otherwise
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Get list of characters to fetch stroke data for
        characters = [k["character"] for k in kanji_list]
        
        console.print(f"[blue]Fetching stroke data for {len(characters)} kanji...[/blue]")
        stroke_data = kanjivg_spider.extract_strokes(characters)
        
        # Combine metadata with stroke data
        kanji_data = []
        for k in kanji_list:
            char = k["character"]
            
            kanji_entry = {
                "character": char,
                "meanings": k.get("meanings", []),
                "stroke_count": k.get("stroke_count"),
                "jlpt_level": k.get("jlpt_level"),
                "frequency": k.get("frequency"),
                "grade": k.get("grade"),
            }
            
            # Add stroke data if available
            if char in stroke_data:
                kanji_entry["stroke_data"] = stroke_data[char]
            
            # Remove None values
            kanji_entry = {k: v for k, v in kanji_entry.items() if v is not None}
            
            if include_readings:
                readings = k.get("readings", [])
                
                # Handle both formats
                if isinstance(readings, list):
                    kanji_entry["readings"] = readings
                elif isinstance(readings, dict):
                    transformed = []
                    
                    for reading in readings.get("on", []):
                        transformed.append({
                            "reading_type": "on",
                            "reading": reading,
                            "romaji": self._kana_to_romaji(reading)
                        })
                    
                    for reading in readings.get("kun", []):
                        clean_reading = reading.split(".")[0]
                        transformed.append({
                            "reading_type": "kun",
                            "reading": clean_reading,
                            "romaji": self._kana_to_romaji(clean_reading)
                        })
                    
                    kanji_entry["readings"] = transformed
            
            kanji_data.append(kanji_entry)
        
        with_strokes = sum(1 for k in kanji_data if "stroke_data" in k)
        
        result = {
            "kanji": kanji_data,
            "_meta": {
                "source": "Kanji Data + KanjiVG",
                "license": "MIT + CC BY-SA 3.0",
                "copyright": "© davidluzgouveia + © Ulrich Apel",
                "attribution": "https://github.com/davidluzgouveia/kanji-data + http://kanjivg.tagaini.net",
                "count": len(kanji_data),
                "with_stroke_data": with_strokes,
                "without_stroke_data": len(kanji_data) - with_strokes,
                "include_readings": include_readings
            }
        }
        
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {len(kanji_data)} kanji to {output_path}")
            console.print(f"[dim]  With stroke data: {with_strokes} | Without: {len(kanji_data) - with_strokes}[/dim]")
            console.print(f"[dim]Attribution: Kanji Data + KanjiVG[/dim]")
            return True
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting: {e}")
            return False
    
    def _kana_to_romaji(self, kana: str) -> str:
        """Convert kana to romaji (basic implementation)."""
        kana_map = {
            # Hiragana
            "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
            "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
            "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
            "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
            "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
            "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
            "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
            "や": "ya", "ゆ": "yu", "よ": "yo",
            "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
            "わ": "wa", "を": "wo", "ん": "n",
            "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
            "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
            "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
            "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
            "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
            "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
            "しゃ": "sha", "しゅ": "shu", "しょ": "sho",
            "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho",
            "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
            "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
            "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
            "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
            "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
            "じゃ": "ja", "じゅ": "ju", "じょ": "jo",
            "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
            "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
            "っ": "", "ー": "-",
            # Katakana
            "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
            "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
            "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
            "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
            "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
            "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
            "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
            "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
            "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
            "ワ": "wa", "ヲ": "wo", "ン": "n",
            "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
            "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
            "ダ": "da", "ヂ": "ji", "ヅ": "zu", "デ": "de", "ド": "do",
            "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
            "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
            "キャ": "kya", "キュ": "kyu", "キョ": "kyo",
            "シャ": "sha", "シュ": "shu", "ショ": "sho",
            "チャ": "cha", "チュ": "chu", "チョ": "cho",
            "ニャ": "nya", "ニュ": "nyu", "ニョ": "nyo",
            "ヒャ": "hya", "ヒュ": "hyu", "ヒョ": "hyo",
            "ミャ": "mya", "ミュ": "myu", "ミョ": "myo",
            "リャ": "rya", "リュ": "ryu", "リョ": "ryo",
            "ギャ": "gya", "ギュ": "gyu", "ギョ": "gyo",
            "ジャ": "ja", "ジュ": "ju", "ジョ": "jo",
            "ビャ": "bya", "ビュ": "byu", "ビョ": "byo",
            "ピャ": "pya", "ピュ": "pyu", "ピョ": "pyo",
            "ッ": "", "ー": "-",
        }
        
        if not kana:
            return ""
        
        result = []
        i = 0
        while i < len(kana):
            if i + 1 < len(kana):
                two_char = kana[i:i+2]
                if two_char in kana_map:
                    result.append(kana_map[two_char])
                    i += 2
                    continue
            
            char = kana[i]
            if char in kana_map:
                romaji = kana_map[char]
                if romaji:
                    result.append(romaji)
            else:
                result.append(char)
            i += 1
        
        romaji = "".join(result)
        romaji = romaji.replace("a-", "aa").replace("i-", "ii").replace("u-", "uu")
        romaji = romaji.replace("e-", "ee").replace("o-", "ou")
        
        return romaji
