.PHONY: help build build-py2 build-py3 clean test release check-deps

# 默认目标
help:
	@echo "Python Archive - Makefile Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  help        - Show this help message"
	@echo "  check-deps  - Check if all dependencies are installed"
	@echo "  build       - Build both Python 2 and Python 3"
	@echo "  build-py2   - Build Python 2.7.18 only"
	@echo "  build-py3   - Build Python 3.13.1 only"
	@echo "  test        - Run build tests"
	@echo "  clean       - Clean build artifacts"
	@echo "  distclean   - Clean all generated files"
	@echo "  release     - Show release instructions"
	@echo ""
	@echo "Environment variables:"
	@echo "  PYTHON2_VERSION - Python 2 version to build (default: 2.7.18)"
	@echo "  PYTHON3_VERSION - Python 3 version to build (default: 3.13.1)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-py3              # Build Python 3"
	@echo "  make build                  # Build both versions"
	@echo "  make clean                  # Clean build files"

# 加载版本配置
-include versions.env
export

# 检查依赖
check-deps:
	@echo "Checking dependencies..."
	@command -v gcc >/dev/null 2>&1 || { echo "Error: gcc not found. Please install build tools."; exit 1; }
	@command -v make >/dev/null 2>&1 || { echo "Error: make not found."; exit 1; }
	@command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || { echo "Error: wget or curl required."; exit 1; }
	@echo "✓ All dependencies found"

# 构建 Python 2
build-py2: check-deps
	@echo "Building Python 2.7.18..."
	@chmod +x scripts/build-python.sh
	@./scripts/build-python.sh 2.7.18

# 构建 Python 3
build-py3: check-deps
	@echo "Building Python 3.13.1..."
	@chmod +x scripts/build-python.sh
	@./scripts/build-python.sh 3.13.1

# 构建所有版本
build: build-py3 build-py2
	@echo "All Python versions built successfully!"

# 测试构建
test: build-py3
	@echo "Testing Python 3 build..."
	@./dist/python-3.13.1/bin/python3 --version
	@./dist/python-3.13.1/bin/pip3 --version
	@./dist/python-3.13.1/bin/python3 -c "import ssl, sqlite3, json; print('✓ Basic modules work')"
	@echo "✓ Python 3 tests passed"

# 清理构建文件
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/
	@echo "✓ Build directory cleaned"

# 完全清理
distclean: clean
	@echo "Cleaning distribution files..."
	@rm -rf dist/
	@echo "✓ All generated files cleaned"

# 显示发布说明
release:
	@echo "To create a new release:"
	@echo ""
	@echo "1. Update versions in versions.env if needed"
	@echo "2. Test locally: make test"
	@echo "3. Update CHANGELOG.md"
	@echo "4. Commit changes: git add . && git commit -m 'chore: prepare release vYYYY.MM.DD'"
	@echo "5. Create tag: git tag -a vYYYY.MM.DD -m 'Release vYYYY.MM.DD'"
	@echo "6. Push tag: git push origin vYYYY.MM.DD"
	@echo ""
	@echo "GitHub Actions will automatically build and create the release."
	@echo ""
	@echo "For detailed instructions, see RELEASE_CHECKLIST.md"

# 显示构建状态
status:
	@echo "Build Status:"
	@echo ""
	@if [ -d "dist/python-3.13.1" ]; then \
		echo "✓ Python 3.13.1: Built"; \
		./dist/python-3.13.1/bin/python3 --version 2>/dev/null || echo "  (but not executable)"; \
	else \
		echo "✗ Python 3.13.1: Not built"; \
	fi
	@if [ -d "dist/python-2.7.18" ]; then \
		echo "✓ Python 2.7.18: Built"; \
		./dist/python-2.7.18/bin/python2 --version 2>/dev/null || echo "  (but not executable)"; \
	else \
		echo "✗ Python 2.7.18: Not built"; \
	fi

# 创建发布包
package: build
	@echo "Creating release packages..."
	@cd dist && \
	if [ -d "python-3.13.1" ]; then \
		tar czf python-3.13.1-$$(uname -s)-$$(uname -m).tar.gz python-3.13.1/; \
		echo "✓ Created python-3.13.1-$$(uname -s)-$$(uname -m).tar.gz"; \
	fi
	@cd dist && \
	if [ -d "python-2.7.18" ]; then \
		tar czf python-2.7.18-$$(uname -s)-$$(uname -m).tar.gz python-2.7.18/; \
		echo "✓ Created python-2.7.18-$$(uname -s)-$$(uname -m).tar.gz"; \
	fi
	@echo "Generating checksums..."
	@cd dist && sha256sum *.tar.gz > SHA256SUMS.txt 2>/dev/null || shasum -a 256 *.tar.gz > SHA256SUMS.txt
	@echo "✓ Packages created in dist/"

# 快速开始（新用户）
quickstart:
	@echo "Python Archive - Quick Start"
	@echo ""
	@echo "This will build Python 3.13.1 for testing..."
	@echo ""
	@make check-deps
	@echo ""
	@read -p "Continue? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		make build-py3; \
		make test; \
		echo ""; \
		echo "✓ Quick start complete!"; \
		echo ""; \
		echo "Python 3 is now available at: ./dist/python-3.13.1/bin/python3"; \
		echo ""; \
		echo "Next steps:"; \
		echo "  - Try: ./dist/python-3.13.1/bin/python3 --version"; \
		echo "  - Read: cat QUICKSTART.md"; \
		echo "  - Build Python 2: make build-py2"; \
	fi
