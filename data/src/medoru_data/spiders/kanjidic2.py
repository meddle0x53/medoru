"""KANJIDIC2 data spider for downloading and parsing kanji metadata."""

import gzip
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from tqdm import tqdm

from ..config import HTTP_TIMEOUT, RAW_DIR, SOURCES

console = Console()


class Kanjidic2Spider:
    """Spider for downloading and parsing KANJIDIC2 data."""
    
    def __init__(self):
        self.source = SOURCES["kanjidic2"]
        self.raw_dir = RAW_DIR / "kanjidic2"
        self.xml_path = self.raw_dir / "kanjidic2.xml"
        
    def download(self, force: bool = False) -> bool:
        """Download KANJIDIC2 data from EDRG.
        
        Args:
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        if self.xml_path.exists() and not force:
            console.print("[green]✓[/green] KANJIDIC2 data already downloaded")
            return True
        
        url = self.source["download_url"]
        gz_path = self.raw_dir / "kanjidic2.xml.gz"
        
        console.print(f"[blue]Downloading KANJIDIC2 from {url}...[/blue]")
        
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
            console.print(f"[red]✗[/red] Error downloading KANJIDIC2: {e}")
            return False
    
    def parse_kanji(self, character_element: ET.Element) -> Optional[dict]:
        """Parse a single kanji entry from KANJIDIC2 XML.
        
        Args:
            character_element: The <character> XML element
            
        Returns:
            Dictionary with kanji data or None if error
        """
        try:
            # Get the kanji character (literal)
            literal_elem = character_element.find("literal")
            if literal_elem is None:
                return None
            
            character = literal_elem.text
            
            # Skip non-kanji characters (hiragana, katakana, etc.)
            if not self._is_kanji(character):
                return None
            
            # Get codepoint info
            codepoint_elem = character_element.find("codepoint")
            ucs_code = None
            if codepoint_elem is not None:
                for cp in codepoint_elem.findall("cp_value"):
                    if cp.get("cp_type") == "ucs":
                        ucs_code = cp.text
                        break
            
            # Get radical info
            radical_elem = character_element.find("radical")
            radicals = []
            if radical_elem is not None:
                for rad in radical_elem.findall("rad_value"):
                    if rad.get("rad_type") == "classical":
                        radicals.append(rad.text)
            
            # Get misc info (stroke count, JLPT, frequency)
            misc_elem = character_element.find("misc")
            stroke_count = None
            jlpt_level = None
            frequency = None
            
            if misc_elem is not None:
                stroke_count_elem = misc_elem.find("stroke_count")
                if stroke_count_elem is not None:
                    stroke_count = int(stroke_count_elem.text)
                
                jlpt_elem = misc_elem.find("jlpt")
                if jlpt_elem is not None:
                    jlpt_level = int(jlpt_elem.text)
                
                freq_elem = misc_elem.find("freq")
                if freq_elem is not None:
                    frequency = int(freq_elem.text)
            
            # Skip if missing essential data
            if stroke_count is None:
                return None
            
            # Get readings and meanings
            reading_meaning_elem = character_element.find("reading_meaning")
            meanings = []
            on_readings = []
            kun_readings = []
            
            if reading_meaning_elem is not None:
                # Get meanings (English)
                for rmgroup in reading_meaning_elem.findall("rmgroup"):
                    for meaning in rmgroup.findall("meaning"):
                        # Skip meanings with m_lang attribute (non-English)
                        if meaning.get("m_lang") is None:
                            meanings.append(meaning.text)
                    
                    # Get readings
                    for reading in rmgroup.findall("reading"):
                        r_type = reading.get("r_type")
                        if r_type == "ja_on":
                            on_readings.append(reading.text)
                        elif r_type == "ja_kun":
                            kun_readings.append(reading.text)
                
                # Also check for nanori readings (name readings) - optional
                nanori_readings = []
                for nanori in reading_meaning_elem.findall("nanori"):
                    nanori_readings.append(nanori.text)
            
            return {
                "character": character,
                "ucs_code": ucs_code,
                "meanings": meanings,
                "stroke_count": stroke_count,
                "jlpt_level": jlpt_level,
                "frequency": frequency,
                "radicals": radicals,
                "readings": {
                    "on": on_readings,
                    "kun": kun_readings,
                }
            }
            
        except Exception as e:
            console.print(f"[red]Error parsing kanji: {e}[/red]")
            return None
    
    def extract_all_kanji(self, filter_jlpt: bool = True) -> list[dict]:
        """Extract all kanji from KANJIDIC2 XML.
        
        Args:
            filter_jlpt: If True, only return kanji with JLPT levels (N1-N5)
            
        Returns:
            List of kanji dictionaries
        """
        if not self.xml_path.exists():
            console.print("[red]Error:[/red] KANJIDIC2 data not downloaded. Run 'medoru-data kanjidic2 download' first.")
            return []
        
        console.print(f"[blue]Parsing KANJIDIC2 XML...[/blue]")
        
        try:
            # Parse XML incrementally to handle large file
            context = ET.iterparse(str(self.xml_path), events=("start", "end"))
            context = iter(context)
            event, root = next(context)
            
            kanji_list = []
            current_character = None
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Extracting kanji data...", total=None)
                
                for event, elem in context:
                    if event == "end" and elem.tag == "character":
                        kanji_data = self.parse_kanji(elem)
                        
                        if kanji_data:
                            # Filter by JLPT if requested
                            if not filter_jlpt or kanji_data["jlpt_level"] is not None:
                                kanji_list.append(kanji_data)
                        
                        # Clear element to free memory
                        elem.clear()
                        root.clear()
                        
                        # Update progress periodically
                        if len(kanji_list) % 100 == 0:
                            progress.update(task, description=f"Extracted {len(kanji_list)} kanji...")
            
            console.print(f"[green]✓[/green] Extracted {len(kanji_list)} kanji")
            return kanji_list
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error parsing KANJIDIC2: {e}")
            return []
    
    def get_kanji_by_level(self, level: int) -> list[dict]:
        """Get kanji filtered by JLPT level.
        
        Args:
            level: JLPT level (1-4 for old JLPT, 5 is not in KANJIDIC2)
            
        Returns:
            List of kanji dictionaries for that level
        """
        all_kanji = self.extract_all_kanji(filter_jlpt=False)
        return [k for k in all_kanji if k["jlpt_level"] == level]
    
    def get_kanji_by_characters(self, characters: list[str]) -> list[dict]:
        """Get kanji data for specific characters.
        
        Args:
            characters: List of kanji characters to look up
            
        Returns:
            List of kanji dictionaries found
        """
        all_kanji = self.extract_all_kanji(filter_jlpt=False)
        char_set = set(characters)
        return [k for k in all_kanji if k["character"] in char_set]
    
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
    
    def _is_kanji(self, char: Optional[str]) -> bool:
        """Check if character is a CJK Unified Ideograph."""
        if not char or len(char) != 1:
            return False
        
        codepoint = ord(char)
        # Main CJK range: U+4E00 to U+9FFF
        # Extension A: U+3400 to U+4DBF
        return (0x4E00 <= codepoint <= 0x9FFF) or (0x3400 <= codepoint <= 0x4DBF)
    
    def _format_size(self, size_bytes: int) -> str:
        """Format byte size to human readable."""
        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"
