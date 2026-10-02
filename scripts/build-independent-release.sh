#!/bin/bash
# Build only from tracked, committed source. Never export the signing key.
set -euo pipefail
umask 077

if [[ $# != 1 ]]; then
    echo "Usage: $0 /absolute/path/to/signing.keychain-db" >&2
    exit 2
fi
keychain=$1
repo=$(git rev-parse --show-toplevel)
if [[ -n $(git -C "$repo" status --porcelain) ]]; then
    echo "Commit or preserve working-tree changes before building a release." >&2
    exit 2
fi
commit=$(git -C "$repo" rev-parse HEAD)
pin=$(/usr/bin/openssl x509 -in "$repo/signing/ReleaseCertificate.pem" \
    -noout -fingerprint -sha1 | sed 's/.*=//; s/://g' | tr '[:upper:]' '[:lower:]')
if [[ ! $pin =~ ^[0-9a-f]{40}$ ]]; then
    echo "Invalid public certificate fingerprint." >&2
    exit 2
fi
work=$(mktemp -d /tmp/Battery-Toolkit-release.XXXXXX)
mkdir "$work/source" "$work/output" "$work/extracted"
git -C "$repo" archive "$commit" | tar -x -C "$work/source"
cd "$work/source"

xcodebuild -project 'Battery Toolkit.xcodeproj' -scheme 'Battery Toolkit' \
    -configuration Release -derivedDataPath "$work/build" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO BT_CODESIGN_CERT_SHA1="$pin" \
    build > "$work/build.log" 2>&1 || {
        echo "Build failed; see $work/build.log" >&2
        exit 1
    }

app="$work/build/Build/Products/Release/Battery Toolkit 1.9.0.app"
executables=(
    "$app/Contents/MacOS/Battery Toolkit 1.9.0"
    "$app/Contents/Library/LaunchServices/io.github.paintaviolin.BatteryToolkit.daemon"
    "$app/Contents/XPCServices/Battery Toolkit Service.xpc/Contents/MacOS/Battery Toolkit Service"
    "$app/Contents/Library/LoginItems/AutostartHelper.app/Contents/MacOS/AutostartHelper"
)
for binary in "${executables[@]}"; do
    /usr/bin/strip -S "$binary"
    if LC_ALL=C /usr/bin/strings "$binary" | /usr/bin/awk '
        /\/Users\// { found=1 } END { exit !found }'; then
        echo "Release executable contains a user-home path; refusing to package." >&2
        exit 1
    fi
done
for plist in "$app/Contents/Info.plist" \
    "$app/Contents/XPCServices/Battery Toolkit Service.xpc/Contents/Info.plist" \
    "$app/Contents/Library/LoginItems/AutostartHelper.app/Contents/Info.plist"; do
    [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist") == 1.9.0 ]]
done
[[ $(/usr/bin/otool -X -v -s __TEXT __info_plist "${executables[1]}" | \
    /usr/bin/plutil -extract CFBundleShortVersionString raw -o - -) == 1.9.0 ]]

sign() {
    /usr/bin/codesign --force --sign "$pin" --keychain "$keychain" \
        --timestamp=none -o hard,kill,restrict,enforce,library-validation,library,runtime "$@"
}
sign "${executables[1]}"
sign "$app/Contents/XPCServices/Battery Toolkit Service.xpc"
sign --entitlements AutostartHelper/AutostartHelper.entitlements \
    "$app/Contents/Library/LoginItems/AutostartHelper.app"
sign --entitlements BatteryToolkit/BatteryToolkit.entitlements "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/codesign --verify --strict -R "=certificate leaf = H\"$pin\"" "$app"

archive="$work/output/Battery-Toolkit-1.9.0-macOS.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
/usr/bin/ditto -x -k "$archive" "$work/extracted"
extracted="$work/extracted/Battery Toolkit 1.9.0.app"
/usr/bin/codesign --verify --deep --strict "$extracted"
for binary in "${executables[@]}"; do
    relative=${binary#"$app/"}
    /usr/bin/cmp "$binary" "$extracted/$relative"
done
if /usr/bin/unzip -Z1 "$archive" | /usr/bin/awk '
    /\.dSYM\/|\.keychain|\.p12$|private-key|\.git\// { found=1 } END { exit !found }'; then
    echo "Unexpected private/development files in archive." >&2
    exit 1
fi
cd "$work/output"
/usr/bin/shasum -a 256 Battery-Toolkit-1.9.0-macOS.zip > SHA256SUMS.txt
printf 'Source commit: %s\nCertificate pin: %s\n' "$commit" "$pin" > BUILD-INFO.txt
printf 'Verified release files: %s/output\n' "$work"
