#!/bin/bash
# 本地测试构建脚本

set -euo pipefail

echo "Testing Python build script..."
echo "This script will build Python locally for testing purposes"
echo ""

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载版本配置
if [ -f "$PROJECT_ROOT/versions.env" ]; then
    source "$PROJECT_ROOT/versions.env"
else
    PYTHON2_VERSION="2.7.18"
    PYTHON3_VERSION="3.13.1"
fi

echo "Available Python versions to build:"
echo "  1) Python 2: $PYTHON2_VERSION"
echo "  2) Python 3: $PYTHON3_VERSION"
echo "  3) Both versions"
echo ""

read -p "Select version to build (1/2/3): " choice

case $choice in
    1)
        echo "Building Python 2..."
        bash "$SCRIPT_DIR/build-python.sh" "$PYTHON2_VERSION"
        ;;
    2)
        echo "Building Python 3..."
        bash "$SCRIPT_DIR/build-python.sh" "$PYTHON3_VERSION"
        ;;
    3)
        echo "Building both versions..."
        bash "$SCRIPT_DIR/build-python.sh" "$PYTHON2_VERSION"
        bash "$SCRIPT_DIR/build-python.sh" "$PYTHON3_VERSION"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Build complete! Check the dist/ directory for output."
