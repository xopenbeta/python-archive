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
# 允许通过环境变量覆盖 ARCH
ARCH="${TARGET_ARCH:-$(uname -m)}"

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
        # 使用 RPATH 确保可执行文件能找到共享库
        # $ORIGIN 是特殊变量，表示可执行文件所在目录
        CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-shared --with-lto"
        # 使用 --enable-shared 时必须指定 RPATH
        # 使用 $ORIGIN 使其可移植（相对路径）
        # Correctly escape $ORIGIN for configure -> Makefile -> shell -> compiler
        # We need the compiler to receive: -Wl,-rpath=$ORIGIN/../lib
        CONFIGURE_OPTS="$CONFIGURE_OPTS LDFLAGS='-Wl,-rpath=\$\$ORIGIN/../lib,-rpath=$INSTALL_DIR/lib'"
        if [ "$PYTHON_MAJOR" = "3" ]; then
            CONFIGURE_OPTS="$CONFIGURE_OPTS --with-ssl"
        fi
        ;;
    Darwin*)
        # macOS specific options
        
        # 在 CI 环境中使用 shared 库构建，避免需要 /Applications 权限
        # 本地开发可以设置 USE_FRAMEWORK=1 使用 framework 构建
        if [ "${USE_FRAMEWORK:-0}" = "1" ] && [ "$PYTHON_MAJOR" = "3" ]; then
            CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-framework=$INSTALL_DIR"
            echo "Using framework build (requires /Applications access)"
        else
            CONFIGURE_OPTS="$CONFIGURE_OPTS --enable-shared"
            # macOS 上使用 @loader_path 代替 $ORIGIN，需要转义
            CONFIGURE_OPTS="$CONFIGURE_OPTS LDFLAGS=-Wl,-rpath,@loader_path/../lib"
            echo "Using shared library build (CI-friendly)"
        fi
        
        if [ "$PYTHON_MAJOR" = "2" ]; then
            # Python 2.7 需要特殊处理
            # 禁用 toolbox-glue 避免 'arch' 命令问题
            CONFIGURE_OPTS="$CONFIGURE_OPTS --disable-toolbox-glue"
            
            # 查找 OpenSSL（Python 2.7 使用 openssl@1.1）
            if [ -d "/usr/local/opt/openssl@1.1" ]; then
                CONFIGURE_OPTS="$CONFIGURE_OPTS --with-openssl=/usr/local/opt/openssl@1.1"
            elif [ -d "/opt/homebrew/opt/openssl@1.1" ]; then
                CONFIGURE_OPTS="$CONFIGURE_OPTS --with-openssl=/opt/homebrew/opt/openssl@1.1"
            fi
        else
            # 查找 OpenSSL (Python 3)
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
        
        # Python 2.7 在 Windows 上需要 Visual Studio 2008，在现代 CI 环境中很难构建
        if [ "$PYTHON_MAJOR" = "2" ]; then
            echo "========================================"
            echo "WARNING: Python 2.7 Windows builds are not officially supported"
            echo "Python 2.7.18 requires Visual Studio 2008 which is not available on modern CI runners"
            echo "========================================"
            echo ""
            echo "Attempting to build anyway with available tools..."
            echo ""
        fi
        
        cd PCbuild
        
        if [ "$PYTHON_MAJOR" = "2" ]; then
            # Python 2.7: 尝试使用 build.bat
            # Python 2.7 主要是 x64 支持，ARM64 对于 2.7 可能不支持或非常困难
            # 这里保持 x64 硬编码，或仅在 TARGET_ARCH 为 x64 时运行
            if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
                echo "Error: Python 2.7 on Windows supports x64 only (mostly due to VS2008 requirement)"
                exit 1
            fi
            
            echo "Running: build.bat -e -p x64"
            cmd.exe //c "build.bat -e -p x64" || {
                echo ""
                echo "========================================"
                echo "ERROR: Python 2.7 build failed"
                echo "This is expected on GitHub Actions Windows runners"
                echo "Python 2.7 requires Visual Studio 2008"
                echo "========================================"
                
                # 列出可用文件用于调试
                echo ""
                echo "Available files in PCbuild:"
                ls -la || dir
                
                exit 1
            }
            BUILD_OUTPUT="amd64"
        else
            # Python 3 构建
            # 根据 ARCH 设置 -p 参数
            WIN_PLATFORM="x64"
            BUILD_OUTPUT="amd64"
            
            if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
                WIN_PLATFORM="ARM64"
                BUILD_OUTPUT="arm64"
            fi
            
            echo "Running: build.bat -e -p $WIN_PLATFORM -c Release"
            cmd.exe //c "build.bat -e -p $WIN_PLATFORM -c Release"
        fi
        
        cd ..
        
        # 检查构建输出是否存在
        if [ ! -d "PCbuild/$BUILD_OUTPUT" ]; then
            echo "Error: Build output directory PCbuild/$BUILD_OUTPUT not found"
            echo "Looking for alternative paths..."
            echo ""
            echo "Contents of PCbuild directory:"
            ls -la PCbuild/ || dir PCbuild\
            
            # 尝试其他可能的输出路径
            if [ -d "PCbuild/win32" ]; then
                echo "Found win32 build"
                BUILD_OUTPUT="win32"
            elif [ -d "PCbuild/x64" ]; then
                echo "Found x64 build"
                BUILD_OUTPUT="x64"
            else
                echo "Error: Could not find any build output directory"
                exit 1
            fi
        fi
        
        # 创建安装目录并复制构建结果
        mkdir -p "$INSTALL_DIR"
        echo "Copying build artifacts from PCbuild/$BUILD_OUTPUT to $INSTALL_DIR"
        cp -r PCbuild/$BUILD_OUTPUT/* "$INSTALL_DIR/" || {
            echo "Error: Failed to copy build artifacts"
            exit 1
        }
        
        echo "Python $PYTHON_VERSION built successfully for Windows"
        exit 0
        ;;
    *)
        echo "Warning: Unknown OS type: $OS_TYPE"
        ;;
esac

# Python 2.7 在 macOS 上的特殊修复：修补 configure 脚本
if [ "$PYTHON_MAJOR" = "2" ] && [ "$OS_TYPE" = "Darwin" ]; then
    echo "Applying macOS compatibility patches for Python 2.7..."
    
    # 修复 'arch' 命令检测问题
    # Python 2.7 的 configure 脚本期望 'arch' 返回特定格式，但新版 macOS 格式不同
    if [ -f "configure" ]; then
        # 备份原始 configure
        cp configure configure.orig
        
        # 修复方法1：修补 configure 脚本中检测 arch 的代码
        # 查找并替换导致问题的 arch 检查
        if grep -q "Unexpected output of 'arch' on OSX" configure; then
            echo "Patching arch detection in configure script..."
            # 替换 arch 检测逻辑，使其接受任何 arch 输出
            # fix: The previous patch deleted lines which caused syntax error (missing esac)
            # New patch replaces the error call with a default arch assignment, preserving structure
            sed -i.bak "/Unexpected output of .arch. on OSX/s/as_fn_error.*/MACOSX_DEFAULT_ARCH=\"$ARCH\"/" configure
        fi
        
        # 修复方法2：设置环境变量以绕过某些检查
        echo "Setting compatibility environment variables..."
        export ac_cv_have_long_long_format=yes
        
        # 修复方法3：在 macOS 上明确设置 ARCHFLAGS
        if [ "$ARCH" = "x86_64" ]; then
            export ARCHFLAGS="-arch x86_64"
        elif [ "$ARCH" = "arm64" ]; then
            export ARCHFLAGS="-arch arm64"
        fi
    fi
