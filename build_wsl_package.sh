#!/bin/bash

# 脚本用于从 QCOW2 镜像构建 WSL 发行版包
# 适用于 Fedora 系统
# 需要安装 libguestfs-tools: dnf install libguestfs-tools
# 需要 root 权限运行
#
# 用法: ./build_wsl_package.sh [--arch ARCH] [--variant VARIANT] [--output-dir DIR]
#   --arch ARCH        指定架构 (x86_64 或 aarch64, 默认: x86_64)
#   --variant VARIANT  指定变体 (shell 或 web, 默认: shell)
#   --output-dir DIR   指定输出目录 (默认: 脚本所在目录)
#   --clean            清理临时文件后退出
#   --help, -h         显示帮助信息

set -euo pipefail

# 检查是否以 root 权限运行，如果不是则使用 sudo 重新执行
if [ "$EUID" -ne 0 ]; then
    echo "此脚本需要 root 权限来操作文件系统"
    echo "使用 sudo 重新执行脚本..."
    exec sudo -E "$0" "$@"
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE=""

# 初始化日志文件
init_log_file() {
    local script_dir=$1
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="$script_dir/build_wsl_${timestamp}.log"

    # 创建日志文件并写入头部信息
    {
        echo "=========================================="
        echo "WSL 包构建日志"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""
    } >"$LOG_FILE"

    echo -e "${GREEN}[INFO]${NC} 日志文件: $LOG_FILE"
}

# 日志函数 - 同时输出到终端和日志文件
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    [ -n "$LOG_FILE" ] && echo "[INFO] $(date '+%H:%M:%S') $1" >>"$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    [ -n "$LOG_FILE" ] && echo "[ERROR] $(date '+%H:%M:%S') $1" >>"$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    [ -n "$LOG_FILE" ] && echo "[WARN] $(date '+%H:%M:%S') $1" >>"$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
    [ -n "$LOG_FILE" ] && echo "[STEP] $(date '+%H:%M:%S') $1" >>"$LOG_FILE"
}

# 仅写入日志文件的函数
log_detail() {
    [ -n "$LOG_FILE" ] && echo "[DETAIL] $(date '+%H:%M:%S') $1" >>"$LOG_FILE"
}

# 将命令输出写入日志文件
log_command_output() {
    if [ -n "$LOG_FILE" ]; then
        while IFS= read -r line; do
            echo "  $line" >>"$LOG_FILE"
        done
    fi
}

# 显示帮助信息
show_help() {
    cat <<EOF
用法: $0 [选项]

从 QCOW2 镜像构建 WSL 发行版包 (.wsl 文件)

选项:
  --arch ARCH        指定架构 (x86_64 或 aarch64, 默认: x86_64)
  --variant VARIANT  指定变体 (shell 或 web, 默认: shell)
  --output-dir DIR   指定输出目录 (默认: 脚本所在目录)
  --clean            清理所有临时文件
  --help, -h         显示此帮助信息

示例:
  $0                                       # 构建 shell 变体的 x86_64 WSL 包
  $0 --variant web                         # 构建 web 变体的 x86_64 WSL 包
  $0 --arch aarch64 --variant shell        # 构建 shell 变体的 aarch64 WSL 包
  $0 --clean                               # 清理临时文件

环境要求:
  - Fedora 系统
  - 已安装 libguestfs-tools (dnf install libguestfs-tools)
  - Root 权限 (脚本会自动使用 sudo)

输出文件:
  - openEuler-Intelligence-{variant}.{arch}.wsl
  - openEuler-Intelligence-{variant}.{arch}.wsl.sha256

注意:
  此脚本需要 root 权限来操作提取的文件系统。
  如果不是以 root 运行，脚本会自动使用 sudo 重新执行。

EOF
}

