# ===========================================================================
# linux_lite 第一阶段构建入口
#
# 目标板 : HiLink HLK-7621A EVB / MT7621 / mipsel_24kc / musl / 软浮点
# 启动链 : legacy uImage  ->  lzma-loader  ->  Kernel + appended DTB
#          ->  内嵌 initramfs  ->  /init  ->  静态 BusyBox sh
# 方案   : doc/linux_lite_phase1_plan.md
#
# 常用命令:
#   make prepare            解包 dl/ 中的内核与 BusyBox 源码到 src/
#   make busybox            编译静态 BusyBox 到 out/busybox
#   make rootfs             生成 out/rootfs.list 与 out/rootfs.cpio
#   make kernel             编译内核与板级 DTB
#   make uimage             生成 out/uImage
#   make all                等价于 make uimage
# ===========================================================================

.DEFAULT_GOAL := help
.NOTPARALLEL:

TOPDIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# ---------------------------------------------------------------------------
# 可覆盖参数
# ---------------------------------------------------------------------------
OPENWRT      ?= $(TOPDIR)/../openwrt-24.10.8

# OpenWrt 工具链的 specs 用 getenv(STAGING_DIR /usr/include) 拼路径，
# 该变量未定义时，每次调用 gcc 都会打印一行 warning
STAGING_DIR  ?= $(OPENWRT)/staging_dir/target-mipsel_24kc_musl
export STAGING_DIR

KERNEL_VER   ?= 6.6.144
BUSYBOX_VER  ?= 1.36.1
JOBS         ?= $(shell nproc 2>/dev/null || echo 4)

TOOLCHAIN    ?= $(OPENWRT)/staging_dir/toolchain-mipsel_24kc_gcc-13.3.0_musl
CROSS        ?= $(TOOLCHAIN)/bin/mipsel-openwrt-linux-musl-
HOST_TOOLS   ?= $(OPENWRT)/staging_dir/host/bin
MKIMAGE      ?= $(HOST_TOOLS)/mkimage
LZMA         ?= $(HOST_TOOLS)/lzma
HOSTCC       ?= gcc

ARCH_FLAGS   ?= -mips32r2 -mtune=24kc -msoft-float -mno-branch-likely

# 镜像布局，沿用 OpenWrt ramips mt7621 在真机验证过的取值
# 内核 ELF 的 LOAD 段本身就是 0x80001000，lzma-loader 解压回该地址后跳入
UIMAGE_LOADADDR ?= 0x80001000
UIMAGE_ENTRY    ?= 0x80001000
LZMA_TEXT_START ?= 0x81800000
BOARD_DTS_NAME  ?= linux_lite_hlk7621
UIMAGE_NAME     ?= MIPS Linux Lite

# 第一阶段最小 applet 集合，/bin/<name> 全部指向 busybox
APPLETS ?= sh mount umount cat ls echo uname dmesg ps poweroff reboot mkdir ln rm sleep

# ---------------------------------------------------------------------------
# 目录与产物
# ---------------------------------------------------------------------------
DL_DIR        := $(TOPDIR)/dl
SRC_DIR       := $(TOPDIR)/src
BUILD_DIR     := $(TOPDIR)/build
OUT_DIR       := $(TOPDIR)/out
CFG_DIR       := $(TOPDIR)/config
OVERLAY_DIR   := $(TOPDIR)/rootfs-overlay

LINUX_TARBALL   := $(DL_DIR)/linux-$(KERNEL_VER).tar.xz
BUSYBOX_TARBALL := $(DL_DIR)/busybox-$(BUSYBOX_VER).tar.bz2

LINUX_SRC     := $(SRC_DIR)/linux-$(KERNEL_VER)
BUSYBOX_SRC   := $(SRC_DIR)/busybox-$(BUSYBOX_VER)
LINUX_BUILD   := $(BUILD_DIR)/kernel
BUSYBOX_BUILD := $(BUILD_DIR)/busybox
LOADER_SRC    := $(TOPDIR)/third_party/lzma-loader
LOADER_BUILD  := $(BUILD_DIR)/lzma-loader

BUSYBOX_BIN   := $(OUT_DIR)/busybox
ROOTFS_LIST   := $(OUT_DIR)/rootfs.list
ROOTFS_CPIO   := $(OUT_DIR)/rootfs.cpio
KERNEL_BIN    := $(OUT_DIR)/vmlinux.bin
BOARD_DTB     := $(OUT_DIR)/$(BOARD_DTS_NAME).dtb
KERNEL_IMAGE  := $(OUT_DIR)/kernel-dtb.bin
KERNEL_LZMA   := $(OUT_DIR)/kernel-dtb.lzma
LOADER_BIN    := $(OUT_DIR)/loader.bin
UIMAGE        := $(OUT_DIR)/uImage

