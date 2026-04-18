#!/bin/bash

# build_wine.sh
# This script constructs the Whisky Libraries environment COMPLETELY from upstream open-source sources,
# ensuring 100% independence from deprecated Whisky servers.

set -e

OUTPUT_DIR="build_output"
LIBRARIES_DIR="$OUTPUT_DIR/Libraries"
WINE_DIR="$LIBRARIES_DIR/Wine"
DXVK_DIR="$LIBRARIES_DIR/DXVK"

echo "==> Preparing independent build environment"
rm -rf "$OUTPUT_DIR"
mkdir -p "$WINE_DIR" "$DXVK_DIR"

fetch_github_api() {
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -s -H "Authorization: token $GITHUB_TOKEN" "$1"
    else
        curl -s "$1"
    fi
}

# -----------------------------------------------------------------------------
# 1. Fetch Wine Core from Gcenx
# -----------------------------------------------------------------------------
echo "==> Fetching latest upstream Wine from Gcenx/macOS_Wine_builds..."
WINE_RELEASE_API="https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases/latest"
WINE_TAG=$(fetch_github_api "$WINE_RELEASE_API" | grep '"tag_name"' | cut -d '"' -f 4)
WINE_DOWNLOAD_URL=$(fetch_github_api "$WINE_RELEASE_API" | grep "browser_download_url.*wine-devel.*osx64.tar.xz" | head -n 1 | cut -d '"' -f 4)

if [ -z "$WINE_DOWNLOAD_URL" ]; then
    echo "Failed to find Wine download URL."
    exit 1
fi

echo "    Downloading: $WINE_DOWNLOAD_URL"
curl -sL "$WINE_DOWNLOAD_URL" -o "$OUTPUT_DIR/wine.tar.xz"
echo "    Extracting Wine..."
tar -xf "$OUTPUT_DIR/wine.tar.xz" -C "$WINE_DIR" --strip-components=1
rm -f "$OUTPUT_DIR/wine.tar.xz"

# -----------------------------------------------------------------------------
# 2. Fetch DXVK from doitsujin
# -----------------------------------------------------------------------------
echo "==> Fetching latest upstream DXVK from doitsujin/dxvk..."
DXVK_RELEASE_API="https://api.github.com/repos/doitsujin/dxvk/releases/latest"
DXVK_DOWNLOAD_URL=$(fetch_github_api "$DXVK_RELEASE_API" | grep "browser_download_url.*dxvk-.*.tar.gz" | head -n 1 | cut -d '"' -f 4)

echo "    Downloading: $DXVK_DOWNLOAD_URL"
curl -sL "$DXVK_DOWNLOAD_URL" -o "$OUTPUT_DIR/dxvk.tar.gz"
echo "    Extracting DXVK..."
mkdir -p "$OUTPUT_DIR/dxvk_extract"
tar -xzf "$OUTPUT_DIR/dxvk.tar.gz" -C "$OUTPUT_DIR/dxvk_extract" --strip-components=1

# Copy x32 and x64 DLLs to the Whisky structure
cp -r "$OUTPUT_DIR/dxvk_extract/x32" "$DXVK_DIR/x32"
cp -r "$OUTPUT_DIR/dxvk_extract/x64" "$DXVK_DIR/x64"
rm -rf "$OUTPUT_DIR/dxvk_extract" "$OUTPUT_DIR/dxvk.tar.gz"

# -----------------------------------------------------------------------------
# 3. Fetch Winetricks and Generate Verbs
# -----------------------------------------------------------------------------
echo "==> Fetching latest Winetricks..."
curl -sL "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -o "$LIBRARIES_DIR/winetricks"
chmod +x "$LIBRARIES_DIR/winetricks"

echo "==> Generating verbs.txt list..."
"$LIBRARIES_DIR/winetricks" list-all 2>/dev/null > "$LIBRARIES_DIR/verbs.txt"

# -----------------------------------------------------------------------------
# 4. Generate Version Manifest
# -----------------------------------------------------------------------------
echo "==> Generating WhiskyWineVersion.plist"
cat <<EOF > "$LIBRARIES_DIR/WhiskyWineVersion.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>version</key>
	<string>$WINE_TAG</string>
</dict>
</plist>
EOF

# -----------------------------------------------------------------------------
# 5. Package for Release
# -----------------------------------------------------------------------------
echo "==> Packaging Libraries.tar.gz"
cd "$OUTPUT_DIR"
tar -czf Libraries.tar.gz Libraries/

echo "==> Independent Build Complete!"
echo "Libraries.tar.gz is ready. Wine version: $WINE_TAG"
