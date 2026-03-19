#!/bin/bash
# Deployment helper script
# Usage: ./deploy.sh [setup|update|build]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="$SCRIPT_DIR/inventory/production"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function show_help() {
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  setup    - Initial server setup (run once)"
    echo "  update   - Deploy a new release"
    echo "  build    - Build the release locally"
    echo ""
    echo "Environment variables required for setup:"
    echo "  DB_PASSWORD          - PostgreSQL password"
    echo "  SECRET_KEY_BASE      - Phoenix secret key"
    echo "  GOOGLE_CLIENT_ID     - Google OAuth Client ID"
    echo "  GOOGLE_CLIENT_SECRET - Google OAuth Client Secret"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh build"
    echo "  DB_PASSWORD=pass SECRET_KEY_BASE=xxx GOOGLE_CLIENT_ID=yyy GOOGLE_CLIENT_SECRET=zzz ./deploy.sh setup"
    echo "  ./deploy.sh update"
}

function check_env_vars() {
    local missing=()

    for var in DB_PASSWORD SECRET_KEY_BASE GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET; do
        if [ -z "${!var}" ]; then
            missing+=($var)
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required environment variables:${NC}"
        for var in "${missing[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Example:"
        echo "  DB_PASSWORD=mypass SECRET_KEY_BASE=xxx GOOGLE_CLIENT_ID=yyy GOOGLE_CLIENT_SECRET=zzz ./deploy.sh setup"
        exit 1
    fi
}

function build_release() {
    echo -e "${YELLOW}Building release...${NC}"
    "$SCRIPT_DIR/build-release.sh"
}

function run_setup() {
    echo -e "${YELLOW}Running setup...${NC}"
    check_env_vars

    echo -e "${GREEN}Environment variables set:${NC}"
    echo "  DB_PASSWORD=***"
    echo "  SECRET_KEY_BASE=${SECRET_KEY_BASE:0:10}..."
    echo "  GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:0:20}..."
    echo "  GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET:0:10}..."
    echo ""

    ansible-playbook -i "$INVENTORY" "$SCRIPT_DIR/setup.yml" -K
}

function run_update() {
    echo -e "${YELLOW}Running update...${NC}"
    ansible-playbook -i "$INVENTORY" "$SCRIPT_DIR/update.yml" -K
}

# Main
case "${1:-}" in
    build)
        build_release
        ;;
    setup)
        run_setup
        ;;
    update)
        run_update
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: ${1:-}${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