BOARD_DTS_SRC  := $(CFG_DIR)/board.dts
BOARD_DTSI     := $(CFG_DIR)/mt7621.dtsi
KERNEL_DTC     := $(LINUX_BUILD)/scripts/dtc/dtc

KERNEL_MAKE   := PATH="$(HOST_TOOLS):$$PATH" $(MAKE) -C $(LINUX_SRC) O=$(LINUX_BUILD) ARCH=mips CROSS_COMPILE=$(CROSS)
BUSYBOX_MAKE  := $(MAKE) -C $(BUSYBOX_SRC) O=$(BUSYBOX_BUILD) CROSS_COMPILE=$(CROSS)

# 目录目标，供 order-only 依赖使用
$(DL_DIR) $(SRC_DIR) $(BUILD_DIR) $(OUT_DIR) $(CFG_DIR):
	@mkdir -p $@

# ---------------------------------------------------------------------------
# 入口目标
# ---------------------------------------------------------------------------
.PHONY: all help prepare busybox busybox-menuconfig rootfs kernel kernel-menuconfig
.PHONY: uimage clean distclean printvars check

all: uimage

help:
	@echo "linux_lite 第一阶段构建"
	@echo
	@echo "  make prepare            解包 dl/ 中的内核与 BusyBox 源码到 src/"
	@echo "  make busybox            静态编译 BusyBox -> out/busybox"
	@echo "  make busybox-menuconfig 修改 BusyBox 配置并回写 config/busybox.config"
	@echo "  make rootfs             生成 out/rootfs.list 与 out/rootfs.cpio"
	@echo "  make kernel             编译内核并生成板级 DTB"
	@echo "  make kernel-menuconfig  修改内核配置并回写 config/kernel.config"
	@echo "  make uimage             打包 legacy uImage -> out/uImage"
	@echo "  make clean              删除 build/ 与 out/"
	@echo "  make distclean          clean 之外再删除 src/"
	@echo "  make printvars          打印当前生效的路径与参数"
	@echo
	@echo "  可覆盖变量: OPENWRT KERNEL_VER BUSYBOX_VER JOBS CROSS UIMAGE_LOADADDR"
	@echo
	@echo "  U-Boot 验证: tftpboot 0x82000000 uImage ; bootm 0x82000000"

printvars:
	@echo "TOPDIR          = $(TOPDIR)"
	@echo "OPENWRT         = $(OPENWRT)"
	@echo "CROSS           = $(CROSS)"
	@echo "MKIMAGE         = $(MKIMAGE)"
	@echo "KERNEL_VER      = $(KERNEL_VER)"
	@echo "BUSYBOX_VER     = $(BUSYBOX_VER)"
	@echo "LINUX_SRC       = $(LINUX_SRC)"
	@echo "LINUX_BUILD     = $(LINUX_BUILD)"
	@echo "OUT_DIR         = $(OUT_DIR)"
	@echo "ARCH_FLAGS      = $(ARCH_FLAGS)"
	@echo "LOADADDR/ENTRY  = $(UIMAGE_LOADADDR) / $(UIMAGE_ENTRY)"

# ---------------------------------------------------------------------------
# 准备阶段
# ---------------------------------------------------------------------------
prepare: check $(LINUX_SRC)/.unpacked $(BUSYBOX_SRC)/.unpacked
	@echo "prepare 完成"

check:
	@test -x "$(CROSS)gcc" || { echo "ERROR: 找不到 $(CROSS)gcc"; exit 1; }
	@test -x "$(MKIMAGE)"  || { echo "ERROR: 找不到 $(MKIMAGE)"; exit 1; }
	@test -x "$(LZMA)"     || { echo "ERROR: 找不到 $(LZMA)"; exit 1; }
	@test -f $(BOARD_DTS_SRC) || { echo "ERROR: 缺少 config/board.dts"; exit 1; }
	@test -f $(BOARD_DTSI) || { echo "ERROR: 缺少 config/mt7621.dtsi"; exit 1; }
	@test -f $(CFG_DIR)/kernel.config || { echo "ERROR: 缺少 config/kernel.config"; exit 1; }
	@test -f $(LOADER_SRC)/loader.c || { echo "ERROR: 缺少 third_party/lzma-loader"; exit 1; }
	@mkdir -p $(DL_DIR) $(SRC_DIR) $(BUILD_DIR) $(OUT_DIR) $(CFG_DIR)

