"""Configuration for data collection pipeline."""

from pathlib import Path

# Base directories
BASE_DIR = Path(__file__).parent.parent.parent.parent
RAW_DIR = BASE_DIR / "raw"
PROCESSED_DIR = BASE_DIR / "processed"
SEEDS_DIR = BASE_DIR / "seeds"

# Ensure directories exist
RAW_DIR.mkdir(exist_ok=True)
PROCESSED_DIR.mkdir(exist_ok=True)
SEEDS_DIR.mkdir(exist_ok=True)

# Data Sources
SOURCES = {
    "kanjivg": {
        "name": "KanjiVG",
        "url": "https://github.com/KanjiVG/kanjivg",
        "download_url": "https://github.com/KanjiVG/kanjivg/archive/refs/heads/master.zip",
        "license": "CC BY-SA 3.0",
        "copyright": "© Ulrich Apel",
        "attribution_url": "http://kanjivg.tagaini.net",
    },
    "kanjidic2": {
        "name": "KANJIDIC2",
        "url": "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project",
        "download_url": "http://ftp.monash.edu.au/pub/nihongo/kanjidic2.xml.gz",
        "license": "CC BY-SA 4.0",
        "copyright": "© EDRG",
        "attribution_url": "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project",
    },
    "jmdict": {
        "name": "JMdict",
        "url": "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project",
        "download_url": "http://ftp.monash.edu.au/pub/nihongo/JMdict_e.gz",
        "license": "CC BY-SA 4.0",
        "copyright": "© EDRG",
        "attribution_url": "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project",
    },
}

# JLPT N5 Kanji (starting set)
N5_KANJI = (
    "日一国人年大十二本中長出"
    "三時行見月分後前内生"
    "五間上東四今金九入"
    "学高円子外八六下来"
    "気小七七山女百先名"
    "川千水男西木聞口"
)

# HTTP Settings
HTTP_TIMEOUT = 30
HTTP_RETRY_ATTEMPTS = 3
HTTP_RETRY_DELAY = 1  # seconds
