#!/usr/bin/env python3
"""
Check the real status of N3 translations in database
"""

import subprocess
import json

def run_sql(sql):
    result = subprocess.run(
        ["psql", "-d", "medoru_dev", "-t", "-A", "-c", sql],
        capture_output=True, text=True
    )
    return result.stdout.strip()

print("=" * 60)
print("📊 N3 Translation Status (Database Truth)")
print("=" * 60)
print()

# Total N3 words
total = int(run_sql("SELECT COUNT(*) FROM words WHERE difficulty = 3;"))
print(f"Total N3 words: {total:,}")

# With Bulgarian translations
with_bg = int(run_sql("SELECT COUNT(*) FROM words WHERE difficulty = 3 AND translations->'bg'->>'meaning' IS NOT NULL AND translations->'bg'->>'meaning' != '';"))
print(f"With Bulgarian translations: {with_bg:,} ({with_bg/total*100:.1f}%)")

# Remaining
remaining = total - with_bg
print(f"Remaining: {remaining:,} ({remaining/total*100:.1f}%)")

print()
print("=" * 60)
print("🔍 Sample Translations (Quality Check)")
print("=" * 60)
print()

sql = """
SELECT meaning, translations->'bg'->>'meaning' as bg
FROM words 
WHERE difficulty = 3 AND translations->>'bg' IS NOT NULL
ORDER BY RANDOM()
LIMIT 5;
"""

result = subprocess.run(
    ["psql", "-d", "medoru_dev", "-t", "-A", "-F", " | ", "-c", sql],
    capture_output=True, text=True
)

print("English → Bulgarian")
print("-" * 60)
for line in result.stdout.strip().split("\n"):
    if line:
        print(f"  {line}")
print("-" * 60)

print()
if with_bg < 1000:
    print("⚠️  WARNING: Very few translations exist!")
    print("   The translation process needs to be started.")
    print()
    print("Options:")
    print("  1. Test NLLB-3.3B quality (100 words)")
    print("     → python3 bin/test_nllb_100.py")
    print()
    print("  2. Run full NLLB-3.3B translation (all 135,847 words)")
    print("     → python3 bin/translate_n3_nllb.py")
    print()
    print("  3. Use faster Helsinki-NLP (lower quality)")
    print("     → python3 bin/retranslate_all_n3.py")
else:
    print(f"✅ {with_bg:,} words translated")
    print("   Check quality with samples above.")
