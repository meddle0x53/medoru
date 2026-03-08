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
def kanjidic2():
    """KANJIDIC2 kanji metadata commands."""
    pass


@kanjidic2.command()
def download():
    """Download KANJIDIC2 data from EDRG."""
    from .spiders.kanjidic2 import Kanjidic2Spider
    
    spider = Kanjidic2Spider()
    spider.download()


@kanjidic2.command()
@click.option("--level", type=click.Choice(["N5", "N4", "N3", "N2", "N1", "all"]), 
              default="all", help="JLPT level filter (note: KANJIDIC2 uses old 1-4 levels)")
@click.option("--characters", "-c", help="Export specific kanji characters (comma-separated)")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--include-readings/--no-readings", default=True, 
              help="Include on/kun readings in export")
def export(level: str, characters: str, output: str, include_readings: bool):
    """Export KANJIDIC2 kanji data to Medoru format.
    
    Note: KANJIDIC2 uses the OLD JLPT levels (1-4). Level mappings:
    - N5 (new) -> Uses predefined N5 kanji list
    - N4 (new) -> Uses predefined N5+N4 kanji list
    - N3-N1 (new) -> Maps to old levels 2-1
    """
    from .spiders.kanjidic2 import Kanjidic2Spider
    from .exporters.kanji_exporter import KanjiExporter
    from .config import N5_KANJI_LIST, N4_KANJI_LIST
    
    spider = Kanjidic2Spider()
    exporter = KanjiExporter()
    
    # If specific characters provided, use those
    if characters:
        char_list = list(characters.replace(" ", "").replace(",", ""))
        kanji_list = spider.extract_all_kanji(filter_jlpt=False)
        kanji_list = [k for k in kanji_list if k["character"] in char_list]
    elif level == "N5":
        # N5 uses predefined list since KANJIDIC2 uses old levels
        kanji_list = spider.get_kanji_by_characters(N5_KANJI_LIST)
    elif level == "N4":
        # N4 combines predefined N5 and N4 lists
        all_n4 = N5_KANJI_LIST + N4_KANJI_LIST
        kanji_list = spider.get_kanji_by_characters(all_n4)
    else:
        # Parse all kanji
        kanji_list = spider.extract_all_kanji(filter_jlpt=(level != "all"))
        
        # Filter by level if specified
        # KANJIDIC2 uses old levels: 1, 2, 3, 4
        # Map: N1->1, N2->2, N3->3, N4->4
        if level != "all":
            level_map = {"N1": 1, "N2": 2, "N3": 3, "N4": 4}
            old_level = level_map.get(level)
            if old_level:
                kanji_list = [k for k in kanji_list if k.get("jlpt_level") == old_level]
    
    exporter.export_kanji_metadata(
        kanji_list, output, include_readings=include_readings,
        source="KANJIDIC2",
        license="CC BY-SA 4.0",
        copyright="© EDRG",
        attribution="https://www.edrdg.org/wiki/index.php/KANJIDIC_Project"
    )


@kanjidic2.command()
def status():
    """Show KANJIDIC2 download status."""
    from .spiders.kanjidic2 import Kanjidic2Spider
    
    spider = Kanjidic2Spider()
    info = spider.get_status()
    
    table = Table(title="KANJIDIC2 Status")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("Downloaded", "✓ Yes" if info["downloaded"] else "✗ No")
    table.add_row("File Size", info["file_size"])
    table.add_row("License", info["license"])
    
    console.print(table)


@kanjidic2.command()
def stats():
    """Show KANJIDIC2 statistics."""
    from .spiders.kanjidic2 import Kanjidic2Spider
    
    spider = Kanjidic2Spider()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] KANJIDIC2 data not downloaded. Run 'medoru-data kanjidic2 download' first.")
        return
    
    console.print("[blue]Analyzing KANJIDIC2 data...[/blue]")
    
    # Get all kanji with JLPT levels
    kanji_list = spider.extract_all_kanji(filter_jlpt=False)
    
    # Calculate stats
    total_kanji = len(kanji_list)
    with_jlpt = len([k for k in kanji_list if k.get("jlpt_level")])
    
    by_level = {}
    for level in [1, 2, 3, 4, 5]:
        count = len([k for k in kanji_list if k.get("jlpt_level") == level])
        by_level[level] = count
    
    # Display stats
    table = Table(title="KANJIDIC2 Statistics")
    table.add_column("Metric", style="cyan")
    table.add_column("Count", style="green", justify="right")
    
    table.add_row("Total Kanji", str(total_kanji))
    table.add_row("With JLPT Level", str(with_jlpt))
    table.add_row("Without JLPT Level", str(total_kanji - with_jlpt))
    table.add_row("", "")
    table.add_row("N1 (Advanced)", str(by_level.get(1, 0)))
    table.add_row("N2 (Upper-Intermediate)", str(by_level.get(2, 0)))
    table.add_row("N3 (Intermediate)", str(by_level.get(3, 0)))
    table.add_row("N4 (Elementary)", str(by_level.get(4, 0)))
    table.add_row("N5 (Beginner)", str(by_level.get(5, 0)))
    
    console.print(table)


