#!/bin/sh
# Copies shared assets from apple/ (the source of truth) into the Android
# module. Destinations are gitignored — run before building a real APK.
set -eu

cd "$(dirname "$0")/.."

mkdir -p app/src/main/assets
cp ../apple/Extensions/cmudict-ipa.txt app/src/main/assets/cmudict-ipa.txt
echo "synced cmudict-ipa.txt ($(wc -c < app/src/main/assets/cmudict-ipa.txt | tr -d ' ') bytes)"

# res/font/ishihara.otf is committed (renamed copy of
# apple/Resources/Ishihara-Regular.otf) because resources can't live in
# assets/; refresh it here so the two never drift.
cp ../apple/Resources/Ishihara-Regular.otf app/src/main/res/font/ishihara.otf
echo "synced ishihara.otf"
