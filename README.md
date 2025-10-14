# openEuler 虚拟机镜像 Tarball 生成工具

这个脚本用于并行生成 openEuler 虚拟机镜像的 rootfs tarball 文件。

## 环境要求

- **系统**: Fedora Linux
- **依赖**: libguestfs-tools

### 安装依赖

在 Fedora 上运行：

```bash
sudo dnf install libguestfs-tools
```

## 使用方法

### 基本用法

```bash
# 给脚本添加执行权限
chmod +x generate_tarballs.sh

# 生成 x86_64 架构的 tarball（默认）
./generate_tarballs.sh

# 生成 aarch64 架构的 tarball
./generate_tarballs.sh --arch aarch64

# 指定输出目录
./generate_tarballs.sh --output-dir /tmp/tarballs

# 组合使用
./generate_tarballs.sh --arch aarch64 --output-dir /tmp/tarballs
```

### 命令行选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--arch ARCH` | 指定架构 (x86_64 或 aarch64) | x86_64 |
| `--output-dir DIR` | 指定输出目录 | 脚本所在目录 |
| `--help, -h` | 显示帮助信息 | - |

## 目录结构

脚本期望以下目录结构：

```text
.
├── generate_tarballs.sh
└── qemu/
    ├── openEuler-intelligence-shell/
    │   ├── openeuler-intelligence-oe2403sp2-aarch64.qcow2
    │   ├── openeuler-intelligence-oe2403sp2-aarch64.xml
    │   ├── openeuler-intelligence-oe2403sp2-x86_64.qcow2
    │   └── openeuler-intelligence-oe2403sp2-x86_64.xml
    └── openEuler-intelligence-web/
        ├── openeuler-intelligence-oe2403sp2-aarch64.qcow2
        ├── openeuler-intelligence-oe2403sp2-aarch64.xml
        ├── openeuler-intelligence-oe2403sp2-x86_64.qcow2
        └── openeuler-intelligence-oe2403sp2-x86_64.xml
```

## 输出文件

脚本会生成以下文件：

- `openEuler-intelligence-shell.rootfs.{arch}.tar`
- `openEuler-intelligence-web.rootfs.{arch}.tar`

其中 `{arch}` 为指定的架构（x86_64 或 aarch64）。

## 功能特性

- ✅ **并行处理**: 同时提取两个虚拟机镜像，大幅缩短总体时间
- ✅ **多架构支持**: 支持 x86_64 和 aarch64 架构
- ✅ **灵活输出**: 可自定义输出目录
- ✅ **完善的错误处理**: 详细的错误检查和日志输出
- ✅ **彩色日志**: 使用颜色区分不同类型的消息
- ✅ **进度追踪**: 显示每个任务的用时和生成文件大小
- ✅ **校验和生成**: 自动生成 SHA256 校验和
- ✅ **任务标签**: 清晰区分并行任务的输出

## 示例输出

```text
[INFO] 工作目录: /path/to/vm
[INFO] QEMU 镜像目录: /path/to/vm/qemu
[INFO] 目标架构: x86_64
[INFO] 输出目录: /path/to/vm
[INFO] 准备并行提取 2 个虚拟机镜像...

[INFO] [SHELL] 开始提取: openeuler-intelligence-oe2403sp2-x86_64.qcow2
[INFO] [WEB] 开始提取: openeuler-intelligence-oe2403sp2-x86_64.qcow2
[INFO] [SHELL] 完成! 用时: 45s, 大小: 1.2G
[INFO] [WEB] 完成! 用时: 48s, 大小: 1.5G
[INFO] [SHELL] 任务成功完成
[INFO] [WEB] 任务成功完成

[INFO] ==================== 总结 ====================
[INFO] 总用时: 48s
[INFO] ✅ 所有 tarball 生成成功!

[INFO] 输出文件:
[INFO]   - /path/to/vm/openEuler-intelligence-shell.rootfs.x86_64.tar
[INFO]   - /path/to/vm/openEuler-intelligence-web.rootfs.x86_64.tar

[INFO] SHA256 校验和:
a1b2c3d4... openEuler-intelligence-shell.rootfs.x86_64.tar
e5f6g7h8... openEuler-intelligence-web.rootfs.x86_64.tar
```

## 故障排查

### 错误: virt-tar-out 未找到

**解决方案**: 安装 libguestfs-tools

```bash
sudo dnf install libguestfs-tools
```

### 错误: QCOW2 文件不存在

**解决方案**: 确保 `qemu/` 目录存在且包含正确的 QCOW2 文件

### 错误: 不支持的架构

**解决方案**: 只使用 `x86_64` 或 `aarch64` 作为 `--arch` 参数

## 性能优化

- 脚本使用 Bash 后台进程实现并行处理
- 相比串行执行，可节省约 50% 的时间
- 对于大型镜像文件，建议在 I/O 性能较好的存储上运行

## 许可证

请根据项目需求添加适当的许可证信息。
