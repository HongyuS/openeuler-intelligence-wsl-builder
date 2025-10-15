#!/bin/bash
#
# 清理脚本 - 清理 WSL 构建过程中生成的所有文件和临时目录
# 用于 openEuler Intelligence WSL 包构建项目
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 工作目录
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$WORK_DIR"

log_info "开始清理 WSL 构建文件..."
log_info "工作目录: $WORK_DIR"

# 1. 清理临时目录（可能被进程占用）
log_info "清理临时目录..."
TEMP_DIRS=$(find . -maxdepth 1 -type d -name "wsl_temp*" 2>/dev/null || true)

if [ -n "$TEMP_DIRS" ]; then
    for dir in $TEMP_DIRS; do
        log_info "处理临时目录: $dir"
        
        # 检查是否有进程占用
        PROCESSES=$(sudo lsof +D "$dir" 2>/dev/null | tail -n +2 | awk '{print $2}' | sort -u || true)
        
        if [ -n "$PROCESSES" ]; then
            log_warn "发现进程占用目录: $dir"
            echo "$PROCESSES" | while read -r pid; do
                PNAME=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                log_warn "  进程 $pid ($PNAME) 正在使用该目录"
            done
            
            # 询问是否强制终止进程
            read -p "是否强制终止这些进程并删除目录? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "终止占用进程..."
                sudo fuser -k "$dir" 2>/dev/null || true
                sleep 1
            else
                log_warn "跳过目录: $dir"
                continue
            fi
        fi
        
        # 修改权限以确保可以删除
        if [ -d "$dir" ]; then
            log_info "修改目录权限..."
            sudo chmod -R u+w "$dir" 2>/dev/null || true
            
            log_info "删除目录: $dir"
            if sudo rm -rf "$dir"; then
                log_info "✅ 已删除: $dir"
            else
                log_error "❌ 删除失败: $dir"
            fi
        fi
    done
else
    log_info "未找到临时目录"
fi

# 2. 清理 WSL 包文件（可选）
log_info "检查 WSL 包文件..."
WSL_FILES=$(ls openEuler-Intelligence-*.wsl 2>/dev/null || true)
if [ -n "$WSL_FILES" ]; then
    log_warn "发现以下 WSL 包文件:"
    for file in $WSL_FILES; do
        SIZE=$(du -h "$file" | cut -f1)
        log_warn "  - $file ($SIZE)"
    done
    
    read -p "是否删除这些 WSL 包文件? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in $WSL_FILES; do
            log_info "删除: $file"
            rm -f "$file"
        done
        log_info "✅ WSL 包文件已清理"
    else
        log_info "保留 WSL 包文件"
    fi
else
    log_info "未找到 WSL 包文件"
fi

# 3. 清理 SHA256 校验文件（可选）
log_info "检查 SHA256 校验文件..."
SHA_FILES=$(ls openEuler-Intelligence-*.wsl.sha256 2>/dev/null || true)
if [ -n "$SHA_FILES" ]; then
    log_warn "发现以下 SHA256 校验文件:"
    for file in $SHA_FILES; do
        log_warn "  - $file"
    done
    
    read -p "是否删除这些 SHA256 校验文件? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in $SHA_FILES; do
            log_info "删除: $file"
            rm -f "$file"
        done
        log_info "✅ SHA256 文件已清理"
    else
        log_info "保留 SHA256 校验文件"
    fi
else
    log_info "未找到 SHA256 文件"
fi

# 4. 清理 wsl_packages 目录
if [ -d "wsl_packages" ]; then
    log_info "清理 wsl_packages 目录..."
    rm -rf wsl_packages
    log_info "✅ wsl_packages 目录已清理"
fi

# 5. 清理构建日志
log_info "清理构建日志..."
LOG_FILES=$(ls build_wsl_*.log 2>/dev/null || true)
if [ -n "$LOG_FILES" ]; then
    for file in $LOG_FILES; do
        log_info "删除: $file"
        rm -f "$file"
    done
    log_info "✅ 构建日志已清理"
else
    log_info "未找到构建日志"
fi

# 6. 清理可能的 libguestfs 缓存（可选）
if [ -d "$HOME/.cache/libguestfs" ]; then
    log_info "发现 libguestfs 缓存目录"
    read -p "是否清理 libguestfs 缓存? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.cache/libguestfs"
        log_info "✅ libguestfs 缓存已清理"
    fi
fi

# 7. 显示清理后的磁盘空间
log_info ""
log_info "=========================================="
log_info "清理完成! 当前目录空间使用情况:"
log_info "=========================================="
du -sh "$WORK_DIR" 2>/dev/null || true

# 8. 列出剩余的大文件（可选）
log_info ""
log_info "剩余的大文件 (>100MB):"
find "$WORK_DIR" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $9, $5}' || true

log_info ""
log_info "✅ 所有清理操作已完成!"
