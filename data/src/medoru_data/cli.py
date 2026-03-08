"""Command-line interface for Medoru data pipeline."""

import click
from rich.console import Console
from rich.table import Table

from . import __version__
from .config import SOURCES

console = Console()


@click.group()
@click.version_option(version=__version__, prog_name="medoru-data")
def main():
    """Medoru Data Collection Pipeline."""
    pass


@main.group()
def kanjivg():
    """KanjiVG stroke data commands."""
    pass


@kanjivg.command()
def download():
    """Download KanjiVG data from GitHub."""
    from .spiders.kanjivg import KanjiVGSpider
    
    spider = KanjiVGSpider()
    spider.download()


@kanjivg.command()
@click.option("--level", default="N5", help="JLPT level (N5, N4, N3, N2, N1, or 'all')")
@click.option("--output", "-o", required=True, help="Output JSON file")
def export(level: str, output: str):
    """Export KanjiVG data to Medoru format."""
    from .spiders.kanjivg import KanjiVGSpider
    from .exporters.kanji_exporter import KanjiExporter
    
    spider = KanjiVGSpider()
    exporter = KanjiExporter()
    
    kanji_list = spider.get_kanji_list(level)
    stroke_data = spider.extract_strokes(kanji_list)
    exporter.export_strokes(stroke_data, output)


@kanjivg.command()
def status():
    """Show KanjiVG download status."""
    from .spiders.kanjivg import KanjiVGSpider
    
    spider = KanjiVGSpider()
    info = spider.get_status()
    
    table = Table(title="KanjiVG Status")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("Downloaded", "✓ Yes" if info["downloaded"] else "✗ No")
    table.add_row("Total Files", str(info["total_files"]))
    table.add_row("Cache Size", info["cache_size"])
    
    console.print(table)


@main.group()
def sources():
    """Show data source information."""
    pass


@sources.command()
def list():
    """List all configured data sources."""
    table = Table(title="Data Sources")
    table.add_column("Source", style="cyan")
    table.add_column("License", style="yellow")
    table.add_column("Copyright", style="green")
    
    for key, source in SOURCES.items():
        table.add_row(
            f"{source['name']}\n{source['url']}",
            source["license"],
            source["copyright"]
        )
    
    console.print(table)
    console.print("\n[dim]All data used under terms of respective licenses.[/dim]")
    console.print("[dim]See README.md for attribution requirements.[/dim]")


if __name__ == "__main__":
    main()
