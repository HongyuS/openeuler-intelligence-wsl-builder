.PHONY: help wsl-shell-x86_64 wsl-shell-aarch64 wsl-web-x86_64 wsl-web-aarch64
.PHONY: wsl-all clean verify-wsl check-deps setup

help:
	@echo "openEuler Intelligence - WSL 包构建工具"
	@echo ""
	@echo "WSL 包构建:"
	@echo "  make wsl-shell-x86_64   - 构建 Shell 变体 x86_64 WSL 包"
	@echo "  make wsl-shell-aarch64  - 构建 Shell 变体 aarch64 WSL 包"
	@echo "  make wsl-web-x86_64     - 构建 Web 变体 x86_64 WSL 包"
	@echo "  make wsl-web-aarch64    - 构建 Web 变体 aarch64 WSL 包"
	@echo "  make wsl-all            - 构建所有 WSL 包"
	@echo ""
	@echo "清理和验证:"
	@echo "  make clean              - 清理 WSL 包和临时文件"
	@echo "  make verify-wsl         - 验证 WSL 包"
	@echo ""
	@echo "其他:"
	@echo "  make check-deps         - 检查依赖是否已安装"
	@echo "  make setup              - 设置脚本执行权限"
	@echo ""
	@echo "环境要求:"
	@echo "  - Fedora 系统（推荐）或其他 Linux"
	@echo "  - libguestfs-tools (运行 'make check-deps' 检查)"

check-deps:
	@echo "检查依赖..."
	@which virt-tar-out > /dev/null 2>&1 && which guestfish > /dev/null 2>&1 && echo "✅ libguestfs-tools 已安装" || (echo "❌ libguestfs-tools 未安装"; echo "请运行: sudo dnf install libguestfs-tools"; exit 1)

wsl-shell-x86_64: check-deps
	@echo "构建 Shell 变体 x86_64 WSL 包..."
	@./build_wsl_package.sh --variant shell --arch x86_64

wsl-shell-aarch64: check-deps
	@echo "构建 Shell 变体 aarch64 WSL 包..."
	@./build_wsl_package.sh --variant shell --arch aarch64

wsl-web-x86_64: check-deps
	@echo "构建 Web 变体 x86_64 WSL 包..."
	@./build_wsl_package.sh --variant web --arch x86_64

wsl-web-aarch64: check-deps
	@echo "构建 Web 变体 aarch64 WSL 包..."
	@./build_wsl_package.sh --variant web --arch aarch64

wsl-all: check-deps
	@echo "批量构建所有 WSL 包..."
	@./build_all_wsl_packages.sh

clean:
	@echo "清理 WSL 包和临时文件..."
	@./build_wsl_package.sh --clean || true
	@rm -vf openEuler-Intelligence-*.wsl
	@rm -vf openEuler-Intelligence-*.wsl.sha256
	@rm -rf wsl_packages/
	@echo "清理完成"

verify-wsl:
	@echo "验证 WSL 包..."
	@if ls openEuler-Intelligence-*.wsl 1> /dev/null 2>&1; then for file in openEuler-Intelligence-*.wsl; do echo ""; ./verify_wsl_package.sh "$$file"; done; else echo "❌ 未找到 WSL 包，请先构建"; exit 1; fi

setup:
	@echo "设置脚本执行权限..."
	@chmod +x build_wsl_package.sh build_all_wsl_packages.sh verify_wsl_package.sh setup.sh wsl/oobe.sh
	@echo "✅ 所有脚本权限设置完成"