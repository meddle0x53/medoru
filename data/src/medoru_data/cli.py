"""Command-line interface for Medoru data pipeline."""

from typing import Optional

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
def jmdict():
    """JMdict Japanese-English dictionary commands."""
    pass


@jmdict.command()
def download():
    """Download JMdict data from EDRG."""
    from .spiders.jmdict import JMdictSpider
    
    spider = JMdictSpider()
    spider.download()


@jmdict.command()
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--limit", "-l", type=int, default=None, help="Limit number of entries (for testing)")
@click.option("--include-kana-only/--no-kana-only", default=False, help="Include kana-only words")
def export(output: str, limit: Optional[int], include_kana_only: bool):
    """Export JMdict words to Medoru format.
    
    Exports words with kanji to JSON format suitable for Medoru.
    """
    from .spiders.jmdict import JMdictSpider
    from .exporters.word_exporter import WordExporter
    
    spider = JMdictSpider()
    exporter = WordExporter()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
        return
    
    words = spider.extract_all_words(limit=limit)
    
    # Filter out kana-only words unless requested
    if not include_kana_only:
        words = [w for w in words if w.get("kanji_forms")]
    
    exporter.export_words(
        words, 
        output,
        source="JMdict",
        license="CC BY-SA 4.0",
        copyright="© EDRG",
        attribution="https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"
    )


@jmdict.command()
@click.option("--kanji", "-k", required=True, help="Kanji character(s) to search for (comma-separated)")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--max-per-kanji", "-m", type=int, default=10, help="Maximum words per kanji")
def export_for_kanji(kanji: str, output: str, max_per_kanji: int):
    """Export words containing specific kanji.
    
    Useful for building vocabulary lists for specific JLPT levels.
    """
    from .spiders.jmdict import JMdictSpider
    from .exporters.word_exporter import WordExporter
    
    spider = JMdictSpider()
    exporter = WordExporter()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
        return
    
    # Parse kanji list
    kanji_list = [c.strip() for c in kanji.replace(",", "").replace(" ", "")]
    kanji_list = [c for c in kanji_list if c]  # Remove empty strings
    
    if not kanji_list:
        console.print("[red]Error:[/red] No valid kanji characters provided.")
        return
    
    # Get words for these kanji
    words_by_kanji = spider.get_words_for_kanji_list(kanji_list, max_per_kanji=max_per_kanji)
    
    # Export organized by kanji
    exporter.export_words_by_kanji(
        words_by_kanji,
        output,
        source="JMdict",
        license="CC BY-SA 4.0",
        copyright="© EDRG",
        attribution="https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"
    )


@jmdict.command()
def status():
    """Show JMdict download status."""
    from .spiders.jmdict import JMdictSpider
    
    spider = JMdictSpider()
    info = spider.get_status()
    
    table = Table(title="JMdict Status")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("Downloaded", "✓ Yes" if info["downloaded"] else "✗ No")
    table.add_row("File Size", info["file_size"])
    table.add_row("License", info["license"])
    
    console.print(table)


@jmdict.command()
def stats():
    """Show JMdict statistics."""
    from .spiders.jmdict import JMdictSpider
    
    spider = JMdictSpider()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
        return
    
    stats_data = spider.get_stats()
    
    table = Table(title="JMdict Statistics")
    table.add_column("Metric", style="cyan")
    table.add_column("Count", style="green", justify="right")
    
    table.add_row("Total Entries", str(stats_data.get("total_entries", 0)))
    table.add_row("With Kanji", str(stats_data.get("with_kanji", 0)))
    table.add_row("Kana Only", str(stats_data.get("kana_only", 0)))
    
    console.print(table)


@jmdict.command(name="export-for-seeding")
@click.option("--kanji", "-k", required=True, help="Kanji characters to find words for (comma-separated)")
@click.option("--max-per-kanji", "-m", type=int, default=10, help="Maximum words per kanji")
@click.option("--output", "-o", required=True, help="Output JSON file (for priv/repo/seeds/)")
@click.option("--kanji-data", "-d", help="Path to kanji JSON file with reading data (e.g., kanji_n5.json)")
def export_for_seeding(kanji: str, max_per_kanji: int, output: str, kanji_data: Optional[str] = None):
    """Export words in format compatible with Medoru seeds.exs.
    
    This exports a flat array of words matching the structure of
    priv/repo/seeds/words_n5.json for direct database seeding.
    
    If --kanji-data is provided, the exporter will match specific kanji readings
    for each word (e.g., 上 in のし上がる → reading "あ").
    
    Example:
        medoru-data jmdict export-for-seeding \\
            --kanji "日,月,火,水,木" \\
            --max-per-kanji 10 \\
            --kanji-data ../priv/repo/seeds/kanji_n5.json \\
            --output ../priv/repo/seeds/words_custom.json
    """
    from .spiders.jmdict import JMdictSpider
    import json
    from pathlib import Path
    
    spider = JMdictSpider()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
        return
    
    # Parse kanji list
    kanji_list = [c.strip() for c in kanji.replace(",", "").replace(" ", "")]
    kanji_list = [c for c in kanji_list if c]
    
    if not kanji_list:
        console.print("[red]Error:[/red] No valid kanji characters provided.")
        return
    
    # Load kanji data with readings if provided
    kanji_mapping = None
    if kanji_data:
        kanji_mapping = _load_kanji_mapping(kanji_data)
        if kanji_mapping:
            console.print(f"[dim]Loaded {len(kanji_mapping)} kanji with readings[/dim]")
    
    # Export words with reading matching
    words = spider.export_words_for_seeding(kanji_list, max_per_kanji=max_per_kanji, kanji_mapping=kanji_mapping)
    
    if not words:
        console.print("[yellow]No words found for the given kanji.[/yellow]")
        return
    
    # Write to file
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    # Show reading match stats
    if kanji_mapping:
        total_kanji = sum(len(w.get("kanji", [])) for w in words)
        matched = sum(1 for w in words for k in w.get("kanji", []) if k.get("reading"))
        console.print(f"[dim]Reading matches: {matched}/{total_kanji} ({matched/total_kanji*100:.1f}%)[/dim]")
    
    console.print(f"[green]✓[/green] Exported {len(words)} words to {output}")
    console.print(f"[dim]Use with: mix medoru.seed_words --file {output}[/dim]")


