"""JMdict data spider for downloading and parsing Japanese word dictionary."""

import gzip
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from tqdm import tqdm

from ..config import HTTP_TIMEOUT, RAW_DIR, SOURCES, N5_KANJI_LIST, N4_KANJI_LIST

console = Console()

# POS tag mapping from JMdict to Medoru word_type
POS_MAPPING = {
    # Nouns
    "noun (common) (futsuumeishi)": "noun",
    "noun, used as a prefix": "noun", 
    "noun, used as a suffix": "noun",
    "nouns which may take the genitive case particle 'no'": "noun",
    "noun or participle which takes the aux. verb suru": "noun",
    "noun or verb acting prenominally": "noun",
    "proper noun": "noun",
    "pronoun": "pronoun",
    "numeric": "counter",
    "counter": "counter",
    
    # Verbs
    "Godan verb": "verb",
    "Godan verb - -aru special class": "verb",
    "Godan verb with 'bu' ending": "verb",
    "Godan verb with 'gu' ending": "verb",
    "Godan verb with 'ku' ending": "verb",
    "Godan verb with 'mu' ending": "verb",
    "Godan verb with 'nu' ending": "verb",
    "Godan verb with 'ru' ending": "verb",
    "Godan verb with 'ru' ending (irregular verb)": "verb",
    "Godan verb with 'su' ending": "verb",
    "Godan verb with 'tsu' ending": "verb",
    "Godan verb with 'u' ending": "verb",
    "Godan verb with 'u' ending (special class)": "verb",
    "Godan verb - Iku/Yuku special class": "verb",
    "Ichidan verb": "verb",
    "Ichidan verb - zuru verb (alternative form of -jiru verbs)": "verb",
    "Ichidan verb - kureru special class": "verb",
    "Kuru verb - special class": "verb",
    "irregular nu verb": "verb",
    "irregular ru verb, plain form ends with -ri": "verb",
    "su verb - precursor to the modern suru": "verb",
    "noun or participle which takes the aux. verb suru": "verb",
    "sur verb - precursor to the modern suru": "verb",
    "transitive verb": "verb",
    "intransitive verb": "verb",
    "auxiliary verb": "verb",
    
    # Adjectives
    "adjective (keiyoushi)": "adjective",
    "adjective (keiyoushi) - yoi/ii class": "adjective",
    "adjectival nouns or quasi-adjectives (keiyodoshi)": "adjective",
    "'taru' adjective": "adjective",
    "archaic/formal form of na-adjective": "adjective",
    "pre-noun adjectival (rentaishi)": "adjective",
    "auxiliary adjective": "adjective",
    
    # Adverbs
    "adverb (fukushi)": "adverb",
    "adverb taking the 'to' particle": "adverb",
    "adverbial noun (fukushitekimeishi)": "adverb",
    
    # Particles/Conjunctions
    "particle": "particle",
    "conjunction": "particle",
    "copula": "particle",
    
    # Expressions
    "expressions (phrases, clauses, etc.)": "expression",
    "interjection (kandoushi)": "expression",
    "auxiliary": "other",
    "unclassified": "other",
}