# dl 里的源码包存在时直接使用，缺失才联网下载；不读取 OpenWrt 目录
$(LINUX_TARBALL):
	@mkdir -p $(DL_DIR)
	@echo "  GET    $(notdir $@)"
	@curl -fL -o $@.part https://cdn.kernel.org/pub/linux/kernel/v6.x/$(notdir $@) && mv $@.part $@

$(BUSYBOX_TARBALL):
	@mkdir -p $(DL_DIR)
	@echo "  GET    $(notdir $@)"
	@curl -fL -o $@.part https://busybox.net/downloads/$(notdir $@) && mv $@.part $@

$(LINUX_SRC)/.unpacked: $(LINUX_TARBALL)
	@echo "  UNPACK linux-$(KERNEL_VER)"
	@mkdir -p $(SRC_DIR)
	@tar -xf $< -C $(SRC_DIR)
	@touch $@

$(BUSYBOX_SRC)/.unpacked: $(BUSYBOX_TARBALL)
	@echo "  UNPACK busybox-$(BUSYBOX_VER)"
	@mkdir -p $(SRC_DIR)
	@tar -xf $< -C $(SRC_DIR)
	@touch $@

# ---------------------------------------------------------------------------
# BusyBox：静态链接，musl，软浮点
# ---------------------------------------------------------------------------
$(BUSYBOX_BUILD)/.config: $(BUSYBOX_SRC)/.unpacked | $(OUT_DIR)
	@mkdir -p $(BUSYBOX_BUILD)
	@if [ -f $(CFG_DIR)/busybox.config ]; then \
		cp $(CFG_DIR)/busybox.config $@; \
	else \
		$(BUSYBOX_MAKE) -s defconfig; \
	fi
	@sed -i -e 's/^# CONFIG_STATIC is not set$$/CONFIG_STATIC=y/' \
		-e 's|^CONFIG_PREFIX=.*|CONFIG_PREFIX="/"|' $@
	@grep -q '^CONFIG_STATIC=y' $@ || echo 'CONFIG_STATIC=y' >> $@
	@yes '' | $(BUSYBOX_MAKE) -s oldconfig >/dev/null
	@echo "  CONFIG busybox: CONFIG_STATIC=y CONFIG_PREFIX=/"

$(BUSYBOX_BIN): $(BUSYBOX_BUILD)/.config | $(OUT_DIR)
	$(BUSYBOX_MAKE) -j$(JOBS) EXTRA_CFLAGS="$(ARCH_FLAGS)"
	@cp $(BUSYBOX_BUILD)/busybox $@
	@printf "  BUSYBOX %s (%s 字节)\n" "$(BUSYBOX_BIN)" "$$(stat -c%s $(BUSYBOX_BIN))"

busybox: $(BUSYBOX_BIN)

busybox-menuconfig: $(BUSYBOX_BUILD)/.config
	$(BUSYBOX_MAKE) menuconfig
	@cp $(BUSYBOX_BUILD)/.config $(CFG_DIR)/busybox.config
	@echo "  NOTE   已回写 config/busybox.config"

# ---------------------------------------------------------------------------
# rootfs：由文件清单生成 cpio，设备节点用 nod 描述，无需 root 权限
# ---------------------------------------------------------------------------
$(OVERLAY_DIR)/init:
	@echo "ERROR: 缺少 $(OVERLAY_DIR)/init"
	@echo "       这是第一阶段的启动脚本（plan 6.2），创建后再执行 make rootfs"
	@exit 1

$(BUILD_DIR)/gen_init_cpio: $(LINUX_SRC)/.unpacked $(LINUX_SRC)/usr/gen_init_cpio.c | $(BUILD_DIR)
	@$(HOSTCC) -O2 -o $@ $(LINUX_SRC)/usr/gen_init_cpio.c
	@echo "  HOSTCC $(notdir $@)"

