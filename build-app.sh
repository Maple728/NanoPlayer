#!/bin/bash
# Build NanoPlayer and assemble a runnable macOS .app bundle.
# Uses swiftc directly so it works with only the Command Line Tools (no Xcode).
set -e

APP="NanoPlayer"
BUNDLE_ID="dev.local.nanoplayer"
cd "$(dirname "$0")"

if ! pkg-config --exists mpv; then
    echo "error: libmpv not found. Install with:  brew install mpv" >&2
    exit 1
fi

echo "==> compiling $APP"
# Header/library locations come from pkg-config, so this builds on both Apple
# Silicon (/opt/homebrew) and Intel (/usr/local) — each machine builds its own arch.
CFLAGS=()
for inc in $(pkg-config --cflags-only-I mpv); do CFLAGS+=("-Xcc" "$inc"); done
LIBS=()
for l in $(pkg-config --libs mpv); do LIBS+=("$l"); done
MPV_LIBDIR=$(pkg-config --variable=libdir mpv)

# All Swift sources under Sources/NanoPlayer (App / Core / Player / Episode).
SOURCES=$(find Sources/NanoPlayer -name '*.swift' | sort)
swiftc -O -module-name "$APP" \
    -I Sources/Cmpv \
    "${CFLAGS[@]}" \
    -Xcc -fmodule-map-file=Sources/Cmpv/module.modulemap \
    -Xlinker -headerpad_max_install_names \
    $SOURCES \
    "${LIBS[@]}" \
    -o "$APP"

APPDIR="$APP.app"
echo "==> assembling $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
mv "$APP" "$APPDIR/Contents/MacOS/$APP"

cat > "$APPDIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP</string>
    <key>CFBundleDisplayName</key><string>$APP</string>
    <key>CFBundleExecutable</key><string>$APP</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Media File</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.movie</string>
                <string>public.video</string>
                <string>public.audiovisual-content</string>
                <string>public.audio</string>
                <string>public.mpeg-4</string>
                <string>com.apple.quicktime-movie</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mp4</string><string>mkv</string><string>mov</string><string>m4v</string>
                <string>webm</string><string>avi</string><string>ts</string><string>flv</string>
                <string>wmv</string><string>mp3</string><string>flac</string><string>wav</string>
                <string>aac</string><string>m4a</string><string>ogg</string><string>opus</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# App icon. Regenerate the .icns if missing (needs the source generator).
if [ ! -f Resources/AppIcon.icns ] && [ -f icon/make-icon.swift ]; then
    echo "==> generating app icon"
    ICONSET="$(mktemp -d)/NanoPlayer.iconset"
    swift icon/make-icon.swift "$ICONSET" >/dev/null
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APPDIR/Contents/Resources/AppIcon.icns"

# Custom idle-screen script (our logo).
[ -f scripts/idle-logo.lua ] && cp scripts/idle-logo.lua "$APPDIR/Contents/Resources/idle-logo.lua"

# Make sure the loader can find Homebrew's libmpv at runtime (prefix-agnostic).
install_name_tool -add_rpath "$MPV_LIBDIR" "$APPDIR/Contents/MacOS/$APP" 2>/dev/null || true
# Ad-hoc sign so Gatekeeper / Metal are happy locally.
codesign --force --sign - "$APPDIR" 2>/dev/null || true

# Register with LaunchServices so it shows up in Finder's "Open With" menu now.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$PWD/$APPDIR" 2>/dev/null || true

echo "==> done: $APPDIR"
echo "Run:  open $APPDIR"
echo "Logs: ./$APPDIR/Contents/MacOS/$APP"
