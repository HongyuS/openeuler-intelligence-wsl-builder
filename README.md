# openEuler Intelligence - WSL 包构建工具

从 QCOW2 虚拟机镜像构建 Windows Subsystem for Linux (WSL) 发行版包的完整工具集。

> 💡 **快速提示**:
>
> - 构建: `make wsl-shell-x86_64`
> - 清理: `make clean-quick` (保留 WSL 包) 或 `make clean` (交互式)
> - 完全清理: `make clean-all` (删除所有文件)

## 功能特性

- ✅ **自动提取**: 从 QCOW2 镜像自动提取文件系统
- ✅ **智能过滤**: 自动排除不需要的系统目录
- ✅ **WSL 优化**: 自动配置 WSL 相关文件和服务
- ✅ **多架构支持**: x86_64 和 aarch64
- ✅ **批量构建**: 一键构建所有变体
- ✅ **完整验证**: 自动生成和验证 SHA256 校验和

## 快速开始

### 获取 QCOW2 镜像

在构建 WSL 包之前，您需要下载 openEuler Intelligence QCOW2 镜像文件：

**x86_64 架构**:

- 下载地址: <https://repo.oepkgs.net/openEuler/rpm/openEuler-24.03-LTS-SP2/contrib/eulercopilot/images/x86_64/qemu/>
- 保存到: `qemu/openEuler-intelligence-shell/` 或 `qemu/openEuler-intelligence-web/`

**aarch64 架构**:

- 下载地址: <https://repo.oepkgs.net/openEuler/rpm/openEuler-24.03-LTS-SP2/contrib/eulercopilot/images/aarch64/qemu/>
- 保存到: `qemu/openEuler-intelligence-shell/` 或 `qemu/openEuler-intelligence-web/`

```bash
# 示例：下载 x86_64 Shell 变体镜像
cd qemu/openEuler-intelligence-shell/
wget https://repo.oepkgs.net/openEuler/rpm/openEuler-24.03-LTS-SP2/contrib/eulercopilot/images/x86_64/qemu/openEuler-intelligence-shell/openeuler-intelligence-oe2403sp2-x86_64.qcow2

# 示例：下载 aarch64 Shell 变体镜像
wget https://repo.oepkgs.net/openEuler/rpm/openEuler-24.03-LTS-SP2/contrib/eulercopilot/images/aarch64/qemu/openEuler-intelligence-shell/openeuler-intelligence-oe2403sp2-aarch64.qcow2
cd ../..
```

### 环境要求

- **系统**: Fedora Linux (推荐) 或其他支持 libguestfs 的 Linux 发行版
- **依赖**: libguestfs-tools
- **权限**: Root 权限（构建脚本会自动使用 sudo）

```bash
# Fedora / RHEL / CentOS
sudo dnf install libguestfs-tools

# Ubuntu / Debian
sudo apt install libguestfs-tools
```

> **注意**: 构建脚本需要 root 权限来操作提取的文件系统。如果不是以 root 运行，脚本会自动使用 sudo 重新执行。

### 构建 WSL 包

```bash
# 1. 设置脚本权限
make setup

# 2. 检查依赖
make check-deps

# 3. 构建 WSL 包
make wsl-shell-x86_64        # 构建 Shell 变体 x86_64
make wsl-all                 # 构建所有 WSL 包

# 4. 验证构建的包
make verify-wsl
```

## 使用 Makefile

```bash
# WSL 包构建
make wsl-shell-x86_64       # Shell 变体 x86_64
make wsl-shell-aarch64      # Shell 变体 aarch64
make wsl-web-x86_64         # Web 变体 x86_64
make wsl-web-aarch64        # Web 变体 aarch64
make wsl-all                # 所有 WSL 包

# 清理和验证
make clean                  # 交互式清理（检查进程占用，可选保留 WSL 包）
make clean-quick            # 快速清理（不检查进程，保留 WSL 包）
make clean-all              # 完全清理（不检查进程，删除所有文件）
make verify-wsl             # 验证 WSL 包

# 辅助功能
make setup                  # 设置脚本执行权限
make check-deps             # 检查依赖
make help                   # 显示帮助
```