fi

# 编译
echo "Building Python (this may take a while)..."
echo "Configure options: $CONFIGURE_OPTS"

# Pre-check compiler to debug "C compiler cannot create executables"
echo "Checking compiler basic functionality..."
echo 'int main() { return 0; }' > test_compile.c
if gcc test_compile.c -o test_compile; then
    echo "Compiler basic check passed."
    rm -f test_compile test_compile.c
else
    echo "Compiler basic check FAILED."
    echo "GCC Version:"
    gcc --version
    rm -f test_compile.c
    # Do not exit, let configure fail and show log
fi

if ! ./configure $CONFIGURE_OPTS; then
    echo "=========================================="
    echo "CONFIGURE FAILED"
    echo "=========================================="
    
    if [ -f config.log ]; then
        echo "Tailing config.log (last 100 lines):"
        tail -n 100 config.log
    else
        echo "config.log not found!"
    fi
    exit 1
fi

# 使用多核编译
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "Using $NPROC parallel jobs"
make -j"$NPROC"

# 运行测试（可选，较慢）
# echo "Running tests..."
# make test

# 安装
echo "Installing Python..."
if [ "$OS_TYPE" = "Darwin" ] && [ "${USE_FRAMEWORK:-0}" = "0" ]; then
    # shared 库构建：使用 altinstall 避免安装到 /Applications
    # altinstall 不会安装 Python.app 和 Python Launcher.app
    echo "Using 'make altinstall' (CI-friendly, skips /Applications)"
    make altinstall
    
    # 手动创建 python/python3 链接（altinstall 不创建）
    if [ "$PYTHON_MAJOR" = "3" ]; then
        cd "$INSTALL_DIR/bin"
        # 查找实际安装的 python 可执行文件（如 python3.13）
        PYTHON_VERSIONED=$(ls python3.* 2>/dev/null | head -n1)
        if [ -n "$PYTHON_VERSIONED" ] && [ ! -e "python3" ]; then
            echo "Creating python3 symlink to $PYTHON_VERSIONED"
            ln -s "$PYTHON_VERSIONED" python3
        fi
        if [ ! -e "python" ]; then
            echo "Creating python symlink to python3"
            ln -s python3 python
        fi
        cd -
    elif [ "$PYTHON_MAJOR" = "2" ]; then
        cd "$INSTALL_DIR/bin"
        if [ -f "python2.7" ] && [ ! -e "python2" ]; then
            echo "Creating python2 symlink to python2.7"
            ln -s python2.7 python2
        fi
        if [ ! -e "python" ]; then
            echo "Creating python symlink to python2"
            ln -s python2 python
        fi
        cd -
    fi
