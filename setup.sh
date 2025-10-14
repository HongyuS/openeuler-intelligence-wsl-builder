#!/bin/bash

# 一键设置脚本 - 为所有脚本添加执行权限

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "openEuler Intelligence WSL 包构建工具"
echo "========================================="
echo ""
echo "设置脚本执行权限..."

# 主要脚本
chmod +x "$SCRIPT_DIR/build_wsl_package.sh"
chmod +x "$SCRIPT_DIR/build_all_wsl_packages.sh"
chmod +x "$SCRIPT_DIR/verify_wsl_package.sh"

# WSL 配置脚本
if [ -f "$SCRIPT_DIR/wsl/oobe.sh" ]; then
    chmod +x "$SCRIPT_DIR/wsl/oobe.sh"
fi

echo "✅ 所有脚本权限设置完成"
echo ""
echo "可以使用的命令:"
echo "  make wsl-shell-x86_64        - 构建 Shell 变体 x86_64 WSL 包"
echo "  make wsl-all                 - 构建所有 WSL 包"
echo "  make verify-wsl              - 验证 WSL 包"
echo "  make help                    - 查看所有可用命令"
echo ""
echo "或直接运行脚本:"
echo "  ./build_wsl_package.sh --help"
echo "  ./build_all_wsl_packages.sh"