## 使用脚本

```bash
# 构建单个 WSL 包 (脚本会自动使用 sudo)
./build_wsl_package.sh --variant shell --arch x86_64
./build_wsl_package.sh --variant web --arch aarch64

# 批量构建所有 WSL 包 (脚本会自动使用 sudo)
./build_all_wsl_packages.sh

# 验证 WSL 包 (不需要 root 权限)
./verify_wsl_package.sh openEuler-Intelligence-Shell.x86_64.wsl
```

## 在 Windows 上安装

### 方法 1: 命令行

```powershell
# 从文件安装
wsl --install --from-file openEuler-Intelligence-Shell.x86_64.wsl

# 验证安装
wsl --list --verbose

# 启动
wsl -d openEuler-Intelligence-Shell
```

### 方法 2: 图形界面

直接双击 `.wsl` 文件即可安装。

## 输出文件

构建完成后会生成：

```plaintext
openEuler-Intelligence-Shell.x86_64.wsl
openEuler-Intelligence-Shell.x86_64.wsl.sha256
openEuler-Intelligence-Shell.aarch64.wsl
openEuler-Intelligence-Shell.aarch64.wsl.sha256
openEuler-Intelligence-Web.x86_64.wsl
openEuler-Intelligence-Web.x86_64.wsl.sha256
openEuler-Intelligence-Web.aarch64.wsl
openEuler-Intelligence-Web.aarch64.wsl.sha256
```

## 排除的目录

WSL 包会自动排除以下不需要的目录：

- `/sys` - 系统虚拟文件系统
- `/run` - 运行时数据
- `/proc` - 进程信息
- `/lost+found` - 文件系统恢复目录
- `/dev` - 设备文件
- `/boot` - 启动文件
- `/afs` - Andrew 文件系统
- `/root/.cache` - Root 用户缓存
- `/var/cache` - 系统缓存
- `/var/log` - 日志文件

## 项目结构

```plaintext
.
├── README.md                      # 本文件
├── Makefile                       # 快捷命令
│
├── build_wsl_package.sh           # WSL 包构建脚本（单个）
├── build_all_wsl_packages.sh      # WSL 包批量构建脚本
├── verify_wsl_package.sh          # WSL 包验证脚本
├── setup.sh                       # 一键设置脚本执行权限
│
├── wsl/                           # WSL 配置文件目录
│   ├── wsl.conf                   # WSL 运行时配置
│   ├── wsl-distribution.conf      # WSL 发行版配置
│   ├── oobe.sh                    # 首次运行体验脚本
│   └── openEuler.ico              # openEuler 图标文件
│
└── qemu/                          # QCOW2 虚拟机镜像目录
    ├── openEuler-intelligence-shell/
    │   ├── .gitkeep
    │   ├── openeuler-intelligence-oe2403sp2-aarch64.qcow2
    │   └── openeuler-intelligence-oe2403sp2-x86_64.qcow2
    └── openEuler-intelligence-web/
        ├── .gitkeep
        ├── openeuler-intelligence-oe2403sp2-aarch64.qcow2
        └── openeuler-intelligence-oe2403sp2-x86_64.qcow2

```

## 配置说明

### WSL 配置文件

所有 WSL 配置文件都在 `wsl/` 目录中：

- **wsl.conf**: WSL 运行时配置（systemd、自动挂载等）
- **wsl-distribution.conf**: 发行版配置（OOBE、快捷方式等）
- **oobe.sh**: 首次运行体验脚本（创建用户）
- **openEuler.ico**: openEuler 图标文件（用于 WSL 快捷方式和终端）

这些文件会在构建时自动复制到正确的位置（`/etc/` 和 `/usr/lib/wsl/`）。

### 自定义配置

编辑 `wsl/` 目录下的配置文件，然后重新构建即可应用更改。

## 清理功能

项目提供了三种清理方式：

### 1. 交互式清理（推荐）

```bash
make clean
```

检测进程占用，询问是否删除 WSL 包文件（默认保留）。适合日常开发使用。

### 2. 快速清理（安全）

