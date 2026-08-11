#!/bin/bash
# Builds StoryStamper.app into build/ from a release swift build.
# If Support/ffmpeg exists (a standalone ffmpeg binary), it is bundled into
# Resources so the app runs without a Homebrew installation.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/StoryStamper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/StoryStamper "$APP/Contents/MacOS/StoryStamper"
cp Support/Info.plist "$APP/Contents/Info.plist"

if [ -f Support/ffmpeg ]; then
    cp Support/ffmpeg "$APP/Contents/Resources/ffmpeg"
    chmod +x "$APP/Contents/Resources/ffmpeg"
    echo "Bundled Support/ffmpeg into the app."
fi

codesign --force -s - "$APP"
echo "Built $APP"
