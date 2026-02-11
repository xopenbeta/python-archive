#!/bin/bash
set -euo pipefail

PYTHON_VERSION="${1:-3.13.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
INSTALL_DIR="$DIST_DIR/python-$PYTHON_VERSION"

echo "=========================================="
echo "Building Python $PYTHON_VERSION"
echo "=========================================="

# 创建构建目录
mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"

# 检测操作系统和架构
OS_TYPE="$(uname -s)"
ARCH="$(uname -m)"

echo "Operating System: $OS_TYPE"
echo "Architecture: $ARCH"

# 确定 Python 主版本
if [[ "$PYTHON_VERSION" == 2.* ]]; then
    PYTHON_MAJOR="2"
    DOWNLOAD_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
elif [[ "$PYTHON_VERSION" == 3.* ]]; then
    PYTHON_MAJOR="3"
    DOWNLOAD_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
else
    echo "Error: Unsupported Python version: $PYTHON_VERSION"
    exit 1
fi

# 下载 Python 源代码
echo "Downloading Python $PYTHON_VERSION..."
cd "$BUILD_DIR"

if [ ! -f "Python-$PYTHON_VERSION.tgz" ]; then
    wget -q --show-progress "$DOWNLOAD_URL" || curl -L -O "$DOWNLOAD_URL"
fi

# 解压源代码
echo "Extracting Python source..."
tar xzf "Python-$PYTHON_VERSION.tgz"
cd "Python-$PYTHON_VERSION"

# 配置编译选项
echo "Configuring build..."
CONFIGURE_OPTS="--prefix=$INSTALL_DIR --enable-optimizations"

# 针对不同操作系统的特殊配置
case "$OS_TYPE" in
    Linux*)
        CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-shared --with-lto"
        if [ "$PYTHON_MAJOR" = "3" ]; then
            CONFIGURE_OPTS="$CONFIGURE_OPTS --with-ssl"
        fi
        ;;
    Darwin*)
        # macOS specific options
        CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-framework=$INSTALL_DIR"
        if [ "$PYTHON_MAJOR" = "3" ]; then
            # 查找 OpenSSL
            if [ -d "/usr/local/opt/openssl@3" ]; then
                CONFIGURE_OPTS="$CONFIGURE_OPTS --with-openssl=/usr/local/opt/openssl@3"
            elif [ -d "/opt/homebrew/opt/openssl@3" ]; then
                CONFIGURE_OPTS="$CONFIGURE_OPTS --with-openssl=/opt/homebrew/opt/openssl@3"
            fi
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Windows build using MSBuild
        echo "Building Python on Windows..."
        cd PCbuild
        if [ "$PYTHON_MAJOR" = "2" ]; then
            ./build.bat -e -p x64
        else
            ./build.bat -e -p x64 -c Release
        fi
        cd ..
        
        # 复制构建结果
        if [ "$PYTHON_MAJOR" = "2" ]; then
            cp -r PCbuild/amd64 "$INSTALL_DIR"
        else
            cp -r PCbuild/amd64 "$INSTALL_DIR"
        fi
        
        echo "Python $PYTHON_VERSION built successfully for Windows"
        exit 0
        ;;
    *)
        echo "Warning: Unknown OS type: $OS_TYPE"
        ;;
esac

# 编译
echo "Building Python (this may take a while)..."
./configure $CONFIGURE_OPTS

# 使用多核编译
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "Using $NPROC parallel jobs"
make -j"$NPROC"

# 运行测试（可选，较慢）
# echo "Running tests..."
# make test

# 安装
echo "Installing Python..."
make install

# 对于 Python 3，安装 pip
if [ "$PYTHON_MAJOR" = "3" ]; then
    echo "Installing pip..."
    "$INSTALL_DIR/bin/python3" -m ensurepip
    "$INSTALL_DIR/bin/pip3" install --upgrade pip setuptools wheel
fi

# 验证安装
echo "Verifying installation..."
if [ "$PYTHON_MAJOR" = "2" ]; then
    "$INSTALL_DIR/bin/python2" --version
else
    "$INSTALL_DIR/bin/python3" --version
fi

# 创建符号链接
cd "$INSTALL_DIR/bin"
if [ "$PYTHON_MAJOR" = "3" ]; then
    ln -sf python3 python
    ln -sf pip3 pip
fi

# 清理构建文件以减小体积
echo "Cleaning up build artifacts..."
cd "$BUILD_DIR/Python-$PYTHON_VERSION"
make clean || true

# 创建版本信息文件
cat > "$INSTALL_DIR/VERSION.txt" << EOF
Python Version: $PYTHON_VERSION
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Operating System: $OS_TYPE
Architecture: $ARCH
EOF

echo "=========================================="
echo "Python $PYTHON_VERSION built successfully!"
echo "Installation directory: $INSTALL_DIR"
echo "=========================================="
