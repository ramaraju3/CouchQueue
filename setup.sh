#!/bin/bash
set -e

echo "CouchQueue — project setup"
echo "=========================="

if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Install it from https://brew.sh then re-run."
        exit 1
    fi
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "Done! CouchQueue.xcodeproj is ready."
echo ""
echo "How to run:"
echo "  1. Select scheme 'CouchQueue'       → run on Apple TV (device or tvOS simulator)"
echo "  2. Select scheme 'CouchQueueRemote' → run on iPhone (device or iOS simulator)"
echo "  3. Both must be on the same Wi-Fi. The Remote app auto-discovers the TV app via Bonjour."
echo ""

read -p "Open Xcode now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open CouchQueue.xcodeproj
fi