$(ROOTFS_LIST): $(BUSYBOX_BIN) $(OVERLAY_DIR)/init | $(OUT_DIR)
	@echo "  GEN    out/rootfs.list"
	@{ \
		echo "dir /bin 0755 0 0"; \
		echo "dir /dev 0755 0 0"; \
		echo "dir /etc 0755 0 0"; \
		echo "dir /proc 0755 0 0"; \
		echo "dir /sys 0755 0 0"; \
		echo "dir /tmp 1777 0 0"; \
		echo "nod /dev/console 0600 0 0 c 5 1"; \
		echo "nod /dev/null 0666 0 0 c 1 3"; \
		echo "nod /dev/tty 0666 0 0 c 5 0"; \
		echo "file /init $(OVERLAY_DIR)/init 0755 0 0"; \
		echo "file /bin/busybox $(BUSYBOX_BIN) 0755 0 0"; \
		for a in $(APPLETS); do echo "slink /bin/$$a busybox 0777 0 0"; done; \
		cd $(OVERLAY_DIR) && find . -mindepth 1 -type d | sort | while read -r d; do \
			case "$$d" in ./bin|./dev|./etc|./proc|./sys|./tmp) continue;; esac; \
			echo "dir $${d#.} 0755 0 0"; done; \
		cd $(OVERLAY_DIR) && find . -mindepth 1 -type f ! -path ./init | sort | while read -r f; do echo "file $${f#.} $(OVERLAY_DIR)/$${f#./} 0644 0 0"; done; \
	} > $@

$(ROOTFS_CPIO): $(ROOTFS_LIST) $(BUILD_DIR)/gen_init_cpio | $(OUT_DIR)
	@$(BUILD_DIR)/gen_init_cpio $(ROOTFS_LIST) > $@
	@printf "  ROOTFS %s (%s 字节)\n" "$(ROOTFS_CPIO)" "$$(stat -c%s $(ROOTFS_CPIO))"

rootfs: $(ROOTFS_CPIO)

# ---------------------------------------------------------------------------
# Kernel：配置内嵌 initramfs，产物为 vmlinux.bin 与板级 DTB
# ---------------------------------------------------------------------------
$(LINUX_BUILD)/.configured: $(LINUX_SRC)/.unpacked $(CFG_DIR)/kernel.config $(ROOTFS_CPIO)
	@mkdir -p $(LINUX_BUILD)
	@cp $(CFG_DIR)/kernel.config $(LINUX_BUILD)/.config
	@sed -i -e '/^CONFIG_INITRAMFS_SOURCE=/d' \
		-e '/^CONFIG_INITRAMFS_COMPRESSION_/d' \
		-e '/^CONFIG_MIPS_NO_APPENDED_DTB=/d' \
		-e '/^CONFIG_MIPS_ELF_APPENDED_DTB=/d' $(LINUX_BUILD)/.config
	@{ \
		echo 'CONFIG_BLK_DEV_INITRD=y'; \
		echo 'CONFIG_INITRAMFS_SOURCE="$(ROOTFS_CPIO)"'; \
		echo 'CONFIG_INITRAMFS_COMPRESSION_LZMA=y'; \
		echo 'CONFIG_RD_LZMA=y'; \
		echo 'CONFIG_SERIAL_8250=y'; \
		echo 'CONFIG_SERIAL_8250_CONSOLE=y'; \
		echo 'CONFIG_MIPS_RAW_APPENDED_DTB=y'; \
		echo 'CONFIG_MIPS_CMDLINE_FROM_DTB=y'; \
		echo '# CONFIG_BUILTIN_DTB is not set'; \
		echo 'CONFIG_PROC_FS=y'; \
		echo 'CONFIG_SYSFS=y'; \
		echo 'CONFIG_TMPFS=y'; \
	} >> $(LINUX_BUILD)/.config
	$(KERNEL_MAKE) -s olddefconfig
	@grep -q '^CONFIG_INITRAMFS_SOURCE="$(ROOTFS_CPIO)"' $(LINUX_BUILD)/.config \
		|| { echo "ERROR: 内核未接受 INITRAMFS_SOURCE"; exit 1; }
	@for opt in CONFIG_BLK_DEV_INITRD CONFIG_RD_LZMA CONFIG_SERIAL_8250_CONSOLE \
		CONFIG_MIPS_RAW_APPENDED_DTB CONFIG_MIPS_CMDLINE_FROM_DTB; do \
		grep -q "^$$opt=y" $(LINUX_BUILD)/.config \
			|| { echo "ERROR: 内核配置缺少 $$opt"; exit 1; }; \
	done
	@touch $@
	@echo "  CONFIG kernel: INITRAMFS_SOURCE=$(ROOTFS_CPIO)"

