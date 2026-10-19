#!/bin/sh
# ---------------------------------------------------------------------------
# build-busybox.sh：静态编译 BusyBox 到 out/busybox
#
# 实际动作：在项目根执行 make busybox
#   - 配置来自 config/busybox.config，没有该文件就用 BusyBox 默认配置
#   - 强制打开 CONFIG_STATIC，去掉动态链接依赖
#   - 用 musl 交叉编译器编译，产物复制到 out/busybox
#
# 用法：
#   scripts/build-busybox.sh
#   scripts/build-busybox.sh JOBS=4
# ---------------------------------------------------------------------------

set -eu
# -e：任何一条命令失败就立刻退出
# -u：引用未定义变量时报错退出

TOPDIR=$(cd "$(dirname "$0")/.." && pwd)
# 定位项目根目录，规则同 prepare.sh

exec make -C "$TOPDIR" "$@" busybox
# busybox 是 Makefile 目标，完成后产物在 out/busybox
