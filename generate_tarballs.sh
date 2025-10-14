#!/bin/bash

# 脚本用于并行生成 openEuler 虚拟机镜像的 rootfs tarball
# 适用于 Fedora 系统
# 需要安装 libguestfs-tools: dnf install libguestfs-tools
#
# 用法: ./generate_tarballs.sh [--arch ARCH] [--output-dir DIR]
#   --arch ARCH        指定架构 (x86_64 或 aarch64, 默认: x86_64)
#   --output-dir DIR   指定输出目录 (默认: 脚本所在目录)
#   --help, -h         显示帮助信息

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat <<EOF
用法: $0 [选项]

并行生成 openEuler 虚拟机镜像的 rootfs tarball

选项:
  --arch ARCH        指定架构 (x86_64 或 aarch64, 默认: x86_64)
  --output-dir DIR   指定输出目录 (默认: 脚本所在目录)
  --help, -h         显示此帮助信息

示例:
  $0                                    # 使用默认设置 (x86_64 架构)
  $0 --arch aarch64                     # 生成 aarch64 架构的 tarball
  $0 --arch x86_64 --output-dir /tmp    # 指定输出目录

环境要求:
  - Fedora 系统
  - 已安装 libguestfs-tools (dnf install libguestfs-tools)

EOF
}

# 检查依赖
check_dependencies() {
    if ! command -v virt-tar-out &>/dev/null; then
        log_error "virt-tar-out 未找到，请安装 libguestfs-tools"
        log_info "在 Fedora 上运行: sudo dnf install libguestfs-tools"
        exit 1
    fi
}

# 提取 tarball 的函数
extract_tarball() {
    local qcow2_path=$1
    local output_tar=$2
    local label=$3
    local start_time
    local end_time
    local duration
    local size
    local basename_result

    basename_result=$(basename "$qcow2_path")
    log_info "[$label] 开始提取: $basename_result"

    if [ ! -f "$qcow2_path" ]; then
        log_error "[$label] QCOW2 文件不存在: $qcow2_path"
        return 1
    fi

    start_time=$(date +%s)

    if virt-tar-out -a "$qcow2_path" / "$output_tar" 2>&1 | while IFS= read -r line; do
        echo "[$label] $line"
    done; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        size=$(du -h "$output_tar" | cut -f1)
        log_info "[$label] 完成! 用时: ${duration}s, 大小: ${size}"
        return 0
    else
        log_error "[$label] 提取失败"
        return 1
    fi
}

# 主函数
main() {
    local script_dir
    local qemu_dir
    local shell_qcow2
    local web_qcow2
    local shell_tar
    local web_tar
    local missing_files
    local overall_start
    local overall_end
    local total_duration
    local failed
    local pid1
    local pid2
    local arch="${ARCH:-x86_64}"
    local output_dir="${OUTPUT_DIR:-}"

    # 验证架构参数
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
        log_error "不支持的架构: $arch (支持: x86_64, aarch64)"
        exit 1
    fi

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    qemu_dir="$script_dir/qemu"

    # 如果未指定输出目录，使用脚本所在目录
    if [ -z "$output_dir" ]; then
        output_dir="$script_dir"
    else
        # 确保输出目录存在
        if [ ! -d "$output_dir" ]; then
            log_info "创建输出目录: $output_dir"
            mkdir -p "$output_dir"
        fi
        output_dir="$(cd "$output_dir" && pwd)"
    fi

    log_info "工作目录: $script_dir"
    log_info "QEMU 镜像目录: $qemu_dir"
    log_info "目标架构: $arch"
    log_info "输出目录: $output_dir"

    # 检查依赖
    check_dependencies

    # 检查 qemu 目录是否存在
    if [ ! -d "$qemu_dir" ]; then
        log_error "qemu 目录不存在: $qemu_dir"
        exit 1
    fi

    # 定义输入输出文件
    shell_qcow2="$qemu_dir/openEuler-intelligence-shell/openeuler-intelligence-oe2403sp2-${arch}.qcow2"
    web_qcow2="$qemu_dir/openEuler-intelligence-web/openeuler-intelligence-oe2403sp2-${arch}.qcow2"

    shell_tar="$output_dir/openEuler-intelligence-shell.rootfs.${arch}.tar"
    web_tar="$output_dir/openEuler-intelligence-web.rootfs.${arch}.tar"

    # 检查输入文件
    missing_files=0
    for file in "$shell_qcow2" "$web_qcow2"; do
        if [ ! -f "$file" ]; then
            log_error "文件不存在: $file"
            missing_files=1
        fi
    done

    if [ $missing_files -eq 1 ]; then
        exit 1
    fi

    log_info "准备并行提取 2 个虚拟机镜像..."
    log_info ""

    overall_start=$(date +%s)

    # 并行执行提取任务
    extract_tarball "$shell_qcow2" "$shell_tar" "SHELL" &
    pid1=$!

    extract_tarball "$web_qcow2" "$web_tar" "WEB" &
    pid2=$!

    # 等待所有后台任务完成
    failed=0

    if wait $pid1; then
        log_info "[SHELL] 任务成功完成"
    else
        log_error "[SHELL] 任务失败"
        failed=1
    fi

    if wait $pid2; then
        log_info "[WEB] 任务成功完成"
    else
        log_error "[WEB] 任务失败"
        failed=1
    fi

    overall_end=$(date +%s)
    total_duration=$((overall_end - overall_start))

    log_info ""
    log_info "==================== 总结 ===================="
    log_info "总用时: ${total_duration}s"

    if [ $failed -eq 0 ]; then
        log_info "✅ 所有 tarball 生成成功!"
        log_info ""
        log_info "输出文件:"
        log_info "  - $shell_tar"
        log_info "  - $web_tar"
        log_info ""
        log_info "SHA256 校验和:"
        (cd "$output_dir" && sha256sum "$(basename "$shell_tar")" "$(basename "$web_tar")")
        exit 0
    else
        log_error "❌ 部分任务失败"
        exit 1
    fi
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            echo ""
            show_help
            exit 1
            ;;
        esac
    done
}

# 解析参数并执行主函数
parse_args "$@"
main
