#!/bin/sh
# ---------------------------------------------------------------------------
# make-uimage.sh：打包 legacy uImage 到 out/uImage
#
# 实际动作：在项目根执行 make uimage
#   - vmlinux.bin 尾部拼接板级 DTB，得到 kernel-dtb.bin
#   - 用 lzma 压缩成 kernel-dtb.lzma
#   - 把压缩后的内核塞进 lzma-loader，编译出 out/loader.bin
#   - 用 mkimage 打成 legacy uImage，加载与入口地址都是 0x80001000
#   - 产物超过 4 MiB 会提示：默认 boot_spi 只读 4 MiB，需要改 U-Boot 环境或继续用 TFTP
#
# 用法：
#   scripts/make-uimage.sh
#   scripts/make-uimage.sh UIMAGE_NAME="MIPS Linux Lite"
# ---------------------------------------------------------------------------

set -eu
# -e：任何一条命令失败就立刻退出
# -u：引用未定义变量时报错退出

TOPDIR=$(cd "$(dirname "$0")/.." && pwd)
# 定位项目根目录，规则同 prepare.sh

exec make -C "$TOPDIR" "$@" uimage
# uimage 是 Makefile 目标，产物是 out/uImage
