#!/bin/bash
# build.sh — Build DRONE_GCS with Qt 6.2.4
set -e

QT_PATH="$HOME/Qt/6.2.4/gcc_64"
PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DRONE GCS — Build Script"
echo "  Qt:      $QT_PATH"
echo "  Project: $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install system dependencies if needed
echo "Checking system dependencies..."
sudo apt-get install -y \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libnss3 \
    libxcomposite-dev \
    libxdamage-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxi-dev \
    libxtst-dev \
    2>/dev/null || true

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ""
echo "Running CMake..."
cmake "$PROJECT_DIR" \
    -DCMAKE_PREFIX_PATH="$QT_PATH" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -G "Unix Makefiles"

echo ""
echo "Building ($(nproc) jobs)..."
make -j$(nproc)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Build successful!"
echo "  Run: $BUILD_DIR/DRONE_GCS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
