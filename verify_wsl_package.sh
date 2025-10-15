#!/bin/bash

# WSL 包验证脚本
# 用于验证构建的 WSL 包是否符合规范

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() {
    echo -e "${GREEN}✅${NC} $1"
}

log_fail() {
    echo -e "${RED}❌${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

if [ $# -lt 1 ]; then
    echo "用法: $0 <wsl-file>"
    echo ""
    echo "示例:"
    echo "  $0 openEuler-Intelligence-Shell.x86_64.wsl"
    exit 1
fi

WSL_FILE="$1"

if [ ! -f "$WSL_FILE" ]; then
    log_fail "文件不存在: $WSL_FILE"
    exit 1
fi

echo "验证 WSL 包: $(basename "$WSL_FILE")"
echo ""

FAILED=0

# 检查文件扩展名
echo "1. 检查文件扩展名..."
if [[ "$WSL_FILE" == *.wsl ]]; then
    log_ok "文件扩展名正确 (.wsl)"
else
    log_fail "文件扩展名错误，应该是 .wsl"
    FAILED=1
fi

# 检查文件类型
echo ""
echo "2. 检查文件类型..."
FILE_TYPE=$(file "$WSL_FILE" | grep -o "gzip compressed data" || echo "")
if [ -n "$FILE_TYPE" ]; then
    log_ok "文件类型正确 (gzip compressed)"
else
    log_fail "文件类型错误，应该是 gzip 压缩的 tar 文件"
    FAILED=1
fi

# 检查校验和文件
echo ""
echo "3. 检查 SHA256 校验和文件..."
CHECKSUM_FILE="${WSL_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    log_ok "校验和文件存在"

    echo "   验证校验和..."
    FILE_DIR=$(dirname "$WSL_FILE")
    CHECKSUM_BASENAME=$(basename "$CHECKSUM_FILE")

    # 尝试验证校验和
    verify_output=""
    verify_result=1

    if command -v sha256sum &>/dev/null; then
        # 使用 sha256sum 验证
        verify_output=$(cd "$FILE_DIR" && sha256sum -c "$CHECKSUM_BASENAME" 2>&1)
        if echo "$verify_output" | grep -q "OK"; then
            verify_result=0
        fi
    elif command -v shasum &>/dev/null; then
        # 使用 shasum 验证
        verify_output=$(cd "$FILE_DIR" && shasum -a 256 -c "$CHECKSUM_BASENAME" 2>&1)
        if echo "$verify_output" | grep -q "OK"; then
            verify_result=0
        fi
    fi

    if [ $verify_result -eq 0 ]; then
        log_ok "校验和验证通过"
    else
        log_fail "校验和验证失败"
        echo "   输出: $verify_output"
        FAILED=1
    fi
else
    log_warn "校验和文件不存在: $CHECKSUM_FILE"
fi

# 创建临时目录提取并检查内容
echo ""
echo "4. 检查 WSL 包内容..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if tar -tzf "$WSL_FILE" >"$TEMP_DIR/filelist.txt" 2>/dev/null; then
    log_ok "WSL 包可以正常解压"

    # 检查必需的配置文件
    echo ""
    echo "5. 检查必需的配置文件..."

    if grep -q "^etc/wsl.conf$" "$TEMP_DIR/filelist.txt" || grep -q "^./etc/wsl.conf$" "$TEMP_DIR/filelist.txt"; then
        log_ok "包含 /etc/wsl.conf"
    else
        log_fail "缺少 /etc/wsl.conf"
        FAILED=1
    fi

    if grep -q "^etc/wsl-distribution.conf$" "$TEMP_DIR/filelist.txt" || grep -q "^./etc/wsl-distribution.conf$" "$TEMP_DIR/filelist.txt"; then
        log_ok "包含 /etc/wsl-distribution.conf"
    else
        log_fail "缺少 /etc/wsl-distribution.conf"
        FAILED=1
    fi

    # 检查不应该包含的目录
    echo ""
    echo "6. 检查排除的目录..."

    EXCLUDED_DIRS=("sys/" "run/" "proc/" "dev/" "boot/" "lost+found/" "afs/")
    EXCLUDED_FOUND=0

    for dir in "${EXCLUDED_DIRS[@]}"; do
        if grep -q "^${dir}" "$TEMP_DIR/filelist.txt" || grep -q "^./${dir}" "$TEMP_DIR/filelist.txt"; then
            log_fail "不应该包含目录: /$dir"
            EXCLUDED_FOUND=1
            FAILED=1
        fi
    done

    if [ $EXCLUDED_FOUND -eq 0 ]; then
        log_ok "已正确排除不需要的目录"
    fi

    # 检查缓存和日志目录
    echo ""
    echo "7. 检查缓存和日志目录..."

    if grep -q "^root/.cache/" "$TEMP_DIR/filelist.txt" || grep -q "^./root/.cache/" "$TEMP_DIR/filelist.txt"; then
        log_fail "不应该包含 /root/.cache"
        FAILED=1
    else
        log_ok "已排除 /root/.cache"
    fi

    if grep -q "^var/cache/" "$TEMP_DIR/filelist.txt" || grep -q "^./var/cache/" "$TEMP_DIR/filelist.txt"; then
        log_fail "不应该包含 /var/cache"
        FAILED=1
    else
        log_ok "已排除 /var/cache"
    fi

    if grep -q "^var/log/" "$TEMP_DIR/filelist.txt" || grep -q "^./var/log/" "$TEMP_DIR/filelist.txt"; then
        log_fail "不应该包含 /var/log"
        FAILED=1
    else
        log_ok "已排除 /var/log"
    fi

    # 检查不应该包含的文件
    echo ""
    echo "8. 检查特殊文件..."

    if grep -q "^etc/resolv.conf$" "$TEMP_DIR/filelist.txt" || grep -q "^./etc/resolv.conf$" "$TEMP_DIR/filelist.txt"; then
        log_fail "不应该包含 /etc/resolv.conf (WSL 会自动生成)"
        FAILED=1
    else
        log_ok "已排除 /etc/resolv.conf"
    fi

    # 统计文件数量
    echo ""
    echo "9. 包统计信息..."
    TOTAL_FILES=$(wc -l <"$TEMP_DIR/filelist.txt")
    FILE_SIZE=$(du -h "$WSL_FILE" | cut -f1)

    echo "   总文件数: $TOTAL_FILES"
    echo "   包大小: $FILE_SIZE"

else
    log_fail "无法解压 WSL 包"
    FAILED=1
fi

# 总结
echo ""
echo "========================================="
if [ $FAILED -eq 0 ]; then
    log_ok "所有检查通过！WSL 包符合规范"
    echo ""
    echo "可以在 Windows 上安装："
    echo "  wsl --install --from-file $(basename "$WSL_FILE")"
    exit 0
else
    log_fail "部分检查失败，请检查构建过程"
    exit 1
fi
