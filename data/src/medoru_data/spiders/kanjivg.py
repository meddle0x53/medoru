"""KanjiVG data spider for downloading and extracting stroke data."""

import json
import os
import re
import shutil
import zipfile
from pathlib import Path
from typing import Optional
from xml.etree import ElementTree as ET

import requests
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from tqdm import tqdm

from ..config import HTTP_TIMEOUT, N5_KANJI, RAW_DIR, SOURCES

console = Console()


class KanjiVGSpider:
    """Spider for downloading and parsing KanjiVG data."""
    
    KVG_NS = "http://kanjivg.tagaini.net"
    SVG_NS = "http://www.w3.org/2000/svg"
    
    def __init__(self):
        self.source = SOURCES["kanjivg"]
        self.raw_dir = RAW_DIR / "kanjivg"
        self.kanji_dir = self.raw_dir / "kanji"
        
    def download(self, force: bool = False) -> bool:
        """Download KanjiVG data from GitHub.
        
        Args:
            force: Force re-download even if already exists
            
        Returns:
            True if successful, False otherwise
        """
        if self.kanji_dir.exists() and not force:
            console.print("[green]✓[/green] KanjiVG data already downloaded")
            return True
        
        url = self.source["download_url"]
        zip_path = self.raw_dir / "kanjivg.zip"
        
        # Ensure directories exist
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        
        console.print(f"[blue]Downloading KanjiVG from {url}...[/blue]")
        
        try:
            # Download with progress bar
            response = requests.get(url, timeout=HTTP_TIMEOUT, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get("content-length", 0))
            
            with open(zip_path, "wb") as f:
                with tqdm(total=total_size, unit="B", unit_scale=True) as pbar:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            pbar.update(len(chunk))
            
            console.print("[green]✓[/green] Download complete, extracting...")
            
            # Extract
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(self.raw_dir)
            
            # Move files from nested directory
            extracted_dir = self.raw_dir / "kanjivg-master"
            if extracted_dir.exists():
                kanji_source = extracted_dir / "kanji"
                if kanji_source.exists():
                    shutil.move(str(kanji_source), str(self.kanji_dir))
                shutil.rmtree(extracted_dir)
            
            # Clean up zip
            zip_path.unlink()
            
            console.print(f"[green]✓[/green] Extraction complete: {len(list(self.kanji_dir.glob('*.svg')))} files")
            return True
            
        except Exception as e:
            console.print(f"[red]✗[/red] Error downloading KanjiVG: {e}")
            return False
    
    def get_kanji_list(self, level: str = "N5") -> list[str]:
        """Get list of kanji for specified JLPT level.
        
        Args:
            level: JLPT level (N5, N4, N3, N2, N1, or 'all')
            
        Returns:
            List of kanji characters
        """
        if level.upper() == "N5":
            return list(N5_KANJI)
        elif level.upper() == "ALL":
            # Return all available kanji
            if not self.kanji_dir.exists():
                return []
            kanji = []
            for svg_file in self.kanji_dir.glob("*.svg"):
                hex_code = svg_file.stem
                try:
                    char = chr(int(hex_code, 16))
                    kanji.append(char)
                except ValueError:
                    continue
            return kanji
        else:
            # For now, only N5 is implemented
            console.print(f"[yellow]Warning:[/yellow] Level {level} not implemented, using N5")
            return list(N5_KANJI)
    
    def extract_stroke(self, svg_path: Path) -> Optional[dict]:
        """Extract stroke data from a KanjiVG SVG file.
        
        Args:
            svg_path: Path to SVG file
            
        Returns:
            Dictionary with stroke data or None if error
        """
        try:
            tree = ET.parse(svg_path)
            root = tree.getroot()
        except ET.ParseError as e:
            console.print(f"[red]Error parsing {svg_path}: {e}[/red]")
            return None
        
        strokes = []
        stroke_number_positions = []
        
        # Find the StrokePaths group
        stroke_paths_group = None
        for g in root.iter(f"{{{self.SVG_NS}}}g"):
            gid = g.get("id", "")
            if "StrokePaths" in gid:
                stroke_paths_group = g
                break
        
        if stroke_paths_group is None:
            return None
        
        # Extract stroke paths
        for path in stroke_paths_group.iter():
            if path.tag == f"{{{self.SVG_NS}}}path":
                path_id = path.get("id", "")
                d = path.get("d", "")
                stroke_type = path.get(f"{{{self.KVG_NS}}}type", "")
                
                # Extract stroke number from ID (e.g., kvg:04e00-s1 -> 1)
                match = re.search(r"-s(\d+)$", path_id)
                if match and d:
                    stroke_num = int(match.group(1))
                    strokes.append({
                        "order": stroke_num,
                        "path": d,
                        "type": self._categorize_stroke_type(stroke_type),
                        "direction": self._infer_direction(d, stroke_type)
                    })
        
        # Sort by order
        strokes.sort(key=lambda x: x["order"])
        
        if not strokes:
            return None
        
        return {
            "bounds": {
                "width": 109,
                "height": 109,
                "viewBox": "0 0 109 109"
            },
            "strokes": strokes
        }
    
    def extract_strokes(self, kanji_list: list[str]) -> dict[str, dict]:
        """Extract stroke data for multiple kanji.
        
        Args:
            kanji_list: List of kanji characters
            
        Returns:
            Dictionary mapping kanji to stroke data
        """
        if not self.kanji_dir.exists():
            console.print("[red]Error:[/red] KanjiVG data not downloaded. Run 'medoru-data kanjivg download' first.")
            return {}
        
        result = {}
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Extracting stroke data...", total=len(kanji_list))
            
            for char in kanji_list:
                hex_code = f"{ord(char):05x}"
                svg_path = self.kanji_dir / f"{hex_code}.svg"
                
                if svg_path.exists():
                    data = self.extract_stroke(svg_path)
                    if data:
                        result[char] = data
                
                progress.advance(task)
        
        return result
    
    def get_status(self) -> dict:
        """Get download status information."""
        downloaded = self.kanji_dir.exists()
        total_files = len(list(self.kanji_dir.glob("*.svg"))) if downloaded else 0
        
        cache_size = "0 B"
        if downloaded:
            total_size = sum(f.stat().st_size for f in self.kanji_dir.glob("*.svg"))
            cache_size = self._format_size(total_size)
        
        return {
            "downloaded": downloaded,
            "total_files": total_files,
            "cache_size": cache_size
        }
    
    def _categorize_stroke_type(self, kvg_type: str) -> str:
        """Categorize KanjiVG stroke type."""
        if not kvg_type:
            return "unknown"
        
        # First character indicates stroke type
        stroke_map = {
            "㇐": "horizontal",
            "㇑": "vertical",
            "㇒": "diagonal",
            "㇏": "diagonal",
            "㇔": "dot",
            "㇀": "rising",
            "㇕": "corner",
            "㇆": "hook",
            "㇇": "corner",
            "㇂": "hook",
            "㇃": "hook",
            "㇄": "corner",
            "㇅": "corner",
            "㇈": "corner",
            "㇉": "corner",
            "㇊": "corner",
            "㇋": "corner",
            "㇌": "corner",
            "㇍": "corner",
            "㇎": "corner",
            "㇓": "diagonal",
            "㇖": "corner",
            "㇗": "corner",
            "㇘": "corner",
            "㇙": "corner",
            "㇚": "hook",
            "㇛": "curve",
            "㇜": "curve",
            "㇝": "curve",
            "㇞": "curve",
            "㇟": "curve",
        }
        
        base_type = kvg_type[0] if kvg_type else ""
        return stroke_map.get(base_type, "unknown")
    
    def _infer_direction(self, path_d: str, stroke_type: str) -> str:
        """Infer stroke direction from path data."""
        if not path_d:
            return "unknown"
        
        # Parse the first move command
        match = re.match(r"M\s*([\d.]+)[,\s]+([\d.]+)", path_d)
        if not match:
            return "unknown"
        
        start_x = float(match.group(1))
        start_y = float(match.group(2))
        
        # Find end point from last coordinates
        coords = re.findall(r"[\d.]+", path_d[match.end():])
        if len(coords) >= 2:
            end_x = float(coords[-2])
            end_y = float(coords[-1])
            
            dx = end_x - start_x
            dy = end_y - start_y
            
            abs_dx = abs(dx)
            abs_dy = abs(dy)
            
            if abs_dx > abs_dy * 2:
                return "left-to-right" if dx > 0 else "right-to-left"
            elif abs_dy > abs_dx * 2:
                return "top-to-bottom" if dy > 0 else "bottom-to-top"
            else:
                if dx > 0 and dy > 0:
                    return "top-left-to-bottom-right"
                elif dx < 0 and dy > 0:
                    return "top-right-to-bottom-left"
                elif dx > 0 and dy < 0:
                    return "bottom-left-to-top-right"
                else:
                    return "bottom-right-to-top-left"
        
        return "unknown"
    
    def _format_size(self, size_bytes: int) -> str:
        """Format byte size to human readable."""
        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"
