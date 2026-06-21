#!/bin/bash
# Build a SELF-CONTAINED, distributable NanoPlayer.app.
#
# It runs the normal build, then bundles libmpv and ALL of its (transitive)
# Homebrew dylib dependencies into Contents/Frameworks and rewrites every install
# name to @rpath, so the app runs on Macs WITHOUT Homebrew / mpv installed.
#
# Usage:
#   ./bundle-dist.sh
#       → ad-hoc signed. Runs on this Mac; on others the user must right-click →
#         Open once (Gatekeeper) since it isn't notarized.
#
#   DEV_ID="Developer ID Application: Your Name (TEAMID)" ./bundle-dist.sh
#       → signed with your Developer ID + hardened runtime, ready to notarize
#         (see the notarization steps printed at the end / in the README).
#
# Note: produces a binary for THIS machine's architecture only. For a universal
# (arm64 + x86_64) app you must build on / with both-arch libmpv and `lipo` them.
set -e
cd "$(dirname "$0")"

APP="NanoPlayer"
APPDIR="$APP.app"

# 1) Normal build (binary + icon + idle script, links Homebrew libmpv).
./build-app.sh

BIN="$APPDIR/Contents/MacOS/$APP"
FW="$APPDIR/Contents/Frameworks"
rm -rf "$FW"; mkdir -p "$FW"

# 2) Recursively copy every non-system dylib into Frameworks/ (flattened).
echo "==> collecting dependencies into Frameworks/"
collect() {
    local file="$1" dep bn
    while IFS= read -r dep; do
        case "$dep" in
            /opt/homebrew/*|/usr/local/*|/opt/local/*)
                bn=$(basename "$dep")
                if [ ! -f "$FW/$bn" ]; then
                    cp -L "$dep" "$FW/$bn"
                    chmod u+w "$FW/$bn"
                    collect "$FW/$bn"          # recurse on the copy
                fi
                ;;
        esac
    done < <(otool -L "$file" | awk 'NR>1{print $1}')
}
collect "$BIN"

# 2b) MoltenVK is the Vulkan driver mpv/libplacebo dlopen at runtime via an ICD
#     manifest — otool can't see it, so bundle it explicitly and ship a
#     bundle-local ICD manifest (the app points VK_DRIVER_FILES at it).
MVK_SRC="$(brew --prefix 2>/dev/null)/lib/libMoltenVK.dylib"
if [ -f "$MVK_SRC" ]; then
    cp -L "$MVK_SRC" "$FW/libMoltenVK.dylib"; chmod u+w "$FW/libMoltenVK.dylib"
    collect "$FW/libMoltenVK.dylib"
    ICDDIR="$APPDIR/Contents/Resources/vulkan/icd.d"
    mkdir -p "$ICDDIR"
    cat > "$ICDDIR/MoltenVK_icd.json" <<'JSON'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "../../../Frameworks/libMoltenVK.dylib",
        "api_version": "1.4.0",
        "is_portability_driver": true
    }
}
JSON
    echo "    bundled MoltenVK + ICD manifest"
else
    echo "    WARNING: libMoltenVK.dylib not found — gpu-next may not render on clean Macs"
fi
echo "    bundled $(ls "$FW" | wc -l | tr -d ' ') dylibs"

# 3) Rewrite install names to @rpath.
echo "==> rewriting install names -> @rpath"
# Drop the Homebrew rpath the normal build added; point at our Frameworks.
install_name_tool -delete_rpath "$(pkg-config --variable=libdir mpv)" "$BIN" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN"
for dep in $(otool -L "$BIN" | awk 'NR>1{print $1}' | grep -E '^(/opt/homebrew|/usr/local|/opt/local)'); do
    install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$BIN"
done
for lib in "$FW"/*.dylib; do
    install_name_tool -id "@rpath/$(basename "$lib")" "$lib"
    for dep in $(otool -L "$lib" | awk 'NR>1{print $1}' | grep -E '^(/opt/homebrew|/usr/local|/opt/local)'); do
        install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$lib"
    done
done

# 4) Sign.
echo "==> signing"
if [ -n "$DEV_ID" ]; then
    find "$FW" -name '*.dylib' -print0 | xargs -0 -I{} \
        codesign --force --timestamp --options runtime --sign "$DEV_ID" {}
    codesign --force --timestamp --options runtime --sign "$DEV_ID" "$BIN"
    codesign --force --timestamp --options runtime --sign "$DEV_ID" "$APPDIR"
else
    codesign --force --deep --sign - "$APPDIR"
fi
codesign --verify --deep --strict "$APPDIR" && echo "    signature OK"

# 5) Verify self-contained.
echo "==> verifying no external (Homebrew) references remain"
LEFT=$( { otool -L "$BIN"; for l in "$FW"/*.dylib; do otool -L "$l"; done; } \
        | grep -E '/opt/homebrew|/usr/local|/opt/local' | grep -v '@rpath' | wc -l | tr -d ' ')
echo "    remaining external refs: $LEFT (expect 0)"

# 6) Zip for distribution (notarization-friendly).
ditto -c -k --keepParent "$APPDIR" "$APP.zip"
echo "==> done: $APPDIR  +  $APP.zip"

if [ -z "$DEV_ID" ]; then
cat <<'NOTE'

This build is AD-HOC signed (fine on this Mac; others must right-click → Open).
To distribute properly:
  1. Re-run with your Developer ID:
       DEV_ID="Developer ID Application: Your Name (TEAMID)" ./bundle-dist.sh
  2. Notarize:
       xcrun notarytool submit NanoPlayer.zip --apple-id you@example.com \
             --team-id TEAMID --password APP_SPECIFIC_PW --wait
  3. Staple the ticket:
       xcrun stapler staple NanoPlayer.app
       ditto -c -k --keepParent NanoPlayer.app NanoPlayer.zip   # re-zip stapled app
NOTE
fi