else
    # Framework 构建或其他平台使用常规安装
    make install
fi

# 对于 Linux/macOS shared 构建，确保运行时能找到共享库
if [ "$OS_TYPE" = "Linux" ] || [ "$OS_TYPE" = "Darwin" ]; then
    # 临时设置 LD_LIBRARY_PATH/DYLD_LIBRARY_PATH 用于后续命令
    if [ "$OS_TYPE" = "Linux" ]; then
        export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
        echo "Set LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
    else
        export DYLD_LIBRARY_PATH="$INSTALL_DIR/lib:${DYLD_LIBRARY_PATH:-}"
        echo "Set DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH"
    fi
fi

# 对于 Python 3，安装 pip
if [ "$PYTHON_MAJOR" = "3" ]; then
    echo "Installing pip..."
    "$INSTALL_DIR/bin/python3" -m ensurepip
    # use python -m pip instead of calling pip3 directly to avoid "No such file or directory" errors
    "$INSTALL_DIR/bin/python3" -m pip install --upgrade pip setuptools wheel
fi

# 验证安装
echo "Verifying installation..."
if [ "$PYTHON_MAJOR" = "2" ]; then
    "$INSTALL_DIR/bin/python2" --version
else
    "$INSTALL_DIR/bin/python3" --version
fi

# 检查 RPATH 设置（调试用）
if [ "$OS_TYPE" = "Linux" ]; then
    echo "Checking RPATH configuration..."
    if [ "$PYTHON_MAJOR" = "2" ]; then
        readelf -d "$INSTALL_DIR/bin/python2" | grep -i rpath || echo "No RPATH found"
    else
        readelf -d "$INSTALL_DIR/bin/python3" | grep -i rpath || echo "No RPATH found"
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    echo "Checking RPATH configuration..."
    if [ "$PYTHON_MAJOR" = "2" ]; then
        otool -l "$INSTALL_DIR/bin/python2" | grep -A 2 LC_RPATH || echo "No RPATH found"
    else
        otool -l "$INSTALL_DIR/bin/python3" | grep -A 2 LC_RPATH || echo "No RPATH found"
    fi
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
Build Type: Portable with embedded RPATH
EOF

# 为 Linux/macOS 创建使用说明
if [ "$OS_TYPE" = "Linux" ] || [ "$OS_TYPE" = "Darwin" ]; then
    cat > "$INSTALL_DIR/README.txt" << 'EOF'
# Portable Python Distribution

This is a portable Python distribution with embedded RPATH.
It can be moved anywhere and does not require system installation.

## Usage

Direct execution:
    ./bin/python --version
    ./bin/pip --version

Add to PATH (optional):
    export PATH="$(pwd)/bin:$PATH"

## Notes

- All shared libraries are included in the lib/ directory
- RPATH is configured to find libraries relative to the executable
- No need to set LD_LIBRARY_PATH or DYLD_LIBRARY_PATH manually
EOF
fi

echo "=========================================="
echo "Python $PYTHON_VERSION built successfully!"
echo "Installation directory: $INSTALL_DIR"
echo "=========================================="
