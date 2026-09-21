#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.."; pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APPDIR="$BUILD_DIR/AppDir"
QT_PATH="$HOME/Qt/6.2.4/gcc_64"
OUTPUT_APPIMAGE="$BUILD_DIR/DRONE_GCS-x86_64.AppImage"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Packaging DRONE_GCS AppImage"
echo "  Project:  $PROJECT_DIR"
echo "  Qt:       $QT_PATH"
echo "  Output:   $OUTPUT_APPIMAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Ensure clean AppDir structure
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/plugins"
mkdir -p "$APPDIR/usr/qml"
mkdir -p "$APPDIR/usr/resources"
mkdir -p "$APPDIR/usr/libexec"
mkdir -p "$APPDIR/usr/translations"
mkdir -p "$APPDIR/map"

# 1. Copy executable and map assets
echo "[1/6] Copying executable & map files..."
cp "$BUILD_DIR/DRONE_GCS" "$APPDIR/usr/bin/"
# Copy map assets next to the binary so appDirPath/map/map.html resolves correctly
mkdir -p "$APPDIR/usr/bin/map"
cp -r "$PROJECT_DIR/map/"* "$APPDIR/usr/bin/map/"
# Also copy at AppDir root as fallback
mkdir -p "$APPDIR/map"
cp -r "$PROJECT_DIR/map/"* "$APPDIR/map/"

# 2. Copy Qt6 Libraries
echo "[2/6] Bundling Qt 6.2.4 core runtime libraries..."
cp -P "$QT_PATH/lib"/libQt6*.so* "$APPDIR/usr/lib/" 2>/dev/null || true
cp -P "$QT_PATH/lib"/libicu*.so* "$APPDIR/usr/lib/" 2>/dev/null || true

# 3. Copy Qt Plugins & WebEngine helper
echo "[3/6] Bundling Qt plugins & WebEngine process..."
cp -r "$QT_PATH/plugins/"* "$APPDIR/usr/plugins/" 2>/dev/null || true

if [ -f "$QT_PATH/libexec/QtWebEngineProcess" ]; then
    cp "$QT_PATH/libexec/QtWebEngineProcess" "$APPDIR/usr/libexec/"
fi

# 4. Copy WebEngine Resources
echo "[4/6] Copying Chromium WebEngine resources & translations..."
if [ -d "$QT_PATH/resources" ]; then
    cp -r "$QT_PATH/resources/"* "$APPDIR/usr/resources/"
fi
if [ -d "$QT_PATH/translations/qtwebengine_locales" ]; then
    mkdir -p "$APPDIR/usr/translations/qtwebengine_locales"
    cp -r "$QT_PATH/translations/qtwebengine_locales/"* "$APPDIR/usr/translations/qtwebengine_locales/"
fi

# 5. Copy QML standard runtime modules and application GCS module
echo "[5/6] Bundling complete QML runtime & modules..."
mkdir -p "$APPDIR/usr/qml"
cp -r "$QT_PATH/qml/"* "$APPDIR/usr/qml/" 2>/dev/null || true
if [ -d "$BUILD_DIR/GCS" ]; then
    cp -r "$BUILD_DIR/GCS" "$APPDIR/usr/qml/"
fi

# 6. Create Desktop file, AppRun, and Icon
echo "[6/6] Generating desktop entry and AppRun launcher..."
cat << 'EOF' > "$APPDIR/DRONE_GCS.desktop"
[Desktop Entry]
Type=Application
Name=DRONE GCS
GenericName=Ground Control Station
Comment=Advanced Multi-Drone Ground Control Station
Exec=DRONE_GCS %F
Icon=DRONE_GCS
Categories=Utility;Science;X-Aerospace;
Terminal=false
StartupNotify=true
EOF

cat << 'EOF' > "$APPDIR/AppRun"
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="${HERE}/usr/plugins"
export QML2_IMPORT_PATH="${HERE}/usr/qml"
export QML_IMPORT_PATH="${HERE}/usr/qml"
export QTWEBENGINEPROCESS_PATH="${HERE}/usr/libexec/QtWebEngineProcess"
export QTWEBENGINE_RESOURCES_PATH="${HERE}/usr/resources"
export QTWEBENGINE_LOCALES_PATH="${HERE}/usr/translations/qtwebengine_locales"
export QTWEBENGINE_CHROMIUM_FLAGS="--disable-web-security --allow-running-insecure-content --ignore-certificate-errors"

# Launch binary
exec "${HERE}/usr/bin/DRONE_GCS" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Generate crisp application icon
python3 -c "
from PIL import Image, ImageDraw
im = Image.new('RGBA', (256, 256), (13, 17, 23, 255))
d = ImageDraw.Draw(im)
# Hexagon background
d.polygon([(128, 16), (232, 76), (232, 196), (128, 256), (24, 196), (24, 76)], fill=(22, 27, 34, 255), outline=(0, 212, 255, 255), width=4)
# Aircraft chevron
d.polygon([(128, 48), (170, 140), (220, 160), (160, 175), (128, 220), (96, 175), (36, 160), (86, 140)], fill=(0, 212, 255, 255), outline=(255, 255, 255, 255), width=3)
d.ellipse([(120, 132), (136, 148)], fill=(255, 255, 255, 255))
im.save('$APPDIR/DRONE_GCS.png')
"

# Package AppImage
echo ""
echo "Creating AppImage using appimagetool..."
rm -f "$OUTPUT_APPIMAGE"
ARCH=x86_64 "$PROJECT_DIR/tools/appimagetool/AppRun" "$APPDIR" "$OUTPUT_APPIMAGE"

chmod +x "$OUTPUT_APPIMAGE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ AppImage generated successfully!"
echo "  Location: $OUTPUT_APPIMAGE"
ls -lh "$OUTPUT_APPIMAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
