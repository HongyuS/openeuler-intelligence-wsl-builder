# WSL systemd 配置说明

## systemd 如何在 WSL 中启用？

根据 [Microsoft 官方文档](https://learn.microsoft.com/zh-cn/windows/wsl/systemd)，在 WSL 中启用 systemd **非常简单**，只需要在 `/etc/wsl.conf` 中添加：

```ini
[boot]
systemd=true
```

**就这样！** 不需要其他额外的配置文件。

本 WSL 发行版已经预先配置好了这个设置，systemd 会自动启动。

## 如何验证 systemd 是否正常工作？

### 检查 systemd 是否运行

运行以下命令检查 systemd 版本和状态：

```bash
systemctl --version
```

应该看到类似输出：

```text
systemd 252 (252-1)
+PAM +AUDIT +SELINUX +APPARMOR ...
```

### 查看系统状态

查看系统整体状态：

```bash
systemctl status
```

如果 systemd 正常工作，你会看到：

- 系统状态（State）显示为 `running` 或 `degraded`
- 列出正在运行的服务
- 没有严重错误

### 列出所有服务

查看所有系统服务的状态：

```bash
systemctl list-units --type=service
```

或者只查看服务文件：

```bash
systemctl list-unit-files --type=service
```

### 检查特定服务

例如，检查 D-Bus 服务（systemd 依赖的基础服务）：

```bash
sudo systemctl status dbus
```

应该显示 `active (running)`。

### 验证 PID 1

systemd 应该作为 PID 1 运行：

```bash
ps -p 1 -o comm=
```

应该输出：`systemd`

如果输出是 `init` 或其他，说明 systemd 没有正常启动。

### 查看系统日志

使用 journalctl 查看系统日志（这也依赖 systemd）：

```bash
journalctl -b
```

如果能看到日志输出，说明 systemd 的日志系统正常工作。

## 问题：`systemctl --user` 无法工作

虽然系统级 systemd 工作正常，但当你在 WSL 中运行 `systemctl --user status` 时，可能会遇到以下错误：

```bash
$ systemctl --user status
Failed to connect to bus: No such file or directory
```

或

```bash
$ sudo systemctl --user status
Failed to connect to bus: No medium found
```

## 原因分析

这个问题的根本原因是**用户级 systemd 需要额外的配置才能在 WSL 中工作**：

1. **环境变量缺失**: 用户级 systemd 需要 `XDG_RUNTIME_DIR` 环境变量
2. **运行时目录不存在**: `/run/user/<uid>` 目录需要在用户登录时创建
3. **D-Bus 会话总线**: 用户级 systemd 需要 D-Bus 用户会话

## 重要说明：已禁用的服务

根据 [Microsoft 官方文档](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro#systemd-recommendations)，以下 systemd 服务在 WSL 中会导致问题，因此已被禁用：

- `systemd-resolved.service` - WSL 自己管理 DNS
- `systemd-networkd.service` - WSL 自己管理网络
- `NetworkManager.service` - 与 WSL 网络冲突
- `systemd-tmpfiles-setup.service` - WSL 自己管理临时文件
- `systemd-tmpfiles-clean.service` - 同上
- `systemd-tmpfiles-clean.timer` - 同上
- `systemd-tmpfiles-setup-dev-early.service` - 同上
- `systemd-tmpfiles-setup-dev.service` - 同上
- `tmp.mount` - WSL 自己管理 /tmp

**这些服务被禁用是正常且必要的**，不是 bug。

## 解决方案

### 方法 1: 使用自动修复脚本（推荐）

WSL 发行版中包含了一个修复脚本，以 root 身份运行：

```bash
sudo fix-systemd-user
```

然后重新登录或运行：

```bash
source ~/.profile
```

### 方法 2: 手动配置

如果自动脚本不可用，可以手动配置：

#### 步骤 1: 创建运行时目录

```bash
sudo mkdir -p /run/user/$(id -u)
sudo chown $(id -u):$(id -g) /run/user/$(id -u)
sudo chmod 700 /run/user/$(id -u)
```

#### 步骤 2: 设置环境变量

将以下内容添加到 `~/.profile` 或 `~/.bashrc`：

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
```

#### 步骤 3: 重新加载环境

```bash
source ~/.profile
```

#### 步骤 4: 验证

```bash
systemctl --user status
```

### 方法 3: 重启 WSL

有时最简单的方法是重启 WSL：

在 Windows PowerShell 中运行：

```powershell
wsl --shutdown
```

然后重新启动 WSL。

## 系统级 systemd vs 用户级 systemd

### 系统级 systemd（`systemctl` 不带 `--user`）

- 由 WSL 自动管理和启动
- 使用 `sudo systemctl` 命令
- 示例：`sudo systemctl status sshd`
- **在 WSL 中应该正常工作**

### 用户级 systemd（`systemctl --user`）

- 为每个用户单独运行
- 使用 `systemctl --user` 命令（不需要 sudo）
- 示例：`systemctl --user status`
- **在 WSL 中需要额外配置**

## 注意事项

1. **不要使用 `sudo` 运行 `systemctl --user`**
   - 错误：`sudo systemctl --user status`
   - 正确：`systemctl --user status`

2. **环境变量必须在用户会话中设置**
   - 每次新登录都需要有正确的环境变量
   - 建议将配置添加到 `~/.profile` 或 `~/.bashrc`

3. **某些服务被禁用是正常的**
   - 这是按照 Microsoft 官方建议进行的配置
   - 不会影响 WSL 的正常使用

## 常见问题

### Q: 为什么禁用了 `systemd-tmpfiles-*` 服务？

A: 根据 Microsoft 官方文档，这些服务会与 WSL 的文件系统管理冲突。WSL 有自己的机制来管理临时文件和运行时目录。

### Q: 禁用这些服务会影响功能吗？

A: 不会。WSL 会接管这些功能，确保一切正常运行。

### Q: 我需要用户级 systemd 吗？

A: 大多数情况下不需要。系统级 systemd 服务（如 nginx、postgresql 等）使用 `sudo systemctl` 管理，这在 WSL 中完全正常工作。用户级 systemd 主要用于：

- 用户自定义的后台服务
- 桌面环境组件（WSL 通常不需要）
- 某些开发工具的个人实例

## 参考资料

- [Microsoft WSL 自定义发行版官方文档](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)
- [WSL systemd 配置文档](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#systemd-support)