```bash
make clean-quick
```

快速清理临时文件和日志，**自动保留 WSL 包**。适合重新构建前清理。

### 3. 完全清理（彻底）

```bash
make clean-all
```

删除所有文件，包括 WSL 包和 SHA256 文件。适合完全重新开始。

### 清理对比表

| 清理方式 | 临时目录 | 日志 | WSL 包 | SHA256 | 进程检测 | 交互式 |
|---------|---------|------|--------|--------|---------|--------|
| `make clean` | ✅ | ✅ | ❓ 询问 | ❓ 询问 | ✅ | ✅ |
| `make clean-quick` | ✅ | ✅ | ❌ 保留 | ❌ 保留 | ❌ | ❌ |
| `make clean-all` | ✅ | ✅ | ✅ 删除 | ✅ 删除 | ❌ | ❌ |

## 故障排查

### 错误: virt-tar-out 未找到

```bash
sudo dnf install libguestfs-tools
```

### 错误: QCOW2 文件不存在

确保 `qemu/` 目录包含正确的 QCOW2 文件。

### 构建失败

```bash
# 查看详细日志
./build_wsl_package.sh --variant shell --arch x86_64 2>&1 | tee build.log

# 清理后重试
make clean
make wsl-shell-x86_64
```

### 权限错误（libguestfs）

如果遇到类似 `permission denied` 或 `无法访问存储文件` 的错误：

```bash
# 方案1: 使用直接后端（推荐）
export LIBGUESTFS_BACKEND=direct
sudo -E make wsl-shell-x86_64

# 方案2: 修改文件权限
sudo chmod 644 qemu/openEuler-intelligence-*/*.qcow2
sudo make wsl-shell-x86_64
```

### 无法删除临时目录

如果 `make clean` 失败或临时目录无法删除：

```bash
# 使用交互式清理（会检查并询问是否终止占用进程）
make clean

# 或使用快速清理（强制删除临时目录，保留 WSL 包）
make clean-quick

# 或使用完全清理（删除所有文件）
make clean-all

# 手动运行清理脚本
./clean.sh
```

**常见原因**：

- 文件管理器（nautilus/dolphin）打开了该目录
- 某个进程正在访问临时文件
- 目录包含只读文件

### 意外删除 WSL 包

如果不小心删除了 WSL 包文件：

```bash
# 重新构建特定包
make wsl-shell-x86_64

# 或重新构建所有包
make wsl-all
```

**建议**：使用 `make clean-quick` 来避免误删 WSL 包文件。

### WSL 安装失败

```powershell
# 检查 WSL 版本（需要 2.4.4 或更高）
wsl --version

# 更新 WSL
wsl --update
```

## 技术细节

### 构建流程

1. 从 QCOW2 镜像提取文件系统
2. 排除不需要的系统目录
3. 配置 WSL 相关文件（从 `wsl/` 复制到 `/etc/`）
4. 优化 systemd 服务（禁用可能导致问题的服务）
5. 打包为 tar.gz 格式
6. 重命名为 .wsl 文件
7. 生成 SHA256 校验和

### 符合 Microsoft 规范

完全遵循 [Microsoft WSL 官方文档](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)：

- ✅ 正确的 tar 创建方式 (`--numeric-owner --absolute-names`)
- ✅ 使用 gzip 最佳压缩
- ✅ 正确的配置文件位置和权限
- ✅ 排除不应包含的文件
- ✅ 禁用可能导致问题的 systemd 服务

## 相关资源

- [Microsoft WSL 文档](https://learn.microsoft.com/en-us/windows/wsl/)
- [构建自定义 WSL 发行版](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)
- [WSL 配置文件](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [libguestfs 文档](https://libguestfs.org/)

## 许可证

本项目采用 [木兰宽松许可证，第2版（Mulan PSL v2）](LICENSE)。

Copyright (c) 2025 [openEuler Intelligence 贡献者](https://www.openeuler.org/zh/sig/sig-intelligence)

您可以根据木兰宽松许可证第2版的条款自由使用本软件。详细信息请参阅 [LICENSE](LICENSE) 文件。
