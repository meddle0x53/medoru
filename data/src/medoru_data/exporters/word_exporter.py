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
            kanji_mapping: Optional dict mapping kanji characters to their reading info
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
            kanji_mapping: Optional dict mapping kanji characters to their reading info
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
            
            # Transform words
            medoru_data = {}
            total_words = 0
            
            for kanji, words in track(words_by_kanji.items(), description="Processing words by kanji..."):
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
            
            # Build kanji breakdown with reading matching
            kanji_breakdown = []
            if kanji_mapping:
                kanji_breakdown = self._build_kanji_breakdown(text, primary_reading, kanji_mapping)
            
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
    
    def _build_kanji_breakdown(
        self,
        text: str,
        reading: str,
        kanji_mapping: dict
    ) -> list[dict]:
        """Build kanji breakdown with reading matching.
        
        For each kanji in the word, tries to determine which specific reading
        is used based on the word's reading.
        
        Args:
            text: Kanji text of the word
            reading: Hiragana reading of the word
            kanji_mapping: Dict mapping kanji to their reading info
            
        Returns:
            List of kanji breakdown dicts with reading info
        """
        breakdown = []
        reading_pos = 0  # Current position in the reading string
        
        for i, char in enumerate(text):
            if char not in kanji_mapping:
                # Kana character - advance reading position
                if reading_pos < len(reading) and reading[reading_pos] == char:
                    reading_pos += 1
                continue
            
            kanji_info = kanji_mapping[char]
            kanji_readings = kanji_info.get("readings", [])
            
            # Try to find which reading matches
            matched_reading = None
            
            # For single-kanji words, the reading should directly match
            if len([c for c in text if c in kanji_mapping]) == 1:
                # Single kanji word - try to match reading directly
                for kr in kanji_readings:
                    if kr["reading"] == reading:
                        matched_reading = kr["reading"]
                        break
                    # Also check without trailing kana (okurigana)
                    if reading.startswith(kr["reading"]):
                        matched_reading = kr["reading"]
                        break
            else:
                # Multi-kanji word - more complex matching needed
                # For now, try simple prefix matching from current position
                remaining_reading = reading[reading_pos:]
                
                # Sort readings by length (longest first) to match greedily
                sorted_readings = sorted(kanji_readings, key=lambda x: len(x["reading"]), reverse=True)
                
                for kr in sorted_readings:
                    kr_text = kr["reading"]
                    # Check if this reading appears at current position
                    if remaining_reading.startswith(kr_text):
                        matched_reading = kr_text
                        reading_pos += len(kr_text)
                        break
                    # Handle rendaku (voicing changes) - basic support
                    # This is a simplified check
                    if kr["reading_type"] == "kun":
                        # Try without checking for now - will need more sophisticated logic
                        pass
            
            breakdown.append({
                "character": char,
                "position": i,
                "reading": matched_reading  # May be None if not matched
            })
        
        return breakdown
    
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
        
        # Adjust based on kanji JLPT levels if available
        kanji_forms = word.get("kanji_forms", [])
        if kanji_forms and kanji_mapping:
            jlpt_levels = []
            for char in kanji_forms[0]:
                if char in kanji_mapping:
                    level = kanji_mapping[char].get("jlpt_level")
                    if level:
                        jlpt_levels.append(level)
            
            if jlpt_levels:
                # Average JLPT level (N5=5, N1=1)
                avg_level = sum(jlpt_levels) / len(jlpt_levels)
                # Convert to difficulty (N5 = easier = lower difficulty)
                difficulty = 100 - (avg_level * 20) + 10
                difficulty = max(1, min(100, difficulty))
        
        # Adjust based on word frequency if available
        priority = word.get("priority", [])
        if priority:
            # Common words are easier
            difficulty -= 10
        
        # Adjust based on word length
        if kanji_forms:
            length = len(kanji_forms[0])
            if length <= 2:
                difficulty -= 5
            elif length >= 4:
                difficulty += 10
        
        return max(1, min(100, difficulty))
