#!/bin/sh
# ---------------------------------------------------------------------------
# build-kernel.sh：编译内核与板级 DTB
#
# 实际动作：在项目根执行 make kernel
#   - 用 config/kernel.config 生成 build/kernel/.config
#   - 追加固定选项：内嵌 initramfs、LZMA 压缩、8250 串口、appended DTB
#   - 内核编译出 raw 镜像 out/vmlinux.bin
#   - config/board.dts 配合 config/mt7621.dtsi 用内核自带 dtc 编出 out/*.dtb
#   - 首次编译是全量编译，耗时较长
#
# 用法：
#   scripts/build-kernel.sh
#   scripts/build-kernel.sh JOBS=8
# ---------------------------------------------------------------------------

set -eu
# -e：任何一条命令失败就立刻退出
# -u：引用未定义变量时报错退出

TOPDIR=$(cd "$(dirname "$0")/.." && pwd)
# 定位项目根目录，规则同 prepare.sh

exec make -C "$TOPDIR" "$@" kernel
# kernel 是 Makefile 目标，完成后产物在 out/vmlinux.bin 与 out/linux_lite_hlk7621.dtb
