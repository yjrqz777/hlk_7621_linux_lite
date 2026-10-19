#!/bin/sh
# ---------------------------------------------------------------------------
# build-rootfs.sh：生成 out/rootfs.list 与 out/rootfs.cpio
#
# 实际动作：在项目根执行 make rootfs
#   - 依赖 out/busybox 与 rootfs-overlay/init，缺任何一个都会报错
#   - rootfs.list 是文件清单：目录、设备节点、/init、/bin/busybox、applet 软链
#   - 设备节点用 nod 行描述（c 5 1 等），不需要 root 权限做 mknod
#   - 清单交给内核自带的 gen_init_cpio 生成 cpio，供内核内嵌
#
# 用法：
#   scripts/build-rootfs.sh
#   scripts/build-rootfs.sh APPLETS="sh mount cat"
# ---------------------------------------------------------------------------

set -eu
# -e：任何一条命令失败就立刻退出
# -u：引用未定义变量时报错退出

TOPDIR=$(cd "$(dirname "$0")/.." && pwd)
# 定位项目根目录，规则同 prepare.sh

exec make -C "$TOPDIR" "$@" rootfs
# rootfs 是 Makefile 目标，完成后产物是 out/rootfs.cpio
