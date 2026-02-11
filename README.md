# Python Archive

这个项目用于构建和发布 Python 的独立可分发版本，支持多个平台。类似于 [python-build-standalone](https://github.com/astral-sh/python-build-standalone)，但专注于打包最新的 Python 2 和 Python 3 版本。

# 快速开始指南

本指南帮助您快速开始使用 Python Archive 项目。

## 🎯 目标

构建并发布 Python 2.7.18 和 Python 3.13.1 的独立发行版。

### 📋 支持的平台

| Python 版本 | Linux | macOS | Windows |
|-----------|-------|-------|---------|
| 2.7.18    | ✅    | ✅    | ❌*     |
| 3.13.1    | ✅    | ✅    | ✅      |

> **⚠️ Python 2.7 Windows 限制说明**
>
> Python 2.7.18 虽然维护到 2020 年，但其构建系统从未现代化：
> - 硬编码使用 **Visual Studio 2008 (VS 9.0)**，发布于 2007 年
> - VS 2008 在 Windows 10/11 和 CI 环境中已不可用
> - 使用现代编译器会导致与官方扩展的 ABI 不兼容
> 
> **解决方案：** 如需 Windows 版本，请从 [python.org](https://www.python.org/downloads/release/python-2718/) 下载官方预编译版本。

## 📤 发布到 GitHub Release

### 方法 1: 通过标签触发（推荐）

```bash
# 创建版本标签
git tag -a v202602112000 -m "Release Python 2.7.18 and 3.13.1"

# 推送标签触发 CI/CD
git push origin v202602112000
```

### 方法 2: 手动触发

1. 访问仓库的 **Actions** 页面
2. 选择 **Build and Release Python Archives** 工作流
3. 点击 **Run workflow**
4. 输入 release tag（例如：`v2024.01.01`）
5. 点击 **Run workflow** 按钮

### 自动化流程

GitHub Actions 将自动：
1. ✅ 在 Linux、macOS 上构建 Python 2.7.18
2. ✅ 在 Linux、macOS、Windows 上构建 Python 3.13.1
3. ✅ 创建压缩包（.tar.gz 和 .zip）
4. ✅ 生成 SHA256 校验和
5. ✅ 创建 GitHub Release
6. ✅ 上传所有构建产物

构建完成后（约 30-60 分钟），您可以在 **Releases** 页面找到新版本。
