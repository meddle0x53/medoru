"""Word exporter for converting JMdict data to Medoru format."""

import json
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.progress import track

console = Console()


class WordExporter:
    """Export word data to Medoru seed format."""
    
    def __init__(self):
        pass
    
    def export_words(
        self,
        words: list[dict],
        output_path: str,
        kanji_mapping: Optional[dict] = None,
        source: str = "JMdict",
        license: str = "CC BY-SA 4.0",
        copyright: str = "© EDRG",
        attribution: str = "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"
    ) -> bool:
        """Export word list to Medoru JSON format.
        
        Args:
            words: List of word dictionaries from JMdict
            output_path: Path to output JSON file
            kanji_mapping: Optional dict mapping kanji characters to their readings
            source: Data source name
            license: License information
            copyright: Copyright notice
            attribution: Attribution URL
            
        Returns:
            True if successful
        """
        try:
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Transform words to Medoru format
            medoru_words = []
            
            for word in track(words, description="Processing words..."):
                medoru_word = self._transform_to_medoru_format(word, kanji_mapping)
                if medoru_word:
                    medoru_words.append(medoru_word)
            
            # Build output structure
            output_data = {
                "_meta": {
                    "source": source,
                    "license": license,
                    "copyright": copyright,
                    "attribution": attribution,
                    "count": len(medoru_words)
                },
                "words": medoru_words
            }
            
            # Write to file
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(output_data, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {len(medoru_words)} words to {output_path}")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting words: {e}")
            return False
    
    def export_words_by_kanji(
        self,
        words_by_kanji: dict[str, list[dict]],
        output_path: str,
        kanji_mapping: Optional[dict] = None,
        source: str = "JMdict",
        license: str = "CC BY-SA 4.0",
        copyright: str = "© EDRG",
        attribution: str = "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"
    ) -> bool:
        """Export words organized by kanji to Medoru JSON format.
        
        Args:
            words_by_kanji: Dict mapping kanji to list of words
            output_path: Path to output JSON file
            kanji_mapping: Optional dict mapping kanji characters to their readings
            source: Data source name
            license: License information
            copyright: Copyright notice
            attribution: Attribution URL
            
        Returns:
            True if successful
        """
        try:
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Transform words for each kanji
            medoru_data = {}
            total_words = 0
            
            for kanji, words in words_by_kanji.items():
                medoru_words = []
                for word in words:
                    medoru_word = self._transform_to_medoru_format(word, kanji_mapping)
                    if medoru_word:
                        medoru_words.append(medoru_word)
                
                if medoru_words:
                    medoru_data[kanji] = medoru_words
                    total_words += len(medoru_words)
            
            # Build output structure
            output_data = {
                "_meta": {
                    "source": source,
                    "license": license,
                    "copyright": copyright,
                    "attribution": attribution,
                    "kanji_count": len(medoru_data),
                    "total_words": total_words
                },
                "words_by_kanji": medoru_data
            }
            
            # Write to file
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(output_data, f, ensure_ascii=False, indent=2)
            
            console.print(f"[green]✓[/green] Exported {total_words} words for {len(medoru_data)} kanji to {output_path}")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting words: {e}")
            return False
    
    def _transform_to_medoru_format(
        self,
        word: dict,
        kanji_mapping: Optional[dict] = None
    ) -> Optional[dict]:
        """Transform JMdict entry to Medoru word format.
        
        Args:
            word: JMdict word entry
            kanji_mapping: Dict mapping kanji chars to their reading info
            
        Returns:
            Transformed word dict or None if should be skipped
        """
        try:
            # Get primary kanji form (prefer first one with kanji)
            kanji_forms = word.get("kanji_forms", [])
            if not kanji_forms:
                # Skip kana-only words for now (could be supported later)
                return None
            
            text = kanji_forms[0]
            
            # Get primary reading
            readings = word.get("readings", [])
            if not readings:
                return None
            
            # Find reading that applies to our text
            primary_reading = None
            for r in readings:
                if r["applies_to"] is None or text in r["applies_to"]:
                    primary_reading = r["reading"]
                    break
            
            if not primary_reading:
                primary_reading = readings[0]["reading"]
            
            # Get primary meaning from first sense
            senses = word.get("senses", [])
            if not senses:
                return None
            
            primary_meaning = senses[0]["glosses"][0] if senses[0]["glosses"] else ""
            
            # Get all meanings
            all_meanings = []
            for sense in senses:
                all_meanings.extend(sense.get("glosses", []))
            
            # Get part of speech
            all_pos = []
            for sense in senses:
                all_pos.extend(sense.get("pos", []))
            all_pos = list(set(all_pos))  # Deduplicate
            
            # Build kanji breakdown if we have kanji mapping
            kanji_breakdown = []
            if kanji_mapping:
                for i, char in enumerate(text):
                    if char in kanji_mapping:
                        # Try to find which reading of this kanji is used
                        kanji_info = kanji_mapping[char]
                        kanji_breakdown.append({
                            "character": char,
                            "position": i,
                            "reading": None  # Will be populated by caller if matched
                        })
            
            # Calculate difficulty (placeholder - could use JLPT or frequency)
            difficulty = self._estimate_difficulty(word, kanji_mapping)
            
            # Usage frequency (placeholder)
            usage_frequency = 50  # Default mid-range
            
            return {
                "text": text,
                "meaning": primary_meaning,
                "readings": all_meanings,
                "reading": primary_reading,
                "difficulty": difficulty,
                "usage_frequency": usage_frequency,
                "pos": all_pos,
                "kanji": kanji_breakdown
            }
            
        except Exception as e:
            console.print(f"[yellow]Warning:[/yellow] Error transforming word: {e}")
            return None
    
    def _estimate_difficulty(
        self,
        word: dict,
        kanji_mapping: Optional[dict] = None
    ) -> int:
        """Estimate word difficulty (1-100 scale).
        
        Args:
            word: JMdict word entry
            kanji_mapping: Dict with kanji info including JLPT levels
            
        Returns:
            Difficulty score (1-100, lower = easier)
        """
        # Base difficulty
        difficulty = 50
        
        kanji_forms = word.get("kanji_forms", [])
        if kanji_forms:
            text = kanji_forms[0]
            kanji_count = sum(1 for c in text if self._is_kanji(c))
            
            # Adjust based on kanji count
            if kanji_count == 1:
                difficulty -= 20
            elif kanji_count == 2:
                difficulty -= 10
            elif kanji_count >= 4:
                difficulty += 10
            
            # Adjust based on kanji JLPT levels if available
            if kanji_mapping:
                total_level = 0
                counted = 0
                for char in text:
                    if char in kanji_mapping:
                        kanji_info = kanji_mapping[char]
                        if isinstance(kanji_info, dict) and "jlpt_level" in kanji_info:
                            # N5=5 (easiest), N1=1 (hardest) - invert for scoring
                            jlpt = kanji_info.get("jlpt_level")
                            if jlpt:
                                total_level += (6 - jlpt) * 20  # N5=100, N4=80, ..., N1=20
                                counted += 1
                
                if counted > 0:
                    kanji_difficulty = total_level / counted
                    difficulty = (difficulty + kanji_difficulty) / 2
        
        return max(1, min(100, int(difficulty)))
    
    def _is_kanji(self, char: str) -> bool:
        """Check if character is a CJK Unified Ideograph."""
        if not char or len(char) != 1:
            return False
        
        codepoint = ord(char)
        # Main CJK range: U+4E00 to U+9FFF
        # Extension A: U+3400 to U+4DBF
        return (0x4E00 <= codepoint <= 0x9FFF) or (0x3400 <= codepoint <= 0x4DBF)
