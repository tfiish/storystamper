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

    # Every version from 2.0.2 to 2.1.2 shipped without a tag, because the tag
    # is the one release step with nothing to remind you of it. This is the
    # moment to say so: the version is bumped, the build is installed, and the
    # commands below are the rest of the release.
    #
    # A warning, not a failure, unlike check-style.sh—installing a build during
    # ordinary development is not a release, and blocking it would be wrong.
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
    if git rev-parse --git-dir > /dev/null 2>&1 &&
       ! git rev-parse -q --verify "refs/tags/$VERSION" > /dev/null; then
        # Dots are regex wildcards, and 2.1.3 would otherwise also match 2913.
        VERSION_RE="${VERSION//./\\.}"
        cat <<NOTICE

$VERSION is not tagged. If this build is the release, the tag and the
release are both still to do—the tag alone puts nothing on the Releases
page, which is how the versions above went missing:

    git tag -a $VERSION -m "Story Stamper $VERSION"
    git push origin main --follow-tags
    gh release create $VERSION --title "Story Stamper $VERSION" --notes "\$(awk '/^## $VERSION_RE/{f=1;next} /^## /{f=0} f' CHANGELOG.md)"
NOTICE
    fi
fi
