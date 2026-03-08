"""Make Me A Hanzi spider for downloading kanji data with radicals and decomposition.

This spider fetches from the makemeahanzi database which provides:
- Radical information
- Character decomposition
- Definitions
- Etymology

Data source: https://github.com/skishore/makemeahanzi
License: CC BY-SA 4.0 (derived from TW-Sung fonts)
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


class MakeMeAHanziSpider:
    """Spider for downloading Make Me A Hanzi data with radicals."""
    
    DICTIONARY_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt"
    STROKES_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"
    
    def __init__(self):
        self.raw_dir = RAW_DIR / "makemeahanzi"
        self.dict_path = self.raw_dir / "dictionary.txt"
        self.strokes_path = self.raw_dir / "graphics.txt"
        
    def download(self, force: bool = False) -> bool:
        """Download Make Me A Hanzi data from GitHub.
        
        Args:
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        if self.dict_path.exists() and self.strokes_path.exists() and not force:
            console.print("[green]✓[/green] Make Me A Hanzi data already downloaded")
            return True
        
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        
        # Download dictionary
        success = self._download_file(self.DICTIONARY_URL, self.dict_path)
        if not success:
            return False
            
        # Download strokes (optional but useful)
        self._download_file(self.STROKES_URL, self.strokes_path)
        
        return True
    
    def _download_file(self, url: str, output_path: Path) -> bool:
        """Download a single file."""
        console.print(f"[blue]Downloading from {url}...[/blue]")
        
        try:
            response = requests.get(url, timeout=HTTP_TIMEOUT, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get("content-length", 0))
            
            with open(output_path, "wb") as f:
                with tqdm(total=total_size, unit="B", unit_scale=True) as pbar:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            pbar.update(len(chunk))
            
            console.print(f"[green]✓[/green] Downloaded to {output_path}")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error downloading: {e}")
            return False
    
    def load_dictionary(self) -> dict:
        """Load the dictionary data.
        
        Returns:
            Dictionary mapping kanji characters to their data
        """
        if not self.dict_path.exists():
            console.print("[red]Error:[/red] Dictionary not downloaded. Run 'medoru-data makemeahanzi download' first.")
            return {}
        
        result = {}
        
        with open(self.dict_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    char = data.get("character")
                    if char:
                        result[char] = data
                except json.JSONDecodeError:
                    continue
        
        return result
    
    def get_kanji_with_radicals(self, characters: list[str]) -> list[dict]:
        """Get radical data for specific kanji characters.
        
        Args:
            characters: List of kanji characters
            
        Returns:
            List of kanji data with radicals
        """
        data = self.load_dictionary()
        result = []
        
        for char in characters:
            if char in data:
                kanji_data = data[char]
                result.append({
                    "character": char,
                    "radical": kanji_data.get("radical"),
                    "definition": kanji_data.get("definition"),
                    "decomposition": kanji_data.get("decomposition"),
                    "etymology": kanji_data.get("etymology"),
                })
        
        return result
    
    def get_radical_for_kanji(self, character: str) -> Optional[str]:
        """Get the main radical for a single kanji.
        
        Args:
            character: Kanji character
            
        Returns:
            Radical character or None
        """
        data = self.load_dictionary()
        
        if character in data:
            return data[character].get("radical")
        
        return None
    
    def get_status(self) -> dict:
        """Get download status information."""
        downloaded = self.dict_path.exists()
        file_size = "0 B"
        kanji_count = 0
        
        if downloaded:
            size_bytes = self.dict_path.stat().st_size
            file_size = self._format_size(size_bytes)
            
            # Count kanji (approximate by line count)
            try:
                with open(self.dict_path, "r", encoding="utf-8") as f:
                    kanji_count = sum(1 for line in f if line.strip())
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
