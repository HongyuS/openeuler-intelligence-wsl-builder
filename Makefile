.PHONY: help x86_64 aarch64 both clean check-deps

help:
	@echo "openEuler 虚拟机镜像 Tarball 生成工具"
	@echo ""
	@echo "用法:"
	@echo "  make x86_64    - 生成 x86_64 架构的 tarball"
	@echo "  make aarch64   - 生成 aarch64 架构的 tarball"
	@echo "  make both      - 生成两种架构的 tarball"
	@echo "  make clean     - 清理生成的 tarball 文件"
	@echo "  make check-deps - 检查依赖是否已安装"
	@echo ""
	@echo "环境要求:"
	@echo "  - Fedora 系统"
	@echo "  - libguestfs-tools (运行 'make check-deps' 检查)"

check-deps:
	@echo "检查依赖..."
	@which virt-tar-out > /dev/null 2>&1 && echo "✅ libguestfs-tools 已安装" || \
		(echo "❌ libguestfs-tools 未安装"; echo "请运行: sudo dnf install libguestfs-tools"; exit 1)

x86_64: check-deps
	@echo "生成 x86_64 架构的 tarball..."
	@./generate_tarballs.sh --arch x86_64

aarch64: check-deps
	@echo "生成 aarch64 架构的 tarball..."
	@./generate_tarballs.sh --arch aarch64

both: check-deps
	@echo "生成 x86_64 架构的 tarball..."
	@./generate_tarballs.sh --arch x86_64
	@echo ""
	@echo "生成 aarch64 架构的 tarball..."
	@./generate_tarballs.sh --arch aarch64

clean:
	@echo "清理生成的 tarball 文件..."
	@rm -vf openEuler-intelligence-*.rootfs.*.tar
	@echo "清理完成"
