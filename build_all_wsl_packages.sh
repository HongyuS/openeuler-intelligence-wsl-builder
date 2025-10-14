#!/bin/bash

# 批量构建所有 WSL 包的脚本
# 用法: ./build_all_wsl_packages.sh [--output-dir DIR]

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 解析参数
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
    --output-dir)
        OUTPUT_DIR="$2"
        shift 2
        ;;
    *)
        echo "未知选项: $1"
        echo "用法: $0 [--output-dir DIR]"
        exit 1
        ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/wsl_packages"
fi

mkdir -p "$OUTPUT_DIR"

log_info "========================================="
log_info "批量构建 WSL 包"
log_info "========================================="
log_info "输出目录: $OUTPUT_DIR"
log_info ""

VARIANTS=("shell" "web")
ARCHS=("x86_64" "aarch64")

TOTAL=$((${#VARIANTS[@]} * ${#ARCHS[@]}))
CURRENT=0
FAILED=0

START_TIME=$(date +%s)

for variant in "${VARIANTS[@]}"; do
    for arch in "${ARCHS[@]}"; do
        CURRENT=$((CURRENT + 1))

        log_step "[$CURRENT/$TOTAL] 构建 ${variant} ${arch}..."

        # 捕获构建输出和退出码
        BUILD_LOG=$(mktemp)
        BUILD_ERROR=0

        if ! "$SCRIPT_DIR/build_wsl_package.sh" --variant "$variant" --arch "$arch" --output-dir "$OUTPUT_DIR" 2>&1 | tee "$BUILD_LOG"; then
            BUILD_ERROR=$?
        fi

        if [ $BUILD_ERROR -eq 0 ]; then
            log_info "✅ ${variant} ${arch} 构建成功"
        else
            log_info "❌ ${variant} ${arch} 构建失败 (退出码: $BUILD_ERROR)"
            FAILED=$((FAILED + 1))
        fi

        rm -f "$BUILD_LOG"

        echo ""
    done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log_info "========================================="
log_info "批量构建完成"
log_info "========================================="
log_info "总用时: ${DURATION}s"
log_info "成功: $((TOTAL - FAILED))/$TOTAL"
log_info "失败: $FAILED/$TOTAL"
log_info ""
log_info "所有 WSL 包位于: $OUTPUT_DIR"
log_info ""

if [ $FAILED -eq 0 ]; then
    log_info "✅ 所有构建成功!"

    log_info ""
    log_info "生成的文件:"
    ls -lh "$OUTPUT_DIR"/*.wsl 2>/dev/null || true

    exit 0
else
    log_info "❌ 部分构建失败"
    exit 1
fi
