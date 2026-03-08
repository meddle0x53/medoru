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