@jmdict.command(name="export-all-for-seeding")
@click.option("--output", "-o", required=True, help="Output JSON file")
@click.option("--limit", "-l", type=int, default=None, help="Limit number of words (default: all)")
@click.option("--kanji-data", "-d", help="Path to kanji JSON file with reading data (e.g., kanji_n5.json)")
def export_all_for_seeding(output: str, limit: Optional[int], kanji_data: Optional[str] = None):
    """Export ALL words from JMdict in seeding format.
    
    This exports all words with kanji (excluding kana-only words) in the format
    compatible with Medoru database seeding. Use --limit for testing.
    
    If --kanji-data is provided, the exporter will match specific kanji readings
    for each word.
    
    WARNING: This will export ~170,000+ words and create a large file (~500MB).
    
    Example:
        # Export all words (large file!)
        medoru-data jmdict export-all-for-seeding \\
            --output ../priv/repo/seeds/words_all.json
        
        # Export first 1000 words for testing
        medoru-data jmdict export-all-for-seeding \\
            --limit 1000 \\
            --output ../priv/repo/seeds/words_sample.json
    """
    from .spiders.jmdict import JMdictSpider
    import json
    from pathlib import Path
    
    spider = JMdictSpider()
    
    if not spider.xml_path.exists():
        console.print("[red]Error:[/red] JMdict data not downloaded. Run 'medoru-data jmdict download' first.")
        return
    
    # Confirm for large exports
    if limit is None or limit > 10000:
        console.print("[yellow]Warning:[/yellow] This will export a large number of words.")
        console.print("The output file may be very large (>100MB).")
        console.print("Consider using --limit to export a smaller set first.")
        console.print("")
    
    # Load kanji data with readings if provided
    kanji_mapping = None
    if kanji_data:
        kanji_mapping = _load_kanji_mapping(kanji_data)
        if kanji_mapping:
            console.print(f"[dim]Loaded {len(kanji_mapping)} kanji with readings[/dim]")
    
    # Export all words with reading matching
    words = spider.export_all_words_for_seeding(limit=limit, kanji_mapping=kanji_mapping)
    
    if not words:
        console.print("[yellow]No words found.[/yellow]")
        return
    
    # Write to file
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
    
    # Get file size
    file_size = output_path.stat().st_size
    size_mb = file_size / (1024 * 1024)
    
    # Show reading match stats
    if kanji_mapping:
        total_kanji = sum(len(w.get("kanji", [])) for w in words)
        matched = sum(1 for w in words for k in w.get("kanji", []) if k.get("reading"))
        console.print(f"[dim]Reading matches: {matched}/{total_kanji} ({matched/total_kanji*100:.1f}%)[/dim]")
    
    console.print(f"[green]✓[/green] Exported {len(words)} words to {output}")
    console.print(f"[dim]File size: {size_mb:.1f} MB[/dim]")
    console.print(f"[dim]Use with: mix medoru.seed_words --file {output}[/dim]")


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


def _load_kanji_mapping(kanji_data_path: str):
    """Load kanji data and build a mapping for reading matching.
    
    Args:
        kanji_data_path: Path to kanji JSON file (e.g., kanji_n5.json)
        
    Returns:
        Dict mapping kanji characters to their reading info, or None if file not found
    """
    import json
    from pathlib import Path
    
    path = Path(kanji_data_path)
    if not path.exists():
        console.print(f"[yellow]Warning:[/yellow] Kanji data file not found: {kanji_data_path}")
        return None
    
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        # Handle different JSON structures
        kanji_list = []
        data_type = type(data).__name__
        
        if data_type == "list":
            kanji_list = data
        elif data_type == "dict":
            if "kanji" in data:
                kanji_list = data["kanji"]
            elif "characters" in data:
                kanji_list = data["characters"]
        
        # Build mapping
        mapping = {}
        for k in kanji_list:
            char = None
            if "character" in k:
                char = k["character"]
            elif "kanji" in k:
                char = k["kanji"]
            
            if char:
                # Normalize readings format
                readings = []
                for r in k.get("readings", []):
                    r_type = type(r).__name__
                    if r_type == "dict":
                        readings.append(r)
                    elif r_type == "str":
                        # Simple string reading - assume kun
                        readings.append({"reading": r, "reading_type": "kun"})
                
                jlpt = k.get("jlpt_level") or k.get("level")
                mapping[char] = {
                    "character": char,
                    "readings": readings,
                    "jlpt_level": jlpt
                }
        
        return mapping
        
    except Exception as e:
        import traceback
        console.print(f"[yellow]Warning:[/yellow] Error loading kanji data: {e}")
        traceback.print_exc()
        return None


if __name__ == "__main__":
    main()