@main.group()
def kanji_data():
    """Comprehensive kanji data with N5-N1 levels."""
    pass


@kanji_data.command()
def download():
    """Download comprehensive kanji data."""
    from .spiders.kanji_data import KanjiDataSpider
    
    spider = KanjiDataSpider()
    spider.download()


@kanji_data.command()
@click.option("--level", type=click.Choice(["N5", "N4", "N3", "N2", "N1", "all"]), 
              default="all", help="JLPT level filter (N5-N1)")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--include-readings/--no-readings", default=True, 
              help="Include on/kun readings in export")
def export(level: str, output: str, include_readings: bool):
    """Export kanji data with N5-N1 levels to Medoru format."""
    from .spiders.kanji_data import KanjiDataSpider
    from .exporters.kanji_exporter import KanjiExporter
    
    spider = KanjiDataSpider()
    exporter = KanjiExporter()
    
    if level == "all":
        kanji_list = spider.get_all_kanji_with_new_levels()
    else:
        level_num = int(level[1])  # "N5" -> 5
        kanji_list = spider.get_kanji_by_new_level(level_num)
    
    exporter.export_kanji_metadata(
        kanji_list, output, include_readings=include_readings,
        source="Kanji Data (davidluzgouveia)",
        license="MIT",
        copyright="© davidluzgouveia",
        attribution="https://github.com/davidluzgouveia/kanji-data"
    )


@kanji_data.command()
def status():
    """Show kanji data download status."""
    from .spiders.kanji_data import KanjiDataSpider
    
    spider = KanjiDataSpider()
    info = spider.get_status()
    
    table = Table(title="Kanji Data Status")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("Downloaded", "✓ Yes" if info["downloaded"] else "✗ No")
    table.add_row("File Size", info["file_size"])
    table.add_row("Kanji Count", str(info["kanji_count"]))
    
    console.print(table)


@kanji_data.command()
def stats():
    """Show kanji data statistics."""
    from .spiders.kanji_data import KanjiDataSpider
    
    spider = KanjiDataSpider()
    
    if not spider.json_path.exists():
        console.print("[red]Error:[/red] Kanji data not downloaded. Run 'medoru-data kanji-data download' first.")
        return
    
    console.print("[blue]Analyzing kanji data...[/blue]")
    
    stats_data = spider.get_stats()
    
    table = Table(title="Kanji Data Statistics")
    table.add_column("Metric", style="cyan")
    table.add_column("Count", style="green", justify="right")
    
    table.add_row("Total Kanji", str(stats_data["total"]))
    table.add_row("With Old JLPT (1-4)", str(stats_data["with_old_jlpt"]))
    table.add_row("With New JLPT (N5-N1)", str(stats_data["with_new_jlpt"]))
    table.add_row("", "")
    table.add_row("N5 (Beginner)", str(stats_data["by_new_level"].get(5, 0)))
    table.add_row("N4 (Elementary)", str(stats_data["by_new_level"].get(4, 0)))
    table.add_row("N3 (Intermediate)", str(stats_data["by_new_level"].get(3, 0)))
    table.add_row("N2 (Upper-Intermediate)", str(stats_data["by_new_level"].get(2, 0)))
    table.add_row("N1 (Advanced)", str(stats_data["by_new_level"].get(1, 0)))
    table.add_row("", "")
    table.add_row("Old Level 4", str(stats_data["by_old_level"].get(4, 0)))
    table.add_row("Old Level 3", str(stats_data["by_old_level"].get(3, 0)))
    table.add_row("Old Level 2", str(stats_data["by_old_level"].get(2, 0)))
    table.add_row("Old Level 1", str(stats_data["by_old_level"].get(1, 0)))
    
    console.print(table)


@kanji_data.command()
@click.option("--level", type=click.Choice(["N5", "N4", "N3", "N2", "N1", "all"]), 
              default="all", help="JLPT level filter (N5-N1)")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--include-readings/--no-readings", default=True, 
              help="Include on/kun readings in export")
