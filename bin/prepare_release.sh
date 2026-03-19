#!/bin/bash

# Prepare release script for Medoru
# Usage: ./prepare_release.sh 0.1.1

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.1.1"
  exit 1
fi

# Validate version format (semantic versioning)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in semantic versioning format (e.g., 0.1.1)"
  exit 1
fi

echo "Preparing release v$VERSION..."

# Get current version from mix.exs
CURRENT_VERSION=$(grep -E '^\s+version: "[0-9]+\.[0-9]+\.[0-9]+"' mix.exs | head -1 | sed 's/.*"\([0-9]\+\.[0-9]\+\.[0-9]\+\)".*/\1/')
echo "Current version: $CURRENT_VERSION"
echo "New version: $VERSION"

# Update version in mix.exs (project version)
sed -i "s/version: \"$CURRENT_VERSION\"/version: \"$VERSION\"/g" mix.exs
echo "✓ Updated mix.exs (project version)"

# Update version in mix.exs (releases version)
sed -i "s/version: \"$CURRENT_VERSION\"/version: \"$VERSION\"/g" mix.exs
echo "✓ Updated mix.exs (release version)"

# Update version in home.html.heex (Early Access badge)
sed -i "s/[0-9]\+\.[0-9]\+\.[0-9]\+ Early Access/$VERSION Early Access/g" lib/medoru_web/controllers/page_html/home.html.heex
echo "✓ Updated home.html.heex"

# Update version examples in RELEASE.md
sed -i "s/--version $CURRENT_VERSION/--version $VERSION/g" RELEASE.md
sed -i "s|releases/$CURRENT_VERSION/|releases/$VERSION/|g" RELEASE.md
echo "✓ Updated RELEASE.md"

echo ""
echo "Release v$VERSION prepared successfully!"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Commit the changes: git add -A && git commit -m 'Bump version to $VERSION'"
echo "  3. Create a tag: git tag v$VERSION"
echo "  4. Push: git push && git push origin v$VERSION"
