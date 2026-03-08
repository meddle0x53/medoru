"""Kanji Data spider for downloading comprehensive kanji information.

This spider fetches from the davidluzgouveia/kanji-data repository which provides:
- Both old (1-4) and new (N5-N1) JLPT levels
- Stroke counts
- Meanings and readings
- Grade level and frequency

Data source: https://github.com/davidluzgouveia/kanji-data
License: Check original repository
"""

import json
from pathlib import Path
from typing import Optional

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from tqdm import tqdm

from ..config import HTTP_TIMEOUT, RAW_DIR

console = Console()


class KanjiDataSpider:
    """Spider for downloading comprehensive kanji data with N5-N1 levels."""
    
    DATA_URL = "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/master/kanji.json"
    
    def __init__(self):
        self.raw_dir = RAW_DIR / "kanji_data"
        self.json_path = self.raw_dir / "kanji.json"
        
    def download(self, force: bool = False) -> bool:
        """Download kanji data from GitHub.
        
        Args:
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        if self.json_path.exists() and not force:
            console.print("[green]✓[/green] Kanji data already downloaded")
            return True
        
        console.print(f"[blue]Downloading kanji data from {self.DATA_URL}...[/blue]")
        
        try:
            self.raw_dir.mkdir(parents=True, exist_ok=True)
            
            # Download with progress
            response = requests.get(self.DATA_URL, timeout=HTTP_TIMEOUT, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get("content-length", 0))
            
            with open(self.json_path, "wb") as f:
                with tqdm(total=total_size, unit="B", unit_scale=True) as pbar:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            pbar.update(len(chunk))
            
            console.print(f"[green]✓[/green] Download complete")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error downloading kanji data: {e}")
            return False
    
    def load_data(self) -> dict:
        """Load the downloaded kanji data.
        
        Returns:
            Dictionary mapping kanji characters to their data
        """
        if not self.json_path.exists():
            console.print("[red]Error:[/red] Kanji data not downloaded. Run 'medoru-data kanji-data download' first.")
            return {}
        
        try:
            with open(self.json_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            console.print(f"[red]Error loading kanji data: {e}[/red]")
            return {}
    
    def get_kanji_by_new_level(self, level: int) -> list[dict]:
        """Get kanji filtered by NEW JLPT level (N5-N1).
        
        Args:
            level: New JLPT level (5, 4, 3, 2, or 1)
            
        Returns:
            List of kanji dictionaries for that level
        """
        data = self.load_data()
        result = []
        
        for char, kanji_data in data.items():
            jlpt_new = kanji_data.get("jlpt_new")
            if jlpt_new == level:
                entry = self._transform_entry(char, kanji_data)
                if entry:
                    result.append(entry)
        
        return result
    
    def get_all_kanji_with_new_levels(self) -> list[dict]:
        """Get all kanji that have new JLPT level assignments.
        
        Returns:
            List of kanji dictionaries with new JLPT levels
        """
        data = self.load_data()
        result = []
        
        for char, kanji_data in data.items():
            jlpt_new = kanji_data.get("jlpt_new")
            if jlpt_new:  # Only include kanji with new JLPT levels
                entry = self._transform_entry(char, kanji_data)
                if entry:
                    result.append(entry)
        
        return result
    
    def get_kanji_by_characters(self, characters: list[str]) -> list[dict]:
        """Get kanji data for specific characters.
        
        Args:
            characters: List of kanji characters to look up
            
        Returns:
            List of kanji dictionaries found
        """
        data = self.load_data()
        result = []
        
        for char in characters:
            if char in data:
                entry = self._transform_entry(char, data[char])
                if entry:
                    result.append(entry)
        
        return result
    
    def get_stats(self) -> dict:
        """Get statistics about the kanji data."""
        data = self.load_data()
        
        total = len(data)
        with_old = sum(1 for k in data.values() if k.get("jlpt_old"))
        with_new = sum(1 for k in data.values() if k.get("jlpt_new"))
        
        by_new_level = {}
        for level in [5, 4, 3, 2, 1]:
            by_new_level[level] = sum(
                1 for k in data.values() 
                if k.get("jlpt_new") == level
            )
        
        by_old_level = {}
        for level in [4, 3, 2, 1]:
            by_old_level[level] = sum(
                1 for k in data.values() 
                if k.get("jlpt_old") == level
            )
        
        return {
            "total": total,
            "with_old_jlpt": with_old,
            "with_new_jlpt": with_new,
            "by_new_level": by_new_level,
            "by_old_level": by_old_level,
        }
    
    def _transform_entry(self, character: str, data: dict) -> Optional[dict]:
        """Transform kanji data entry to Medoru format.
        
        Args:
            character: The kanji character
            data: Raw kanji data
            
        Returns:
            Transformed dictionary or None if invalid
        """
        try:
            # Build readings list
            readings = []
            
            # On readings (convert hiragana to katakana for consistency)
            for reading in data.get("readings_on", []):
                katakana = self._hiragana_to_katakana(reading)
                readings.append({
                    "reading_type": "on",
                    "reading": katakana,
                    "romaji": self._kana_to_romaji(katakana)
                })
            
            # Kun readings (clean okurigana markers)
            for reading in data.get("readings_kun", []):
                # Remove okurigana markers (e.g., "ひと.つ" -> "ひと")
                clean = reading.split(".")[0]
                # Remove leading ! from wani kani format
                clean = clean.lstrip("!")
                if clean:
                    readings.append({
                        "reading_type": "kun",
                        "reading": clean,
                        "romaji": self._kana_to_romaji(clean)
                    })
            
            # Remove duplicates while preserving order
            seen = set()
            unique_readings = []
            for r in readings:
                key = (r["reading_type"], r["reading"])
                if key not in seen:
                    seen.add(key)
                    unique_readings.append(r)
            
            return {
                "character": character,
                "meanings": data.get("meanings", []),
                "stroke_count": data.get("strokes"),
                "jlpt_level": data.get("jlpt_new"),  # Use new JLPT level
                "jlpt_old": data.get("jlpt_old"),    # Keep old level for reference
                "frequency": data.get("freq"),
                "grade": data.get("grade"),
                "readings": unique_readings
            }
            
        except Exception as e:
            console.print(f"[yellow]Warning:[/yellow] Error transforming {character}: {e}")
            return None
    
    def _hiragana_to_katakana(self, text: str) -> str:
        """Convert hiragana to katakana."""
        result = []
        for char in text:
            code = ord(char)
            # Hiragana range: U+3040 to U+309F
            # Katakana range: U+30A0 to U+30FF
            if 0x3040 <= code <= 0x309F:
                # Convert to katakana by adding 0x60 to the code point
                result.append(chr(code + 0x60))
            else:
                result.append(char)
        return "".join(result)
    
    def _kana_to_romaji(self, kana: str) -> str:
        """Convert kana to romaji (basic implementation)."""
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
            # Try 2-character combinations first
            if i + 1 < len(kana):
                two_char = kana[i:i+2]
                if two_char in kana_map:
                    result.append(kana_map[two_char])
                    i += 2
                    continue
            
            # Single character
            char = kana[i]
            if char in kana_map:
                romaji = kana_map[char]
                if romaji:
                    result.append(romaji)
            else:
                result.append(char)
            i += 1
        
        # Join and fix long vowel markers
        romaji = "".join(result)
        romaji = romaji.replace("a-", "aa").replace("i-", "ii").replace("u-", "uu")
        romaji = romaji.replace("e-", "ee").replace("o-", "ou")
        
        return romaji
    
    def get_status(self) -> dict:
        """Get download status information."""
        downloaded = self.json_path.exists()
        file_size = "0 B"
        kanji_count = 0
        
        if downloaded:
            size_bytes = self.json_path.stat().st_size
            file_size = self._format_size(size_bytes)
            
            # Count kanji
            try:
                with open(self.json_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    kanji_count = len(data)
            except:
                pass
        
        return {
            "downloaded": downloaded,
            "file_size": file_size,
            "kanji_count": kanji_count,
        }
    
    def _format_size(self, size_bytes: int) -> str:
        """Format byte size to human readable."""
        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"
