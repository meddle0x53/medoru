#!/bin/bash
# Build Medoru release for production deployment

set -e

echo "=== Building Medoru Release ==="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}Step 1: Cleaning previous builds...${NC}"
rm -rf _build/prod
rm -f deployment/medoru_release.tar.gz

echo -e "${YELLOW}Step 2: Fetching dependencies...${NC}"
mix deps.get --only prod

echo -e "${YELLOW}Step 3: Compiling...${NC}"
MIX_ENV=prod mix compile

echo -e "${YELLOW}Step 4: Building assets...${NC}"
# Phoenix 1.8+ uses esbuild via Elixir package
# Assets are built automatically during mix compile

echo -e "${YELLOW}Step 5: Digesting assets...${NC}"
MIX_ENV=prod mix phx.digest

echo -e "${YELLOW}Step 6: Building release...${NC}"
MIX_ENV=prod mix release

echo -e "${YELLOW}Step 7: Creating tarball...${NC}"
tar -czf deployment/medoru_release.tar.gz -C _build/prod/rel/medoru .

echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Release tarball: deployment/medoru_release.tar.gz"
echo ""
echo "Next steps:"
echo "1. If initial setup: ansible-playbook -i deployment/inventory/production deployment/setup.yml"
echo "2. If updating: ansible-playbook -i deployment/inventory/production deployment/update.yml"
