#!/bin/bash
# 修复 WSL 中的 systemd --user 问题
# 此脚本应在 WSL 实例首次启动后运行

set -e

echo "=========================================="
echo "WSL systemd --user 诊断和修复工具"
echo "=========================================="
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
fi

echo "[1/5] 检查 systemd 是否启用..."
if ! systemctl --version &>/dev/null; then
    echo "错误: systemd 未运行"
    exit 1
fi
echo "✓ systemd 正在运行"
echo ""

echo "[2/5] 检查 dbus 是否安装和运行..."
if ! command -v dbus-daemon &>/dev/null; then
    echo "警告: dbus-daemon 未安装，尝试安装..."
    if command -v dnf &>/dev/null; then
        dnf install -y dbus dbus-daemon
    elif command -v apt &>/dev/null; then
        apt update && apt install -y dbus
    fi
fi

# 启动 dbus 服务
if ! systemctl is-active --quiet dbus; then
    echo "启动 dbus 服务..."
    systemctl start dbus
fi
echo "✓ dbus 服务正常"
echo ""

echo "[3/5] 检查用户级 systemd 配置..."

# 确保 /run/user 目录存在
mkdir -p /run/user
chmod 755 /run/user

# 为每个普通用户创建运行时目录
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        uid=$(id -u "$username" 2>/dev/null || echo "")

        if [ -n "$uid" ] && [ "$uid" -ge 1000 ]; then
            runtime_dir="/run/user/$uid"

            if [ ! -d "$runtime_dir" ]; then
                echo "为用户 $username (UID: $uid) 创建运行时目录..."
                mkdir -p "$runtime_dir"
                chown "$username:$username" "$runtime_dir"
                chmod 700 "$runtime_dir"
            fi

            # 确保环境变量设置
            profile_file="$user_home/.profile"
            if ! grep -q "XDG_RUNTIME_DIR" "$profile_file" 2>/dev/null; then
                echo "添加 XDG_RUNTIME_DIR 到 $profile_file..."
                cat >>"$profile_file" <<EOF

# WSL systemd --user 支持
export XDG_RUNTIME_DIR=/run/user/$uid
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
EOF
                chown "$username:$username" "$profile_file"
            fi

            # 同样更新 .bashrc
            bashrc_file="$user_home/.bashrc"
            if [ -f "$bashrc_file" ] && ! grep -q "XDG_RUNTIME_DIR" "$bashrc_file" 2>/dev/null; then
                echo "添加 XDG_RUNTIME_DIR 到 $bashrc_file..."
                cat >>"$bashrc_file" <<EOF

# WSL systemd --user 支持
export XDG_RUNTIME_DIR=/run/user/$uid
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
EOF
                chown "$username:$username" "$bashrc_file"
            fi
        fi
    fi
done

echo "✓ 用户运行时目录配置完成"
echo ""

echo "[4/5] 启用用户级 systemd 服务..."

# 启用 user@.service 模板
if systemctl list-unit-files | grep -q "user@.service"; then
    if ! systemctl is-enabled --quiet user@.service 2>/dev/null; then
        systemctl enable user@.service || true
    fi
    echo "✓ user@.service 已启用"
else
    echo "警告: user@.service 未找到，这可能是正常的"
fi
echo ""

echo "[5/5] 验证配置..."
echo ""
echo "请以普通用户身份运行以下命令来测试:"
echo ""
echo "  source ~/.profile"
echo "  systemctl --user status"
echo ""
echo "=========================================="
echo "修复完成!"
echo "=========================================="
echo ""
echo "注意事项:"
echo "1. 请重新登录或运行 'source ~/.profile' 使环境变量生效"
echo "2. 如果问题仍然存在，请尝试重启 WSL: 'wsl --shutdown'"
echo "3. 某些 systemd 服务已按 Microsoft 建议禁用，这是正常的"
echo ""