# 检查依赖
check_dependencies() {
    local missing_deps=0

    if ! command -v virt-tar-out &>/dev/null; then
        log_error "virt-tar-out 未找到"
        missing_deps=1
    fi

    if ! command -v guestfish &>/dev/null; then
        log_error "guestfish 未找到"
        missing_deps=1
    fi

    if [ $missing_deps -eq 1 ]; then
        log_error "请安装 libguestfs-tools: sudo dnf install libguestfs-tools"
        exit 1
    fi
}

# 清理临时文件
cleanup_temp() {
    local temp_dir=$1
    if [ -d "$temp_dir" ]; then
        log_detail "清理临时目录: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# 清理所有临时文件
cleanup_all() {
    local script_dir="$1"
    log_info "清理所有临时文件..."
    rm -rf "$script_dir"/wsl_temp_*
    log_info "清理完成"
}

# 从 QCOW2 提取文件系统并排除不需要的目录
extract_filesystem() {
    local qcow2_path=$1
    local temp_dir=$2

    log_step "提取文件系统 (排除不需要的目录)..."

    if [ ! -f "$qcow2_path" ]; then
        log_error "QCOW2 文件不存在: $qcow2_path"
        return 1
    fi

    local qcow2_size
    qcow2_size=$(du -h "$qcow2_path" | cut -f1)
    log_info "QCOW2 文件大小: $qcow2_size"
    log_detail "QCOW2 文件路径: $qcow2_path"

    # 创建临时目录
    mkdir -p "$temp_dir/rootfs"

    log_info "检查镜像内容..."

    # 使用 guestfish 获取根目录下的所有条目
    local entries
    local guestfish_output
    local guestfish_error

    guestfish_output=$(mktemp)
    guestfish_error=$(mktemp)

    log_detail "执行命令: guestfish --ro -a \"$qcow2_path\" -i ls /"

    if ! guestfish --ro -a "$qcow2_path" -i ls / >"$guestfish_output" 2>"$guestfish_error"; then
        log_error "guestfish 命令失败"
        if [ -s "$guestfish_error" ]; then
            log_error "详细错误信息请查看日志文件"
            [ -n "$LOG_FILE" ] && {
                echo "[ERROR] guestfish 错误输出:" >>"$LOG_FILE"
                cat "$guestfish_error" >>"$LOG_FILE"
            }
        fi
        rm -f "$guestfish_output" "$guestfish_error"
        return 1
    fi

    entries=$(cat "$guestfish_output")

    if [ -n "$(cat "$guestfish_error")" ]; then
        log_detail "guestfish 警告信息 (详见日志文件)"
        [ -n "$LOG_FILE" ] && {
            echo "[WARN] guestfish 警告:" >>"$LOG_FILE"
            cat "$guestfish_error" >>"$LOG_FILE"
        }
    fi

    rm -f "$guestfish_output" "$guestfish_error"

    if [ -z "$entries" ]; then
        log_error "无法列出 QCOW2 镜像中的文件"
        return 1
    fi

    # 将镜像内容写入日志
    log_detail "镜像根目录内容:"
    echo "$entries" | while IFS= read -r entry; do
        log_detail "  $entry"
    done

    log_info "提取文件系统 (这可能需要几分钟)..."

    # 使用 virt-tar-out 提取，但先提取到临时 tar 然后解压
    local temp_tar="$temp_dir/temp.tar"
    local virt_output
    local virt_error

    virt_output=$(mktemp)
    virt_error=$(mktemp)

    log_detail "执行命令: virt-tar-out -a \"$qcow2_path\" / \"$temp_tar\""

    if ! virt-tar-out -a "$qcow2_path" / "$temp_tar" >"$virt_output" 2>"$virt_error"; then
        log_error "virt-tar-out 命令失败"

        if [ -s "$virt_error" ]; then
            log_error "详细错误信息请查看日志文件"
            [ -n "$LOG_FILE" ] && {
                echo "[ERROR] virt-tar-out 错误输出:" >>"$LOG_FILE"
                cat "$virt_error" >>"$LOG_FILE"
            }
        fi

        rm -f "$virt_output" "$virt_error"
        return 1
    fi

    # 将命令输出写入日志文件
    if [ -s "$virt_output" ]; then
        log_detail "virt-tar-out 标准输出 (详见日志文件)"
        [ -n "$LOG_FILE" ] && {
            echo "[DETAIL] virt-tar-out 输出:" >>"$LOG_FILE"
            cat "$virt_output" >>"$LOG_FILE"
        }
    fi

    if [ -s "$virt_error" ]; then
        log_detail "virt-tar-out 警告信息 (详见日志文件)"
        [ -n "$LOG_FILE" ] && {
            echo "[WARN] virt-tar-out 警告:" >>"$LOG_FILE"
            cat "$virt_error" >>"$LOG_FILE"
        }
    fi

    rm -f "$virt_output" "$virt_error"

    # 检查临时 tar 文件是否创建成功
    if [ ! -f "$temp_tar" ]; then
        log_error "临时 tar 文件未创建: $temp_tar"
        return 1
    fi

    local temp_tar_size
    temp_tar_size=$(du -h "$temp_tar" | cut -f1)
    log_info "提取完成，临时文件大小: $temp_tar_size"

    log_info "解压文件系统..."
    log_detail "解压用户: $(whoami) (UID: $(id -u))"

    # 解压时排除不需要的目录
    local tar_output
    local tar_error

    tar_output=$(mktemp)
    tar_error=$(mktemp)

    # 使用 --preserve-permissions 和 --same-owner 保留原始权限和所有者
    if ! tar -xf "$temp_tar" -C "$temp_dir/rootfs" \
        --preserve-permissions \
        --same-owner \
        --exclude='./sys' --exclude='./sys/*' \
        --exclude='./run' --exclude='./run/*' \
        --exclude='./proc' --exclude='./proc/*' \
        --exclude='./lost+found' --exclude='./lost+found/*' \
        --exclude='./dev' --exclude='./dev/*' \
        --exclude='./boot' --exclude='./boot/*' \
        --exclude='./afs' --exclude='./afs/*' \
        --exclude='./root/.cache' --exclude='./root/.cache/*' \
        --exclude='./var/cache' --exclude='./var/cache/*' \
        --exclude='./var/log' --exclude='./var/log/*' >"$tar_output" 2>"$tar_error"; then
        log_error "tar 解压失败"

        if [ -s "$tar_error" ]; then
            log_error "详细错误信息请查看日志文件"
            [ -n "$LOG_FILE" ] && {
                echo "[ERROR] tar 错误输出:" >>"$LOG_FILE"
                cat "$tar_error" >>"$LOG_FILE"
            }
        fi

        rm -f "$tar_output" "$tar_error"
        return 1
    fi

    if [ -s "$tar_error" ]; then
        log_detail "tar 警告信息 (详见日志文件)"
        [ -n "$LOG_FILE" ] && {
            echo "[WARN] tar 警告:" >>"$LOG_FILE"
            cat "$tar_error" >>"$LOG_FILE"
        }
    fi

    rm -f "$tar_output" "$tar_error"

    # 检查 rootfs 是否有内容
    local rootfs_count
    rootfs_count=$(find "$temp_dir/rootfs" -mindepth 1 -maxdepth 1 | wc -l)

    if [ "$rootfs_count" -eq 0 ]; then
        log_error "rootfs 目录为空"
        return 1
    fi

    log_info "解压完成，rootfs 包含 $rootfs_count 个顶级目录/文件"

    # 删除临时 tar 文件
    rm -f "$temp_tar"

    log_info "文件系统提取完成 ✓"
    return 0
}

# 配置 WSL 文件
configure_wsl_files() {
    local temp_dir=$1
    local variant=$2
    local script_dir=$3
    local rootfs="$temp_dir/rootfs"

    log_step "配置 WSL 文件..."

    # 创建必要的目录
    mkdir -p "$rootfs/etc"
    mkdir -p "$rootfs/usr/lib/wsl"

    # 复制 wsl.conf
    if [ -f "$script_dir/wsl/wsl.conf" ]; then
        log_detail "复制 wsl.conf"
        cp "$script_dir/wsl/wsl.conf" "$rootfs/etc/wsl.conf"
        chmod 644 "$rootfs/etc/wsl.conf"
    else
        log_warn "wsl.conf 不存在，创建默认配置"
        cat >"$rootfs/etc/wsl.conf" <<'WSLEOF'
[boot]
systemd=true

[automount]
enabled=true
options = "metadata"
mountFsTab = true
WSLEOF
        chmod 644 "$rootfs/etc/wsl.conf"
    fi

    # 复制 wsl-distribution.conf
    if [ -f "$script_dir/wsl/wsl-distribution.conf" ]; then
        log_detail "复制 wsl-distribution.conf"
        cp "$script_dir/wsl/wsl-distribution.conf" "$rootfs/etc/wsl-distribution.conf"

        # 根据变体修改 defaultName
        if [ "$variant" = "web" ]; then
            sed -i 's/defaultName = .*/defaultName = openEuler-Intelligence-Web/' "$rootfs/etc/wsl-distribution.conf"
        else
            sed -i 's/defaultName = .*/defaultName = openEuler-Intelligence-Shell/' "$rootfs/etc/wsl-distribution.conf"
        fi

        chmod 644 "$rootfs/etc/wsl-distribution.conf"
    else
        log_warn "wsl-distribution.conf 不存在，创建默认配置"
        cat >"$rootfs/etc/wsl-distribution.conf" <<DISTEOF
[oobe]
command = /etc/oobe.sh
defaultUid = 1000
defaultName = openEuler-Intelligence-${variant^}

[shortcut]
enabled = true

[windowsterminal]
enabled = true
DISTEOF
        chmod 644 "$rootfs/etc/wsl-distribution.conf"
    fi

    # 复制 oobe.sh
    if [ -f "$script_dir/wsl/oobe.sh" ]; then
        log_detail "复制 oobe.sh"
        cp "$script_dir/wsl/oobe.sh" "$rootfs/etc/oobe.sh"
        chmod 755 "$rootfs/etc/oobe.sh"
    else
        log_warn "oobe.sh 不存在，跳过"
    fi

    # 复制图标文件
    if [ -f "$script_dir/wsl/openEuler.ico" ]; then
        log_detail "复制 openEuler 图标"
        cp "$script_dir/wsl/openEuler.ico" "$rootfs/usr/lib/wsl/openeuler.ico"
        chmod 644 "$rootfs/usr/lib/wsl/openeuler.ico"
    else
        log_warn "openEuler.ico 不存在，跳过"
    fi

    # 确保 root 用户存在于 /etc/passwd
    if [ -f "$rootfs/etc/passwd" ]; then
        if ! grep -q "^root:" "$rootfs/etc/passwd"; then
            log_warn "添加 root 用户到 /etc/passwd"
            echo "root:x:0:0:root:/root:/bin/bash" >>"$rootfs/etc/passwd"
        fi
    fi

    # 删除 /etc/resolv.conf (WSL 会自动生成)
    if [ -f "$rootfs/etc/resolv.conf" ] || [ -L "$rootfs/etc/resolv.conf" ]; then
        log_detail "删除 /etc/resolv.conf (WSL 会自动生成)"
        rm -f "$rootfs/etc/resolv.conf"
    fi

    # 清理密码哈希 (如果存在 /etc/shadow)
    if [ -f "$rootfs/etc/shadow" ]; then
        log_detail "清理密码哈希"
        # 备份原文件
        cp "$rootfs/etc/shadow" "$rootfs/etc/shadow.bak"
        # 清空所有密码字段
        sed -i 's/^\([^:]*\):[^:]*:/\1:!:/' "$rootfs/etc/shadow"
    fi

    # 禁用可能导致问题的 systemd 服务
    if [ "$variant" = "shell" ] || [ "$variant" = "web" ]; then
        log_info "禁用不兼容的 systemd 服务..."

        local services_to_mask=(
            "systemd-resolved.service"
            "systemd-networkd.service"
            "NetworkManager.service"
            "systemd-tmpfiles-setup.service"
            "systemd-tmpfiles-clean.service"
            "systemd-tmpfiles-clean.timer"
            "systemd-tmpfiles-setup-dev-early.service"
            "systemd-tmpfiles-setup-dev.service"
        )

        local masked_count=0
        for service in "${services_to_mask[@]}"; do
            local service_path="$rootfs/etc/systemd/system/$service"
            if [ ! -e "$service_path" ]; then
                mkdir -p "$(dirname "$service_path")"
                ln -sf /dev/null "$service_path" 2>/dev/null || true
                ((masked_count++))
                log_detail "禁用服务: $service"
            fi
        done

        # 禁用 tmp.mount
        local tmp_mount="$rootfs/etc/systemd/system/tmp.mount"
        if [ ! -e "$tmp_mount" ]; then
            mkdir -p "$(dirname "$tmp_mount")"
            ln -sf /dev/null "$tmp_mount" 2>/dev/null || true
            ((masked_count++))
            log_detail "禁用挂载: tmp.mount"
        fi

        log_info "已禁用 $masked_count 个服务/挂载"
    fi

    log_info "WSL 配置完成 ✓"
}

# 创建 WSL tar 包
create_wsl_tar() {
    local temp_dir=$1
    local output_tar=$2
    local rootfs="$temp_dir/rootfs"

    log_step "创建 WSL tar 包..."

    log_info "打包文件系统 (这可能需要几分钟)..."
    log_detail "执行命令: tar --numeric-owner --absolute-names -c * | gzip --best"

    # 使用推荐的方式创建 tar 文件
    if ! (cd "$rootfs" && tar --numeric-owner --absolute-names -c * 2>&1 | tee -a "$LOG_FILE" | gzip --best >"$output_tar"); then
        log_error "创建 tar 包失败"
        return 1
    fi

    local size
    size=$(du -h "$output_tar" | cut -f1)
    log_info "打包完成，大小: $size ✓"

    return 0
}

# 创建 .wsl 文件
create_wsl_file() {
    local tar_file=$1
    local wsl_file=$2

    log_step "创建 .wsl 文件..."

    # 重命名 .tar.gz 为 .wsl
    mv "$tar_file" "$wsl_file"

    log_info "WSL 包创建完成: $(basename "$wsl_file")"
}

# 生成校验和
generate_checksum() {
    local wsl_file=$1
    local checksum_file="${wsl_file}.sha256"

    log_step "生成 SHA256 校验和..."

    local dir
    local filename
    dir=$(dirname "$wsl_file")
    filename=$(basename "$wsl_file")

    (cd "$dir" && sha256sum "$filename" >"$(basename "$checksum_file")")

    # 将校验和写入日志文件
    if [ -n "$LOG_FILE" ]; then
        echo "[INFO] 校验和:" >>"$LOG_FILE"
        cat "$checksum_file" >>"$LOG_FILE"
    fi

    log_info "校验和生成完成 ✓"
}

# 主函数
main() {
    local script_dir
    local qemu_dir
    local qcow2_path
    local output_dir
    local arch
    local variant
    local temp_dir
    local output_name
    local output_tar
    local output_wsl
    local start_time
    local end_time
    local duration

    arch="${ARCH:-x86_64}"
    variant="${VARIANT:-shell}"
    output_dir="${OUTPUT_DIR:-}"

    # 验证架构参数
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
        log_error "不支持的架构: $arch (支持: x86_64, aarch64)"
        exit 1
    fi

    # 验证变体参数
    if [[ "$variant" != "shell" && "$variant" != "web" ]]; then
        log_error "不支持的变体: $variant (支持: shell, web)"
        exit 1
    fi

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    qemu_dir="$script_dir/qemu"

    # 初始化日志文件
    init_log_file "$script_dir"

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

    echo ""
    log_info "========================================"
    log_info "构建 openEuler Intelligence WSL 包"
    log_info "========================================"
    log_info "架构: $arch"
    log_info "变体: $variant"
    log_info ""

    # 详细信息写入日志文件
    log_detail "工作目录: $script_dir"
    log_detail "QEMU 镜像目录: $qemu_dir"
    log_detail "输出目录: $output_dir"
    log_detail "当前用户: $(whoami) (UID: $(id -u))"

    # 检查依赖
    check_dependencies

    # 检查 qemu 目录是否存在
    if [ ! -d "$qemu_dir" ]; then
        log_error "qemu 目录不存在: $qemu_dir"
        exit 1
    fi

    # 确定 QCOW2 文件路径
    if [ "$variant" = "shell" ]; then
        qcow2_path="$qemu_dir/openEuler-intelligence-shell/openeuler-intelligence-oe2403sp2-${arch}.qcow2"
    else
        qcow2_path="$qemu_dir/openEuler-intelligence-web/openeuler-intelligence-oe2403sp2-${arch}.qcow2"
    fi

    if [ ! -f "$qcow2_path" ]; then
        log_error "QCOW2 文件不存在: $qcow2_path"
        exit 1
    fi

    # 创建临时目录
    temp_dir="$script_dir/wsl_temp_${variant}_${arch}_$$"
    mkdir -p "$temp_dir"

    # 设置清理陷阱
    trap 'cleanup_temp "$temp_dir"' EXIT INT TERM

    start_time=$(date +%s)

    # 提取文件系统
    if ! extract_filesystem "$qcow2_path" "$temp_dir"; then
        log_error "文件系统提取失败"
        exit 1
    fi

    # 配置 WSL 文件
    if ! configure_wsl_files "$temp_dir" "$variant" "$script_dir"; then
        log_error "WSL 配置失败"
        exit 1
    fi

    # 创建输出文件名
    output_name="openEuler-Intelligence-${variant^}.${arch}"
    output_tar="$output_dir/${output_name}.tar.gz"
    output_wsl="$output_dir/${output_name}.wsl"

    # 创建 WSL tar 包
    if ! create_wsl_tar "$temp_dir" "$output_tar"; then
        log_error "创建 WSL tar 包失败"
        exit 1
    fi

    # 创建 .wsl 文件
    if ! create_wsl_file "$output_tar" "$output_wsl"; then
        log_error "创建 .wsl 文件失败"
        exit 1
    fi

    # 生成校验和
    generate_checksum "$output_wsl"

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # 格式化时间
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    local time_str=""
    if [ $hours -gt 0 ]; then
        time_str="${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        time_str="${minutes}m ${seconds}s"
    else
        time_str="${seconds}s"
    fi

    echo ""
    log_info "========================================"
    log_info "✓ 构建完成!"
    log_info "========================================"
    log_info "用时: $time_str"
    log_info "输出文件: $(basename "$output_wsl")"
    log_info "校验和: $(basename "${output_wsl}.sha256")"
    log_info "日志文件: $(basename "$LOG_FILE")"
    log_info ""
    log_info "安装方法:"
    log_info "  wsl --install --from-file $(basename "$output_wsl")"
    log_info "  或者直接双击 .wsl 文件进行安装"
    log_info ""

    # 将完成信息也写入日志
    {
        echo ""
        echo "=========================================="
        echo "构建完成"
        echo "=========================================="
        echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "总用时: $time_str"
        echo "输出文件: $output_wsl"
        echo "校验和文件: ${output_wsl}.sha256"
        echo ""
    } >>"$LOG_FILE"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --variant)
            VARIANT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --clean)
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            cleanup_all "$script_dir"
            exit 0
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
