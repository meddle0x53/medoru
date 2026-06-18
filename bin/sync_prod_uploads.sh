#!/bin/bash
# Sync production uploads (word images, sounds, etc.) to local dev.
# Usage: ./bin/sync_prod_uploads.sh [--dry-run]
#
# This script is DOWNLOAD-ONLY from production and is safe for production data.
# It reads the server/user/key from deployment/inventory/production by default.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults (match deployment/inventory/production)
DEFAULT_SERVER="medoru.net"
DEFAULT_USER="meddle"
DEFAULT_KEY="$HOME/.ssh/id_ghub_ed25519"
DEFAULT_REMOTE_DIR="/var/opt/medoru/uploads"
DEFAULT_LOCAL_DIR="$PROJECT_ROOT/priv/static/uploads"

# Allow overrides via environment variables
PROD_SERVER="${PROD_SERVER:-$DEFAULT_SERVER}"
PROD_USER="${PROD_USER:-$DEFAULT_USER}"
PROD_SSH_KEY="${PROD_SSH_KEY:-$DEFAULT_KEY}"
PROD_UPLOADS_DIR="${PROD_UPLOADS_DIR:-$DEFAULT_REMOTE_DIR}"
LOCAL_UPLOADS_DIR="${LOCAL_UPLOADS_DIR:-$DEFAULT_LOCAL_DIR}"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

echo -e "${BLUE}=== Medoru Production Uploads Sync ===${NC}"
echo "Source: ${PROD_USER}@${PROD_SERVER}:${PROD_UPLOADS_DIR}/"
echo "Target: ${LOCAL_UPLOADS_DIR}/"
if [ "$DRY_RUN" == true ]; then
  echo -e "${YELLOW}Mode: DRY RUN (no files will be changed)${NC}"
fi
echo ""

# Validate SSH key exists
if [ ! -f "$PROD_SSH_KEY" ]; then
  echo -e "${RED}Error: SSH key not found: $PROD_SSH_KEY${NC}"
  echo "Set PROD_SSH_KEY to the correct path, or ensure ~/.ssh/id_ghub_ed25519 exists."
  exit 1
fi

# Ensure local uploads directory exists
mkdir -p "$LOCAL_UPLOADS_DIR"

# Build rsync options
RSYNC_OPTS="-avz --progress"
if [ "$DRY_RUN" == true ]; then
  RSYNC_OPTS="$RSYNC_OPTS --dry-run"
fi

echo -e "${YELLOW}Starting rsync...${NC}"
rsync $RSYNC_OPTS \
  -e "ssh -i $PROD_SSH_KEY -o StrictHostKeyChecking=accept-new" \
  "${PROD_USER}@${PROD_SERVER}:${PROD_UPLOADS_DIR}/" \
  "$LOCAL_UPLOADS_DIR/"

echo ""
if [ "$DRY_RUN" == true ]; then
  echo -e "${GREEN}=== Dry run complete. No files were changed.${NC}"
  echo "Run without --dry-run to perform the actual sync."
else
  echo -e "${GREEN}=== Sync complete ===${NC}"
  echo "Production uploads are now in: $LOCAL_UPLOADS_DIR/"
fi
