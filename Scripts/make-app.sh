#!/bin/bash
# Builds StoryStamper.app into build/, and with --install also copies it to
# /Applications so it appears in Finder, Spotlight, and Launchpad.
#
# If Support/ffmpeg exists (a standalone ffmpeg binary), it is bundled into
# Resources so the app runs without a Homebrew installation.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=false
if [ "${1:-}" = "--install" ]; then
    INSTALL=true
fi

# Before the compiler, because a design-system violation is cheaper to hear
# about in a second than after a release build.
./Scripts/check-style.sh

swift build -c release

APP="build/StoryStamper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/StoryStamper "$APP/Contents/MacOS/StoryStamper"
cp Support/Info.plist "$APP/Contents/Info.plist"

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
swift Scripts/make-icon.swift "$ICONSET" > /dev/null
iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

if [ -f Support/ffmpeg ]; then
    cp Support/ffmpeg "$APP/Contents/Resources/ffmpeg"
    chmod +x "$APP/Contents/Resources/ffmpeg"
    echo "Bundled Support/ffmpeg into the app."
fi

codesign --force -s - "$APP"
echo "Built $APP"

if [ "$INSTALL" = true ]; then
    DESTINATION="/Applications/StoryStamper.app"
    rm -rf "$DESTINATION"
    cp -R "$APP" "$DESTINATION"
    # Nudge Launch Services so the new icon and app register immediately.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$DESTINATION" > /dev/null 2>&1 || true
    echo "Installed $DESTINATION"
fi
