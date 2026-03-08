"""Exporter for kanji data to Medoru format."""

import json
from pathlib import Path

from rich.console import Console

console = Console()


class KanjiExporter:
    """Export kanji stroke data to Medoru seed format."""
    
    def export_strokes(self, stroke_data: dict[str, dict], output_path: str) -> bool:
        """Export stroke data to JSON file.
        
        Args:
            stroke_data: Dictionary mapping kanji to stroke data
            output_path: Output file path
            
        Returns:
            True if successful, False otherwise
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        result = {
            "strokes": stroke_data,
            "_meta": {
                "source": "KanjiVG",
                "license": "CC BY-SA 3.0",
                "copyright": "© Ulrich Apel",
                "attribution": "http://kanjivg.tagaini.net",
                "count": len(stroke_data)
            }
        }
        
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {len(stroke_data)} kanji to {output_path}")
            return True
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting: {e}")
            return False
    
    def export_for_elixir_seeds(self, stroke_data: dict[str, dict], output_path: str) -> bool:
        """Export in format compatible with Elixir seeds.
        
        This exports just the strokes object without metadata wrapper,
        suitable for direct use in priv/repo/seeds/.
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        result = {"strokes": stroke_data}
        
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {len(stroke_data)} kanji to {output_path}")
            console.print(f"[dim]Attribution: KanjiVG © Ulrich Apel (CC BY-SA 3.0)[/dim]")
            return True
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting: {e}")
            return False
    
    def export_kanji_metadata(self, kanji_list: list[dict], output_path: str, 
                              include_readings: bool = True,
                              source: str = "Kanji Data",
                              license: str = "MIT",
                              copyright: str = "© davidluzgouveia",
                              attribution: str = "https://github.com/davidluzgouveia/kanji-data") -> bool:
        """Export kanji metadata to Medoru format.
        
        Args:
            kanji_list: List of kanji dictionaries
            output_path: Output file path
            include_readings: Whether to include on/kun readings
            source: Data source name
            license: License type
            copyright: Copyright notice
            attribution: Attribution URL
            
        Returns:
            True if successful, False otherwise
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Transform to Medoru format
        kanji_data = []
        for k in kanji_list:
            kanji_entry = {
                "character": k["character"],
                "meanings": k.get("meanings", []),
                "stroke_count": k.get("stroke_count"),
                "jlpt_level": k.get("jlpt_level"),
                "frequency": k.get("frequency"),
                "radicals": k.get("radicals", []),
            }
            
            # Remove None values
            kanji_entry = {k: v for k, v in kanji_entry.items() if v is not None}
            
            if include_readings:
                readings = k.get("readings", [])
                
                # Handle both formats:
                # 1. List format (from kanji-data spider): [{"reading_type": "on", "reading": "..."}, ...]
                # 2. Dict format (from KANJIDIC2): {"on": [...], "kun": [...]}
                
                if isinstance(readings, list):
                    # Already in list format, use as-is
                    kanji_entry["readings"] = readings
                elif isinstance(readings, dict):
                    # Transform from dict to list format
                    transformed = []
                    
                    # On readings (katakana)
                    for reading in readings.get("on", []):
                        transformed.append({
                            "reading_type": "on",
                            "reading": reading,
                            "romaji": self._kana_to_romaji(reading)
                        })
                    
                    # Kun readings (hiragana)
                    for reading in readings.get("kun", []):
                        # Remove okurigana marker (e.g., "あ.る" -> "あ")
                        clean_reading = reading.split(".")[0]
                        transformed.append({
                            "reading_type": "kun",
                            "reading": clean_reading,
                            "romaji": self._kana_to_romaji(clean_reading)
                        })
                    
                    kanji_entry["readings"] = transformed
            
            kanji_data.append(kanji_entry)
        
        result = {
            "kanji": kanji_data,
            "_meta": {
                "source": source,
                "license": license,
                "copyright": copyright,
                "attribution": attribution,
                "count": len(kanji_data),
                "include_readings": include_readings
            }
        }
        
        try:
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {len(kanji_data)} kanji to {output_path}")
            console.print(f"[dim]Attribution: {source} ({license})[/dim]")
            return True
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting: {e}")
            return False
    
    def _kana_to_romaji(self, kana: str) -> str:
        """Convert kana to romaji (basic implementation).
        
        This is a simplified romaji conversion. For production use,
        consider using a library like `pykakasi` or `cutlet`.
        """
        # Basic kana to romaji mapping
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
            "ぱ": "pa", "ぴ": "pi", "ぷ": "pe", "ぺ": "pe", "ぽ": "po",
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
            "っ": "",  # Small tsu (will be handled specially)
            "ー": "-",  # Long vowel marker
            
            # Katakana (same sounds)
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
            "ッ": "",  # Small tsu
            "ー": "-",  # Long vowel marker
        }
        
        # Handle empty string
        if not kana:
            return ""
        
        result = []
        i = 0
        while i < len(kana):
            # Try 2-character combinations first (for small yoon)
            if i + 1 < len(kana):
                two_char = kana[i:i+2]
                if two_char in kana_map:
                    # Check if it's a small tsu (sokuon)
                    if kana_map[two_char] == "":
                        # Double the next consonant
                        if result:
                            # This is simplified - proper implementation would look ahead
                            pass
                    else:
                        result.append(kana_map[two_char])
                    i += 2
                    continue
            
            # Single character
            char = kana[i]
            if char in kana_map:
                romaji = kana_map[char]
                if romaji == "":
                    # Small tsu - doubles next consonant if present
                    pass
                else:
                    result.append(romaji)
            else:
                # Unknown character, keep as-is
                result.append(char)
            i += 1
        
        # Join and fix long vowel markers
        romaji = "".join(result)
        romaji = romaji.replace("a-", "aa").replace("i-", "ii").replace("u-", "uu")
        romaji = romaji.replace("e-", "ee").replace("o-", "ou")
        
        return romaji