class JMdictSpider:
    """Spider for downloading and parsing JMdict word dictionary data."""
    
    def __init__(self):
        self.source = SOURCES["jmdict"]
        self.raw_dir = RAW_DIR / "jmdict"
        self.xml_path = self.raw_dir / "JMdict_e"
        
    def download(self, force: bool = False) -> bool:
        """Download JMdict data from EDRG.
        
        Args:
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        if self.xml_path.exists() and not force:
            console.print("[green]✓[/green] JMdict data already downloaded")
            return True
        
        url = self.source["download_url"]
        gz_path = self.raw_dir / "JMdict_e.gz"
        
        console.print(f"[blue]Downloading JMdict from {url}...[/blue]")
        
        try:
            # Download with progress bar
            response = requests.get(url, timeout=HTTP_TIMEOUT, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get("content-length", 0))
            
            self.raw_dir.mkdir(parents=True, exist_ok=True)
            
            with open(gz_path, "wb") as f:
                with tqdm(total=total_size, unit="B", unit_scale=True) as pbar:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            pbar.update(len(chunk))
            
            console.print("[green]✓[/green] Download complete, extracting...")
            
            # Extract gzip
            with gzip.open(gz_path, "rb") as gz_file:
                with open(self.xml_path, "wb") as xml_file:
                    xml_file.write(gz_file.read())
            
            # Clean up gzip file
            gz_path.unlink()
            
            console.print(f"[green]✓[/green] Extraction complete")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error downloading JMdict: {e}")
            return False
    
    def parse_entry(self, entry_element: ET.Element) -> Optional[dict]:
        """Parse a single word entry from JMdict XML.
        
        Args:
            entry_element: The <entry> XML element
            
        Returns:
            Dictionary with word data or None if error/skip
        """
        try:
            # Get entry sequence number (unique ID)
            ent_seq_elem = entry_element.find("ent_seq")
            ent_seq = ent_seq_elem.text if ent_seq_elem is not None else None
            
            # Get k_ele (kanji elements) - words can have multiple kanji writings
            kanji_forms = []
            for k_ele in entry_element.findall("k_ele"):
                keb = k_ele.find("keb")
                if keb is not None:
                    kanji_forms.append(keb.text)
            
            # Get r_ele (reading elements) - kana readings
            readings = []
            for r_ele in entry_element.findall("r_ele"):
                reb = r_ele.find("reb")
                if reb is not None:
                    # Check for restricted readings (only apply to specific kanji forms)
                    re_restr = [r.text for r in r_ele.findall("re_restr")]
                    readings.append({
                        "reading": reb.text,
                        "applies_to": re_restr if re_restr else None  # None means applies to all
                    })
            
            # Get sense elements (meanings, POS, etc.)
            senses = []
            for sense in entry_element.findall("sense"):
                # Part of speech
                pos_list = [pos.text for pos in sense.findall("pos")]
                
                # Field (domain-specific terms)
                field_list = [field.text for field in sense.findall("field")]
                
                # Gloss (meanings in English)
                glosses = []
                for gloss in sense.findall("gloss"):
                    # Only include English glosses (xml:lang="eng" or no lang attribute)
                    lang = gloss.get("{http://www.w3.org/XML/1998/namespace}lang")
                    if lang is None or lang == "eng":
                        glosses.append(gloss.text)
                
                # Example sentences (if present)
                examples = []
                for example in sense.findall("example"):
                    ex_text = example.find("ex_text")
                    ex_sent = example.find("ex_sent")
                    if ex_text is not None and ex_sent is not None:
                        examples.append({
                            "japanese": ex_sent.text,
                            "english": ex_text.text
                        })
                
                if glosses:  # Only add sense if it has glosses
                    senses.append({
                        "pos": pos_list,
                        "field": field_list,
                        "glosses": glosses,
                        "examples": examples
                    })
            
            # Skip entries without any valid senses
            if not senses:
                return None
            
            # Get JLPT level from miscellaneous info (if available)
            # Note: JMdict doesn't have official JLPT levels, but may have tags
            misc_info = []
            for misc in entry_element.iter("misc"):
                misc_info.append(misc.text)
            
            return {
                "ent_seq": ent_seq,
                "kanji_forms": kanji_forms,
                "readings": readings,
                "senses": senses,
                "misc": misc_info
            }
            
        except Exception as e:
            console.print(f"[red]Error parsing entry {ent_seq}: {e}[/red]")
            return None
    
    def parse_entry_for_seeding(self, entry_element: ET.Element, kanji_mapping: Optional[dict] = None) -> Optional[dict]:
        """Parse entry in format compatible with Medoru database seeding.
        
        Args:
            entry_element: XML entry element from JMdict
            kanji_mapping: Optional dict mapping kanji chars to their reading info
            
        Returns format matching priv/repo/seeds/words_n5.json structure.
        """
        try:
            # Get k_ele (kanji elements)
            kanji_forms = []
            for k_ele in entry_element.findall("k_ele"):
                keb = k_ele.find("keb")
                if keb is not None:
                    kanji_forms.append(keb.text)
            
            # Skip kana-only words
            if not kanji_forms:
                return None
            
            text = kanji_forms[0]  # Use first kanji form as primary
            
            # Get readings
            readings = []
            for r_ele in entry_element.findall("r_ele"):
                reb = r_ele.find("reb")
                if reb is not None:
                    readings.append(reb.text)
            
            if not readings:
                return None
            
            primary_reading = readings[0]
            
            # Get primary meaning and POS tags
            senses = []
            all_pos_tags = []
            for sense in entry_element.findall("sense"):
                glosses = []
                for gloss in sense.findall("gloss"):
                    lang = gloss.get("{http://www.w3.org/XML/1998/namespace}lang")
                    if lang is None or lang == "eng":
                        glosses.append(gloss.text)
                
                # Collect POS tags
                pos_tags = [pos.text for pos in sense.findall("pos") if pos.text]
                all_pos_tags.extend(pos_tags)
                
                if glosses:
                    senses.append(glosses)
            
            if not senses:
                return None
            
            primary_meaning = senses[0][0]
            
            # Truncate very long meanings (database limit is 255 chars)
            if primary_meaning and len(primary_meaning) > 250:
                primary_meaning = primary_meaning[:247] + "..."
            
            # Determine word type from POS tags
            word_type = self._determine_word_type(all_pos_tags)
            
            # Build kanji breakdown with reading matching
            kanji_breakdown = []
            kanji_chars = []
            for i, char in enumerate(text):
                if self._is_cjk_kanji(char):
                    kanji_chars.append(char)
            
            # Match readings if kanji_mapping provided
            if kanji_mapping:
                kanji_breakdown = self._match_kanji_readings(text, primary_reading, kanji_chars, kanji_mapping)
            else:
                # Without mapping, just create basic breakdown
                for i, char in enumerate(text):
                    if self._is_cjk_kanji(char):
                        kanji_breakdown.append({
                            "character": char,
                            "position": i,
                            "reading": ""
                        })
            
            # Skip if no actual CJK kanji found
            if not kanji_breakdown:
                return None
            
            # Calculate JLPT level based on kanji composition
            jlpt_level = self._calculate_jlpt_level(kanji_chars)
            
            # Map JLPT level to difficulty (1-5 scale)
            # N5=1 (easiest), N1=5 (hardest)
            difficulty = jlpt_level if jlpt_level else 3
            
            return {
                "text": text,
                "meaning": primary_meaning,
                "reading": primary_reading,
                "difficulty": difficulty,
                "usage_frequency": 1000,  # Default
                "word_type": word_type,
                "kanji": kanji_breakdown
            }
            
        except Exception as e:
            return None
    
    def _match_kanji_readings(self, text: str, word_reading: str, kanji_chars: list[str], kanji_mapping: dict) -> list[dict]:
        """Match specific kanji readings used in a word.
        
        Args:
            text: The kanji text of the word
            word_reading: The hiragana/katakana reading of the word
            kanji_chars: List of kanji characters in the word
            kanji_mapping: Dict mapping kanji to their reading info
            
        Returns:
            List of kanji breakdown dicts with matched readings
        """
        breakdown = []
        reading_pos = 0
        
        for i, char in enumerate(text):
            if not self._is_cjk_kanji(char):
                # Kana character - advance reading position
                if reading_pos < len(word_reading) and word_reading[reading_pos] == char:
                    reading_pos += 1
                continue
            
            kanji_info = kanji_mapping.get(char, {})
            readings = kanji_info.get("readings", [])
            
            matched_reading = ""
            
            if len(kanji_chars) == 1:
                # Single kanji word - try direct matching
                for kr in readings:
                    kr_text = kr.get("reading", "")
                    if word_reading == kr_text or word_reading.startswith(kr_text):
                        matched_reading = kr_text
                        break
            else:
                # Multi-kanji word - try matching from current position
                remaining = word_reading[reading_pos:]
                
                # Sort by length (longest first) for greedy matching
                sorted_readings = sorted(readings, key=lambda x: len(x.get("reading", "")), reverse=True)
                
                for kr in sorted_readings:
                    kr_text = kr.get("reading", "")
                    if remaining.startswith(kr_text):
                        matched_reading = kr_text
                        reading_pos += len(kr_text)
                        break
            
            breakdown.append({
                "character": char,
                "position": i,
                "reading": matched_reading
            })
        
        return breakdown
    
    def _determine_word_type(self, pos_tags: list[str]) -> str:
        """Determine word type from JMdict POS tags."""
        if not pos_tags:
            return "other"
        
        # Check each POS tag in order of priority
        for pos in pos_tags:
            # Try exact match first
            if pos in POS_MAPPING:
                return POS_MAPPING[pos]
            
            # Try prefix match for verb classifications
            for key, value in POS_MAPPING.items():
                if pos.startswith(key):
                    return value
        
        return "other"
    
    def _calculate_jlpt_level(self, kanji_chars: list[str]) -> int:
        """Calculate JLPT level based on kanji composition.
        
        Rules:
        - If all kanji are N5 -> N5 word (level 5, easiest)
        - If all kanji are N5 or N4 -> N4 word (level 4)
        - If kanji include N3 or unknown -> N3+ word (level 3)
        - Default to N3 (level 3) if unknown
        """
        if not kanji_chars:
            return 3
        
        n5_set = set(N5_KANJI_LIST)
        n4_set = set(N4_KANJI_LIST)
        
        # Check if all kanji are N5
        all_n5 = all(k in n5_set for k in kanji_chars)
        if all_n5:
            return 5  # N5 = level 5 (easiest)
        
        # Check if all kanji are N5 or N4
        all_n4_or_lower = all(k in n5_set or k in n4_set for k in kanji_chars)
        if all_n4_or_lower:
            return 4  # N4 = level 4
        
        # Default to N3 (level 3 - middle)
        return 3
    
    def _is_cjk_kanji(self, char: str) -> bool:
        """Check if character is a CJK Unified Ideograph (kanji)."""
        if not char or len(char) != 1:
            return False
        codepoint = ord(char)
        # Main CJK range: U+4E00 to U+9FFF
        # Extension A: U+3400 to U+4DBF
        return (0x4E00 <= codepoint <= 0x9FFF) or (0x3400 <= codepoint <= 0x4DBF)
    
    def extract_all_words(self, limit: Optional[int] = None) -> list[dict]:
        """Extract all words from JMdict XML.
        
        Args:
            limit: Optional limit on number of entries to extract
            
        Returns:
            List of word dictionaries
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
            return []
        
        console.print(f"[blue]Parsing JMdict XML...[/blue]")
        
        try:
            # Parse XML incrementally to handle large file
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            word_list = []
            in_entry = False
            current_entry = None
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Extracting word entries...", total=None)
                
                for event, elem in context:
                    if event == "start" and elem.tag == "entry":
                        in_entry = True
                        current_entry = elem
                    
                    elif event == "end" and elem.tag == "entry":
                        word_data = self.parse_entry(elem)
                        
                        if word_data:
                            word_list.append(word_data)
                        
                        # Clear element to free memory
                        elem.clear()
                        root.clear()
                        
                        # Update progress periodically
                        if len(word_list) % 1000 == 0:
                            progress.update(task, description=f"Extracted {len(word_list)} words...")
                        
                        # Check limit
                        if limit and len(word_list) >= limit:
                            break
                        
                        in_entry = False
                        current_entry = None
            
            console.print(f"[green]✓[/green] Extracted {len(word_list)} words")
            return word_list
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error parsing JMdict: {e}")
            return []
    
    def get_words_by_kanji(self, kanji_char: str) -> list[dict]:
        """Get all words that contain a specific kanji character.
        
        Args:
            kanji_char: Single kanji character to search for
            
        Returns:
            List of word dictionaries containing that kanji
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] JMdict data not downloaded.")
            return []
        
        console.print(f"[blue]Searching for words containing '{kanji_char}'...[/blue]")
        
        try:
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            word_list = []
            
            for event, elem in context:
                if event == "end" and elem.tag == "entry":
                    # Check if this entry contains the kanji in any k_ele
                    contains_kanji = False
                    for k_ele in elem.findall("k_ele"):
                        keb = k_ele.find("keb")
                        if keb is not None and kanji_char in keb.text:
                            contains_kanji = True
                            break
                    
                    if contains_kanji:
                        word_data = self.parse_entry(elem)
                        if word_data:
                            word_list.append(word_data)
                    
                    # Clear element
                    elem.clear()
                    root.clear()
            
            console.print(f"[green]✓[/green] Found {len(word_list)} words containing '{kanji_char}'")
            return word_list
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error searching JMdict: {e}")
            return []
    
    def get_words_for_kanji_list(self, kanji_list: list[str], max_per_kanji: int = 10) -> dict[str, list[dict]]:
        """Get words for a list of kanji characters.
        
        Args:
            kanji_list: List of kanji characters
            max_per_kanji: Maximum words to return per kanji
            
        Returns:
            Dictionary mapping kanji to list of words
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] JMdict data not downloaded.")
            return {}
        
        console.print(f"[blue]Extracting words for {len(kanji_list)} kanji...[/blue]")
        
        try:
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            kanji_set = set(kanji_list)
            results = {k: [] for k in kanji_list}
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Matching words to kanji...", total=None)
                
                for event, elem in context:
                    if event == "end" and elem.tag == "entry":
                        # Check which kanji from our list appear in this entry
                        matching_kanji = []
                        
                        for k_ele in elem.findall("k_ele"):
                            keb = k_ele.find("keb")
                            if keb is not None:
                                for kanji in kanji_set:
                                    if kanji in keb.text and kanji not in matching_kanji:
                                        # Check if we still need more words for this kanji
                                        if len(results[kanji]) < max_per_kanji:
                                            matching_kanji.append(kanji)
                        
                        if matching_kanji:
                            word_data = self.parse_entry(elem)
                            if word_data:
                                for kanji in matching_kanji:
                                    results[kanji].append(word_data)
                        
                        # Clear element
                        elem.clear()
                        root.clear()
                        
                        # Update progress
                        total_found = sum(len(v) for v in results.values())
                        if total_found % 100 == 0:
                            progress.update(task, description=f"Found {total_found} word matches...")
            
            total_words = sum(len(v) for v in results.values())
            console.print(f"[green]✓[/green] Extracted {total_words} words for {len(kanji_list)} kanji")
            return results
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error extracting words: {e}")
            return {}
    
    def export_words_for_seeding(self, kanji_list: list[str], max_per_kanji: int = 10, kanji_mapping: Optional[dict] = None) -> list[dict]:
        """Export words in format compatible with Medoru seeds.exs.
        
        This returns a flat list of word objects matching the structure of
        priv/repo/seeds/words_n5.json
        
        Args:
            kanji_list: List of kanji characters to find words for
            max_per_kanji: Maximum words per kanji
            kanji_mapping: Optional dict mapping kanji to their reading info for matching
            
        Returns:
            List of word dictionaries in seeding format
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] JMdict data not downloaded.")
            return []
        
        console.print(f"[blue]Exporting words for seeding ({len(kanji_list)} kanji)...[/blue]")
        
        try:
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            kanji_set = set(kanji_list)
            results = {k: [] for k in kanji_list}
            seen_words = set()  # Track unique words
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Finding words...", total=None)
                
                for event, elem in context:
                    if event == "end" and elem.tag == "entry":
                        # Parse entry in seeding format with reading matching
                        word_data = self.parse_entry_for_seeding(elem, kanji_mapping)
                        
                        if word_data and word_data["text"] not in seen_words:
                            text = word_data["text"]
                            
                            # Check which kanji this word contains
                            for kanji in kanji_set:
                                if kanji in text and len(results[kanji]) < max_per_kanji:
                                    results[kanji].append(word_data)
                                    seen_words.add(text)
                                    break
                        
                        # Clear element
                        elem.clear()
                        root.clear()
                        
                        # Update progress
                        total_found = sum(len(v) for v in results.values())
                        if total_found % 50 == 0:
                            progress.update(task, description=f"Found {total_found} words...")
                        
                        # Check if we have enough words for all kanji
                        if all(len(v) >= max_per_kanji for v in results.values()):
                            break
            
            # Flatten results to a single list
            all_words = []
            for kanji in kanji_list:
                all_words.extend(results[kanji])
            
            console.print(f"[green]✓[/green] Exported {len(all_words)} words for seeding")
            return all_words
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting words: {e}")
            return []
    
    def export_all_words_for_seeding(self, limit: Optional[int] = None, kanji_mapping: Optional[dict] = None) -> list[dict]:
        """Export ALL words from JMdict in seeding format.
        
        This exports all words with kanji (not kana-only) in the format
        compatible with Medoru database seeding.
        
        Args:
            limit: Optional limit on number of words to export
            kanji_mapping: Optional dict mapping kanji to their reading info for matching
            
        Returns:
            List of word dictionaries in seeding format
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] JMdict data not downloaded.")
            return []
        
        console.print(f"[blue]Exporting all words from JMdict...[/blue]")
        if limit:
            console.print(f"[dim]Limit: {limit} words[/dim]")
        
        try:
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            all_words = []
            seen_words = set()  # Track unique words by text
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Processing entries...", total=None)
                
                for ev, elem in context:
                    if ev == "end" and elem.tag == "entry":
                        # Parse entry in seeding format with reading matching
                        word_data = self.parse_entry_for_seeding(elem, kanji_mapping)
                        
                        if word_data:
                            text = word_data["text"]
                            # Only add if we haven't seen this word before
                            if text not in seen_words:
                                all_words.append(word_data)
                                seen_words.add(text)
                        
                        # Clear element to free memory
                        elem.clear()
                        root.clear()
                        
                        # Update progress periodically
                        if len(all_words) % 1000 == 0:
                            progress.update(task, description=f"Exported {len(all_words)} words...")
                        
                        # Check limit
                        if limit and len(all_words) >= limit:
                            break
            
            console.print(f"[green]✓[/green] Exported {len(all_words)} words for seeding")
            return all_words
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error exporting words: {e}")
            return []
    
    def get_stats(self) -> dict:
        """Get statistics about the JMdict data."""
        if not self.xml_path.exists():
            return {"downloaded": False}
        
        console.print("[blue]Analyzing JMdict data...[/blue]")
        
        try:
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            total_entries = 0
            with_kanji = 0
            kana_only = 0
            
            for event, elem in context:
                if event == "end" and elem.tag == "entry":
                    total_entries += 1
                    
                    # Check if entry has kanji forms
                    k_ele = elem.find("k_ele")
                    if k_ele is not None:
                        with_kanji += 1
                    else:
                        kana_only += 1
                    
                    # Clear element periodically to save memory
                    if total_entries % 10000 == 0:
                        elem.clear()
                        root.clear()
                    else:
                        elem.clear()
            
            return {
                "downloaded": True,
                "total_entries": total_entries,
                "with_kanji": with_kanji,
                "kana_only": kana_only
            }
            
        except Exception as e:
            console.print(f"[red]Error analyzing JMdict: {e}[/red]")
            return {"downloaded": True, "error": str(e)}
    
    def get_status(self) -> dict:
        """Get download status information."""
        downloaded = self.xml_path.exists()
        file_size = "0 B"
        
        if downloaded:
            size_bytes = self.xml_path.stat().st_size
            file_size = self._format_size(size_bytes)
        
        return {
            "downloaded": downloaded,
            "file_size": file_size,
            "source": self.source["name"],
            "license": self.source["license"],
        }
    
    def _format_size(self, size_bytes: int) -> str:
        """Format byte size to human readable."""
        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"
