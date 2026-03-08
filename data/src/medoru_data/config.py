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
        "download_url": "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz",
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

# JLPT N5 Kanji (starting set) - 80 characters
N5_KANJI_LIST = [
    '日', '一', '国', '人', '年', '大', '十', '二', '本', '中',
    '長', '出', '三', '時', '行', '見', '月', '分', '後', '前',
    '内', '生', '五', '間', '上', '東', '四', '今', '金', '九',
    '入', '学', '高', '円', '子', '外', '八', '六', '下', '来',
    '気', '小', '七', '七', '山', '女', '百', '先', '名',
    '川', '千', '水', '男', '西', '木', '聞', '口'
]

# Keep string version for backward compatibility
N5_KANJI = "".join(N5_KANJI_LIST)

# JLPT N4 Kanji - additional characters beyond N5
N4_KANJI_LIST = [
    '会', '同', '事', '社', '自', '発', '者', '地', '業', '方', '新', '場', '員', '立', '開', '手', '力', '問', '代', '明',
    '動', '京', '目', '通', '言', '理', '体', '田', '主', '題', '意', '不', '作', '用', '度', '強', '公', '持', '野', '以',
    '思', '家', '世', '多', '正', '安', '院', '心', '界', '教', '文', '重', '近', '考', '画', '海', '去', '走', '集', '知',
    '別', '物', '使', '待', '系', '親', '乗', '飲', '品', '商', '酒', '冷', '静', '医', '矢', '知', '唱', '冬', '館', '岩',
    '旅', '貸', '負', '喜', '消', '燃', '色', '切', '悪', '業', '研', '神', '祭', '借', '弓', '魚', '指', '注', '路', '弟',
    '妹', '姉', '兄', '習', '歳', '泳', '走', '町', '村', '門', '林', '森', '早', '昼', '鼻', '歌', '村', '店', '姉', '曜',
    '鳴'
]

# String versions for backward compatibility
N4_KANJI = "".join(N4_KANJI_LIST)

# HTTP Settings
HTTP_TIMEOUT = 30
HTTP_RETRY_ATTEMPTS = 3
HTTP_RETRY_DELAY = 1  # seconds