def export_with_strokes(level: str, output: str, include_readings: bool):
    """Export kanji with N5-N1 levels AND stroke data from KanjiVG.
    
    This combines the kanji metadata (levels, meanings, readings) with
    stroke animation data from KanjiVG.
    """
    from .spiders.kanji_data import KanjiDataSpider
    from .spiders.kanjivg import KanjiVGSpider
    from .exporters.combined_kanji_exporter import CombinedKanjiExporter
    
    # Ensure KanjiVG data is downloaded
    vg_spider = KanjiVGSpider()
    if not vg_spider.get_status()["downloaded"]:
        console.print("[yellow]Downloading KanjiVG stroke data...[/yellow]")
        vg_spider.download()
    
    spider = KanjiDataSpider()
    exporter = CombinedKanjiExporter()
    
    if level == "all":
        kanji_list = spider.get_all_kanji_with_new_levels()
    else:
        level_num = int(level[1])  # "N5" -> 5
        kanji_list = spider.get_kanji_by_new_level(level_num)
    
    exporter.export_combined(
        kanji_list, 
        vg_spider, 
        output, 
        include_readings=include_readings
    )


@main.group()
def makemeahanzi():
    """Make Me A Hanzi data (radicals, decomposition)."""
    pass


@makemeahanzi.command()
def download():
    """Download Make Me A Hanzi data."""
    from .spiders.makemeahanzi import MakeMeAHanziSpider
    
    spider = MakeMeAHanziSpider()
    spider.download()


@makemeahanzi.command()
@click.option("--characters", "-c", required=True, help="Kanji characters to look up (comma-separated)")
def lookup(characters: str):
    """Look up radical data for specific kanji."""
    from .spiders.makemeahanzi import MakeMeAHanziSpider
    
    spider = MakeMeAHanziSpider()
    
    if not spider.dict_path.exists():
        console.print("[red]Error:[/red] Data not downloaded. Run 'medoru-data makemeahanzi download' first.")
        return
    
    # Handle kanji characters safely
    char_string = characters.replace(",", "").replace(" ", "")
    char_list = [c for c in char_string]
    data = spider.get_kanji_with_radicals(char_list)
    
    table = Table(title="Kanji Radical Data")
    table.add_column("Kanji", style="cyan")
    table.add_column("Radical", style="green")
    table.add_column("Definition", style="yellow")
    
    for k in data:
        table.add_row(
            k["character"],
            k["radical"] or "N/A",
            (k["definition"] or "N/A")[:30]
        )
    
    console.print(table)


@makemeahanzi.command()
def status():
    """Show download status."""
    from .spiders.makemeahanzi import MakeMeAHanziSpider
    
    spider = MakeMeAHanziSpider()
    info = spider.get_status()
    
    table = Table(title="Make Me A Hanzi Status")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("Downloaded", "✓ Yes" if info["downloaded"] else "✗ No")
    table.add_row("File Size", info["file_size"])
    table.add_row("Kanji Count", str(info["kanji_count"]))
    
    console.print(table)


@main.command()
@click.option("--level", type=click.Choice(["N5", "N4", "N3", "N2", "N1", "all"]), 
              default="all", help="JLPT level filter (N5-N1)")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--include-readings/--no-readings", default=True, 
              help="Include on/kun readings in export")
def export_full(level: str, output: str, include_readings: bool):
    """Export kanji with N5-N1 levels, stroke data, AND radical data.
    
    This combines all three data sources:
    - Kanji Data: Metadata (levels, meanings, readings)
    - KanjiVG: Stroke animation data
    - Make Me A Hanzi: Radical information
    """
    from .spiders.kanji_data import KanjiDataSpider
    from .spiders.kanjivg import KanjiVGSpider
    from .spiders.makemeahanzi import MakeMeAHanziSpider
    from .exporters.full_kanji_exporter import FullKanjiExporter
    
    # Ensure all data sources are downloaded
    vg_spider = KanjiVGSpider()
    if not vg_spider.get_status()["downloaded"]:
        console.print("[yellow]Downloading KanjiVG stroke data...[/yellow]")
        vg_spider.download()
    
    mmah_spider = MakeMeAHanziSpider()
    if not mmah_spider.get_status()["downloaded"]:
        console.print("[yellow]Downloading MakeMeAHanzi radical data...[/yellow]")
        mmah_spider.download()
    
    spider = KanjiDataSpider()
    exporter = FullKanjiExporter()
    
    if level == "all":
        kanji_list = spider.get_all_kanji_with_new_levels()
    else:
        level_num = int(level[1])  # "N5" -> 5
        kanji_list = spider.get_kanji_by_new_level(level_num)
    
    exporter.export_full(
        kanji_list, 
        vg_spider, 
        mmah_spider,
        output, 
        include_readings=include_readings
    )


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