$(KERNEL_BIN): $(LINUX_BUILD)/.configured | $(OUT_DIR)
	$(KERNEL_MAKE) -j$(JOBS) vmlinux.bin
	@cp $(LINUX_BUILD)/arch/mips/boot/vmlinux.bin $@
	@printf "  KERNEL %s (%s 字节)\n" "$(KERNEL_BIN)" "$$(stat -c%s $(KERNEL_BIN))"

$(BOARD_DTB): $(BOARD_DTS_SRC) $(BOARD_DTSI) $(LINUX_BUILD)/.configured | $(OUT_DIR)
	@$(KERNEL_MAKE) -s scripts_dtc
	@$(HOSTCC) -E -nostdinc -I $(CFG_DIR) -I $(LINUX_SRC)/scripts/dtc/include-prefixes \
		-undef -D__DTS__ -x assembler-with-cpp -o $@.cpp $(BOARD_DTS_SRC)
	@$(KERNEL_DTC) -I dts -O dtb -b 0 \
		-Wno-interrupt_provider -Wno-unique_unit_address -o $@ $@.cpp
	@rm -f $@.cpp
	@printf "  DTB    %s (%s 字节)\n" "$(BOARD_DTB)" "$$(stat -c%s $(BOARD_DTB))"

kernel: $(KERNEL_BIN) $(BOARD_DTB)

kernel-menuconfig: $(LINUX_BUILD)/.configured
	$(KERNEL_MAKE) menuconfig
	@cp $(LINUX_BUILD)/.config $(CFG_DIR)/kernel.config
	@echo "  NOTE   已回写 config/kernel.config"

# ---------------------------------------------------------------------------
# 镜像：vmlinux.bin + DTB -> lzma -> lzma-loader -> legacy uImage
# ---------------------------------------------------------------------------
$(KERNEL_IMAGE): $(KERNEL_BIN) $(BOARD_DTB) | $(OUT_DIR)
	@cat $(KERNEL_BIN) $(BOARD_DTB) > $@
	@printf "  APPEND dtb -> %s (%s 字节)\n" "$(KERNEL_IMAGE)" "$$(stat -c%s $@)"

$(KERNEL_LZMA): $(KERNEL_IMAGE) | $(OUT_DIR)
	@$(LZMA) e $< -lc1 -lp2 -pb2 $@
	@printf "  LZMA   %s (%s 字节)\n" "$(KERNEL_LZMA)" "$$(stat -c%s $@)"

$(LOADER_BIN): $(KERNEL_LZMA) $(LOADER_SRC)/loader.c | $(OUT_DIR)
	@rm -rf $(LOADER_BUILD)
	@mkdir -p $(LOADER_BUILD)
	@cp -a $(LOADER_SRC)/. $(LOADER_BUILD)/
	$(MAKE) -C $(LOADER_BUILD) \
		CROSS_COMPILE=$(CROSS) \
		SUBTARGET=mt7621 \
		LZMA_TEXT_START=$(LZMA_TEXT_START) \
		LOADADDR=$(UIMAGE_LOADADDR) \
		LOADER_DATA=$(KERNEL_LZMA) \
		CACHE_FLAGS="-DCONFIG_CACHELINE_SIZE=32" \
		clean loader.bin
	@cp $(LOADER_BUILD)/loader.bin $@
	@printf "  LOADER %s (%s 字节)\n" "$(LOADER_BIN)" "$$(stat -c%s $@)"

uimage: $(LOADER_BIN) | $(OUT_DIR)
	@$(MKIMAGE) -A mips -O linux -T kernel -C none \
		-a $(UIMAGE_LOADADDR) -e $(UIMAGE_ENTRY) \
		-n "$(UIMAGE_NAME)" -d $(LOADER_BIN) $(UIMAGE)
	@sz=$$(stat -c%s $(UIMAGE)); \
		printf "  UIMAGE %s (%s 字节)\n" "$(UIMAGE)" "$$sz"; \
		if [ $$sz -gt 4194304 ]; then \
			echo "  WARN   超过 4 MiB，默认 boot_spi 只读 4 MiB，请先用 TFTP 验证"; \
		fi

# ---------------------------------------------------------------------------
# 清理
# ---------------------------------------------------------------------------
clean:
	@rm -rf $(BUILD_DIR) $(OUT_DIR)
	@echo "clean 完成"

distclean: clean
	@rm -rf $(SRC_DIR)
	@echo "distclean 完成（dl/、config/、third_party/ 保留）"
