#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
BUILD="${ROOT}/build/pkg"
APP="${BUILD}/payload/Applications/Homey Work Insights.app"
IDENTIFIER="com.homey.work-insights.agent"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/scripts"

cd "$ROOT/agent"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/HomeyAgent"

cp "$BIN" "$APP/Contents/MacOS/HomeyAgent"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>Homey Work Insights</string>
<key>CFBundleExecutable</key><string>HomeyAgent</string>
<key>CFBundleIdentifier</key><string>${IDENTIFIER}</string>
<key>CFBundleName</key><string>Homey Work Insights</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundleVersion</key><string>${VERSION}</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

cat > "$APP/Contents/Resources/README.txt" <<EOF
Homey Work Insights Agent ${VERSION}
Bundle ID: ${IDENTIFIER}

This application is managed by Homey IT through Scalefusion.
Screen capture remains disabled unless the managed policy enables it.
EOF

chmod 755 "$APP/Contents/MacOS/HomeyAgent"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

pkgbuild \
  --root "${BUILD}/payload" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  --scripts "${BUILD}/scripts" \
  "${BUILD}/HomeyWorkInsights-${VERSION}.pkg"

PKG="${BUILD}/HomeyWorkInsights-${VERSION}.pkg"
if [[ -n "${DEVELOPER_ID_INSTALLER:-}" ]]; then
  productsign --sign "$DEVELOPER_ID_INSTALLER" "$PKG" "${BUILD}/HomeyWorkInsights-${VERSION}-signed.pkg"
  mv "${BUILD}/HomeyWorkInsights-${VERSION}-signed.pkg" "$PKG"
  pkgutil --check-signature "$PKG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG"
fi

mkdir -p "$ROOT/dist"
cp "$PKG" "$ROOT/dist/HomeyWorkInsights-${VERSION}.pkg"
echo "Built: $ROOT/dist/HomeyWorkInsights-${VERSION}.pkg"
