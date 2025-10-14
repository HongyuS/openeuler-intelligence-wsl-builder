#!/bin/bash
# OOBE (Out Of Box Experience) 脚本
# 用于首次启动时创建用户

set -ue

DEFAULT_GROUPS='wheel,users'
DEFAULT_UID='1000'

echo '=========================================='
echo 'Welcome to openEuler Intelligence!'
echo '=========================================='
echo ''
echo 'Please create a default openEuler user account.'
echo 'The username does not need to match your Windows username.'
echo 'For more information visit: https://aka.ms/wslusers'
echo ''

# 检查用户是否已存在
if getent passwd "$DEFAULT_UID" >/dev/null; then
    echo 'User account already exists, skipping creation'
    exit 0
fi

while true; do
    # 提示输入用户名
    read -rp 'Enter new openEuler username: ' username

    # 验证用户名格式
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Error: Invalid username format. Please use lowercase letters, numbers, underscore, and hyphen."
        continue
    fi

    # 创建用户
    if /usr/sbin/useradd -m -u "$DEFAULT_UID" -G "$DEFAULT_GROUPS" -s /bin/bash "$username"; then
        echo ''
        echo "User '$username' created successfully."

        # 设置密码
        echo "Please set a password for user '$username':"
        if passwd "$username"; then
            echo ''
            echo 'Setup complete!'
            echo "You can now use 'sudo' to run commands as root."
            break
        else
            # 如果设置密码失败，删除用户
            /usr/sbin/userdel -r "$username" 2>/dev/null || true
            echo "Error: Failed to set password. Please try again."
        fi
    else
        echo "Error: Failed to create user. Please try a different username."
    fi
done

exit 0
