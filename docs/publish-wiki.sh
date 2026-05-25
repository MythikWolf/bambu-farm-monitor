#!/bin/bash
#
# Script to publish wiki documentation to GitHub Wiki
#
# This script copies all wiki markdown files to the GitHub wiki repository
# and pushes them.
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WIKI_DIR="$SCRIPT_DIR/wiki"
WIKI_REPO="git@github.com:mythikwolf/bambu-farm-monitor.wiki.git"
TMP_DIR="/tmp/bambu-wiki-$$"

echo "📚 Bambu Farm Monitor - Wiki Publisher"
echo "======================================="
echo ""

# Check if wiki files exist
if [ ! -d "$WIKI_DIR" ]; then
    echo "❌ Error: Wiki directory not found at $WIKI_DIR"
    exit 1
fi

# Count wiki files
FILE_COUNT=$(ls -1 "$WIKI_DIR"/*.md 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "❌ Error: No markdown files found in $WIKI_DIR"
    exit 1
fi

echo "✅ Found $FILE_COUNT wiki files to publish"
echo ""

# Clone the wiki repository
echo "📥 Cloning wiki repository..."
if ! git clone "$WIKI_REPO" "$TMP_DIR" 2>&1; then
    echo ""
    echo "❌ Error: Could not clone wiki repository"
    echo ""
    echo "The wiki needs to be initialized first:"
    echo "1. Go to https://github.com/mythikwolf/bambu-farm-monitor/wiki"
    echo "2. Click 'Create the first page'"
    echo "3. Add any content and save"
    echo "4. Run this script again"
    echo ""
    exit 1
fi

echo "✅ Wiki repository cloned"
echo ""

# Copy wiki files
echo "📝 Copying wiki files..."
cd "$TMP_DIR"

# Remove README.md from copy list (it's for documentation purposes only)
for file in "$WIKI_DIR"/*.md; do
    filename=$(basename "$file")
    if [ "$filename" != "README.md" ]; then
        cp "$file" .
        echo "   • Copied $filename"
    fi
done

echo "✅ Files copied"
echo ""

# Check if there are changes
if git diff --quiet && git diff --cached --quiet; then
    echo "ℹ️  No changes detected, wiki is already up to date"
    rm -rf "$TMP_DIR"
    exit 0
fi

# Commit and push
echo "💾 Committing changes..."
git add .
git commit -m "Update wiki documentation from main repository

Published articles:
- Home.md - Wiki landing page with navigation
- Installation-Guide.md - Complete installation instructions
- Finding-Printer-Information.md - How to locate printer details
- API-Documentation.md - Complete REST API reference
- Common-Issues.md - Troubleshooting guide

Generated from docs/wiki/ in main repository
Published by: docs/publish-wiki.sh"

echo "✅ Changes committed"
echo ""

echo "🚀 Pushing to GitHub..."
if git push; then
    echo "✅ Wiki published successfully!"
    echo ""
    echo "🌐 View at: https://github.com/mythikwolf/bambu-farm-monitor/wiki"
else
    echo "❌ Error: Failed to push to GitHub"
    echo ""
    echo "You may need to:"
    echo "1. Check your SSH keys are configured"
    echo "2. Verify you have write access to the repository"
    echo ""
    rm -rf "$TMP_DIR"
    exit 1
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR"

echo "✅ Done!"
echo ""
echo "📚 Wiki Pages Published:"
ls -1 "$WIKI_DIR"/*.md | grep -v README.md | while read file; do
    filename=$(basename "$file" .md)
    echo "   • $filename"
done
