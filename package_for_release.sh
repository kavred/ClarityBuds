#!/bin/bash
#
# package_for_release.sh — Zips ClarityBuds.app for GitHub Releases.
#

set -e

# Always ensure we are running from the project directory
cd "$(dirname "$0")"

# Build the app to make sure it's the latest version
./build_app.sh

echo "📦 Packaging for GitHub Release..."

# macOS 'ditto' creates clean zip files from .app bundles
ditto -c -k --keepParent /Applications/ClarityBuds.app ClarityBudsRelease.zip

echo "✅ Success! 'ClarityBudsRelease.zip' created."
echo ""
echo "To publish this to GitHub:"
echo "1. Go to https://github.com/kavred/ClarityBuds/releases/new"
echo "2. Create a new tag (e.g., v1.0.0)"
echo "3. Drag and drop 'ClarityBudsRelease.zip' into the 'Attach binaries' box."
echo "4. Publish the release!"
