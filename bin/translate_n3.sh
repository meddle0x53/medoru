#!/bin/bash
# N3 Translation Menu

echo "======================================================================"
echo "              N3 Word Translation (135,847 words)"
echo "======================================================================"
echo ""
echo "Current Status:"
psql -d medoru_dev -t -c "SELECT COUNT(*) FROM words WHERE difficulty = 3;" 2>/dev/null | xargs echo "  Total N3 words:"
psql -d medoru_dev -t -c "SELECT COUNT(*) FROM words WHERE difficulty = 3 AND translations->'bg'->>'meaning' IS NOT NULL;" 2>/dev/null | xargs echo "  Translated:"
echo ""
echo "Translation Options:"
echo ""
echo "  1) Test NLLB-200-3.3B (100 words)"
echo "     • Best quality, ~13GB download"
echo "     • Tests on 100 random words first"
echo "     • Takes ~10 minutes"
echo ""
echo "  2) Run NLLB-200-3.3B Full Translation"
echo "     • Best quality for all 135K words"
echo "     • Requires 16GB+ RAM"
echo "     • Takes 6-8 hours"
echo "     • Resumable if interrupted"
echo ""
echo "  3) Check Status"
echo "     • Show current translation stats"
echo "     • View sample translations"
echo ""
echo "  4) Cancel"
echo ""
echo "----------------------------------------------------------------------"
read -p "Enter choice (1-4): " choice

case $choice in
  1)
    python3 bin/test_nllb_100.py
    ;;
  2)
    python3 bin/translate_n3_nllb.py
    ;;
  3)
    python3 bin/check_n3_status.py
    ;;
  *)
    echo "Cancelled."
    exit 0
    ;;
esac
